"""
Business onboarding endpoints.

Every section is skippable, so these are all independent: the client can PATCH
the business form, add goals, add loans, or none of the above, in any order.
GET /status/ is what lets the app resume where the user left off.
"""

import logging

from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import (
    BUSINESS_SIZE_CHOICES,
    REVENUE_RANGE_CHOICES,
    SPEND_CATEGORY_CHOICES,
    BusinessGoal,
    BusinessProfile,
    Loan,
)
from .onboarding_serializers import (
    BusinessGoalSerializer,
    BusinessProfileSerializer,
    LoanSerializer,
)

logger = logging.getLogger(__name__)


def _has_connected_accounts(user):
    """Whether the user has linked a bank account.

    ConnectedAccount arrives with the Mono work (CP3); until then no account
    can exist, so this is False by construction rather than by guess.
    """
    try:
        from .models import ConnectedAccount
    except ImportError:
        return False
    return ConnectedAccount.objects.filter(user=user, status='connected').exists()


def _choices_payload():
    """The value vocabularies, so the Flutter chips have one source of truth."""
    return {
        'business_size': [{'value': v, 'label': l} for v, l in BUSINESS_SIZE_CHOICES],
        'spend_categories': [{'value': v, 'label': l} for v, l in SPEND_CATEGORY_CHOICES],
        'revenue_ranges': [{'value': v, 'label': l} for v, l in REVENUE_RANGE_CHOICES],
    }


class BusinessProfileView(APIView):
    """GET / PATCH /api/onboarding/business/"""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        profile = BusinessProfile.objects.filter(user=request.user).first()
        return Response({
            'business': BusinessProfileSerializer(profile).data if profile else None,
            'choices': _choices_payload(),
        })

    def patch(self, request):
        profile = BusinessProfile.objects.filter(user=request.user).first()
        # partial=True on an existing row, but a first save must still supply
        # business_name — it is the one required field.
        serializer = BusinessProfileSerializer(
            profile, data=request.data, partial=profile is not None
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        profile = serializer.save(user=request.user)
        return Response(BusinessProfileSerializer(profile).data)


class BusinessGoalListCreateView(APIView):
    """GET / POST /api/onboarding/goals/"""

    permission_classes = [IsAuthenticated]
    # MultiPart so the optional attachment can ride along with the goal text.
    parser_classes = [JSONParser, MultiPartParser, FormParser]

    def get(self, request):
        goals = BusinessGoal.objects.filter(user=request.user)
        return Response({'goals': BusinessGoalSerializer(goals, many=True).data})

    def post(self, request):
        serializer = BusinessGoalSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        goal = serializer.save(user=request.user)
        return Response(BusinessGoalSerializer(goal).data, status=status.HTTP_201_CREATED)


class BusinessGoalDetailView(APIView):
    """DELETE /api/onboarding/goals/{id}/"""

    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        # Scoped to the requester: deleting someone else's goal must 404,
        # not succeed.
        deleted, _ = BusinessGoal.objects.filter(pk=pk, user=request.user).delete()
        if not deleted:
            return Response(
                {'error': 'not_found', 'message': 'Goal not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class LoanListCreateView(APIView):
    """GET / POST /api/onboarding/loans/"""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        loans = Loan.objects.filter(user=request.user)
        return Response({'loans': LoanSerializer(loans, many=True).data})

    def post(self, request):
        serializer = LoanSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        loan = serializer.save(user=request.user)
        return Response(LoanSerializer(loan).data, status=status.HTTP_201_CREATED)


class LoanDetailView(APIView):
    """DELETE /api/onboarding/loans/{id}/"""

    permission_classes = [IsAuthenticated]

    def delete(self, request, pk):
        deleted, _ = Loan.objects.filter(pk=pk, user=request.user).delete()
        if not deleted:
            return Response(
                {'error': 'not_found', 'message': 'Loan not found.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class OnboardingStatusView(APIView):
    """GET /api/onboarding/status/ — which sections hold data, for resuming."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = BusinessProfile.objects.filter(user=user).first()

        has_business = profile is not None
        has_goals = BusinessGoal.objects.filter(user=user).exists()
        has_loans = Loan.objects.filter(user=user).exists()
        has_accounts = _has_connected_accounts(user)

        # The third section counts as touched if either half has data.
        section_three = has_accounts or has_loans

        if not has_business:
            next_route = 'business'
        elif not has_goals:
            next_route = 'goals'
        elif not section_three:
            next_route = 'connect'
        else:
            next_route = None

        return Response({
            'business': has_business,
            'goals': has_goals,
            'accounts': has_accounts,
            'loans': has_loans,
            'complete': has_business and has_goals and section_three,
            'next_route': next_route,
            'choices': _choices_payload(),
        })
