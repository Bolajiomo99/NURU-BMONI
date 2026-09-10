"""
Regression tests for the NURU API.
These are deterministic gate tests: no network, no real LLM calls.
"""

import os
from decimal import Decimal
from unittest import mock

from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from rest_framework.authtoken.models import Token

import api.ai_engine as ai_engine
from .analytics import get_financial_summary
from .seed_data import seed_demo_data
from .models import Transaction


def _round(value, places=2):
    return round(float(value), places)


class BaseApiTestCase(TestCase):
    def setUp(self):
        self.user = seed_demo_data()
        self.client.defaults['HTTP_X_BMONI_USER_ID'] = self.user.bmoni_user_id
        # Identity comes from the auth token. Link the seeded profile to a real
        # account so these tests act as Bolaji rather than as the zero-balance
        # guest profile that unauthenticated requests now resolve to.
        self.auth_user = User.objects.create_user(
            username=self.user.email,
            email=self.user.email,
            password='demo-pass-123',
        )
        self.user.user = self.auth_user
        self.user.save(update_fields=['user'])
        self.token = Token.objects.create(user=self.auth_user)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Token {self.token.key}'


class DashboardTestCase(BaseApiTestCase):
    def test_dashboard_returns_full_payload(self):
        resp = self.client.get('/api/dashboard/')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('health_score', data)
        self.assertTrue(0 <= data['health_score'] <= 100)
        self.assertEqual(
            set(data['balances'].keys()),
            {'usd', 'ngn', 'total_usd_equivalent'},
        )
        self.assertIsInstance(data['recent_transactions'], list)
        self.assertIsInstance(data['categories'], list)
        self.assertTrue(data['safe_weekly_spend_usd'] > 0)


class GuestDashboardTestCase(BaseApiTestCase):
    """Option A: an unauthenticated caller sees zeros, not someone else's money."""

    def test_unauthenticated_dashboard_is_empty(self):
        self.client.defaults.pop('HTTP_AUTHORIZATION', None)
        self.client.defaults.pop('HTTP_X_BMONI_USER_ID', None)
        resp = self.client.get('/api/dashboard/')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(_round(data['balances']['usd']), 0.0)
        self.assertEqual(_round(data['balances']['ngn']), 0.0)


class AffordabilityTestCase(BaseApiTestCase):
    def test_afford_valid_amount(self):
        resp = self.client.get('/api/afford/?amount=100')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('can_afford', data)
        self.assertIn('within_safe_range', data)

    def test_afford_invalid_amount_returns_400(self):
        resp = self.client.get('/api/afford/?amount=abc')
        self.assertEqual(resp.status_code, 400)


class ChatTestCase(BaseApiTestCase):
    def _mock_ai_down(self):
        """Force every Gemini call to fail so the graceful path is exercised."""
        return mock.patch.object(
            ai_engine, '_get_client', side_effect=RuntimeError('LLM unavailable')
        )

    def test_chat_returns_200_when_llm_unavailable(self):
        with self._mock_ai_down():
            resp = self.client.post(
                '/api/chat/',
                {'message': "Can I afford to send $100 to my family?"},
                content_type='application/json',
            )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('message', data)
        self.assertIsNotNone(data.get('error'))


class TransferActionTestCase(BaseApiTestCase):
    def test_transfer_debits_balance(self):
        resp = self.client.post(
            '/api/action/transfer/',
            {
                'amount': '100',
                'currency': 'USD',
                'to_address': '0x0000000000000000000000000000000000000000',
            },
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data['success'])
        self.assertEqual(_round(data['updated_balance']['usd']), 2205.55)


