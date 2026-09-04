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
from .bmoni_client import BmoniClient
from .phone_utils import normalize_phone_e164, InvalidPhoneNumberError
from .seed_data import seed_demo_data

logger = logging.getLogger(__name__)


def _get_demo_user():
    """Get or create the seeded demo user (Bolaji).

    This is the fallback persona used when no real BMONI identity is
    attached to the request — never mutated by a real login.
    """
    try:
        user = UserProfile.objects.filter(email='bolaji@nuru.demo').first()
        if not user or user.transactions.filter(description__contains='—').exists():
            user = seed_demo_data()
        return user
    except Exception as e:
        logger.error(f"Error fetching user, running migrations: {e}")
        try:
            from django.core.management import call_command
            call_command('migrate', interactive=False)
            return seed_demo_data()
        except Exception as err:
            logger.error(f"Migration fallback failed: {err}")
            raise err


def _get_current_user(request):
    """Resolve the acting UserProfile for this request.

    The Flutter app sends the X-Bmoni-User-Id header for every request
    once a real BMONI login has succeeded. If it's absent or doesn't match
    a known profile (no login yet, or a flaky BMONI lookup), this falls
    back to the seeded demo persona so the app still has data to show.
    """
    header_id = request.headers.get('X-Bmoni-User-Id', '').strip()
    if header_id:
        user = UserProfile.objects.filter(bmoni_user_id=header_id).first()
        if user:
            return user
    return _get_demo_user()


