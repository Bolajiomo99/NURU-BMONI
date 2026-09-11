"""
Transaction PIN helpers: setup, verification, and lockout bookkeeping.

Views stay thin; the rules about attempt counts and lockout windows live
here so they are testable without going through HTTP.
"""

import logging
from datetime import timedelta

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.utils import timezone

from .models import TransactionSecurity

logger = logging.getLogger(__name__)

PIN_LENGTH = 4


def get_or_create_security(user):
    security, _ = TransactionSecurity.objects.get_or_create(user=user)
    return security


def validate_pin_format(pin):
    """Return an error message, or None if `pin` is an acceptable PIN."""
    if not isinstance(pin, str) or not pin.isdigit() or len(pin) != PIN_LENGTH:
        return f'PIN must be exactly {PIN_LENGTH} digits.'
    return None


def setup_pin(user, pin):
    """Set (or replace) the transaction PIN. Clears any existing lockout."""
    security = get_or_create_security(user)
    security.pin_hash = make_password(pin)
    security.pin_set_at = timezone.now()
    security.pin_failed_attempts = 0
    security.pin_locked_until = None
    security.save(update_fields=[
        'pin_hash', 'pin_set_at', 'pin_failed_attempts', 'pin_locked_until', 'updated_at',
    ])
    return security


def verify_pin(user, pin):
    """Check a submitted PIN against the stored hash.

    Returns (ok, error_code) where error_code is one of 'no_pin', 'locked',
    'incorrect', or None on success. A correct guess resets the failure
    counter; an incorrect one increments it and locks the account out once
    TRANSACTION_PIN_MAX_ATTEMPTS is reached.
    """
    security = get_or_create_security(user)

    if not security.pin_hash:
        return False, 'no_pin'

    if security.pin_locked_until and timezone.now() < security.pin_locked_until:
        return False, 'locked'

    if check_password(pin, security.pin_hash):
        if security.pin_failed_attempts or security.pin_locked_until:
            security.pin_failed_attempts = 0
            security.pin_locked_until = None
            security.save(update_fields=['pin_failed_attempts', 'pin_locked_until', 'updated_at'])
        return True, None

    security.pin_failed_attempts += 1
    if security.pin_failed_attempts >= settings.TRANSACTION_PIN_MAX_ATTEMPTS:
        security.pin_locked_until = timezone.now() + timedelta(
            minutes=settings.TRANSACTION_PIN_LOCKOUT_MINUTES
        )
        security.save(update_fields=['pin_failed_attempts', 'pin_locked_until', 'updated_at'])
        return False, 'locked'

    security.save(update_fields=['pin_failed_attempts', 'updated_at'])
    return False, 'incorrect'


def record_face_check(user):
    """Log that a (placeholder) face-2FA check was requested. See
    TransactionSecurity's docstring: this is not a real biometric match."""
    security = get_or_create_security(user)
    security.last_face_check_at = timezone.now()
    security.save(update_fields=['last_face_check_at', 'updated_at'])
    return security
