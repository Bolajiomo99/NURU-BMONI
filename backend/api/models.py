"""
NURU Data Models
Tracks user financial profiles, transactions, and AI interactions.
"""

from django.db import models
from django.utils import timezone


class UserProfile(models.Model):
    """Links a NURU user to their BMONI identity."""
    bmoni_user_id = models.CharField(max_length=255, unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    email = models.EmailField()
    phone_number = models.CharField(max_length=20)
    created_at = models.DateTimeField(auto_now_add=True)

    # BMONI wallet references
    smart_wallet_id = models.CharField(max_length=255, blank=True, default='')
    wallet_address = models.CharField(max_length=255, blank=True, default='')
    onboarding_complete = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.bmoni_user_id})"


class Transaction(models.Model):
    """Financial transaction record for AI analysis."""

    CATEGORY_CHOICES = [
        ('freelance_income', 'Freelance Income'),
        ('business_income', 'Business Income'),
        ('employment', 'Employment'),
        ('family_support', 'Family Support'),
        ('entertainment', 'Entertainment'),
        ('business_expense', 'Business Expense'),
        ('business_tool', 'Business Tool'),
        ('transport', 'Transport'),
        ('food', 'Food & Groceries'),
        ('utilities', 'Utilities'),
        ('transfer_out', 'Transfer Out'),
        ('transfer_in', 'Transfer In'),
        ('conversion', 'Currency Conversion'),
        ('other_income', 'Other Income'),
        ('other_expense', 'Other Expense'),
    ]

    CURRENCY_CHOICES = [
        ('USD', 'US Dollar'),
        ('NGN', 'Nigerian Naira'),
    ]

    TYPE_CHOICES = [
        ('credit', 'Credit'),
        ('debit', 'Debit'),
    ]

    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='transactions')
    description = models.CharField(max_length=500)
    amount = models.DecimalField(max_digits=15, decimal_places=2)
    currency = models.CharField(max_length=3, choices=CURRENCY_CHOICES)
    transaction_type = models.CharField(max_length=10, choices=TYPE_CHOICES)
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES)
    timestamp = models.DateTimeField(default=timezone.now)
    reference = models.CharField(max_length=255, blank=True, default='')

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        sign = '+' if self.transaction_type == 'credit' else '-'
        return f"{sign}{self.currency} {self.amount} - {self.description}"


class FinancialSnapshot(models.Model):
    """Point-in-time financial health snapshot for trending."""
    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='snapshots')
    health_score = models.IntegerField(default=50)
    total_usd = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    total_ngn = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    monthly_income_usd = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    monthly_spending_usd = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    monthly_income_ngn = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    monthly_spending_ngn = models.DecimalField(max_digits=15, decimal_places=2, default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class ChatMessage(models.Model):
    """Stores AI conversation history."""
    ROLE_CHOICES = [
        ('user', 'User'),
        ('assistant', 'NURU AI'),
    ]

    user = models.ForeignKey(UserProfile, on_delete=models.CASCADE, related_name='chat_messages')
    role = models.CharField(max_length=10, choices=ROLE_CHOICES)
    content = models.TextField()
    # Structured action data if AI recommends an action
    action_type = models.CharField(max_length=50, blank=True, default='')
    action_data = models.JSONField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['timestamp']
