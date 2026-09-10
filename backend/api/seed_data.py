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
            'description': 'Export settlement - AgroGlobal Trade',
            'amount': Decimal('1250.00'),
            'currency': 'USD',
            'transaction_type': 'credit',
            'category': 'business_income',
            'timestamp': month_start + timedelta(hours=2),
        },
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


def seed_demo_onboarded_user():
    """
    Creates/updates a fully onboarded test persona:
      - Email: demo@nuru.com / samson@nuru.com
      - Password: Password123!
      - Persona: Samson Jabo
      - Completed BusinessProfile (Samson Tech & Agro-Logistics)
      - Active BusinessGoals (Warehouse expansion, dispatch van fleet)
      - Connected Accounts (3 commercial banks: Access Bank, GTBank, Zenith Bank)
      - Active Loans (FairMoney SME Facility, Lapo Microfinance)
      - Full Nigerian transactions & balances ($2,305.55 / ₦3,500,000)
      - PIN 1234, Face recognition enrolled
    """
    from django.contrib.auth.models import User
    from rest_framework.authtoken.models import Token
    from .models import (
        UserProfile, BusinessProfile, BusinessGoal, Loan, ConnectedAccount
    )

    email = 'demo@nuru.com'
    auth_user, _ = User.objects.get_or_create(
        username=email,
        defaults={
            'email': email,
            'first_name': 'Samson',
            'last_name': 'Jabo',
            'is_active': True,
        }
    )
    auth_user.set_password('Password123!')
    auth_user.first_name = 'Samson'
    auth_user.last_name = 'Jabo'
    auth_user.email = email
    auth_user.is_active = True
    auth_user.save()

    Token.objects.get_or_create(user=auth_user)

    # Also make sure samson@nuru.com works with the same password
    alt_user, _ = User.objects.get_or_create(
        username='samson@nuru.com',
        defaults={
            'email': 'samson@nuru.com',
            'first_name': 'Samson',
            'last_name': 'Jabo',
            'is_active': True,
        }
    )
    alt_user.set_password('Password123!')
    alt_user.is_active = True
    alt_user.save()
    Token.objects.get_or_create(user=alt_user)

    # Link UserProfile
    profile, _ = UserProfile.objects.get_or_create(
        bmoni_user_id='43fc704e-bfd9-4ad3-8edf-b189453773b0',
        defaults={
            'first_name': 'Samson',
            'last_name': 'Jabo',
            'email': email,
            'phone_number': '+2348000000001',
            'smart_wallet_id': '3e64d0ba-30d1-4277-b72e-a2d2464b9c19',
            'wallet_address': '0xe7b1e4c0d790B66360cf66Dd9fbC1e0E3B2dd5d6',
            'smart_account_address': '0xe7b1e4c0d790B66360cf66Dd9fbC1e0E3B2dd5d6',
            'face_enrolled': False,
        }
    )
    profile.user = auth_user
    profile.email = email
    # Sandbox demo persona begins with 2FA un-enrolled so presenter/judges test live setup
    profile.face_enrolled = False
    profile.transaction_pin_hash = ''
    profile.face_image_data = ''
    profile.smart_wallet_id = '3e64d0ba-30d1-4277-b72e-a2d2464b9c19'
    profile.wallet_address = '0xe7b1e4c0d790B66360cf66Dd9fbC1e0E3B2dd5d6'
    profile.smart_account_address = '0xe7b1e4c0d790B66360cf66Dd9fbC1e0E3B2dd5d6'
    profile.save()

    # Seed Samson's Nigerian transactions
    if profile.transactions.count() == 0 or profile.transactions.filter(currency='USD', description__contains='Upwork').exists():
        seed_samson_transactions(profile, force_reset=True)

    # BusinessProfile
    biz, _ = BusinessProfile.objects.get_or_create(
        user=auth_user,
        defaults={
            'business_name': 'Samson Tech & Agro-Logistics',
            'business_size': 'small',
            'has_employees': True,
            'avg_employee_pay': Decimal('85000.00'),
            'spend_categories': ['inventory', 'utilities', 'transport', 'salaries'],
            'avg_monthly_revenue_range': '2m_10m',
            'description': 'Consumer electronics retail and cross-city agricultural logistics in Lagos and Abuja',
            'onboarding_step_completed': True,
        }
    )
    biz.business_name = 'Samson Tech & Agro-Logistics'
    biz.business_size = 'small'
    biz.has_employees = True
    biz.onboarding_step_completed = True
    biz.save()

    # BusinessGoals
    if not BusinessGoal.objects.filter(user=auth_user).exists():
        BusinessGoal.objects.create(
            user=auth_user,
            goal_text='Expand warehouse inventory in Ikeja for solar backup hardware by Q4',
        )
        BusinessGoal.objects.create(
            user=auth_user,
            goal_text='Deploy fleet tracking & cold-chain equipment for 3 dispatch vans',
        )

    # Connected Accounts (Commercial Banks)
    banks = [
        {
            'institution_name': 'Access Bank',
            'account_name': 'Samson Jabo Logistics',
            'account_number_masked': '069123****',
            'mono_account_id': 'mono_acc_access_01',
            'status': 'connected',
        },
        {
            'institution_name': 'GTBank',
            'account_name': 'Samson Jabo Commercial',
            'account_number_masked': '014987****',
            'mono_account_id': 'mono_acc_gtb_02',
            'status': 'connected',
        },
        {
            'institution_name': 'Zenith Bank',
            'account_name': 'Samson Jabo Corporate Reserve',
            'account_number_masked': '208345****',
            'mono_account_id': 'mono_acc_zenith_03',
            'status': 'connected',
        },
    ]
    for b in banks:
        ConnectedAccount.objects.update_or_create(
            user=auth_user,
            mono_account_id=b['mono_account_id'],
            defaults={
                'provider': 'mono',
                'institution_name': b['institution_name'],
                'account_name': b['account_name'],
                'account_number_masked': b['account_number_masked'],
                'status': 'connected',
            }
        )

    # Loans
    now = timezone.now().date()
    loans = [
        {
            'lender_name': 'FairMoney SME Growth Facility',
            'amount': Decimal('1500000.00'),
            'interest_rate': Decimal('3.500'),
            'date_taken': now - timedelta(days=45),
            'due_date': now + timedelta(days=135),
        },
        {
            'lender_name': 'Lapo Microfinance Inventory Expansion',
            'amount': Decimal('650000.00'),
            'interest_rate': Decimal('4.000'),
            'date_taken': now - timedelta(days=20),
            'due_date': now + timedelta(days=160),
        },
    ]
    for l in loans:
        Loan.objects.update_or_create(
            user=auth_user,
            lender_name=l['lender_name'],
            defaults=l,
        )

    return auth_user
