"""
Tests for the transaction PIN + face-2FA endpoints (CP5b follow-up).

Covers PIN setup, correct/incorrect verification, lockout after repeated
failures, the face-check endpoint, and that guests can't reach any of it.
"""

from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.authtoken.models import Token

from .models import TransactionSecurity

FAST_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']


@override_settings(PASSWORD_HASHERS=FAST_HASHERS)
class TransactionSecurityTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='ada@example.com', email='ada@example.com', password='irrelevant',
        )
        self.token = Token.objects.create(user=self.user)
        self.auth_headers = {'HTTP_AUTHORIZATION': f'Token {self.token.key}'}

    def _get(self, path):
        return self.client.get(path, **self.auth_headers)

    def _post(self, path, body):
        return self.client.post(path, body, content_type='application/json', **self.auth_headers)

    def test_status_defaults_to_no_pin(self):
        resp = self._get('/api/security/status/')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {'has_pin': False})

    def test_setup_pin_then_status_reflects_it(self):
        resp = self._post('/api/security/pin/setup/', {'pin': '1234'})
        self.assertEqual(resp.status_code, 200)

        resp = self._get('/api/security/status/')
        self.assertEqual(resp.json(), {'has_pin': True})

        security = TransactionSecurity.objects.get(user=self.user)
        self.assertNotEqual(security.pin_hash, '1234')
        self.assertTrue(security.pin_hash)

    def test_setup_pin_rejects_non_4_digit(self):
        for bad in ['12', '12345', 'abcd', '']:
            resp = self._post('/api/security/pin/setup/', {'pin': bad})
            self.assertEqual(resp.status_code, 400, bad)

    def test_verify_pin_before_setup_fails(self):
        resp = self._post('/api/security/pin/verify/', {'pin': '1234'})
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()['error'], 'no_pin')

    def test_verify_correct_pin_succeeds(self):
        self._post('/api/security/pin/setup/', {'pin': '4321'})
        resp = self._post('/api/security/pin/verify/', {'pin': '4321'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {'verified': True})

    def test_verify_incorrect_pin_fails_and_counts_attempt(self):
        self._post('/api/security/pin/setup/', {'pin': '4321'})
        resp = self._post('/api/security/pin/verify/', {'pin': '0000'})
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()['error'], 'incorrect')

        security = TransactionSecurity.objects.get(user=self.user)
        self.assertEqual(security.pin_failed_attempts, 1)

    def test_lockout_after_max_attempts(self):
        self._post('/api/security/pin/setup/', {'pin': '4321'})

        from django.conf import settings
        for _ in range(settings.TRANSACTION_PIN_MAX_ATTEMPTS):
            resp = self._post('/api/security/pin/verify/', {'pin': '0000'})

        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()['error'], 'locked')

        # Even the correct PIN is refused while locked.
        resp = self._post('/api/security/pin/verify/', {'pin': '4321'})
        self.assertEqual(resp.json()['error'], 'locked')

    def test_lockout_clears_after_window_expires(self):
        self._post('/api/security/pin/setup/', {'pin': '4321'})
        security = TransactionSecurity.objects.get(user=self.user)
        security.pin_failed_attempts = 5
        security.pin_locked_until = timezone.now() - timezone.timedelta(seconds=1)
        security.save()

        resp = self._post('/api/security/pin/verify/', {'pin': '4321'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {'verified': True})

    def test_correct_pin_resets_failed_attempts(self):
        self._post('/api/security/pin/setup/', {'pin': '4321'})
        self._post('/api/security/pin/verify/', {'pin': '0000'})
        self._post('/api/security/pin/verify/', {'pin': '4321'})

        security = TransactionSecurity.objects.get(user=self.user)
        self.assertEqual(security.pin_failed_attempts, 0)

    def test_verify_face_records_timestamp(self):
        resp = self._post('/api/security/face/verify/', {'image': 'data:image/jpeg;base64,x'})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {'verified': True})

        security = TransactionSecurity.objects.get(user=self.user)
        self.assertIsNotNone(security.last_face_check_at)

    def test_verify_face_requires_image_field(self):
        resp = self._post('/api/security/face/verify/', {})
        self.assertEqual(resp.status_code, 400)

    def test_unauthenticated_requests_rejected(self):
        for path, body in [
            ('/api/security/status/', None),
            ('/api/security/pin/setup/', {'pin': '1234'}),
            ('/api/security/pin/verify/', {'pin': '1234'}),
            ('/api/security/face/verify/', {'image': 'x'}),
        ]:
            resp = (
                self.client.get(path) if body is None
                else self.client.post(path, body, content_type='application/json')
            )
            self.assertEqual(resp.status_code, 401, path)
