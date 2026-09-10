"""
Mono integration tests (CP3). No network: requests is patched everywhere.

Two groups carry the security weight:
  * CryptoTestCase / TokenAtRestTestCase — the stored credential is genuine
    Fernet ciphertext, not an encoding, and the plaintext is absent from the
    raw database column.
  * CredentialLoggingTestCase — no plaintext credential ever reaches a log
    record, on the success path or any error path.
"""

import base64
import re
from unittest import mock

from django.contrib.auth.models import User
from django.db import connection
from django.test import TestCase, override_settings
from rest_framework.authtoken.models import Token

from . import crypto
from .models import ConnectedAccount
from .mono_client import MonoClient, _redact, _redact_path

FAST_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']

# The credential the widget code exchanges into. Distinctive so a substring
# search over logs and DB bytes is unambiguous.
SECRET_ACCOUNT_ID = 'acc_SUPERSECRET_638adf19c2b4'
WIDGET_CODE = 'code_SUPERSECRET_f0e1d2c3b4a5'


def _mono_response(status_code=200, payload=None):
    """A fake requests.Response good enough for MonoClient._request."""
    resp = mock.Mock()
    resp.status_code = status_code
    resp.text = '{}' if payload is None else 'non-empty'
    resp.json.return_value = payload if payload is not None else {}
    return resp


AUTH_OK = {'status': 'successful', 'data': {'id': SECRET_ACCOUNT_ID}}
ACCOUNT_OK = {
    'status': 'successful',
    'data': {
        'account': {
            'name': 'ADA OBI',
            'accountNumber': '0123456789',
            'institution': {'name': 'GTBank', 'type': 'PERSONAL_BANKING'},
        }
    },
}
INITIATE_OK = {
    'status': 'successful',
    'data': {'mono_url': 'https://connect.withmono.com/?key=abc', 'customer': 'cus_1'},
}


class CryptoTestCase(TestCase):
    def setUp(self):
        crypto.reset_fernet_cache()
        self.addCleanup(crypto.reset_fernet_cache)

    def test_round_trip(self):
        self.assertEqual(crypto.decrypt(crypto.encrypt(SECRET_ACCOUNT_ID)), SECRET_ACCOUNT_ID)

    def test_ciphertext_is_not_the_plaintext_or_an_encoding_of_it(self):
        ct = crypto.encrypt(SECRET_ACCOUNT_ID)
        self.assertNotEqual(ct, SECRET_ACCOUNT_ID)
        self.assertNotIn(SECRET_ACCOUNT_ID, ct)

        # Fernet tokens are urlsafe-base64. Decoding must NOT reveal the
        # plaintext — that is the difference between encryption and encoding.
        raw = base64.urlsafe_b64decode(ct.encode())
        self.assertNotIn(SECRET_ACCOUNT_ID.encode(), raw)
        # Fernet v1 framing: first byte 0x80, then an 8-byte timestamp.
        self.assertEqual(raw[0], 0x80)
        # 1 version + 8 timestamp + 16 IV + ciphertext + 32 HMAC
        self.assertGreater(len(raw), 57)

    def test_same_plaintext_encrypts_differently_each_time(self):
        self.assertNotEqual(crypto.encrypt(SECRET_ACCOUNT_ID), crypto.encrypt(SECRET_ACCOUNT_ID))

    def test_decrypt_of_garbage_returns_empty_and_does_not_raise(self):
        self.assertEqual(crypto.decrypt('not-a-fernet-token'), '')
        self.assertEqual(crypto.decrypt(''), '')

    def test_ciphertext_is_unreadable_with_a_different_key(self):
        ct = crypto.encrypt(SECRET_ACCOUNT_ID)
        crypto.reset_fernet_cache()
        with override_settings(SECRET_KEY='an-entirely-different-secret-key'):
            self.assertEqual(crypto.decrypt(ct), '')


