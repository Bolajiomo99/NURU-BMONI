"""
NURU Data Models
Tracks user financial profiles, transactions, and AI interactions.
"""

from django.conf import settings
from django.db import models
from django.utils import timezone

from .crypto import EncryptedTextField

OTP_PURPOSE_CHOICES = [
    ('signup', 'Signup verification'),
    ('reset', 'Password reset'),
]

BUSINESS_SIZE_CHOICES = [
    ('solo', 'Just me'),
    ('small', 'Small (2-10 people)'),
    ('medium', 'Medium (11+ people)'),
]

# Fixed vocabulary rather than free text: analytics and the AI layer can only
# aggregate these columns if the values are drawn from a known set.
SPEND_CATEGORY_CHOICES = [
    ('inventory', 'Inventory & stock'),
    ('salaries', 'Salaries & wages'),
    ('rent', 'Rent'),
    ('utilities', 'Utilities'),
    ('transport', 'Transport & logistics'),
    ('marketing', 'Marketing & advertising'),
    ('software', 'Software & subscriptions'),
    ('equipment', 'Equipment'),
    ('taxes', 'Taxes & levies'),
    ('loan_repayment', 'Loan repayment'),
    ('other', 'Other'),
]

CONNECTED_ACCOUNT_PROVIDER_CHOICES = [
    ('mono', 'Mono'),
]

CONNECTED_ACCOUNT_STATUS_CHOICES = [
    ('pending', 'Link started'),
    ('connected', 'Connected'),
    ('failed', 'Link failed'),
    ('disconnected', 'Disconnected'),
]

# Monthly revenue, in naira.
REVENUE_RANGE_CHOICES = [
    ('under_100k', 'Under ₦100,000'),
    ('100k_500k', '₦100,000 - ₦500,000'),
    ('500k_2m', '₦500,000 - ₦2,000,000'),
    ('2m_10m', '₦2,000,000 - ₦10,000,000'),
    ('over_10m', 'Over ₦10,000,000'),
]


class UserProfile(models.Model):
    """A NURU user's financial profile.

    `user` is the identity of record. `bmoni_user_id` is retained as the unique
    external id column — 'nuru-…' for accounts created through signup,
    'demo-user-001' / 'guest-unauthenticated' for the seeded fixtures.
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        # SET_NULL, not CASCADE: deleting an auth user must not destroy the
        # transaction history hanging off this profile.
        on_delete=models.SET_NULL,
        related_name='profile',
    )
    bmoni_user_id = models.CharField(max_length=255, unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    email = models.EmailField()
    phone_number = models.CharField(max_length=20)
    created_at = models.DateTimeField(auto_now_add=True)

    # TODO(0006): dropped alongside the Flutter/dashboard change that stops
    # reading it. Nothing writes it any more now that BMONI onboarding is gone.
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


class OTP(models.Model):
    """A one-time code emailed for signup verification or password reset.

    Keyed on email rather than a user FK so a code can be issued before the
    account is confirmed to exist (and without leaking whether it does).
    """
    email = models.EmailField(db_index=True)
    code_hash = models.CharField(max_length=128)
    purpose = models.CharField(max_length=10, choices=OTP_PURPOSE_CHOICES)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['email', 'purpose', 'used_at'])]

    def is_valid(self):
        return self.used_at is None and timezone.now() < self.expires_at

    def __str__(self):
        return f"OTP({self.purpose}) for {self.email}"


class PasswordResetToken(models.Model):
    """A single-use password reset token. Only the hash is stored."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='password_reset_tokens',
    )
    token_hash = models.CharField(max_length=128, db_index=True)
    expires_at = models.DateTimeField()
    used_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def is_valid(self):
        return self.used_at is None and timezone.now() < self.expires_at


class BusinessProfile(models.Model):
    """What the user's business is, captured during onboarding.

    One row per user: the endpoint is a PATCH that edits the same record, and
    every field except business_name is skippable.
    """
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='business_profile',
    )
    business_name = models.CharField(max_length=200)
    business_size = models.CharField(max_length=10, choices=BUSINESS_SIZE_CHOICES, blank=True, default='')
    # Tri-state on purpose: null means "skipped", which is not the same as
    # "answered no".
    has_employees = models.BooleanField(null=True, blank=True)
    avg_employee_pay = models.DecimalField(max_digits=15, decimal_places=2, null=True, blank=True)
    spend_categories = models.JSONField(default=list, blank=True)
    avg_monthly_revenue_range = models.CharField(
        max_length=20, choices=REVENUE_RANGE_CHOICES, blank=True, default=''
    )
    description = models.TextField(blank=True, default='')
    # "The user finished or skipped the business step" — distinct from whether
    # the other onboarding sections hold any data.
    onboarding_step_completed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.business_name


class BusinessGoal(models.Model):
    """A goal the user wants NURU to help them reach. Repeatable."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='business_goals',
    )
    goal_text = models.TextField()
    # NOTE: Railway's filesystem is ephemeral, so uploads do not survive a
    # redeploy. Tracked as a follow-up to move to object storage.
    attachment = models.FileField(upload_to='goals/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return self.goal_text[:60]


class Loan(models.Model):
    """An outstanding loan the user is servicing."""
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='loans',
    )
    amount = models.DecimalField(max_digits=15, decimal_places=2)
    interest_rate = models.DecimalField(max_digits=6, decimal_places=3, null=True, blank=True)
    date_taken = models.DateField()
    due_date = models.DateField(null=True, blank=True)
    lender_name = models.CharField(max_length=200, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date_taken']

    def __str__(self):
        return f"{self.lender_name or 'Loan'}: {self.amount}"


class ConnectedAccount(models.Model):
    """A bank account the user linked through Mono.

    `mono_account_id` is stored in plaintext because it is the lookup key.
    `mono_access_token` holds the credential material and is encrypted at rest
    via EncryptedTextField, so the raw column is Fernet ciphertext.
    """
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='connected_accounts',
    )
    provider = models.CharField(
        max_length=20, choices=CONNECTED_ACCOUNT_PROVIDER_CHOICES, default='mono'
    )
    mono_account_id = models.CharField(max_length=255, blank=True, default='')
    institution_name = models.CharField(max_length=200, blank=True, default='')
    account_name = models.CharField(max_length=200, blank=True, default='')
    account_number_masked = models.CharField(max_length=32, blank=True, default='')
    mono_access_token = EncryptedTextField(blank=True, default='')
    # Correlates a callback with the initiate call that started it.
    mono_ref = models.CharField(max_length=64, blank=True, default='', db_index=True)
    status = models.CharField(
        max_length=20, choices=CONNECTED_ACCOUNT_STATUS_CHOICES, default='pending'
    )
    last_error = models.CharField(max_length=500, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            # Makes "connect another account" and callback retries idempotent.
            models.UniqueConstraint(
                fields=['user', 'mono_account_id'],
                condition=models.Q(mono_account_id__gt=''),
                name='uniq_user_mono_account',
            )
        ]

    def __str__(self):
        return f"{self.institution_name or self.provider} ({self.status})"


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
