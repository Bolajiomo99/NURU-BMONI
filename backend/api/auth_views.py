"""
Email + password auth endpoints.

Signup creates an inactive user and emails a 6-digit code; the account is only
activated (and a token issued) once that code is verified.
"""

import logging

from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.db import transaction
from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .auth_serializers import (
    ForgotPasswordSerializer,
    LoginSerializer,
    ResendOtpSerializer,
    ResetPasswordSerializer,
    SignupSerializer,
    VerifyOtpSerializer,
)
from .auth_utils import (
    consume_reset_token,
    ensure_user_profile,
    issue_otp,
    issue_reset_token,
    split_name,
    verify_otp,
)
from .serializers import UserProfileSerializer

logger = logging.getLogger(__name__)


def _auth_payload(user):
    """Token + profile, the shape both verify-otp and login return."""
    profile = ensure_user_profile(user)
    token, _ = Token.objects.get_or_create(user=user)
    return {
        'token': token.key,
        'user': {
            'id': user.id,
            'name': f"{user.first_name} {user.last_name}".strip(),
            'email': user.email,
            'profile': UserProfileSerializer(profile).data,
        },
    }


class SignupView(APIView):
    """POST /api/auth/signup/ — create an inactive user and email an OTP."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SignupSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        data = serializer.validated_data
        email = data['email']
        first_name, last_name = split_name(data['name'])

        with transaction.atomic():
            user = User.objects.filter(username__iexact=email).first()
            if user is None:
                user = User.objects.create_user(
                    username=email,
                    email=email,
                    password=data['password'],
                    first_name=first_name,
                    last_name=last_name,
                    is_active=False,
                )
            else:
                # Abandoned unverified signup: refresh the details and re-issue.
                # validate_email already rejected active accounts.
                user.set_password(data['password'])
                user.first_name = first_name
                user.last_name = last_name
                user.email = email
                user.save()

        # Not inside the atomic block: a failed send must not roll back the user.
        _, error = issue_otp(email, purpose='signup', enforce_cooldown=False)
        if error == 'cooldown':
            return Response(
                {'error': 'cooldown', 'message': 'Please wait before requesting another code.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )

        return Response(
            {'email': email, 'message': 'Verification code sent.'},
            status=status.HTTP_201_CREATED,
        )


class VerifyOtpView(APIView):
    """POST /api/auth/verify-otp/ — activate the account and return a token."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyOtpSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        ok, error, remaining = verify_otp(email, serializer.validated_data['code'], 'signup')

        if not ok:
            body = {'error': error}
            if error == 'invalid_code':
                body['attempts_remaining'] = remaining
                body['message'] = f'Incorrect code. {remaining} attempts remaining.'
            elif error == 'expired':
                body['message'] = 'That code has expired. Request a new one.'
            elif error == 'too_many_attempts':
                body['message'] = 'Too many incorrect attempts. Request a new code.'
            else:
                body['message'] = 'No active code for this email. Request a new one.'
            return Response(body, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(username__iexact=email).first()
        if user is None:
            return Response(
                {'error': 'no_account', 'message': 'No account found for this email.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.is_active:
            user.is_active = True
            user.save(update_fields=['is_active'])

        return Response(_auth_payload(user), status=status.HTTP_200_OK)


class ResendOtpView(APIView):
    """POST /api/auth/resend-otp/ — invalidate the old code and send a new one."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResendOtpSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        purpose = serializer.validated_data['purpose']

        # Same 201 shape whether or not the account exists — no enumeration.
        if not User.objects.filter(username__iexact=email).exists():
            return Response({'email': email, 'message': 'Verification code sent.'})

        _, error = issue_otp(email, purpose=purpose)
        if error == 'cooldown':
            return Response(
                {'error': 'cooldown', 'message': 'Please wait before requesting another code.'},
                status=status.HTTP_429_TOO_MANY_REQUESTS,
            )
        return Response({'email': email, 'message': 'Verification code sent.'})


class LoginView(APIView):
    """POST /api/auth/login/ — email + password, returns a token."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        password = serializer.validated_data['password']

        user = authenticate(request, username=email, password=password)
        if user is None:
            # authenticate() returns None for inactive users too, so check
            # separately and send the app to the OTP screen rather than a
            # dead-end "wrong password".
            pending = User.objects.filter(username__iexact=email, is_active=False).first()
            if pending is not None and pending.check_password(password):
                issue_otp(email, purpose='signup', enforce_cooldown=False)
                return Response(
                    {
                        'error': 'email_not_verified',
                        'email': email,
                        'message': 'Verify your email to continue. We sent you a new code.',
                    },
                    status=status.HTTP_403_FORBIDDEN,
                )
            return Response(
                {'error': 'invalid_credentials', 'message': 'Incorrect email or password.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(_auth_payload(user), status=status.HTTP_200_OK)


class ForgotPasswordView(APIView):
    """POST /api/auth/forgot-password/ — always 200, never reveals existence."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        email = serializer.validated_data['email']
        user = User.objects.filter(username__iexact=email, is_active=True).first()
        if user is not None:
            issue_reset_token(user)

        return Response(
            {'message': 'If an account exists for that email, a reset link is on its way.'}
        )


class ResetPasswordView(APIView):
    """POST /api/auth/reset-password/ — consume a token and set a new password."""

    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        user, error = consume_reset_token(serializer.validated_data['token'])
        if user is None:
            return Response(
                {'error': error, 'message': 'That reset link is invalid or has expired.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(serializer.validated_data['new_password'])
        user.save(update_fields=['password'])

        # Force re-login everywhere: the old token must not survive a reset.
        Token.objects.filter(user=user).delete()

        return Response({'message': 'Password updated. You can now log in.'})


class MeView(APIView):
    """GET /api/auth/me/ — restore a session on cold start."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        profile = ensure_user_profile(user)
        return Response(
            {
                'id': user.id,
                'name': f"{user.first_name} {user.last_name}".strip(),
                'email': user.email,
                'profile': UserProfileSerializer(profile).data,
            }
        )
