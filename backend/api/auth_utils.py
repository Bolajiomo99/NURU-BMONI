"""
Auth helpers: OTP issuance and verification, reset tokens, profile bridging.

Views stay thin; the rules about expiry, attempt counts and invalidation live
here so they are testable without going through HTTP.
"""

import logging
import secrets
from datetime import timedelta
from uuid import uuid4

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.utils import timezone

from .email_service import send_otp_email, send_password_reset_email
from .models import OTP, PasswordResetToken, UserProfile

logger = logging.getLogger(__name__)


def split_name(name):
    """Split a free-text full name into (first, last). Last may be ''."""
    parts = (name or '').strip().split()
    if not parts:
        return '', ''
    return parts[0], ' '.join(parts[1:])


def generate_otp_code():
    """A cryptographically random 6-digit code, leading zeros preserved."""
    return ''.join(secrets.choice('0123456789') for _ in range(6))


def hash_code(code):
    return make_password(code)


def check_code(code, code_hash):
    return check_password(code, code_hash)


def issue_otp(email, purpose='signup', enforce_cooldown=True):
    """Invalidate any outstanding code for this email+purpose, then send a new one.

    Returns (otp, error_code). error_code is 'cooldown' when the caller asked
    for a resend too soon, in which case no new code is issued.
    """
    email = email.lower().strip()
    outstanding = OTP.objects.filter(email=email, purpose=purpose, used_at__isnull=True)

    if enforce_cooldown:
        latest = outstanding.order_by('-created_at').first()
        if latest is not None:
            age = (timezone.now() - latest.created_at).total_seconds()
            if age < settings.OTP_RESEND_COOLDOWN_SECONDS:
                return None, 'cooldown'

    # Burn the old codes before minting a new one, so the previous email's
    # code stops working the moment a replacement is sent.
    outstanding.update(used_at=timezone.now())

    code = generate_otp_code()
    otp = OTP.objects.create(
        email=email,
        code_hash=hash_code(code),
        purpose=purpose,
        expires_at=timezone.now() + timedelta(minutes=settings.OTP_TTL_MINUTES),
    )
    send_otp_email(email, code, purpose)
    return otp, None


def verify_otp(email, code, purpose='signup'):
    """Check a submitted code.

    Returns (ok, error_code, attempts_remaining). error_code is one of
    'no_code', 'expired', 'too_many_attempts', 'invalid_code'.
    """
    email = email.lower().strip()
    otp = (
        OTP.objects.filter(email=email, purpose=purpose, used_at__isnull=True)
        .order_by('-created_at')
        .first()
    )
    if otp is None:
        return False, 'no_code', 0

    if timezone.now() >= otp.expires_at:
        otp.used_at = timezone.now()
        otp.save(update_fields=['used_at'])
        return False, 'expired', 0

    if otp.attempts >= settings.OTP_MAX_ATTEMPTS:
        otp.used_at = timezone.now()
        otp.save(update_fields=['used_at'])
        return False, 'too_many_attempts', 0

    if not check_code(code, otp.code_hash):
        otp.attempts += 1
        otp.save(update_fields=['attempts'])
        remaining = max(settings.OTP_MAX_ATTEMPTS - otp.attempts, 0)
        if remaining == 0:
            otp.used_at = timezone.now()
            otp.save(update_fields=['used_at'])
            return False, 'too_many_attempts', 0
        return False, 'invalid_code', remaining

    otp.used_at = timezone.now()
    otp.save(update_fields=['used_at'])
    return True, None, 0


def issue_reset_token(user):
    """Mint a single-use password reset token and email it. Returns the raw token."""
    PasswordResetToken.objects.filter(user=user, used_at__isnull=True).update(
        used_at=timezone.now()
    )
    raw = secrets.token_urlsafe(32)
    PasswordResetToken.objects.create(
        user=user,
        token_hash=hash_code(raw),
        expires_at=timezone.now() + timedelta(minutes=settings.PASSWORD_RESET_TTL_MINUTES),
    )
    send_password_reset_email(user.email, raw)
    return raw


def consume_reset_token(raw_token):
    """Validate and burn a reset token. Returns (user, error_code).

    The hash is salted per-row, so this scans unused, unexpired tokens rather
    than looking one up by hash. Volume is low enough for that to be fine.
    """
    if not raw_token:
        return None, 'invalid_token'
    candidates = PasswordResetToken.objects.filter(
        used_at__isnull=True, expires_at__gt=timezone.now()
    ).select_related('user')
    for token in candidates:
        if check_code(raw_token, token.token_hash):
            token.used_at = timezone.now()
            token.save(update_fields=['used_at'])
            return token.user, None
    return None, 'invalid_token'


def ensure_user_profile(user):
    """Return the UserProfile for an auth user, creating or adopting one.

    Every downstream feature (dashboard, chat, analytics) is keyed on
    UserProfile, so a freshly verified account needs one before it can load the
    app at all.

    The 'nuru-' prefix on bmoni_user_id is load-bearing: analytics._get_balances
    skips live BMONI lookups for these profiles.
    """
    profile = UserProfile.objects.filter(user=user).first()
    if profile is not None:
        return profile

    # Adopt an unlinked profile with the same email if one exists, so a user
    # who was seeded or previously created does not end up with two rows.
    profile = UserProfile.objects.filter(
        email__iexact=user.email, user__isnull=True
    ).first()

    if profile is None:
        profile = UserProfile(
            bmoni_user_id=f'nuru-{uuid4().hex[:12]}',
            first_name=user.first_name or '',
            last_name=user.last_name or '',
            email=user.email,
            phone_number='',
        )

    profile.user = user
    profile.save()
    logger.info(f"Linked UserProfile {profile.bmoni_user_id} to auth user {user.pk}")
    return profile