@override_settings(PASSWORD_HASHERS=FAST_HASHERS)
class TokenAtRestTestCase(TestCase):
    """Prove the database column holds ciphertext, reading it raw."""

    def setUp(self):
        self.user = User.objects.create_user(username='ada@example.com', password='pw-123456!')

    def _raw_column_value(self, pk):
        with connection.cursor() as cur:
            cur.execute('SELECT mono_access_token FROM api_connectedaccount WHERE id = %s', [pk])
            return cur.fetchone()[0]

    def test_stored_column_is_ciphertext_and_orm_read_decrypts(self):
        account = ConnectedAccount.objects.create(
            user=self.user,
            mono_account_id='acc_public_id',
            mono_access_token=SECRET_ACCOUNT_ID,
            status='connected',
        )

        raw = self._raw_column_value(account.pk)
        self.assertNotEqual(raw, SECRET_ACCOUNT_ID)
        self.assertNotIn(SECRET_ACCOUNT_ID, raw)
        self.assertNotIn(SECRET_ACCOUNT_ID.encode(), base64.urlsafe_b64decode(raw.encode()))
        self.assertEqual(base64.urlsafe_b64decode(raw.encode())[0], 0x80)

        # The ORM still hands back plaintext.
        self.assertEqual(
            ConnectedAccount.objects.get(pk=account.pk).mono_access_token,
            SECRET_ACCOUNT_ID,
        )

    def test_plaintext_appears_nowhere_in_the_row(self):
        account = ConnectedAccount.objects.create(
            user=self.user, mono_account_id='acc_public_id',
            mono_access_token=SECRET_ACCOUNT_ID, status='connected',
        )
        with connection.cursor() as cur:
            cur.execute('SELECT * FROM api_connectedaccount WHERE id = %s', [account.pk])
            row = cur.fetchone()
        blob = ' '.join(str(v) for v in row)
        self.assertNotIn(SECRET_ACCOUNT_ID, blob)


class MonoClientTestCase(TestCase):
    """The client must honour BmoniClient's never-raise envelope contract."""

    @mock.patch('api.mono_client.requests.request')
    @override_settings(MONO_SECRET_KEY='test_sk_x', MONO_BASE_URL='https://api.withmono.com')
    def test_initiate_sends_the_documented_shape(self, mock_request):
        mock_request.return_value = _mono_response(200, INITIATE_OK)
        MonoClient().initiate_account_link(
            name='Ada Obi', email='ada@example.com', ref='r1',
            redirect_url='https://nuru.test/cb',
        )
        kwargs = mock_request.call_args.kwargs
        self.assertEqual(kwargs['url'], 'https://api.withmono.com/v2/accounts/initiate')
        self.assertEqual(kwargs['headers']['mono-sec-key'], 'test_sk_x')
        body = kwargs['json']
        self.assertEqual(body['customer'], {'name': 'Ada Obi', 'email': 'ada@example.com'})
        self.assertEqual(body['meta'], {'ref': 'r1'})
        self.assertEqual(body['scope'], 'auth')
        self.assertEqual(body['redirect_url'], 'https://nuru.test/cb')

    @mock.patch('api.mono_client.requests.request')
    def test_http_error_returns_envelope_without_raising(self, mock_request):
        mock_request.return_value = _mono_response(400, {'message': 'bad code'})
        result = MonoClient().exchange_token('nope')
        self.assertFalse(result['success'])
        self.assertEqual(result['status_code'], 400)

    @mock.patch('api.mono_client.requests.request')
    def test_connection_error_returns_envelope_without_raising(self, mock_request):
        import requests as rq
        mock_request.side_effect = rq.exceptions.ConnectionError('boom')
        result = MonoClient().get_account('acc_1')
        self.assertFalse(result['success'])
        self.assertEqual(result['status_code'], 500)

    @mock.patch('api.mono_client.requests.request')
    def test_non_json_body_does_not_escape(self, mock_request):
        resp = mock.Mock()
        resp.status_code = 502
        resp.text = '<html>gateway</html>'
        resp.json.side_effect = ValueError('not json')
        mock_request.return_value = resp
        result = MonoClient().get_account('acc_1')
        self.assertFalse(result['success'])
        self.assertEqual(result['data'], {'error': 'invalid_response'})


class RedactionUnitTestCase(TestCase):
    def test_sensitive_keys_are_masked(self):
        out = _redact({'data': {'id': SECRET_ACCOUNT_ID, 'institution': 'GTBank'}})
        self.assertEqual(out['data']['id'], '***')
        self.assertEqual(out['data']['institution'], 'GTBank')

    def test_nested_and_listed_values_are_masked(self):
        out = _redact({'accounts': [{'id': SECRET_ACCOUNT_ID}, {'token': WIDGET_CODE}]})
        self.assertNotIn(SECRET_ACCOUNT_ID, str(out))
        self.assertNotIn(WIDGET_CODE, str(out))

    def test_account_id_in_path_is_masked_but_verbs_are_kept(self):
        self.assertEqual(_redact_path(f'/v2/accounts/{SECRET_ACCOUNT_ID}'), '/v2/accounts/***')
        self.assertEqual(
            _redact_path(f'/v2/accounts/{SECRET_ACCOUNT_ID}/balance'), '/v2/accounts/***/balance'
        )
        self.assertEqual(_redact_path('/v2/accounts/auth'), '/v2/accounts/auth')
        self.assertEqual(_redact_path('/v2/accounts/initiate'), '/v2/accounts/initiate')


