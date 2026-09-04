"""
NURU Analytics Engine
Financial health scoring, spending categorization, and trend analysis.
"""

from decimal import Decimal
from datetime import timedelta
from django.utils import timezone
from django.db.models import Sum, Q


# Approximate NGN to USD rate for unified calculations
NGN_TO_USD_RATE = Decimal('0.00062')  # ~₦1,600 = $1


def calculate_health_score(user):
    """
    Calculate a 0-100 financial health score based on:
    - Income stability (25 pts)
    - Spending ratio (25 pts)
    - Currency diversification (20 pts)
    - Savings buffer (20 pts)
    - Spending trend (10 pts)
    """
    from .models import Transaction

    now = timezone.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    last_month_start = (month_start - timedelta(days=1)).replace(day=1)

    txns_this_month = user.transactions.filter(timestamp__gte=month_start)
    txns_last_month = user.transactions.filter(
        timestamp__gte=last_month_start, timestamp__lt=month_start
    )

    score = 0

    # ── Income Stability (25 pts) ─────────────────────────────────
    income_this = _total_income_usd(txns_this_month)
    income_last = _total_income_usd(txns_last_month)

    if income_this > 0:
        score += 15  # Has income this month
        if income_last > 0:
            ratio = float(income_this / income_last)
            if ratio >= 0.8:
                score += 10  # Stable or growing
            elif ratio >= 0.5:
                score += 5

    # ── Spending Ratio (25 pts) ───────────────────────────────────
    spending_this = _total_spending_usd(txns_this_month)

    if income_this > 0:
        spend_ratio = float(spending_this / income_this)
        if spend_ratio <= 0.4:
            score += 25  # Very healthy
        elif spend_ratio <= 0.6:
            score += 20
        elif spend_ratio <= 0.8:
            score += 12
        elif spend_ratio <= 1.0:
            score += 5
    elif spending_this == 0:
        score += 15  # No spending, no income — neutral

    # ── Currency Diversification (20 pts) ─────────────────────────
    usd_balance, ngn_balance = _get_balances_from_transactions(user)
    total_usd_equiv = usd_balance + (ngn_balance * NGN_TO_USD_RATE)

    if total_usd_equiv > 0:
        usd_pct = float(usd_balance / total_usd_equiv) if total_usd_equiv > 0 else 0
        if 0.3 <= usd_pct <= 0.7:
            score += 20  # Well diversified
        elif 0.2 <= usd_pct <= 0.8:
            score += 14
        else:
            score += 7  # Heavily concentrated

    # ── Savings Buffer (20 pts) ───────────────────────────────────
    weekly_spending = spending_this / max(Decimal('1'), Decimal(str(_days_into_month(now)))) * 7
    if weekly_spending > 0 and total_usd_equiv > 0:
        weeks_covered = float(total_usd_equiv / weekly_spending)
        if weeks_covered >= 8:
            score += 20
        elif weeks_covered >= 4:
            score += 15
        elif weeks_covered >= 2:
            score += 10
        elif weeks_covered >= 1:
            score += 5
    elif total_usd_equiv > 0:
        score += 15  # Has money, no spending pattern yet

    # ── Spending Trend (10 pts) ───────────────────────────────────
    spending_last = _total_spending_usd(txns_last_month)
    if spending_last > 0 and spending_this > 0:
        trend = float(spending_this / spending_last)
        if trend <= 0.9:
            score += 10  # Spending decreased
        elif trend <= 1.1:
            score += 7   # Roughly stable
        elif trend <= 1.3:
            score += 3   # Slight increase
    elif spending_this == 0:
        score += 8

    return min(100, max(0, score))


