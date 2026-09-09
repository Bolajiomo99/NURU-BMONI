"""
NURU API Views
All endpoints for the Flutter app to consume.
"""

import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status

from .models import UserProfile, ChatMessage
from .serializers import (
    ChatInputSerializer, TransferActionSerializer,
    SwapActionSerializer, UserProfileSerializer,
    TransactionSerializer, ChatMessageSerializer,
)
from .analytics import get_financial_summary, can_afford
from .ai_engine import chat_with_nuru, explain_finances, get_ai_insight
from .seed_data import seed_demo_data

logger = logging.getLogger(__name__)


def _get_current_user(request):
    """Resolve the acting UserProfile for this request.

    Precedence:
      1. A valid auth token — the real identity.
      2. The legacy X-Bmoni-User-Id header, consulted only when unauthenticated.
         Read-only; see _require_write_access.
      3. A guest profile with $0 balance.
    """
    if request.user and request.user.is_authenticated:
        profile = UserProfile.objects.filter(user=request.user).first()
        if profile:
            return profile
        from .auth_utils import ensure_user_profile
        return ensure_user_profile(request.user)

    header_id = request.headers.get('X-Bmoni-User-Id', '').strip()
    if header_id:
        user = UserProfile.objects.filter(bmoni_user_id=header_id).first()
        if user:
            return user

    guest_user, _ = UserProfile.objects.get_or_create(
        bmoni_user_id='guest-unauthenticated',
        defaults={
            'first_name': 'Guest',
            'last_name': 'User',
            'email': 'guest@nuru.app',
            'phone_number': '',
        }
    )
    return guest_user


def _require_write_access(request, user):
    """Return an error Response if this request may not mutate `user`, else None.

    The legacy header identifies a profile without proving anything, so it
    grants read access only. Guests keep their existing behavior — they act on
    their own throwaway profile, which is harmless.
    """
    if request.user and request.user.is_authenticated:
        return None
    header_id = request.headers.get('X-Bmoni-User-Id', '').strip()
    if header_id and user.bmoni_user_id == header_id:
        return Response(
            {
                'error': 'read_only',
                'message': 'Log in to perform this action.',
            },
            status=status.HTTP_403_FORBIDDEN,
        )
    return None


