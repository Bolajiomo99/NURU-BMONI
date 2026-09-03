"""
Regression tests for the NURU API.
These are deterministic gate tests: no network, no real LLM calls.
"""

import os
from decimal import Decimal
from unittest import mock

from django.test import TestCase, override_settings

import api.ai_engine as ai_engine
from .analytics import get_financial_summary
from .seed_data import seed_demo_data
from .models import Transaction


def _round(value, places=2):
    return round(float(value), places)


class BaseApiTestCase(TestCase):
    def setUp(self):
        self.user = seed_demo_data()


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