def get_financial_summary(user):
    """Generate a complete financial summary for the dashboard and AI."""
    from .models import Transaction

    now = timezone.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    last_month_start = (month_start - timedelta(days=1)).replace(day=1)

    txns_this_month = user.transactions.filter(timestamp__gte=month_start)
    txns_last_month = user.transactions.filter(
        timestamp__gte=last_month_start, timestamp__lt=month_start
    )

    # Current month totals
    income_usd = _sum_by(txns_this_month, 'credit', 'USD')
    income_ngn = _sum_by(txns_this_month, 'credit', 'NGN')
    spending_usd = _sum_by(txns_this_month, 'debit', 'USD')
    spending_ngn = _sum_by(txns_this_month, 'debit', 'NGN')

    # Last month for comparison
    last_income_usd = _sum_by(txns_last_month, 'credit', 'USD')
    last_spending_usd = _sum_by(txns_last_month, 'debit', 'USD')

    # Spending by category
    categories = get_spending_by_category(user)

    # Health score
    health_score = calculate_health_score(user)

    # Safe to spend this week
    safe_weekly = _calculate_safe_weekly_spend(user, health_score)

    # Income change percentage
    total_income = income_usd + (income_ngn * NGN_TO_USD_RATE)
    total_last_income = last_income_usd
    income_change_pct = 0
    if total_last_income > 0:
        income_change_pct = round(
            float((total_income - total_last_income) / total_last_income * 100), 1
        )

    # Spending change percentage
    total_spending = spending_usd + (spending_ngn * NGN_TO_USD_RATE)
    total_last_spending = last_spending_usd
    spending_change_pct = 0
    if total_last_spending > 0:
        spending_change_pct = round(
            float((total_spending - total_last_spending) / total_last_spending * 100), 1
        )

    # Currency concentration
    usd_balance, ngn_balance = _get_balances_from_transactions(user)
    total_equiv = usd_balance + (ngn_balance * NGN_TO_USD_RATE)
    usd_concentration = round(float(usd_balance / total_equiv * 100), 1) if total_equiv > 0 else 0

    return {
        'health_score': health_score,
        'health_status': _score_to_status(health_score),
        'balances': {
            'usd': float(usd_balance),
            'ngn': float(ngn_balance),
            'total_usd_equivalent': float(total_equiv),
        },
        'this_month': {
            'income_usd': float(income_usd),
            'income_ngn': float(income_ngn),
            'spending_usd': float(spending_usd),
            'spending_ngn': float(spending_ngn),
            'net_usd': float(income_usd - spending_usd),
            'net_ngn': float(income_ngn - spending_ngn),
        },
        'trends': {
            'income_change_pct': income_change_pct,
            'spending_change_pct': spending_change_pct,
        },
        'categories': categories,
        'safe_weekly_spend_usd': float(safe_weekly),
        'currency_concentration': {
            'usd_pct': usd_concentration,
            'ngn_pct': round(100 - usd_concentration, 1),
        },
        'recent_transactions': _recent_transactions(user, limit=10),
    }


def get_spending_by_category(user):
    """Aggregate spending by category for current month."""
    now = timezone.now()
    month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    debits = user.transactions.filter(
        timestamp__gte=month_start,
        transaction_type='debit',
    ).values('category').annotate(
        total_usd=Sum('amount', filter=Q(currency='USD')),
        total_ngn=Sum('amount', filter=Q(currency='NGN')),
    )

    categories = []
    for item in debits:
        usd = item['total_usd'] or Decimal('0')
        ngn = item['total_ngn'] or Decimal('0')
        total_equiv = float(usd + ngn * NGN_TO_USD_RATE)
        categories.append({
            'category': item['category'],
            'label': dict(
                user.transactions.model.CATEGORY_CHOICES
            ).get(item['category'], item['category']),
            'usd': float(usd),
            'ngn': float(ngn),
            'total_usd_equivalent': total_equiv,
        })

    categories.sort(key=lambda x: x['total_usd_equivalent'], reverse=True)
    return categories


def can_afford(user, amount_usd):
    """Check if a user can afford a USD expense while remaining safe."""
    summary = get_financial_summary(user)
    current_balance = Decimal(str(summary['balances']['usd']))
    safe_weekly = Decimal(str(summary['safe_weekly_spend_usd']))
    remaining = current_balance - Decimal(str(amount_usd))

    return {
        'can_afford': remaining >= 0,
        'remaining_after': float(remaining),
        'within_safe_range': remaining >= safe_weekly,
        'current_balance': float(current_balance),
        'safe_weekly_spend': float(safe_weekly),
        'health_impact': 'none' if remaining >= safe_weekly else
                         'low' if remaining >= safe_weekly * Decimal('0.5') else 'high',
    }