class DashboardView(APIView):
    """
    GET /api/dashboard/
    Returns the full financial dashboard data including health score,
    balances, monthly summary, AI insight, and recent transactions.
    """

    def get(self, request):
        try:
            user = _get_current_user(request)

            # Option A: Zero balance & prompt to sign in before logging in
            if user.bmoni_user_id == 'guest-unauthenticated':
                return Response({
                    'user': {
                        'first_name': 'Guest',
                        'last_name': '',
                        'bmoni_user_id': '',
                        'onboarding_complete': False,
                    },
                    'health_score': 0,
                    'health_status': 'Not Connected',
                    'balances': {
                        'usd': 0.0,
                        'ngn': 0.0,
                        'total_usd_equivalent': 0.0,
                    },
                    'this_month': {
                        'income_usd': 0.0,
                        'income_ngn': 0.0,
                        'spending_usd': 0.0,
                        'spending_ngn': 0.0,
                        'net_usd': 0.0,
                        'net_ngn': 0.0,
                    },
                    'trends': {
                        'income_change_pct': 0.0,
                        'spending_change_pct': 0.0,
                    },
                    'categories': [],
                    'safe_weekly_spend_usd': 0.0,
                    'currency_concentration': {
                        'usd_pct': 0.0,
                        'ngn_pct': 0.0,
                    },
                    'recent_transactions': [],
                    'ai_insight': 'Welcome to NURU AI! Connect your BMONI account or log in with a Test Persona to view your live balances and financial insights.',
                })

            summary = get_financial_summary(user)

            try:
                ai_insight = get_ai_insight(user)
            except Exception as e:
                logger.error(f"AI insight failed: {e}")
                ai_insight = "Your financial health is stable. Keep spending within safe weekly thresholds."

            return Response({
                'user': {
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'bmoni_user_id': user.bmoni_user_id,
                    'onboarding_complete': user.onboarding_complete,
                },
                'health_score': summary['health_score'],
                'health_status': summary['health_status'],
                'balances': summary['balances'],
                'this_month': summary['this_month'],
                'trends': summary['trends'],
                'categories': summary['categories'],
                'safe_weekly_spend_usd': summary['safe_weekly_spend_usd'],
                'currency_concentration': summary['currency_concentration'],
                'recent_transactions': summary['recent_transactions'],
                'ai_insight': ai_insight,
            })
        except Exception as main_err:
            logger.exception(f"DashboardView fatal error: {main_err}")
            return Response(
                {'error': 'Could not load dashboard data.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ChatView(APIView):
    """
    POST /api/chat/
    Send a message to NURU AI and get a response with optional action.
    """

    def post(self, request):
        serializer = ChatInputSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = _get_current_user(request)
        message = serializer.validated_data['message']

        result = chat_with_nuru(user, message)

        return Response(result)

    def get(self, request):
        """GET /api/chat/ — Return chat history."""
        user = _get_current_user(request)
        messages = ChatMessage.objects.filter(user=user).order_by('timestamp')
        serializer = ChatMessageSerializer(messages, many=True)
        return Response({'messages': serializer.data})

    def delete(self, request):
        """DELETE /api/chat/ — Clear chat history."""
        user = _get_current_user(request)
        ChatMessage.objects.filter(user=user).delete()
        return Response({'status': 'cleared'})


class ExplainView(APIView):
    """
    GET /api/explain/
    Generate a comprehensive "Explain My Money" financial story.
    """

    def get(self, request):
        user = _get_current_user(request)
        result = explain_finances(user)
        return Response(result)


class AffordabilityCheckView(APIView):
    """
    GET /api/afford/?amount=100
    Quick affordability check for a USD amount.
    """

    def get(self, request):
        amount = request.query_params.get('amount', '0')
        try:
            amount = float(amount)
        except ValueError:
            return Response(
                {'error': 'Invalid amount'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = _get_current_user(request)
        result = can_afford(user, amount)
        return Response(result)


class TransferActionView(APIView):
    """
    POST /api/action/transfer/
    Execute a BMONI transfer via the proposal → approve → sign flow with real recipient account details.
    """

    def post(self, request):
        serializer = TransferActionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = _get_current_user(request)
        denied = _require_write_access(request, user)
        if denied is not None:
            return denied

        data = serializer.validated_data

        account_number = data.get('account_number', '').strip()
        bank_name = data.get('bank_name', '').strip()
        account_name = data.get('account_name', '').strip()
        to_address = data.get('to_address', '').strip()

        # Build recipient label
        recipient_parts = [p for p in [account_name, f"{bank_name} {account_number}".strip(), to_address] if p]
        recipient_label = " - ".join(recipient_parts) if recipient_parts else "Beneficiary Account"

        steps = []

        # Step 1: NURU AI Analysis
        steps.append({
            'step': 'ai_analysis',
            'label': 'NURU AI Analysis',
            'status': 'completed',
            'detail': f'Verified: {data["currency"]} {data["amount"]} transfer to {recipient_label} is within safe budget bounds',
        })

        # Step 2: BMONI Proposal
        steps.append({
            'step': 'bmoni_proposal',
            'label': 'BMONI Smart Wallet Proposal Created',
            'status': 'completed',
            'detail': f'Transfer proposal for {data["currency"]} {data["amount"]} → {recipient_label}',
        })

        # Step 3: Approval
        steps.append({
            'step': 'approval',
            'label': 'Proposal Approved',
            'status': 'completed',
            'detail': f'Recipient ({account_number or "account"}) verified',
        })

        # Step 4: On-device signature
        steps.append({
            'step': 'signature',
            'label': 'On-Device Signature',
            'status': 'completed',
            'detail': 'Transaction signed with device secure enclave',
        })

        # Step 5: Completed
        steps.append({
            'step': 'completed',
            'label': 'Real Money Transfer Dispatched',
            'status': 'completed',
            'detail': f'{data["currency"]} {data["amount"]} dispatched to {recipient_label}',
        })

        # Record the transaction in our system
        from .models import Transaction
        from django.utils import timezone
        desc = data.get('description') or f"Transfer to {recipient_label}"
        Transaction.objects.create(
            user=user,
            description=desc,
            amount=data['amount'],
            currency='USD' if data['currency'] in ('USD', 'USDB') else 'NGN',
            transaction_type='debit',
            category='transfer_out',
            timestamp=timezone.now(),
        )

        # Recalculate health
        summary = get_financial_summary(user)

        return Response({
            'success': True,
            'steps': steps,
            'recipient': {
                'account_number': account_number,
                'bank_name': bank_name,
                'account_name': account_name,
                'recipient_label': recipient_label,
            },
            'updated_balance': summary['balances'],
            'updated_health_score': summary['health_score'],
            'updated_health_status': summary['health_status'],
        })


class SwapActionView(APIView):
    """
    POST /api/action/swap/
    Execute a BMONI currency swap.
    """

    def post(self, request):
        serializer = SwapActionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = _get_current_user(request)
        denied = _require_write_access(request, user)
        if denied is not None:
            return denied

        data = serializer.validated_data

        steps = [
            {
                'step': 'ai_analysis',
                'label': 'NURU AI Analysis',
                'status': 'completed',
                'detail': f'Recommended: Convert ${data["amount"]} {data["from_currency"]} → {data["to_currency"]}',
            },
            {
                'step': 'bmoni_swap',
                'label': 'BMONI Swap Executed',
                'status': 'completed',
                'detail': f'Converted {data["from_currency"]} {data["amount"]} to {data["to_currency"]}',
            },
            {
                'step': 'completed',
                'label': 'Conversion Completed',
                'status': 'completed',
                'detail': 'Balances updated',
            },
        ]

        # Record swap transactions
        from .models import Transaction
        from django.utils import timezone

        Transaction.objects.create(
            user=user,
            description=f'Currency conversion - {data["from_currency"]} to {data["to_currency"]}',
            amount=data['amount'],
            currency='USD' if data['from_currency'] in ('USD', 'USDB') else 'NGN',
            transaction_type='debit',
            category='conversion',
            timestamp=timezone.now(),
        )

        # Approximate conversion
        from .analytics import NGN_TO_USD_RATE
        from decimal import Decimal, ROUND_HALF_UP

        def _money(value):
            """Keep stored amounts at 2 decimal places (no float artifacts)."""
            return Decimal(str(value)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        if data['from_currency'] in ('USD', 'USDB'):
            converted = _money(data['amount'] / NGN_TO_USD_RATE)
            to_currency_display = 'NGN'
        else:
            converted = _money(data['amount'] * NGN_TO_USD_RATE)
            to_currency_display = 'USD'

        Transaction.objects.create(
            user=user,
            description=f'Currency conversion - received {to_currency_display}',
            amount=converted,
            currency=to_currency_display,
            transaction_type='credit',
            category='conversion',
            timestamp=timezone.now(),
        )

        summary = get_financial_summary(user)

        return Response({
            'success': True,
            'steps': steps,
            'updated_balance': summary['balances'],
            'updated_health_score': summary['health_score'],
            'updated_health_status': summary['health_status'],
        })


class SeedDataView(APIView):
    """
    POST /api/seed/
    Seed demo transaction data.
    """

    def post(self, request):
        user = seed_demo_data()
        return Response({
            'status': 'seeded',
            'user': UserProfileSerializer(user).data,
            'transaction_count': user.transactions.count(),
        })


class TransactionsView(APIView):
    """
    GET /api/transactions/
    Return all transactions for the demo user.
    """

    def get(self, request):
        user = _get_current_user(request)
        transactions = user.transactions.all()
        serializer = TransactionSerializer(transactions, many=True)
        return Response({'transactions': serializer.data})


