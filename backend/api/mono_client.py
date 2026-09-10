"""
Mono API Client
Wraps Mono Connect v2 for NURU's backend.
Base URL: https://api.withmono.com — sandbox vs live is decided by the key
prefix (test_sk_… / live_sk_…), not by the URL.

Follows BmoniClient's contract: one _request funnel, never raises, always
returns {'status_code', 'data', 'success'}.

DELIBERATE DIVERGENCE FROM BmoniClient: that client logs `response.text`
verbatim on any 4xx/5xx. Mono's request and response bodies carry exchangeable
credentials (the widget `code`, and the account id returned by /accounts/auth),
so every logged body here goes through _redact first. Paths containing an
account id are masked too. Nothing in this module ever logs a raw credential.
"""

import logging
import re

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

# Keys whose values are credentials or can be exchanged for one.
SENSITIVE_KEYS = {
    'id', 'code', 'token', 'access_token', 'accessToken',
    'account', 'accountId', 'account_id', 'mono_url', 'secret',
}

_MASK = '***'


def _redact(value, _depth=0):
    """Recursively replace credential values so a body is safe to log."""
    if _depth > 6:
        return _MASK
    if isinstance(value, dict):
        return {
            k: (_MASK if k in SENSITIVE_KEYS else _redact(v, _depth + 1))
            for k, v in value.items()
        }
    if isinstance(value, list):
        return [_redact(v, _depth + 1) for v in value[:10]]
    return value


def _redact_path(path):
    """Mask an id embedded in a URL path, e.g. /v2/accounts/<id>/balance."""
    return re.sub(r'/v2/accounts/(?!auth$|initiate$)[^/]+', '/v2/accounts/' + _MASK, path)


class MonoClient:
    """Client for the Mono Connect v2 REST API."""

    def __init__(self):
        self.base_url = settings.MONO_BASE_URL.rstrip('/')
        self.secret_key = settings.MONO_SECRET_KEY
        self.headers = {
            'mono-sec-key': self.secret_key,
            'accept': 'application/json',
            'Content-Type': 'application/json',
        }

    def _request(self, method, path, data=None, params=None):
        """Make an authenticated request to the Mono API."""
        url = f"{self.base_url}{path}"
        safe_path = _redact_path(path)
        try:
            response = requests.request(
                method=method,
                url=url,
                headers=self.headers,
                json=data,
                params=params,
                timeout=30,
            )
            logger.info(f"MONO {method} {safe_path} → {response.status_code}")

            try:
                payload = response.json() if response.text else {}
            except ValueError:
                # A non-JSON body (an HTML 502 from a proxy) is not a
                # RequestException, so it would otherwise escape uncaught.
                logger.error(f"MONO {method} {safe_path} returned a non-JSON body")
                return {
                    'status_code': response.status_code,
                    'data': {'error': 'invalid_response'},
                    'success': False,
                }

            if response.status_code >= 400:
                logger.error(f"MONO error on {safe_path}: {_redact(payload)}")

            return {
                'status_code': response.status_code,
                'data': payload,
                'success': 200 <= response.status_code < 300,
            }
        except requests.exceptions.RequestException as e:
            logger.error(f"MONO request failed on {safe_path}: {type(e).__name__}")
            return {
                'status_code': 500,
                'data': {'error': str(e)},
                'success': False,
            }

    # ── Account linking ───────────────────────────────────────────
    def initiate_account_link(self, name, email, ref, redirect_url, scope='auth'):
        """POST /v2/accounts/initiate — returns data.mono_url for the widget."""
        return self._request('POST', '/v2/accounts/initiate', data={
            'customer': {'name': name, 'email': email},
            'meta': {'ref': ref},
            'scope': scope,
            'redirect_url': redirect_url,
        })

    def exchange_token(self, code):
        """POST /v2/accounts/auth — swap the widget code for an account id."""
        return self._request('POST', '/v2/accounts/auth', data={'code': code})

    # ── Account data ──────────────────────────────────────────────
    def get_account(self, account_id):
        """GET /v2/accounts/{id} — institution, account name, masked number."""
        return self._request('GET', f'/v2/accounts/{account_id}')

    def get_account_balance(self, account_id):
        """GET /v2/accounts/{id}/balance — current balance in kobo."""
        return self._request('GET', f'/v2/accounts/{account_id}/balance')
