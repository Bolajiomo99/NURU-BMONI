"""
Smoke tests for the email/password auth flow (CP1).

Happy path plus the failure modes that are easy to get wrong. The full matrix
(enumeration, cooldown, reset-token reuse, identity precedence) lands at CP7.

No network: email_service is patched so Resend is never called, and the OTP
code is read back out of the issue_otp call rather than from an inbox.
"""

from unittest import mock

from django.contrib.auth.models import User
from django.test import TestCase, override_settings

from .models import OTP, UserProfile

# Django 6 defaults to ~1.2M PBKDF2 iterations; these hash a password and an
# OTP per test, which dominates the runtime otherwise.
FAST_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']


@override_settings(PASSWORD_HASHERS=FAST_HASHERS)
class AuthFlowTestCase(TestCase):
    """End-to-end: signup -> verify -> token -> authenticated dashboard."""

    def setUp(self):
        patcher = mock.patch('api.auth_utils.send_otp_email')
        self.mock_send = patcher.start()
        self.addCleanup(patcher.stop)

    def _signup(self, email='ada@example.com', password='str0ng-passphrase!'):
        return self.client.post(
            '/api/auth/signup/',
            {
                'name': 'Ada Obi',
                'email': email,
                'password': password,
                'confirm_password': password,
            },
            content_type='application/json',
        )

    def _sent_code(self):
        """The code handed to the emailer on the most recent send."""
        return self.mock_send.call_args[0][1]

    def test_signup_creates_inactive_user_and_sends_code(self):
        resp = self._signup()
        self.assertEqual(resp.status_code, 201)

        user = User.objects.get(username='ada@example.com')
        self.assertFalse(user.is_active)
        self.assertEqual(user.first_name, 'Ada')
        self.assertEqual(user.last_name, 'Obi')
        self.assertEqual(OTP.objects.filter(purpose='signup').count(), 1)

        self.mock_send.assert_called_once()
        code = self._sent_code()
        self.assertEqual(len(code), 6)
        self.assertTrue(code.isdigit())
        # The code must never travel in the HTTP response.
        self.assertNotIn(code, resp.content.decode())

    def test_verify_activates_user_and_returns_working_token(self):
        self._signup()
        resp = self.client.post(
            '/api/auth/verify-otp/',
            {'email': 'ada@example.com', 'code': self._sent_code()},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 200)
        token = resp.json()['token']

        user = User.objects.get(username='ada@example.com')
        self.assertTrue(user.is_active)

        # A profile must exist or the dashboard cannot render for this account.
        profile = UserProfile.objects.get(user=user)
        self.assertTrue(profile.bmoni_user_id.startswith('nuru-'))

        dash = self.client.get('/api/dashboard/', HTTP_AUTHORIZATION=f'Token {token}')
        self.assertEqual(dash.status_code, 200)

    def test_wrong_code_counts_down_attempts(self):
        self._signup()
        for expected_remaining in (4, 3, 2, 1):
            resp = self.client.post(
                '/api/auth/verify-otp/',
                {'email': 'ada@example.com', 'code': '000000'},
                content_type='application/json',
            )
            self.assertEqual(resp.status_code, 400)
            self.assertEqual(resp.json()['error'], 'invalid_code')
            self.assertEqual(resp.json()['attempts_remaining'], expected_remaining)

        # 5th wrong attempt exhausts the code.
        resp = self.client.post(
            '/api/auth/verify-otp/',
            {'email': 'ada@example.com', 'code': '000000'},
            content_type='application/json',
        )
        self.assertEqual(resp.json()['error'], 'too_many_attempts')
        self.assertFalse(User.objects.get(username='ada@example.com').is_active)

    def test_resend_is_rate_limited_by_the_cooldown(self):
        self._signup()
        resp = self.client.post(
            '/api/auth/resend-otp/',
            {'email': 'ada@example.com'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 429)
        self.assertEqual(resp.json()['error'], 'cooldown')
        # The original code must survive a throttled resend.
        self.assertEqual(self.mock_send.call_count, 1)

    @override_settings(OTP_RESEND_COOLDOWN_SECONDS=0)
    def test_resend_invalidates_the_previous_code(self):
        self._signup()
        first_code = self._sent_code()

        resend = self.client.post(
            '/api/auth/resend-otp/',
            {'email': 'ada@example.com'},
            content_type='application/json',
        )
        self.assertEqual(resend.status_code, 200)
        second_code = self._sent_code()
        self.assertNotEqual(first_code, second_code)

        stale = self.client.post(
            '/api/auth/verify-otp/',
            {'email': 'ada@example.com', 'code': first_code},
            content_type='application/json',
        )
        self.assertEqual(stale.status_code, 400)

        fresh = self.client.post(
            '/api/auth/verify-otp/',
            {'email': 'ada@example.com', 'code': second_code},
            content_type='application/json',
        )
        self.assertEqual(fresh.status_code, 200)

    def test_login_rejects_unverified_account_with_actionable_error(self):
        self._signup()
        resp = self.client.post(
            '/api/auth/login/',
            {'email': 'ada@example.com', 'password': 'str0ng-passphrase!'},
            content_type='application/json',
        )
        # 403 + email_not_verified is what routes the app to the OTP screen
        # instead of showing "wrong password" for a correct password.
        self.assertEqual(resp.status_code, 403)
        self.assertEqual(resp.json()['error'], 'email_not_verified')

    def test_login_after_verification_returns_token(self):
        self._signup()
        self.client.post(
            '/api/auth/verify-otp/',
            {'email': 'ada@example.com', 'code': self._sent_code()},
            content_type='application/json',
        )
        resp = self.client.post(
            '/api/auth/login/',
            # Email lookups are case-insensitive.
            {'email': 'ADA@example.com', 'password': 'str0ng-passphrase!'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 200)
        self.assertIn('token', resp.json())

    def test_signup_rejects_mismatched_passwords_without_creating_a_user(self):
        resp = self.client.post(
            '/api/auth/signup/',
            {
                'name': 'Ada Obi',
                'email': 'ada@example.com',
                'password': 'str0ng-passphrase!',
                'confirm_password': 'something-else',
            },
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 400)
        self.assertFalse(User.objects.filter(username='ada@example.com').exists())
        self.mock_send.assert_not_called()


@override_settings(PASSWORD_HASHERS=FAST_HASHERS)
class PasswordResetTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='ada@example.com',
            email='ada@example.com',
            password='old-passphrase-1!',
        )
        patcher = mock.patch('api.auth_utils.send_password_reset_email')
        self.mock_send = patcher.start()
        self.addCleanup(patcher.stop)

    def _request_reset(self, email='ada@example.com'):
        return self.client.post(
            '/api/auth/forgot-password/', {'email': email}, content_type='application/json'
        )

    def test_unknown_email_returns_200_and_sends_nothing(self):
        resp = self._request_reset('nobody@example.com')
        self.assertEqual(resp.status_code, 200)
        self.mock_send.assert_not_called()

    def test_reset_token_is_single_use_and_changes_the_password(self):
        self._request_reset()
        raw_token = self.mock_send.call_args[0][1]

        body = {
            'token': raw_token,
            'new_password': 'brand-new-passphrase!',
            'confirm_password': 'brand-new-passphrase!',
        }
        first = self.client.post(
            '/api/auth/reset-password/', body, content_type='application/json'
        )
        self.assertEqual(first.status_code, 200)

        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('brand-new-passphrase!'))
        self.assertFalse(self.user.check_password('old-passphrase-1!'))

        # Replaying the same token must fail.
        second = self.client.post(
            '/api/auth/reset-password/', body, content_type='application/json'
        )
        self.assertEqual(second.status_code, 400)
