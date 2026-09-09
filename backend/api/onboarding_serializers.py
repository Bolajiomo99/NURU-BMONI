"""Serializers for the 3-step business onboarding."""

from rest_framework import serializers

from .models import (
    SPEND_CATEGORY_CHOICES,
    BusinessGoal,
    BusinessProfile,
    Loan,
)

SPEND_CATEGORY_VALUES = [value for value, _ in SPEND_CATEGORY_CHOICES]


class BusinessProfileSerializer(serializers.ModelSerializer):
    """Everything is skippable except business_name."""

    spend_categories = serializers.ListField(
        child=serializers.ChoiceField(choices=SPEND_CATEGORY_VALUES),
        required=False,
        allow_empty=True,
    )

    class Meta:
        model = BusinessProfile
        fields = [
            'business_name',
            'business_size',
            'has_employees',
            'avg_employee_pay',
            'spend_categories',
            'avg_monthly_revenue_range',
            'description',
            'onboarding_step_completed',
            'updated_at',
        ]
        read_only_fields = ['updated_at']
        extra_kwargs = {
            'business_size': {'required': False},
            'has_employees': {'required': False},
            'avg_employee_pay': {'required': False},
            'avg_monthly_revenue_range': {'required': False},
            'description': {'required': False},
            'onboarding_step_completed': {'required': False},
        }

    def validate_business_name(self, value):
        name = (value or '').strip()
        if not name:
            raise serializers.ValidationError('Business name is required.')
        return name

    def validate_spend_categories(self, value):
        # Preserve order, drop duplicates — the client sends chip taps.
        return list(dict.fromkeys(value))


class BusinessGoalSerializer(serializers.ModelSerializer):
    class Meta:
        model = BusinessGoal
        fields = ['id', 'goal_text', 'attachment', 'created_at']
        read_only_fields = ['id', 'created_at']

    def validate_goal_text(self, value):
        text = (value or '').strip()
        if not text:
            raise serializers.ValidationError('Goal cannot be empty.')
        return text


class LoanSerializer(serializers.ModelSerializer):
    class Meta:
        model = Loan
        fields = [
            'id', 'amount', 'interest_rate', 'date_taken',
            'due_date', 'lender_name', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']

    def validate(self, attrs):
        date_taken = attrs.get('date_taken')
        due_date = attrs.get('due_date')
        if date_taken and due_date and due_date < date_taken:
            raise serializers.ValidationError(
                {'due_date': 'Due date cannot be before the date the loan was taken.'}
            )
        return attrs
