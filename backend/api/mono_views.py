"""
Mono Connect endpoints.

Flow: the client asks for a widget URL, opens it, and Mono redirects to
MONO_REDIRECT_URL carrying ?code=. The client intercepts that redirect and
POSTs the code here, so identity comes from request.user and no server-side
ref→user mapping is needed.
"""

import logging
from uuid import uuid4

from django.conf import settings
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import ConnectedAccount
from .mono_client import MonoClient
from .serializers import ConnectedAccountSerializer

logger = logging.getLogger(__name__)


def _customer_name(user):
    full = f"{user.first_name} {user.last_name}".strip()
    return full or (user.email.split('@')[0] if user.email else 'NURU user')


class MonoInitiateView(APIView):
    """POST /api/mono/connect/initiate/ — returns the widget URL."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not settings.MONO_SECRET_KEY:
            return Response(
                {
                    'error': 'mono_not_configured',
                    'message': 'Account linking is not available right now.',
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        ref = uuid4().hex
        redirect_url = request.data.get('redirect_url') or settings.MONO_REDIRECT_URL

        result = MonoClient().initiate_account_link(
            name=_customer_name(request.user),
            email=request.user.email,
            ref=ref,
            redirect_url=redirect_url,
        )

        if not result.get('success'):
            return Response(
                {
                    'error': 'initiate_failed',
                    'message': result.get('data', {}).get('message')
                               or 'Could not start account linking. Try again.',
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        data = result.get('data') or {}
        payload = data.get('data') if isinstance(data.get('data'), dict) else data
        mono_url = payload.get('mono_url') or payload.get('monoUrl')

        if not mono_url:
            logger.error('MONO initiate succeeded but returned no mono_url')
            return Response(
                {'error': 'initiate_failed', 'message': 'Mono did not return a widget link.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # Record the attempt so a callback can be correlated and so a user who
        # abandons the widget leaves a visible 'pending' row rather than nothing.
        ConnectedAccount.objects.create(
            user=request.user, provider='mono', mono_ref=ref, status='pending'
        )

        return Response({'mono_url': mono_url, 'ref': ref, 'redirect_url': redirect_url})


class MonoCallbackView(APIView):
    """POST /api/mono/connect/callback/ — exchange the widget code for an account."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        code = (request.data.get('code') or '').strip()
        ref = (request.data.get('ref') or '').strip()

        if not code:
            return Response(
                {'error': 'missing_code', 'message': 'No authorisation code supplied.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        client = MonoClient()
        exchange = client.exchange_token(code)

        if not exchange.get('success'):
            self._mark_failed(request.user, ref, exchange)
            return Response(
                {
                    'error': 'exchange_failed',
                    'message': exchange.get('data', {}).get('message')
                               or 'Could not link that account. Try again.',
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        body = exchange.get('data') or {}
        inner = body.get('data') if isinstance(body.get('data'), dict) else body
        account_id = inner.get('id') or inner.get('account_id')

        if not account_id:
            self._mark_failed(request.user, ref, exchange, 'no account id returned')
            return Response(
                {'error': 'exchange_failed', 'message': 'Mono did not return an account.'},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        details = self._fetch_details(client, account_id)

        account, _ = ConnectedAccount.objects.update_or_create(
            user=request.user,
            mono_account_id=account_id,
            defaults={
                'provider': 'mono',
                'mono_ref': ref,
                'mono_access_token': account_id,
                'status': 'connected',
                'last_error': '',
                **details,
            },
        )

        # Collapse the placeholder row this ref created at initiate time.
        ConnectedAccount.objects.filter(
            user=request.user, mono_ref=ref, status='pending', mono_account_id=''
        ).exclude(pk=account.pk).delete()

        return Response(
            ConnectedAccountSerializer(account).data, status=status.HTTP_201_CREATED
        )

    def _fetch_details(self, client, account_id):
        """Institution and account naming. Best-effort: a failure here must not
        undo an otherwise successful link."""
        result = client.get_account(account_id)
        if not result.get('success'):
            return {}
        body = result.get('data') or {}
        inner = body.get('data') if isinstance(body.get('data'), dict) else body
        acct = inner.get('account') if isinstance(inner.get('account'), dict) else inner
        institution = acct.get('institution') or {}
        return {
            'institution_name': (institution.get('name') if isinstance(institution, dict) else '') or '',
            'account_name': acct.get('name') or '',
            'account_number_masked': str(acct.get('accountNumber') or '')[-4:],
        }

    def _mark_failed(self, user, ref, result, note=''):
        reason = note or str(result.get('data', {}).get('message') or 'exchange failed')
        updated = ConnectedAccount.objects.filter(
            user=user, mono_ref=ref, mono_account_id=''
        ).update(status='failed', last_error=reason[:500])
        if not updated:
            ConnectedAccount.objects.create(
                user=user, provider='mono', mono_ref=ref,
                status='failed', last_error=reason[:500],
            )


class MonoAccountsView(APIView):
    """GET /api/mono/accounts/ — the user's linked accounts."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        accounts = ConnectedAccount.objects.filter(user=request.user).exclude(
            status__in=['pending', 'failed']
        )
        include_balances = request.query_params.get('balances') == 'true'

        data = ConnectedAccountSerializer(accounts, many=True).data
        if include_balances:
            client = MonoClient()
            for row, account in zip(data, accounts):
                row['balance'] = self._balance(client, account.mono_account_id)

        return Response({'accounts': data})

    def _balance(self, client, account_id):
        if not account_id:
            return None
        result = client.get_account_balance(account_id)
        if not result.get('success'):
            return None
        body = result.get('data') or {}
        inner = body.get('data') if isinstance(body.get('data'), dict) else body
        raw = inner.get('balance')
        if raw is None:
            return None
        # Mono returns kobo.
        return {'amount': float(raw) / 100.0, 'currency': inner.get('currency') or 'NGN'}