# ── Private helpers ───────────────────────────────────────────────

def _sum_by(queryset, txn_type, currency):
    result = queryset.filter(
        transaction_type=txn_type, currency=currency
    ).aggregate(total=Sum('amount'))['total']
    return result or Decimal('0')


def _total_income_usd(queryset):
    usd = _sum_by(queryset, 'credit', 'USD')
    ngn = _sum_by(queryset, 'credit', 'NGN')
    return usd + (ngn * NGN_TO_USD_RATE)


def _total_spending_usd(queryset):
    usd = _sum_by(queryset, 'debit', 'USD')
    ngn = _sum_by(queryset, 'debit', 'NGN')
    return usd + (ngn * NGN_TO_USD_RATE)


def _get_balances_from_transactions(user):
    """Calculate running balances or fetch live BMONI balances if connected."""
    if user.bmoni_user_id and user.bmoni_user_id != 'demo-user-001' and not user.bmoni_user_id.startswith('bmoni-0'):
        try:
            from .bmoni_client import BmoniClient
            client = BmoniClient()
            res = client.get_balances(user.bmoni_user_id)
            if res.get('success') and res.get('data'):
                data = res['data']
                usd_bal = Decimal('0')
                ngn_bal = Decimal('0')
                if isinstance(data, list):
                    for item in data:
                        curr = str(item.get('currency', '')).upper()
                        amt = Decimal(str(item.get('amount', 0)))
                        if curr in ['USD', 'USDC']:
                            usd_bal += amt
                        elif curr in ['NGN', 'CNGN']:
                            ngn_bal += amt
                    if usd_bal > 0 or ngn_bal > 0:
                        return (usd_bal, ngn_bal)
                elif isinstance(data, dict):
                    usd_bal = Decimal(str(data.get('usd', data.get('USD', 0))))
                    ngn_bal = Decimal(str(data.get('ngn', data.get('NGN', 0))))
                    if usd_bal > 0 or ngn_bal > 0:
                        return (usd_bal, ngn_bal)
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"Error fetching live BMONI balances: {e}")

    credits_usd = _sum_by(user.transactions.all(), 'credit', 'USD')
    debits_usd = _sum_by(user.transactions.all(), 'debit', 'USD')
    credits_ngn = _sum_by(user.transactions.all(), 'credit', 'NGN')
    debits_ngn = _sum_by(user.transactions.all(), 'debit', 'NGN')
    return (credits_usd - debits_usd, credits_ngn - debits_ngn)


def _calculate_safe_weekly_spend(user, health_score):
    """Estimate safe weekly spending based on balance and patterns."""
    usd_balance, ngn_balance = _get_balances_from_transactions(user)
    total = usd_balance + (ngn_balance * NGN_TO_USD_RATE)

    # Conservatively allow 15-25% of total balance per week
    if health_score >= 80:
        return total * Decimal('0.25')
    elif health_score >= 60:
        return total * Decimal('0.20')
    elif health_score >= 40:
        return total * Decimal('0.15')
    else:
        return total * Decimal('0.10')


def _days_into_month(now):
    return now.day


def _score_to_status(score):
    if score >= 80:
        return 'Healthy'
    elif score >= 60:
        return 'Good'
    elif score >= 40:
        return 'Fair'
    elif score >= 20:
        return 'Caution'
    else:
        return 'Critical'


def _recent_transactions(user, limit=10):
    txns = user.transactions.all()[:limit]
    return [
        {
            'id': t.id,
            'description': t.description,
            'amount': float(t.amount),
            'currency': t.currency,
            'type': t.transaction_type,
            'category': t.category,
            'category_label': dict(t.CATEGORY_CHOICES).get(t.category, t.category),
            'timestamp': t.timestamp.isoformat(),
        }
        for t in txns
    ]