class SwapActionTestCase(BaseApiTestCase):
    def test_swap_usd_to_ngn_stores_two_decimal_amounts(self):
        resp = self.client.post(
            '/api/action/swap/',
            {'amount': '50', 'from_currency': 'USD', 'to_currency': 'NGN'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        # 140,000 + 50/0.00062 = 220,645.16. Must be exact — a float artifact
        # like 220645.161290323 proves the amount was never quantized.
        self.assertEqual(data['updated_balance']['ngn'], 220645.16)

        # Every stored amount must respect the 2-decimal money format.
        for txn in Transaction.objects.filter(user=self.user, category='conversion'):
            self.assertEqual(
                txn.amount,
                txn.amount.quantize(Decimal('0.01')),
                f"Amount {txn.amount} has more than 2 decimal places",
            )

    def test_swap_ngn_to_usd(self):
        resp = self.client.post(
            '/api/action/swap/',
            {'amount': '100000', 'from_currency': 'NGN', 'to_currency': 'USD'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        # 100000 NGN is debited, 62.00 USD is credited to the USD balance.
        self.assertEqual(_round(data['updated_balance']['usd']), 2305.55 + 62.00)


class ExplainTestCase(BaseApiTestCase):
    def test_explain_returns_fallback_story_when_llm_unavailable(self):
        with mock.patch.object(
            ai_engine, '_get_client', side_effect=RuntimeError('LLM unavailable')
        ):
            resp = self.client.get('/api/explain/')
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn('story', data)
        self.assertIn('summary', data)


class GeminiClientTestCase(TestCase):
    def test_get_client_does_not_raise_name_error_without_key(self):
        # Regression: ai_engine called os.getenv() without importing os,
        # so any key-less build crashed with NameError before the SDK could
        # raise its own (expected) "no API key" error.
        with mock.patch.dict(os.environ, {}, clear=True):
            with override_settings(GEMINI_API_KEY=''):
                try:
                    ai_engine._get_client()
                    self.fail('Expected genai to reject a missing API key')
                except NameError:
                    self.fail('_get_client raised NameError (os not imported)')
                except ValueError:
                    pass  # Expected: SDK requires an API key.


class HealthScoreTestCase(TestCase):
    def test_health_score_clamped_between_zero_and_100(self):
        user = seed_demo_data()
        summary = get_financial_summary(user)
        self.assertTrue(0 <= summary['health_score'] <= 100)
        self.assertTrue(summary['safe_weekly_spend_usd'] > 0)


class SecurityAuthTestCase(BaseApiTestCase):
    def test_pin_and_face_flow(self):
        # 1. Initial status: no PIN
        resp = self.client.get('/api/auth/security-status/')
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.json()['has_pin'])

        # 2. Setup PIN
        resp = self.client.post('/api/auth/pin/setup/', {'pin': '7392'}, content_type='application/json')
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()['has_pin'])

        # Verify hashed, not plain
        self.user.refresh_from_db()
        self.assertTrue(self.user.has_pin)
        self.assertNotEqual(self.user.transaction_pin_hash, '7392')
        self.assertTrue(self.user.check_pin('7392'))
        self.assertFalse(self.user.check_pin('0000'))

        # 3. Verify PIN via API
        resp = self.client.post('/api/auth/pin/verify/', {'pin': '7392'}, content_type='application/json')
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()['success'])

        # Wrong PIN via API
        resp = self.client.post('/api/auth/pin/verify/', {'pin': '1111'}, content_type='application/json')
        self.assertEqual(resp.status_code, 400)

        # 4. Enroll Face
        resp = self.client.post('/api/auth/face/enroll/', {'face_image': 'data:image/jpeg;base64,sample'}, content_type='application/json')
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()['face_enrolled'])

        # 5. Verify Face 2FA
        resp = self.client.post('/api/auth/face/verify/', {'face_image': 'data:image/jpeg;base64,sample2'}, content_type='application/json')
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.json()['matched'])

    def test_transfer_action_step_label_is_security_policy_verification(self):
        payload = {
            'amount': '25.00',
            'currency': 'USD',
            'account_number': '0123456789',
            'bank_name': 'Access Bank',
            'account_name': 'Zainab Ahmed',
        }
        resp = self.client.post('/api/action/transfer/', payload, content_type='application/json')
        self.assertEqual(resp.status_code, 200)
        steps = resp.json()['steps']
        step_labels = [s['label'] for s in steps]
        self.assertIn('Security Policy Verification', step_labels)
        self.assertNotIn('Admin Approval', step_labels)
