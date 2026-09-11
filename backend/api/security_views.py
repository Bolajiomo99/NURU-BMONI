"""
Transaction PIN + face-2FA endpoints, gating the transfer/swap action sheet.

Requires a real authenticated account (IsAuthenticated) — there is no guest
concept for money-moving authorization, unlike the header-based fallback the
core action endpoints allow for reads.
"""

import logging

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .security_utils import get_or_create_security, record_face_check, setup_pin, verify_pin
from .serializers import FaceVerifySerializer, TransactionPinSerializer

logger = logging.getLogger(__name__)


class SecurityStatusView(APIView):
    """GET /api/security/status/ — whether this account has a PIN set."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        security = get_or_create_security(request.user)
        return Response({'has_pin': bool(security.pin_hash)})


class SetupTransactionPinView(APIView):
    """POST /api/security/pin/setup/ — create or replace the transaction PIN."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = TransactionPinSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        setup_pin(request.user, serializer.validated_data['pin'])
        return Response({'message': 'Transaction PIN set.'})


class VerifyTransactionPinView(APIView):
    """POST /api/security/pin/verify/ — check the PIN before authorizing an action."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = TransactionPinSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        ok, error = verify_pin(request.user, serializer.validated_data['pin'])
        if ok:
            return Response({'verified': True})

        body = {'error': error}
        if error == 'no_pin':
            body['message'] = 'No transaction PIN set for this account.'
        elif error == 'locked':
            body['message'] = 'Too many incorrect attempts. Try again later.'
        else:
            body['message'] = 'Incorrect PIN.'
        return Response(body, status=status.HTTP_400_BAD_REQUEST)


class VerifyFaceView(APIView):
    """POST /api/security/face/verify/ — record a face-2FA check.

    See TransactionSecurity's docstring in models.py: this does not perform
    real biometric matching yet, it only logs that a check was requested.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = FaceVerifySerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        record_face_check(request.user)
        return Response({'verified': True})
