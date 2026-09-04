"""
BMONI API Client
Wraps the BMONI Embedded REST API for NURU's backend.
Base URL: https://embedded-dev.bmoni.com (sandbox)
"""

import requests
import logging
from django.conf import settings

logger = logging.getLogger(__name__)


class BmoniClient:
    """Client for the BMONI Embedded REST API."""

    def __init__(self):
        self.base_url = settings.BMONI_BASE_URL.rstrip('/')
        self.api_key = settings.BMONI_API_KEY
        self.headers = {
            'x-api-key': self.api_key,
            'Content-Type': 'application/json',
        }

    def _request(self, method, path, data=None, params=None):
        """Make an authenticated request to the BMONI API."""
        url = f"{self.base_url}{path}"
        try:
            response = requests.request(
                method=method,
                url=url,
                headers=self.headers,
                json=data,
                params=params,
                timeout=30,
            )
            logger.info(f"BMONI {method} {path} → {response.status_code}")
            if response.status_code >= 400:
                logger.error(f"BMONI error: {response.text}")
            return {
                'status_code': response.status_code,
                'data': response.json() if response.text else {},
                'success': 200 <= response.status_code < 300,
            }
        except requests.exceptions.RequestException as e:
            logger.error(f"BMONI request failed: {e}")
            return {
                'status_code': 500,
                'data': {'error': str(e)},
                'success': False,
            }

    # ── Stage 1: User Creation ────────────────────────────────────
    def create_user(self, first_name, last_name, email, phone_number):
        """POST /v1/users — Create a BMONI user."""
        return self._request('POST', '/v1/users', data={
            'firstName': first_name,
            'lastName': last_name,
            'email': email,
            'phoneNumber': phone_number,
        })

    def get_user(self, user_id):
        """GET /v1/users/{userId} — Get BMONI user profile details."""
        return self._request('GET', f'/v1/users/{user_id}')

    # ── Stage 2: Smart Wallet ─────────────────────────────────────
    def request_owner_proof_challenge(self, user_id, currency, owner_address):
        """POST /v1/users/{userId}/smart-wallets/owner-proof-challenges"""
        return self._request('POST',
            f'/v1/users/{user_id}/smart-wallets/owner-proof-challenges',
            data={
                'currency': currency,
                'userOwnerAddress': owner_address,
            })

    def create_managed_wallet(self, user_id, currency, owner_address,
                               challenge_id, signature):
        """POST /v1/users/{userId}/smart-wallets/create-managed"""
        return self._request('POST',
            f'/v1/users/{user_id}/smart-wallets/create-managed',
            data={
                'currency': currency,
                'userOwnerAddress': owner_address,
                'ownerProofChallengeId': challenge_id,
                'ownerProofSignature': signature,
            })

    # ── Stage 3–4: KYC & Onboarding ──────────────────────────────
    def get_onboarding_status(self, user_id):
        """GET /v1/users/{userId}/onboarding/status"""
        return self._request('GET', f'/v1/users/{user_id}/onboarding/status')

    def submit_kyc(self, user_id, kyc_data):
        """PATCH /v1/users/{userId}/kyc"""
        return self._request('PATCH', f'/v1/users/{user_id}/kyc', data=kyc_data)

    def start_nigeria_onboarding(self, user_id, bvn, wallet_address, wallet_index=0):
        """POST /v1/users/{userId}/onboarding/start-nigeria"""
        return self._request('POST',
            f'/v1/users/{user_id}/onboarding/start-nigeria',
            data={
                'bvn': bvn,
                'ngnWalletAddress': wallet_address,
                'ngnWalletIndex': wallet_index,
            })

    # ── Stage 5: Balances & Wallets ───────────────────────────────
    def get_balances(self, user_id):
        """GET /v1/users/{userId}/smart-wallets/account/balances"""
        return self._request('GET',
            f'/v1/users/{user_id}/smart-wallets/account/balances')

    def get_wallets(self, user_id):
        """GET /v1/users/{userId}/smart-wallets/account/wallets"""
        return self._request('GET',
            f'/v1/users/{user_id}/smart-wallets/account/wallets')

    def get_wallet_detail(self, user_id, smart_wallet_id):
        """GET /v1/users/{userId}/smart-wallets/{smartWalletId}"""
        return self._request('GET',
            f'/v1/users/{user_id}/smart-wallets/{smart_wallet_id}')

    # ── Stage 6: Move Money ───────────────────────────────────────
    def create_transfer_proposal(self, user_id, smart_wallet_id,
                                  to_address, amount, currency, description=''):
        """POST /v1/users/{userId}/smart-wallets/{smartWalletId}/proposals"""
        proposal = {
            'type': 'TRANSFER',
            'toAddress': to_address,
            'amount': str(amount),
            'currency': currency,
        }
        if description:
            proposal['description'] = description
        return self._request('POST',
            f'/v1/users/{user_id}/smart-wallets/{smart_wallet_id}/proposals',
            data={'proposal': proposal})

    def create_swap_proposal(self, user_id, smart_wallet_id,
                              from_stablecoin, to_stablecoin, amount):
        """POST /v1/users/{userId}/smart-wallets/{smartWalletId}/proposals (SWAP)"""
        return self._request('POST',
            f'/v1/users/{user_id}/smart-wallets/{smart_wallet_id}/proposals',
            data={'proposal': {
                'type': 'SWAP',
                'fromStablecoin': from_stablecoin,
                'toStablecoin': to_stablecoin,
                'fromAmount': str(amount),
                'slippageBps': 50,
            }})

    def approve_proposal(self, user_id, proposal_id):
        """POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/approve"""
        return self._request('POST',
            f'/v1/users/{user_id}/smart-wallets/proposals/{proposal_id}/approve')

    def get_sign_payload(self, user_id, proposal_id):
        """GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign-payload"""
        return self._request('GET',
            f'/v1/users/{user_id}/smart-wallets/proposals/{proposal_id}/sign-payload')

    def submit_signature(self, user_id, proposal_id, signature):
        """POST /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign"""
        return self._request('POST',
            f'/v1/users/{user_id}/smart-wallets/proposals/{proposal_id}/sign',
            data={'signature': signature})

    def get_proposal(self, user_id, proposal_id):
        """GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}"""
        return self._request('GET',
            f'/v1/users/{user_id}/smart-wallets/proposals/{proposal_id}')

    # ── Currency Exchange ─────────────────────────────────────────
    def exchange_convert(self, user_id, from_currency, to_currency, amount):
        """POST /v1/users/{userId}/exchange/convert"""
        return self._request('POST',
            f'/v1/users/{user_id}/exchange/convert',
            data={
                'fromCurrency': from_currency,
                'toCurrency': to_currency,
                'amount': str(amount),
            })

    # ── Supported Data ────────────────────────────────────────────
    def get_supported_currencies(self):
        """GET /v1/smart-wallets/supported-currencies"""
        return self._request('GET', '/v1/smart-wallets/supported-currencies')
