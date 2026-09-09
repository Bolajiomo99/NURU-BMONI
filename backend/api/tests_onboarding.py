"""
Smoke tests for the 3-step business onboarding (CP2).

Covers the rules that are easy to get wrong: what is skippable, that deleting
another user's row 404s, and that every endpoint actually requires auth.
"""

from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from django.urls import reverse
from rest_framework.authtoken.models import Token

from .models import BusinessGoal, BusinessProfile, Loan

FAST_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']


@override_settings(PASSWORD_HASHERS=FAST_HASHERS)
class OnboardingTestCaseBase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='ada@example.com', email='ada@example.com', password='pw-123456!'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Token {self.token.key}'

    def _patch_business(self, **fields):
        body = {'business_name': 'Ada Fabrics'}
        body.update(fields)
        return self.client.patch(
            '/api/onboarding/business/', body, content_type='application/json'
        )


class PermissionMatrixTestCase(TestCase):
    """Every onboarding endpoint must reject an unauthenticated caller.

    A forgotten permission_classes silently makes an endpoint public, so this
    loops the URL table rather than spot-checking.
    """

    def test_all_onboarding_endpoints_require_auth(self):
        cases = [
            ('get', '/api/onboarding/business/'),
            ('patch', '/api/onboarding/business/'),
            ('get', '/api/onboarding/goals/'),
            ('post', '/api/onboarding/goals/'),
            ('delete', '/api/onboarding/goals/1/'),
            ('get', '/api/onboarding/loans/'),
            ('post', '/api/onboarding/loans/'),
            ('delete', '/api/onboarding/loans/1/'),
            ('get', '/api/onboarding/status/'),
        ]
        for method, path in cases:
            with self.subTest(method=method, path=path):
                resp = getattr(self.client, method)(path)
                self.assertEqual(
                    resp.status_code, 401,
                    f'{method.upper()} {path} returned {resp.status_code}, expected 401',
                )


