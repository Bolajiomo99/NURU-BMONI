"""
Resend transactional email.

Follows the same contract as BmoniClient._request: never raises, always returns
{'status_code', 'data', 'success'}. Callers check res['success'] and carry on —
a failed email must not roll back a signup.

With no RESEND_API_KEY set, sends are skipped and the OTP code / reset link are
logged at WARNING instead, so local dev and the test suite work without a key.
"""

import logging

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

RESEND_ENDPOINT = 'https://api.resend.com/emails'


def send_email(to, subject, html, text=None):
    """POST one email to Resend. Returns the standard envelope."""
    if not settings.RESEND_API_KEY:
        logger.warning(
            f"RESEND_API_KEY unset — skipping email to {to}. "
            f"Subject: {subject}. Body: {text or html}"
        )
        return {'status_code': 0, 'data': {}, 'success': False, 'skipped': True}

    payload = {
        'from': settings.RESEND_FROM_EMAIL,
        'to': [to],
        'subject': subject,
        'html': html,
    }
    if text:
        payload['text'] = text

    try:
        response = requests.post(
            RESEND_ENDPOINT,
            headers={
                'Authorization': f'Bearer {settings.RESEND_API_KEY}',
                'Content-Type': 'application/json',
            },
            json=payload,
            timeout=15,
        )
        logger.info(f"RESEND POST /emails → {response.status_code}")
        if response.status_code >= 400:
            logger.error(f"Resend error: {response.text}")
        return {
            'status_code': response.status_code,
            'data': response.json() if response.text else {},
            'success': 200 <= response.status_code < 300,
        }
    except requests.exceptions.RequestException as e:
        logger.error(f"Resend request failed: {e}")
        return {'status_code': 500, 'data': {'error': str(e)}, 'success': False}
    except ValueError as e:
        # Non-JSON body (an HTML 502 from a proxy) is not a RequestException.
        logger.error(f"Resend returned a non-JSON body: {e}")
        return {'status_code': 502, 'data': {'error': 'invalid_response'}, 'success': False}


def send_otp_email(email, code, purpose='signup'):
    """Email a 6-digit verification code."""
    ttl = settings.OTP_TTL_MINUTES
    if purpose == 'reset':
        subject = 'Your NURU password reset code'
        lead = 'Use this code to reset your NURU password.'
    else:
        subject = 'Verify your NURU account'
        lead = 'Welcome to NURU. Use this code to finish setting up your account.'

    html = f"""
      <div style="font-family:system-ui,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px">
        <h1 style="font-size:20px;margin:0 0 8px">NURU</h1>
        <p style="color:#555;margin:0 0 24px">{lead}</p>
        <p style="font-size:34px;font-weight:700;letter-spacing:8px;margin:0 0 24px">{code}</p>
        <p style="color:#777;font-size:13px;margin:0">
          This code expires in {ttl} minutes. If you didn't request it, you can ignore this email.
        </p>
      </div>
    """
    text = f"NURU verification code: {code}\n\nThis code expires in {ttl} minutes."
    return send_email(email, subject, html, text)


def send_password_reset_email(email, token):
    """Email a password-reset link plus the raw token.

    The raw token is included because the mobile app has no deep-link scheme
    configured yet — ResetPasswordScreen accepts a pasted token.
    """
    link = f"{settings.FRONTEND_BASE_URL.rstrip('/')}/#/auth/reset?token={token}"
    ttl = settings.PASSWORD_RESET_TTL_MINUTES
    html = f"""
      <div style="font-family:system-ui,sans-serif;max-width:480px;margin:0 auto;padding:32px 24px">
        <h1 style="font-size:20px;margin:0 0 8px">Reset your NURU password</h1>
        <p style="color:#555;margin:0 0 24px">Tap the button below, or paste the code into the app.</p>
        <p style="margin:0 0 24px">
          <a href="{link}" style="background:#00D09E;color:#0A0E1A;text-decoration:none;
             padding:12px 24px;border-radius:10px;font-weight:600;display:inline-block">Reset password</a>
        </p>
        <p style="color:#555;font-size:13px;margin:0 0 8px">Or paste this code:</p>
        <p style="font-family:monospace;font-size:13px;word-break:break-all;margin:0 0 24px">{token}</p>
        <p style="color:#777;font-size:13px;margin:0">
          This link expires in {ttl} minutes. If you didn't request it, you can ignore this email.
        </p>
      </div>
    """
    text = f"Reset your NURU password: {link}\n\nOr paste this code into the app:\n{token}\n\nExpires in {ttl} minutes."
    return send_email(email, 'Reset your NURU password', html, text)
