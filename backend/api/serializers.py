"""
NURU API Serializers
DRF serializers for all API responses.
"""

from rest_framework import serializers
from .models import Transaction, ChatMessage, UserProfile


class TransactionSerializer(serializers.ModelSerializer):
    category_label = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = [
            'id', 'description', 'amount', 'currency',
            'transaction_type', 'category', 'category_label',
            'timestamp', 'reference',
        ]

    def get_category_label(self, obj):
        return dict(Transaction.CATEGORY_CHOICES).get(obj.category, obj.category)


class ChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = ['id', 'role', 'content', 'action_type', 'action_data', 'timestamp']


class ChatInputSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=1000)


class TransferActionSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=15, decimal_places=2)
    currency = serializers.CharField(max_length=10, default='CNGN')
    to_address = serializers.CharField(max_length=255)
    description = serializers.CharField(max_length=500, required=False, default='')


class SwapActionSerializer(serializers.Serializer):
    from_currency = serializers.CharField(max_length=10)
    to_currency = serializers.CharField(max_length=10)
    amount = serializers.DecimalField(max_digits=15, decimal_places=2)


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = [
            'id', 'bmoni_user_id', 'first_name', 'last_name',
            'email', 'phone_number', 'smart_wallet_id',
            'wallet_address', 'onboarding_complete', 'created_at',
        ]