@override_settings(PASSWORD_HASHERS=FAST_HASHERS, MONO_SECRET_KEY='test_sk_x')
class MonoConnectFlowTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='ada@example.com', email='ada@example.com',
            password='pw-123456!', first_name='Ada', last_name='Obi',
        )
        self.token = Token.objects.create(user=self.user)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Token {self.token.key}'

    def _callback(self, code=WIDGET_CODE, ref=''):
        return self.client.post(
            '/api/mono/connect/callback/',
            {'code': code, 'ref': ref},
            content_type='application/json',
        )

    @mock.patch('api.mono_client.requests.request')
    def test_initiate_returns_widget_url_and_records_a_pending_row(self, mock_request):
        mock_request.return_value = _mono_response(200, INITIATE_OK)
        resp = self.client.post(
            '/api/mono/connect/initiate/', {}, content_type='application/json'
        )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()['mono_url'], 'https://connect.withmono.com/?key=abc')
        self.assertTrue(resp.json()['ref'])
        self.assertTrue(
            ConnectedAccount.objects.filter(user=self.user, status='pending').exists()
        )

    @mock.patch('api.mono_client.requests.request')
    def test_callback_creates_a_connected_account(self, mock_request):
        mock_request.side_effect = [
            _mono_response(200, AUTH_OK),
            _mono_response(200, ACCOUNT_OK),
        ]
        resp = self._callback()
        self.assertEqual(resp.status_code, 201)

        account = ConnectedAccount.objects.get(user=self.user, status='connected')
        self.assertEqual(account.mono_account_id, SECRET_ACCOUNT_ID)
        self.assertEqual(account.institution_name, 'GTBank')
        self.assertEqual(account.account_name, 'ADA OBI')
        self.assertEqual(account.account_number_masked, '6789')

        # The response body must not carry the credential field.
        self.assertNotIn('mono_access_token', resp.json())

    @mock.patch('api.mono_client.requests.request')
    def test_repeat_callback_does_not_duplicate_the_account(self, mock_request):
        mock_request.side_effect = [
            _mono_response(200, AUTH_OK), _mono_response(200, ACCOUNT_OK),
            _mono_response(200, AUTH_OK), _mono_response(200, ACCOUNT_OK),
        ]
        self._callback()
        self._callback()
        self.assertEqual(
            ConnectedAccount.objects.filter(
                user=self.user, mono_account_id=SECRET_ACCOUNT_ID
            ).count(),
            1,
        )

    @mock.patch('api.mono_client.requests.request')
    def test_failed_exchange_returns_502_and_records_the_failure(self, mock_request):
        mock_request.return_value = _mono_response(400, {'message': 'Invalid code'})
        resp = self._callback(ref='r9')
        self.assertEqual(resp.status_code, 502)
        self.assertEqual(resp.json()['error'], 'exchange_failed')
        self.assertTrue(
            ConnectedAccount.objects.filter(user=self.user, status='failed').exists()
        )

    def test_callback_without_a_code_is_rejected(self):
        resp = self._callback(code='')
        self.assertEqual(resp.status_code, 400)
        self.assertEqual(resp.json()['error'], 'missing_code')

    @mock.patch('api.mono_client.requests.request')
    def test_details_lookup_failure_still_links_the_account(self, mock_request):
        mock_request.side_effect = [
            _mono_response(200, AUTH_OK),
            _mono_response(500, {'message': 'upstream down'}),
        ]
        resp = self._callback()
        self.assertEqual(resp.status_code, 201)
        account = ConnectedAccount.objects.get(user=self.user, status='connected')
        self.assertEqual(account.institution_name, '')

    @mock.patch('api.mono_client.requests.request')
    def test_accounts_listing_is_scoped_and_hides_the_credential(self, mock_request):
        mock_request.side_effect = [
            _mono_response(200, AUTH_OK), _mono_response(200, ACCOUNT_OK),
        ]
        self._callback()

        other = User.objects.create_user(username='bob@example.com', password='pw-123456!')
        ConnectedAccount.objects.create(
            user=other, mono_account_id='acc_theirs',
            mono_access_token='their-secret', status='connected',
        )

        resp = self.client.get('/api/mono/accounts/')
        self.assertEqual(resp.status_code, 200)
        accounts = resp.json()['accounts']
        self.assertEqual(len(accounts), 1)
        self.assertEqual(accounts[0]['institution_name'], 'GTBank')
        self.assertNotIn('mono_access_token', accounts[0])
        self.assertNotIn('acc_theirs', resp.content.decode())

    @mock.patch('api.mono_client.requests.request')
    def test_pending_and_failed_rows_are_not_listed_as_accounts(self, mock_request):
        mock_request.return_value = _mono_response(200, INITIATE_OK)
        self.client.post('/api/mono/connect/initiate/', {}, content_type='application/json')
        resp = self.client.get('/api/mono/accounts/')
        self.assertEqual(resp.json()['accounts'], [])

    @override_settings(MONO_SECRET_KEY='')
    def test_initiate_without_a_key_returns_503_not_500(self):
        resp = self.client.post(
            '/api/mono/connect/initiate/', {}, content_type='application/json'
        )
        self.assertEqual(resp.status_code, 503)

    def test_mono_endpoints_require_auth(self):
        self.client.defaults.pop('HTTP_AUTHORIZATION')
        for method, path in [
            ('post', '/api/mono/connect/initiate/'),
            ('post', '/api/mono/connect/callback/'),
            ('get', '/api/mono/accounts/'),
        ]:
            with self.subTest(path=path):
                self.assertEqual(getattr(self.client, method)(path).status_code, 401)


