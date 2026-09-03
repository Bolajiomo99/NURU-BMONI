"""
NURU Demo Data Seeder
Creates a realistic freelancer financial profile for demo purposes.
Timestamps are carefully placed to ensure data spans the current month.
"""

from decimal import Decimal
from datetime import timedelta
from django.utils import timezone


def seed_demo_data():
    """Seed the database with a realistic demo profile and transaction history."""
    from .models import UserProfile, Transaction

    # Clear existing demo data
    UserProfile.objects.filter(email='bolaji@nuru.demo').delete()

    # Create demo user
    user = UserProfile.objects.create(
        bmoni_user_id='demo-user-001',
        first_name='Bolaji',
        last_name='Omo',
        email='bolaji@nuru.demo',
        phone_number='+2348000000000',
        onboarding_complete=True,
    )

    now = timezone.now()
    # Anchor all "this month" transactions from the 1st of the current month
    month_start = now.replace(day=1, hour=9, minute=0, second=0, microsecond=0)

    # ── This Month Transactions ───────────────────────────────────
    transactions = [
        # Income — this month (anchored from month start)
        {
            'description': 'Freelance payment - Upwork',
            'amount': Decimal('500.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'freelance_income',
            'timestamp': month_start + timedelta(hours=6),
        },
        {
            'description': 'Freelance payment - Fiverr',
            'amount': Decimal('300.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'freelance_income',
            'timestamp': month_start + timedelta(hours=12),
        },
        {
            'description': 'Salary - Digital Agency',
            'amount': Decimal('620.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'employment',
            'timestamp': month_start + timedelta(hours=3),
        },
        {
            'description': 'Local client payment - Logo design',
            'amount': Decimal('200000.00'),
            'currency': 'NGN',
            'transaction_type': 'credit',
            'category': 'business_income',
            'timestamp': month_start + timedelta(hours=18),
        },

        # Spending USD — this month
        {
            'description': 'Netflix subscription',
            'amount': Decimal('15.99'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'entertainment',
            'timestamp': month_start + timedelta(hours=24),
        },
        {
            'description': 'Spotify Premium',
            'amount': Decimal('9.99'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'entertainment',
            'timestamp': month_start + timedelta(hours=30),
        },
        {
            'description': 'AWS hosting - production server',
            'amount': Decimal('23.50'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start + timedelta(hours=36),
        },
        {
            'description': 'Family support transfer',
            'amount': Decimal('100.00'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'family_support',
            'timestamp': month_start + timedelta(hours=42),
        },
        {
            'description': 'Figma Pro subscription',
            'amount': Decimal('12.99'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'business_tool',
            'timestamp': month_start + timedelta(hours=48),
        },
        {
            'description': 'Domain renewal - GoDaddy',
            'amount': Decimal('14.99'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start + timedelta(hours=50),
        },

        # Spending NGN — this month
        {
            'description': 'Uber rides - weekly',
            'amount': Decimal('15000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'transport',
            'timestamp': month_start + timedelta(hours=52),
        },
        {
            'description': 'Food & groceries - Shoprite',
            'amount': Decimal('25000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'food',
            'timestamp': month_start + timedelta(hours=54),
        },
        {
            'description': 'Internet bill - Spectranet',
            'amount': Decimal('12000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'utilities',
            'timestamp': month_start + timedelta(hours=56),
        },
        {
            'description': 'Electricity - IKEDC prepaid',
            'amount': Decimal('8000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'utilities',
            'timestamp': month_start + timedelta(hours=58),
        },

        # ── Last month income (for trend comparison) ──────────────
        {
            'description': 'Freelance payment - Toptal',
            'amount': Decimal('400.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'freelance_income',
            'timestamp': month_start - timedelta(days=5),
        },
        {
            'description': 'Salary - Digital Agency',
            'amount': Decimal('620.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'employment',
            'timestamp': month_start - timedelta(days=15),
        },
        {
            'description': 'Freelance payment - direct client',
            'amount': Decimal('180.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'freelance_income',
            'timestamp': month_start - timedelta(days=10),
        },

        # Last month spending
        {
            'description': 'Netflix subscription',
            'amount': Decimal('15.99'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'entertainment',
            'timestamp': month_start - timedelta(days=3),
        },
        {
            'description': 'AWS hosting',
            'amount': Decimal('21.00'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start - timedelta(days=7),
        },
        {
            'description': 'Family support transfer',
            'amount': Decimal('100.00'),
            'currency': 'USD',
            'transaction_type': 'debit',
            'category': 'family_support',
            'timestamp': month_start - timedelta(days=8),
        },
    ]

    for txn_data in transactions:
        Transaction.objects.create(user=user, **txn_data)

    print(f"✅ Seeded {len(transactions)} transactions for {user.first_name} {user.last_name}")
    return user
