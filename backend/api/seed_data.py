"""
NURU Demo Data Seeder
Creates a realistic freelancer financial profile for demo purposes.
Timestamps are carefully placed to ensure data spans the current month.
"""

from decimal import Decimal
from datetime import timedelta
from django.utils import timezone


def seed_user_transactions(user, force_reset=False):
    """Seed or re-seed realistic transaction history for any user profile."""
    from .models import Transaction

    if not force_reset and user.transactions.count() > 0:
        return user

    if force_reset:
        user.transactions.all().delete()

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

    print(f"Seeded {len(transactions)} transactions for {user.first_name} {user.last_name}")
    return user


def seed_demo_data():
    """Seed the database with a realistic demo profile and transaction history."""
    from .models import UserProfile

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

    return seed_user_transactions(user, force_reset=True)


def seed_samson_transactions(user, force_reset=False):
    """Seed realistic Nigerian business & BMONI sandbox transactions for Samson Jabo."""
    from .models import Transaction

    if not force_reset and user.transactions.count() > 0:
        return user

    if force_reset:
        user.transactions.all().delete()

    now = timezone.now()
    month_start = now.replace(day=1, hour=9, minute=0, second=0, microsecond=0)

    transactions = [
        # This Month - Income
        {
            'description': 'Farmyn Produce Settlement',
            'amount': Decimal('180000.00'),
            'currency': 'NGN',
            'transaction_type': 'credit',
            'category': 'business_income',
            'timestamp': month_start + timedelta(hours=4),
        },
        {
            'description': 'Ajortrust P2P Credit',
            'amount': Decimal('45000.00'),
            'currency': 'NGN',
            'transaction_type': 'credit',
            'category': 'business_income',
            'timestamp': month_start + timedelta(hours=14),
        },
        {
            'description': 'Contract Services Payout',
            'amount': Decimal('60000.00'),
            'currency': 'NGN',
            'transaction_type': 'credit',
            'category': 'freelance_income',
            'timestamp': month_start + timedelta(days=1, hours=2),
        },

        # This Month - Debits (matching official BMONI Sandbox proposals)
        {
            'description': 'Farmyn escrow order',
            'amount': Decimal('28000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start + timedelta(days=1, hours=8),
        },
        {
            'description': 'Ajortrust Phase 4 real sandbox P2P',
            'amount': Decimal('1.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'transfer_out',
            'timestamp': month_start + timedelta(days=2, hours=1),
        },
        {
            'description': 'Farmyn escrow order',
            'amount': Decimal('28000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start + timedelta(days=2, hours=5),
        },
        {
            'description': 'Food & groceries - Shoprite',
            'amount': Decimal('25000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'food',
            'timestamp': month_start + timedelta(days=2, hours=9),
        },
        {
            'description': 'Fuel & logistics',
            'amount': Decimal('15000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'transport',
            'timestamp': month_start + timedelta(days=2, hours=12),
        },
        {
            'description': 'Internet subscription - Spectranet',
            'amount': Decimal('12000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'utilities',
            'timestamp': month_start + timedelta(days=2, hours=15),
        },
        {
            'description': 'Electricity - IKEDC prepaid',
            'amount': Decimal('8000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'utilities',
            'timestamp': month_start + timedelta(days=2, hours=18),
        },

        # Last Month - Trends baseline
        {
            'description': 'Farmyn Harvest Settlement',
            'amount': Decimal('220000.00'),
            'currency': 'NGN',
            'transaction_type': 'credit',
            'category': 'business_income',
            'timestamp': month_start - timedelta(days=15),
        },
        {
            'description': 'Farmyn agricultural supply',
            'amount': Decimal('50000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start - timedelta(days=12),
        },
        {
            'description': 'Logistics & equipment repair',
            'amount': Decimal('30000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'business_expense',
            'timestamp': month_start - timedelta(days=7),
        },
        {
            'description': 'Household supplies & groceries',
            'amount': Decimal('25000.00'),
            'currency': 'NGN',
            'transaction_type': 'debit',
            'category': 'food',
            'timestamp': month_start - timedelta(days=4),
        },
    ]

    for txn_data in transactions:
        Transaction.objects.create(user=user, **txn_data)

    print(f"Seeded {len(transactions)} Nigerian transactions for Samson Jabo ({user.bmoni_user_id})")
    return user
