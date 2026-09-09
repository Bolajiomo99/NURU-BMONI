"""Serializers for the email/password auth endpoints."""

from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers

# auth.User.username is max_length=150 while EmailField allows 254. We use the
# email as the username, so anything longer would blow up at save() time.
EMAIL_MAX_LENGTH = 150


class _PasswordPairMixin:
    """Shared confirm-match + Django password-policy validation."""

    password_field = 'password'
    confirm_field = 'confirm_password'

    def validate(self, attrs):
        password = attrs.get(self.password_field)
        confirm = attrs.get(self.confirm_field)
        if password != confirm:
            raise serializers.ValidationError(
                {self.confirm_field: 'Passwords do not match.'}
            )
        try:
            validate_password(password)
        except DjangoValidationError as e:
            raise serializers.ValidationError({self.password_field: list(e.messages)})
        return attrs


class SignupSerializer(_PasswordPairMixin, serializers.Serializer):
    name = serializers.CharField(max_length=150)
    email = serializers.EmailField(max_length=EMAIL_MAX_LENGTH)
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    def validate_email(self, value):
        email = value.lower().strip()
        # Only *verified* accounts block reuse. An unverified row is treated as
        # an abandoned signup and gets a fresh code instead of an error.
        if User.objects.filter(username__iexact=email, is_active=True).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return email


class VerifyOtpSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=EMAIL_MAX_LENGTH)
    code = serializers.CharField(min_length=6, max_length=6)

    def validate_email(self, value):
        return value.lower().strip()

    def validate_code(self, value):
        code = value.strip()
        if not code.isdigit():
            raise serializers.ValidationError('Code must be 6 digits.')
        return code


class ResendOtpSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=EMAIL_MAX_LENGTH)
    purpose = serializers.ChoiceField(choices=['signup', 'reset'], default='signup')

    def validate_email(self, value):
        return value.lower().strip()


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=EMAIL_MAX_LENGTH)
    password = serializers.CharField(write_only=True)

    def validate_email(self, value):
        return value.lower().strip()


class ForgotPasswordSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=EMAIL_MAX_LENGTH)

    def validate_email(self, value):
        return value.lower().strip()


class ResetPasswordSerializer(_PasswordPairMixin, serializers.Serializer):
    password_field = 'new_password'

    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)
