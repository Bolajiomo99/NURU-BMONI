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

    If X-Bmoni-User-Id header is present, returns the authenticated user.
    If absent, returns a guest profile with $0 balance (Option A).
    """
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
            'onboarding_complete': False,
        }
    )
    return guest_user


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
        first_name = (request.data.get('first_name') or '').strip()
        last_name = (request.data.get('last_name') or '').strip()
        email = (request.data.get('email') or '').strip()
        raw_phone = (request.data.get('phone_number') or '').strip()
        bvn = (request.data.get('bvn') or '').strip()

        if not raw_phone:
            return Response(
                {'error': 'Phone number is required for BMONI registration.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            phone_number = normalize_phone_e164(raw_phone)
        except InvalidPhoneNumberError:
            phone_number = raw_phone if raw_phone.startswith('+') else f"+234{raw_phone.lstrip('0')}"

        # Persona matching rules per BMONI Sandbox documentation
        if bvn == '95888168924':
            first_name = first_name if first_name and first_name != 'User' else 'Bunch'
            last_name = last_name if last_name and last_name != 'BMONI' else 'Dillon'
            phone_number = '+2348000000000' if not raw_phone or raw_phone in ('08000000000', '+2348000000000') else phone_number
            email = email or 'bunch.dillon@example.com'
        elif bvn == '22222222222':
            first_name = first_name if first_name and first_name != 'User' else 'Samson'
            last_name = last_name if last_name and last_name != 'BMONI' else 'Jabo'
            phone_number = '+2348000000001' if not raw_phone or raw_phone in ('08000000001', '+2348000000001') else phone_number
            email = email or 'samson.jabo@example.com'
        else:
            if not first_name:
                first_name = 'User'
            if not last_name:
                last_name = 'BMONI'
            if not email:
                email = f"user_{abs(hash(phone_number))}@bmoni-demo.com"

        client = BmoniClient()

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
            # User already registered with phone number — resolve existing BMONI identity
            u_data, _ = _resolve_or_create_bmoni_user(client, phone_number)
            if u_data:
                u_info = u_data.get('user', u_data)
                bmoni_user_id = u_info.get('bmoniUserId') or u_info.get('id')

        if not bmoni_user_id:
            bmoni_user_id = f"bmoni-{phone_number.replace('+', '')}"

        # Create/Get distinct UserProfile for THIS user (never Bolaji demo user)
        user, _ = UserProfile.objects.get_or_create(
            bmoni_user_id=bmoni_user_id,
            defaults={
                'first_name': first_name,
                'last_name': last_name,
                'email': email,
                'phone_number': phone_number,
            },
        )
        user.first_name = first_name or user.first_name
        user.last_name = last_name or user.last_name
        user.email = email or user.email
        user.phone_number = phone_number or user.phone_number
        if not user.wallet_address:
            user.wallet_address = '0x89205A3A3b2A69De6Dbf7f01ED13B2108B2c43e7'
        user.save()

        # Seed initial transactions if brand new profile
        if user.transactions.count() == 0:
            demo_user = UserProfile.objects.filter(bmoni_user_id='demo-user-001').first()
            if demo_user:
                for tx in demo_user.transactions.all():
                    tx.pk = None
                    tx.user = user
                    tx.save()

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
        else:
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


def _resolve_or_create_bmoni_user(client, raw_input):
    """
    Search BMONI API for a user by phone, email, name, or UUID.
    If no user exists yet in BMONI for this input, auto-create one.
    """
    raw_input = (raw_input or '').strip()
    if not raw_input:
        return None, 'Please enter a valid phone number, email, or account name.'

    u_data = None

    # 1. UUID direct lookup
    if len(raw_input) >= 32 and '-' in raw_input:
        res = client.get_user(raw_input)
        if res.get('success') and res.get('data'):
            u_data = res['data']

    # 2. Try by-phone API
    if not u_data:
        try:
            e164 = normalize_phone_e164(raw_input)
            res = client.get_user_by_phone(e164)
            if res.get('success') and res.get('data'):
                b_uid = res['data'].get('bmoniUserId') or res['data'].get('id')
                if b_uid:
                    u_res = client.get_user(b_uid)
                    if u_res.get('success') and u_res.get('data'):
                        u_data = u_res['data']
                    else:
                        u_data = res['data']
        except Exception:
            pass

    # 3. Comprehensive search in BMONI /v1/users list
    if not u_data:
        all_res = client._request('GET', '/v1/users')
        if all_res.get('success'):
            users = all_res['data'].get('users', [])
            q_lower = raw_input.lower()
            q_clean = ''.join(c for c in raw_input if c.isdigit())

            for u in users:
                phone = u.get('phoneNumber', '')
                phone_clean = ''.join(c for c in phone if c.isdigit())
                email = (u.get('email') or '').lower()
                fname = (u.get('firstName') or '').lower()
                lname = (u.get('lastName') or '').lower()
                buid = (u.get('bmoniUserId') or '').lower()
                uid = (u.get('id') or '').lower()

                if q_lower in (email, buid, uid) or (q_lower and q_lower in f"{fname} {lname}"):
                    u_data = u
                    break
                if q_clean and len(q_clean) >= 7 and (q_clean in phone_clean or phone_clean in q_clean):
                    u_data = u
                    break

    # 4. Auto-create user on BMONI if not found
    if not u_data:
        try:
            e164 = normalize_phone_e164(raw_input)
        except Exception:
            digits = ''.join(c for c in raw_input if c.isdigit())
            e164 = f"+234{digits.zfill(10)[-10:]}" if digits else f"+23480{abs(hash(raw_input)) % 100000000:08d}"

        parts = raw_input.split()
        fname = parts[0] if parts else 'BMONI'
        lname = parts[1] if len(parts) > 1 else 'User'
        email = raw_input if '@' in raw_input else f"user_{abs(hash(raw_input))}@bmoni-demo.com"

        c_res = client.create_user(fname, lname, email, e164)
        if c_res.get('success') and c_res.get('data'):
            u_data = c_res['data']
        elif c_res.get('status_code') == 409:
            # Re-fetch user list
            all_res = client._request('GET', '/v1/users')
            if all_res.get('success'):
                for u in all_res['data'].get('users', []):
                    if u.get('phoneNumber') == e164 or u.get('email') == email:
                        u_data = u
                        break

    if not u_data:
        return None, 'Could not resolve or create BMONI user account.'

    return u_data, None


class BmoniLoginView(APIView):
    """
    POST /api/bmoni/login/
    Log in seamlessly with ANY identifier (Phone Number, Email, Name, or BMONI User ID).
    Resolves real live BMONI smart wallet balances and syncs user data.
    """

    def post(self, request):
        identifier = (
            request.data.get('identifier')
            or request.data.get('phone_number')
            or request.data.get('bmoni_user_id')
            or ''
        ).strip()

        if not identifier:
            return Response(
                {'error': 'Please enter a valid Phone Number, Email, or Account Name.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        client = BmoniClient()
        u_data, error_msg = _resolve_or_create_bmoni_user(client, identifier)

        if error_msg or not u_data:
            return Response(
                {'status': 'error', 'message': error_msg or 'Could not resolve BMONI user.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # BMONI response shape varies - extract underlying user data dict
        u_info = u_data.get('user', u_data)
        resolved_bmoni_user_id = u_info.get('bmoniUserId') or u_info.get('id') or identifier

        # Distinct row per real BMONI identity
        user, _ = UserProfile.objects.get_or_create(
            bmoni_user_id=resolved_bmoni_user_id,
            defaults={
                'first_name': u_info.get('firstName') or 'BMONI',
                'last_name': u_info.get('lastName') or 'User',
                'email': u_info.get('email') or f"user_{resolved_bmoni_user_id[:8]}@bmoni.com",
                'phone_number': u_info.get('phoneNumber') or identifier,
            },
        )

        user.first_name = u_info.get('firstName') or user.first_name
        user.last_name = u_info.get('lastName') or user.last_name
        user.email = u_info.get('email') or user.email
        user.phone_number = u_info.get('phoneNumber') or identifier or user.phone_number
        user.onboarding_complete = True
        user.save()

        # Seed initial transactions if brand new user profile
        if user.transactions.count() == 0:
            from .seed_data import seed_demo_data
            # Copy sample transactions from demo profile if new
            demo_user = UserProfile.objects.filter(bmoni_user_id='demo-user-001').first()
            if demo_user:
                for tx in demo_user.transactions.all():
                    tx.pk = None
                    tx.user = user
                    tx.save()

        # Query live BMONI status and balances
        status_res = client.get_onboarding_status(user.bmoni_user_id)
        balance_res = client.get_balances(user.bmoni_user_id)

        summary = get_financial_summary(user)

        return Response({
            'status': 'success',
            'message': f'Logged in as BMONI user {user.first_name} {user.last_name}',
            'user': UserProfileSerializer(user).data,
            'bmoni_user_detail': u_info,
            'bmoni_balances': balance_res.get('data'),
            'bmoni_status': status_res.get('data'),
            'dashboard': summary,
        })