class BusinessProfileTestCase(OnboardingTestCaseBase):
    def test_business_name_is_the_only_required_field(self):
        resp = self._patch_business()
        self.assertEqual(resp.status_code, 200)
        profile = BusinessProfile.objects.get(user=self.user)
        self.assertEqual(profile.business_name, 'Ada Fabrics')
        self.assertEqual(profile.business_size, '')
        self.assertEqual(profile.spend_categories, [])
        # Skipped is not the same as answered-no.
        self.assertIsNone(profile.has_employees)

    def test_missing_business_name_is_rejected(self):
        resp = self.client.patch(
            '/api/onboarding/business/',
            {'business_size': 'solo'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn('business_name', resp.json())
        self.assertFalse(BusinessProfile.objects.filter(user=self.user).exists())

    def test_blank_business_name_is_rejected(self):
        resp = self.client.patch(
            '/api/onboarding/business/',
            {'business_name': '   '},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 400)

    def test_second_patch_updates_rather_than_duplicating(self):
        self._patch_business()
        resp = self.client.patch(
            '/api/onboarding/business/',
            {'business_size': 'small', 'has_employees': True},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(BusinessProfile.objects.filter(user=self.user).count(), 1)
        profile = BusinessProfile.objects.get(user=self.user)
        self.assertEqual(profile.business_size, 'small')
        self.assertTrue(profile.has_employees)
        # The name from the first save survives a partial update.
        self.assertEqual(profile.business_name, 'Ada Fabrics')

    def test_unknown_spend_category_is_rejected(self):
        resp = self._patch_business(spend_categories=['inventory', 'not_a_category'])
        self.assertEqual(resp.status_code, 400)
        self.assertIn('spend_categories', resp.json())

    def test_spend_categories_are_deduplicated(self):
        resp = self._patch_business(spend_categories=['rent', 'inventory', 'rent'])
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(
            BusinessProfile.objects.get(user=self.user).spend_categories,
            ['rent', 'inventory'],
        )

    def test_get_returns_choice_vocabularies(self):
        resp = self.client.get('/api/onboarding/business/')
        self.assertEqual(resp.status_code, 200)
        choices = resp.json()['choices']
        self.assertIn('business_size', choices)
        self.assertIn('spend_categories', choices)
        self.assertIn('revenue_ranges', choices)
        # Null business until one is saved.
        self.assertIsNone(resp.json()['business'])


class BusinessGoalTestCase(OnboardingTestCaseBase):
    def test_create_and_list_goals(self):
        for text in ('Open a second stall', 'Buy an industrial machine'):
            resp = self.client.post(
                '/api/onboarding/goals/', {'goal_text': text}, content_type='application/json'
            )
            self.assertEqual(resp.status_code, 201)

        listing = self.client.get('/api/onboarding/goals/')
        self.assertEqual(len(listing.json()['goals']), 2)

    def test_empty_goal_is_rejected(self):
        resp = self.client.post(
            '/api/onboarding/goals/', {'goal_text': '  '}, content_type='application/json'
        )
        self.assertEqual(resp.status_code, 400)

    def test_delete_own_goal(self):
        created = self.client.post(
            '/api/onboarding/goals/', {'goal_text': 'Hire an apprentice'},
            content_type='application/json',
        )
        goal_id = created.json()['id']
        resp = self.client.delete(f'/api/onboarding/goals/{goal_id}/')
        self.assertEqual(resp.status_code, 204)
        self.assertFalse(BusinessGoal.objects.filter(pk=goal_id).exists())

    def test_cannot_delete_another_users_goal(self):
        other = User.objects.create_user(username='bob@example.com', password='pw-123456!')
        their_goal = BusinessGoal.objects.create(user=other, goal_text='Not yours')

        resp = self.client.delete(f'/api/onboarding/goals/{their_goal.pk}/')
        self.assertEqual(resp.status_code, 404)
        # Still there.
        self.assertTrue(BusinessGoal.objects.filter(pk=their_goal.pk).exists())


class LoanTestCase(OnboardingTestCaseBase):
    def test_create_loan_with_minimum_fields(self):
        resp = self.client.post(
            '/api/onboarding/loans/',
            {'amount': '250000.00', 'date_taken': '2026-01-15'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 201)
        loan = Loan.objects.get(user=self.user)
        self.assertIsNone(loan.interest_rate)
        self.assertIsNone(loan.due_date)
        self.assertEqual(loan.lender_name, '')

    def test_due_date_before_date_taken_is_rejected(self):
        resp = self.client.post(
            '/api/onboarding/loans/',
            {'amount': '1000', 'date_taken': '2026-05-01', 'due_date': '2026-04-01'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 400)
        self.assertIn('due_date', resp.json())

    def test_invalid_date_is_rejected(self):
        resp = self.client.post(
            '/api/onboarding/loans/',
            {'amount': '1000', 'date_taken': 'not-a-date'},
            content_type='application/json',
        )
        self.assertEqual(resp.status_code, 400)

    def test_cannot_delete_another_users_loan(self):
        other = User.objects.create_user(username='bob@example.com', password='pw-123456!')
        their_loan = Loan.objects.create(user=other, amount=500, date_taken='2026-02-01')
        resp = self.client.delete(f'/api/onboarding/loans/{their_loan.pk}/')
        self.assertEqual(resp.status_code, 404)


class OnboardingStatusTestCase(OnboardingTestCaseBase):
    def _status(self):
        return self.client.get('/api/onboarding/status/').json()

    def test_status_starts_empty_and_points_at_the_first_step(self):
        data = self._status()
        self.assertFalse(data['business'])
        self.assertFalse(data['goals'])
        self.assertFalse(data['accounts'])
        self.assertFalse(data['loans'])
        self.assertFalse(data['complete'])
        self.assertEqual(data['next_route'], 'business')

    def test_status_advances_section_by_section(self):
        self._patch_business()
        self.assertEqual(self._status()['next_route'], 'goals')

        self.client.post(
            '/api/onboarding/goals/', {'goal_text': 'Grow revenue'},
            content_type='application/json',
        )
        data = self._status()
        self.assertTrue(data['goals'])
        self.assertEqual(data['next_route'], 'connect')
        self.assertFalse(data['complete'])

        # A loan alone satisfies the third section — connecting an account is
        # skippable, so onboarding must be completable without one.
        self.client.post(
            '/api/onboarding/loans/',
            {'amount': '1000', 'date_taken': '2026-03-01'},
            content_type='application/json',
        )
        data = self._status()
        self.assertTrue(data['loans'])
        self.assertTrue(data['complete'])
        self.assertIsNone(data['next_route'])

    def test_status_is_scoped_to_the_requesting_user(self):
        other = User.objects.create_user(username='bob@example.com', password='pw-123456!')
        BusinessProfile.objects.create(user=other, business_name="Bob's Shop")
        BusinessGoal.objects.create(user=other, goal_text='Their goal')

        data = self._status()
        self.assertFalse(data['business'])
        self.assertFalse(data['goals'])