@override_settings(PASSWORD_HASHERS=FAST_HASHERS, MONO_SECRET_KEY='test_sk_x')
class CredentialLoggingTestCase(TestCase):
    """No plaintext credential may reach a log record, on any path.

    This is the regression guard against BmoniClient's `logger.error(response.text)`
    pattern being reintroduced.
    """

    def setUp(self):
        self.user = User.objects.create_user(
            username='ada@example.com', email='ada@example.com', password='pw-123456!'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Token {self.token.key}'

    def _assert_clean(self, captured):
        blob = '\n'.join(captured.output)
        self.assertNotIn(SECRET_ACCOUNT_ID, blob)
        self.assertNotIn(WIDGET_CODE, blob)
        # The secret key itself must never be logged either.
        self.assertNotIn('test_sk_x', blob)
        return blob

    @mock.patch('api.mono_client.requests.request')
    def test_success_path_logs_no_credential(self, mock_request):
        mock_request.side_effect = [
            _mono_response(200, AUTH_OK), _mono_response(200, ACCOUNT_OK),
        ]
        with self.assertLogs('api.mono_client', level='DEBUG') as captured:
            self.client.post(
                '/api/mono/connect/callback/',
                {'code': WIDGET_CODE}, content_type='application/json',
            )
        blob = self._assert_clean(captured)
        # It still logged something useful.
        self.assertIn('/v2/accounts/auth', blob)
        self.assertIn('/v2/accounts/***', blob)

    @mock.patch('api.mono_client.requests.request')
    def test_error_body_echoing_the_credential_is_redacted(self, mock_request):
        # The hostile case: upstream echoes the code and id back in a 4xx.
        mock_request.return_value = _mono_response(400, {
            'message': 'invalid',
            'code': WIDGET_CODE,
            'data': {'id': SECRET_ACCOUNT_ID},
        })
        with self.assertLogs('api.mono_client', level='DEBUG') as captured:
            self.client.post(
                '/api/mono/connect/callback/',
                {'code': WIDGET_CODE}, content_type='application/json',
            )
        blob = self._assert_clean(captured)
        self.assertIn('***', blob)

    @mock.patch('api.mono_client.requests.request')
    def test_connection_error_logs_no_credential(self, mock_request):
        import requests as rq
        mock_request.side_effect = rq.exceptions.ConnectionError(
            f'failed connecting while sending {WIDGET_CODE}'
        )
        with self.assertLogs('api.mono_client', level='DEBUG') as captured:
            self.client.post(
                '/api/mono/connect/callback/',
                {'code': WIDGET_CODE}, content_type='application/json',
            )
        self._assert_clean(captured)

    @mock.patch('api.mono_client.requests.request')
    def test_non_json_error_body_logs_no_credential(self, mock_request):
        resp = mock.Mock()
        resp.status_code = 502
        resp.text = f'<html>{WIDGET_CODE}</html>'
        resp.json.side_effect = ValueError('not json')
        mock_request.return_value = resp
        with self.assertLogs('api.mono_client', level='DEBUG') as captured:
            self.client.post(
                '/api/mono/connect/callback/',
                {'code': WIDGET_CODE}, content_type='application/json',
            )
        self._assert_clean(captured)

    def test_mono_client_source_does_not_log_raw_response_text(self):
        """Static guard: `response.text` must never be handed to a logger."""
        from pathlib import Path
        source = Path(__file__).with_name('mono_client.py').read_text(encoding='utf-8')
        offenders = re.findall(r'logger\.\w+\([^)]*response\.text[^)]*\)', source)
        self.assertEqual(offenders, [], f'mono_client.py logs raw response text: {offenders}')