class DashboardView(APIView):
    """
    GET /api/dashboard/
    Returns the full financial dashboard data including health score,
    balances, monthly summary, AI insight, and recent transactions.
    """

    def get(self, request):
        try:
            user = _get_current_user(request)
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
            # Log the traceback server-side; never return it to the client.
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
    Execute a BMONI transfer via the proposal → approve → sign flow.
    For demo, we simulate the BMONI interaction and record it.
    """

    def post(self, request):
        serializer = TransferActionSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user = _get_current_user(request)
        data = serializer.validated_data

        # In demo mode: simulate the BMONI proposal flow
        # In production: use BmoniClient for real API calls
        steps = []

        # Step 1: NURU AI Analysis
        steps.append({
            'step': 'ai_analysis',
            'label': 'NURU AI Analysis',
            'status': 'completed',
            'detail': f'Verified: ${data["amount"]} transfer is within safe spending range',
        })

        # Step 2: BMONI Proposal
        steps.append({
            'step': 'bmoni_proposal',
            'label': 'BMONI Proposal Created',
            'status': 'completed',
            'detail': f'Transfer proposal for {data["currency"]} {data["amount"]}',
        })

        # Step 3: Approval
        steps.append({
            'step': 'approval',
            'label': 'Proposal Approved',
            'status': 'completed',
            'detail': 'Approval threshold met',
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
            'label': 'Transfer Completed',
            'status': 'completed',
            'detail': f'{data["currency"]} {data["amount"]} sent successfully',
        })

        # Record the transaction in our system
        from .models import Transaction
        from django.utils import timezone
        Transaction.objects.create(
            user=user,
            description=data.get('description', 'Transfer via NURU'),
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


class BmoniUserView(APIView):
    """
    POST /api/bmoni/user/
    Create/Register a user in BMONI system and perform BVN onboarding.
    """

    def post(self, request):
        first_name = request.data.get('first_name', 'Bolaji')
        last_name = request.data.get('last_name', 'Jimoh')
        email = request.data.get('email', 'bolajijimoh8@gmail.com')
        phone_number = request.data.get('phone_number', '+2348123456789')
        bvn = request.data.get('bvn', '')

        client = BmoniClient()
        user = _get_current_user(request)

        # Step 1: Create BMONI user
        create_res = client.create_user(
            first_name=first_name,
            last_name=last_name,
            email=email,
            phone_number=phone_number,
        )

        bmoni_user_id = None
        if create_res.get('success'):
            user_data = create_res['data'].get('user', {})
            bmoni_user_id = user_data.get('bmoniUserId') or user_data.get('id') or create_res['data'].get('bmoniUserId')
        elif create_res.get('status_code') == 409:
            # User already registered with phone number
            bmoni_user_id = user.bmoni_user_id if user.bmoni_user_id and user.bmoni_user_id != 'demo-user-001' else f"bmoni-{phone_number.replace('+', '')}"

        if not bmoni_user_id:
            bmoni_user_id = f"bmoni-{phone_number.replace('+', '')}"

        # Update local UserProfile
        user.first_name = first_name
        user.last_name = last_name
        user.email = email
        user.phone_number = phone_number
        user.bmoni_user_id = bmoni_user_id
        if not user.wallet_address:
            user.wallet_address = '0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7'
        user.save()

        # Step 2: Nigeria BVN Onboarding if BVN supplied
        onboarding_res = None
        status_res = None
        if bvn and bmoni_user_id and not bmoni_user_id.startswith('bmoni-'):
            onboarding_res = client.start_nigeria_onboarding(
                user_id=bmoni_user_id,
                bvn=bvn,
                wallet_address=user.wallet_address,
            )
            status_res = client.get_onboarding_status(bmoni_user_id)
            if onboarding_res.get('success'):
                user.onboarding_complete = True
                user.save()

        return Response({
            'status': 'success',
            'message': 'BMONI registration & BVN onboarding processed',
            'user': UserProfileSerializer(user).data,
            'bmoni_create': create_res,
            'bmoni_onboarding': onboarding_res['data'] if onboarding_res and onboarding_res.get('success') else onboarding_res,
            'bmoni_status': status_res['data'] if status_res and status_res.get('success') else status_res,
        })


class BmoniBalancesView(APIView):
    """
    GET /api/bmoni/balances/
    Fetch live balances from BMONI.
    """

    def get(self, request):
        user = _get_current_user(request)
        if not user.bmoni_user_id or user.bmoni_user_id == 'demo-user-001':
            # Return calculated balances for demo
            summary = get_financial_summary(user)
            return Response({
                'source': 'nuru_calculated',
                'balances': summary['balances'],
            })

        client = BmoniClient()
        result = client.get_balances(user.bmoni_user_id)
        return Response(result)


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


class BmoniLoginView(APIView):
    """
    POST /api/bmoni/login/
    Log in with an existing BMONI User ID or a registered phone number to
    view real live data & balances.

    A phone number is normalized to E.164 (default region NG) and resolved
    via BMONI's by-phone lookup — never guessed or fabricated. A failed
    lookup (404) never falls back to the seeded demo persona; it returns a
    distinct 'not_found' response so the frontend can point the user at
    BMONI onboarding instead.
    """

    def post(self, request):
        bmoni_user_id = (request.data.get('bmoni_user_id') or '').strip()
        raw_phone = (request.data.get('phone_number') or '').strip()

        if not bmoni_user_id and not raw_phone:
            return Response(
                {'error': 'Please enter a valid BMONI User ID or phone number.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        client = BmoniClient()

        if bmoni_user_id:
            lookup_res = client.get_user(bmoni_user_id)
        else:
            try:
                e164_phone = normalize_phone_e164(raw_phone)
            except InvalidPhoneNumberError as e:
                return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
            lookup_res = client.get_user_by_phone(e164_phone)

        if lookup_res.get('status_code') == 404:
            return Response(
                {
                    'status': 'not_found',
                    'message': 'No BMONI account found for that BMONI User ID or phone number.',
                },
                status=status.HTTP_404_NOT_FOUND,
            )

        if not lookup_res.get('success') or not lookup_res.get('data'):
            return Response(
                {
                    'status': 'error',
                    'message': 'Could not reach BMONI to verify this account. Please try again.',
                    'detail': lookup_res.get('data'),
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # BMONI's response shape varies by endpoint - some nest under 'user'.
        u_data = lookup_res['data'].get('user', lookup_res['data'])
        resolved_bmoni_user_id = u_data.get('bmoniUserId') or u_data.get('id') or bmoni_user_id

        if not resolved_bmoni_user_id:
            return Response(
                {
                    'status': 'error',
                    'message': 'BMONI returned no user identifier for this account.',
                },
                status=status.HTTP_502_BAD_GATEWAY,
            )

        # Distinct row per real BMONI identity - never the seeded demo user.
        user, _ = UserProfile.objects.get_or_create(
            bmoni_user_id=resolved_bmoni_user_id,
            defaults={
                'first_name': u_data.get('firstName', ''),
                'last_name': u_data.get('lastName', ''),
                'email': u_data.get('email', ''),
                'phone_number': u_data.get('phoneNumber') or raw_phone,
            },
        )
        user.first_name = u_data.get('firstName') or user.first_name
        user.last_name = u_data.get('lastName') or user.last_name
        user.email = u_data.get('email') or user.email
        user.phone_number = u_data.get('phoneNumber') or raw_phone or user.phone_number
        user.onboarding_complete = True
        user.save()

        # Query live BMONI status and balances
        status_res = client.get_onboarding_status(user.bmoni_user_id)
        balance_res = client.get_balances(user.bmoni_user_id)

        summary = get_financial_summary(user)

        return Response({
            'status': 'success',
            'message': f'Logged in as BMONI user {user.bmoni_user_id}',
            'user': UserProfileSerializer(user).data,
            'bmoni_user_detail': lookup_res.get('data'),
            'bmoni_balances': balance_res.get('data'),
            'bmoni_status': status_res.get('data'),
            'dashboard': summary,
        })
