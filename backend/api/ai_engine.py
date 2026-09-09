"""
NURU AI Engine
Financial intelligence powered by Google Gemini.
Produces structured recommendations, not just text.
"""

import json
import logging
import os
import re
from google import genai
from google.genai import types
from django.conf import settings
from .analytics import get_financial_summary, can_afford, NGN_TO_USD_RATE

logger = logging.getLogger(__name__)

def _get_client():
    api_key = getattr(settings, 'GEMINI_API_KEY', '') or os.getenv('GEMINI_API_KEY', '')
    return genai.Client(api_key=api_key)

CANDIDATE_MODELS = [
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-3.7-flash',
]

def _generate_content_with_fallback(client, contents, config=None):
    """Generate content with model fallbacks if primary model experiences 503 spikes."""
    last_err = None
    for model_name in CANDIDATE_MODELS:
        try:
            return client.models.generate_content(
                model=model_name,
                contents=contents,
                config=config,
            )
        except Exception as e:
            logger.warning(f"Gemini model {model_name} failed: {e}. Attempting fallback...")
            last_err = e
    raise last_err

SYSTEM_PROMPT = """You are NURU, an AI Financial Copilot built on top of BMONI.
You help African freelancers, remote workers, and small business owners understand their money, make smarter decisions, and take action confidently.

Your personality:
- Warm, professional, and encouraging
- You speak clearly without jargon
- You give specific numbers and actionable advice
- You are concise — max 3-4 sentences per response unless explaining finances in detail
- You refer to yourself as "NURU" in third person when needed

Your capabilities:
- Analyze financial health from transaction history
- Recommend whether users can afford expenses
- Suggest optimal currency allocations (USD vs NGN)
- Flag spending trends and risks
- Recommend actionable BMONI operations (transfers, conversions)

CRITICAL REAL-MONEY TRANSFER RULES:
1. Since transfers process REAL MONEY, whenever the user asks to send or transfer money, you MUST ask for complete recipient account details if they were not already provided in the message!
2. Specifically, if Account Number, Bank Name, or Beneficiary Name are missing, ask the user clearly:
   "To complete this real transfer safely, please provide the recipient's account details:
   - Account Number (10-digit NGN account or BMONI User ID)
   - Bank Name (e.g. Access Bank, GTBank, Kuda, Zenith, OPay)
   - Beneficiary / Account Name"
3. DO NOT output a ```action``` block for transfers until the recipient's account details (or target beneficiary) are specified.
4. Never recommend spending that would put the user below their safe weekly spending threshold.
5. Ground recommendations in actual balance data and transaction history.

When you recommend a TRANSFER ACTION after account details are specified, include the recipient details in the JSON action block:
```action
{"type": "transfer", "amount": 10000, "currency": "NGN", "account_number": "0123456789", "bank_name": "GTBank", "account_name": "John Doe", "to": "John Doe (GTBank - 0123456789)", "description": "Transfer to John Doe"}
```
or for currency conversion / swap:
```action
{"type": "swap", "from_currency": "USD", "to_currency": "NGN", "amount": 150, "description": "Convert for local expenses"}
```
Only include the action block when you are specifically recommending a validated action with complete details.
"""


def chat_with_nuru(user, message):
    """
    Process a user message and return NURU's AI response.
    Includes financial context for grounded recommendations.
    """
    from .models import ChatMessage

    # Build financial context
    summary = get_financial_summary(user)
    context = _build_financial_context(user, summary)

    # Get conversation history (last 10 messages)
    history = ChatMessage.objects.filter(user=user).order_by('-timestamp')[:10]
    history = list(reversed(history))

    # Build Gemini contents
    contents = []
    for msg in history:
        contents.append(
            types.Content(
                role='user' if msg.role == 'user' else 'model',
                parts=[types.Part.from_text(text=msg.content)],
            )
        )

    # Add current message with financial context
    full_message = f"""[FINANCIAL CONTEXT — current data, not visible to user]
{context}

[USER MESSAGE]
{message}"""

    contents.append(
        types.Content(
            role='user',
            parts=[types.Part.from_text(text=full_message)],
        )
    )

    try:
        client = _get_client()
        response = _generate_content_with_fallback(
            client=client,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                temperature=0.7,
                max_output_tokens=1024,
            ),
        )

        ai_text = response.text

        # Extract action if present
        action_type, action_data = _extract_action(ai_text)

        # Clean the response (remove action block from displayed text)
        clean_text = _clean_response(ai_text)

        # Save messages
        ChatMessage.objects.create(user=user, role='user', content=message)
        ChatMessage.objects.create(
            user=user,
            role='assistant',
            content=clean_text,
            action_type=action_type,
            action_data=action_data,
        )

        return {
            'message': clean_text,
            'action': {
                'type': action_type,
                'data': action_data,
            } if action_type else None,
            'financial_summary': {
                'health_score': summary['health_score'],
                'health_status': summary['health_status'],
                'balances': summary['balances'],
            },
        }

    except Exception as e:
        logger.error(f"Gemini API error: {e}")
        return {
            'message': "I'm having trouble processing that right now. Let me try again in a moment.",
            'action': None,
            'error': str(e),
        }


def explain_finances(user):
    """
    Generate a comprehensive "Explain My Money" financial story.
    """
    if user.bmoni_user_id and user.bmoni_user_id != 'guest-unauthenticated' and user.transactions.count() == 0:
        try:
            if user.bmoni_user_id == '43fc704e-bfd9-4ad3-8edf-b189453773b0':
                from .seed_data import seed_samson_transactions
                seed_samson_transactions(user)
            else:
                from .seed_data import seed_user_transactions
                seed_user_transactions(user)
        except Exception:
            pass

    # If guest or genuinely no transactions, return friendly onboarding explanation instantly
    if user.transactions.count() == 0:
        return {
            'story': (
                "## Welcome to NURU!\n\n"
                "You haven't made any transactions yet. As soon as you receive funds, send transfers, "
                "or convert currencies, your personalized AI financial story, spending breakdowns, "
                "and cash flow insights will be generated right here."
            ),
            'summary': {
                'health_score': 0,
                'health_status': 'Not Connected' if user.bmoni_user_id == 'guest-unauthenticated' else 'New Account',
                'balances': {'usd': 0.0, 'ngn': 0.0, 'total_usd_equivalent': 0.0},
                'this_month': {
                    'income_usd': 0.0, 'income_ngn': 0.0,
                    'spending_usd': 0.0, 'spending_ngn': 0.0,
                    'net_usd': 0.0, 'net_ngn': 0.0,
                },
                'trends': {'income_change_pct': 0.0, 'spending_change_pct': 0.0},
                'categories': [],
                'safe_weekly_spend_usd': 0.0,
                'currency_concentration': {'usd_pct': 0.0, 'ngn_pct': 0.0},
                'recent_transactions': [],
            },
        }

    summary = get_financial_summary(user)
    context = _build_financial_context(user, summary)

    prompt = f"""[FINANCIAL CONTEXT]
{context}

Generate a comprehensive financial story for this user. Structure your response as:

1. **Your Financial Story** — A narrative summary of their month
2. **Key Insights** — 3-4 specific observations about their finances
3. **Recommended Actions** — 2-3 specific, actionable recommendations with amounts

Be specific with numbers. Reference actual transactions and patterns.
Keep the total response under 300 words but make every word count.
"""

    try:
        client = _get_client()
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                _generate_content_with_fallback,
                client=client,
                contents=prompt,
                config=types.GenerateContentConfig(
                    system_instruction=SYSTEM_PROMPT,
                    temperature=0.7,
                    max_output_tokens=600,
                ),
            )
            response = future.result(timeout=6.5)

        return {
            'story': response.text,
            'summary': summary,
        }

    except Exception as e:
        logger.warning(f"Gemini explain_finances fallback triggered: {e}")
        return {
            'story': _generate_fallback_story(summary),
            'summary': summary,
        }


def get_ai_insight(user, summary=None):
    """
    Generate a single-line AI insight for the dashboard.
    Fast, focused, and specific.
    """
    if summary is None:
        summary = get_financial_summary(user)

    prompt = f"""Based on this financial data, generate ONE concise insight (1-2 sentences max).
Be specific with numbers and percentages. Do not use markdown formatting.

Health Score: {summary['health_score']}/100
USD Balance: ${summary['balances']['usd']:.2f}
NGN Balance: ₦{summary['balances']['ngn']:,.0f}
This month income: ${summary['this_month']['income_usd']:.2f} + ₦{summary['this_month']['income_ngn']:,.0f}
This month spending: ${summary['this_month']['spending_usd']:.2f} + ₦{summary['this_month']['spending_ngn']:,.0f}
Income change: {summary['trends']['income_change_pct']}%
Spending change: {summary['trends']['spending_change_pct']}%
USD concentration: {summary['currency_concentration']['usd_pct']}%
Safe weekly spend: ${summary['safe_weekly_spend_usd']:.2f}

Respond with ONLY the insight text, nothing else."""

    try:
        client = _get_client()
        import concurrent.futures
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
            future = executor.submit(
                _generate_content_with_fallback,
                client=client,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=0.5,
                    max_output_tokens=150,
                ),
            )
            response = future.result(timeout=4.0)

        return response.text.strip()
    except Exception as e:
        logger.warning(f"Gemini insight fallback triggered: {e}")
        # Fallback insight
        if summary['trends']['income_change_pct'] > 0:
            return f"Your income is {summary['trends']['income_change_pct']}% higher than last month. Your financial health is {summary['health_status'].lower()}."
        else:
            return f"Your financial health score is {summary['health_score']}/100. You can safely spend about ${summary['safe_weekly_spend_usd']:.0f} this week."


# ── Private helpers ───────────────────────────────────────────────

def _build_financial_context(user, summary):
    """Build a text context block for Gemini."""
    txn_list = '\n'.join([
        f"  {'+'if t['type']=='credit' else '-'}{t['currency']} {t['amount']:.2f} | {t['category_label']} | {t['description']} | {t['timestamp'][:10]}"
        for t in summary['recent_transactions']
    ])

    cat_list = '\n'.join([
        f"  {c['label']}: ${c['total_usd_equivalent']:.2f}"
        for c in summary['categories']
    ])

    return f"""User: {user.first_name} {user.last_name}
Health Score: {summary['health_score']}/100 ({summary['health_status']})

Balances:
  USD: ${summary['balances']['usd']:.2f}
  NGN: ₦{summary['balances']['ngn']:,.0f}
  Total (USD equiv): ${summary['balances']['total_usd_equivalent']:.2f}

This Month:
  Income: ${summary['this_month']['income_usd']:.2f} USD + ₦{summary['this_month']['income_ngn']:,.0f} NGN
  Spending: ${summary['this_month']['spending_usd']:.2f} USD + ₦{summary['this_month']['spending_ngn']:,.0f} NGN
  Net: ${summary['this_month']['net_usd']:.2f} USD / ₦{summary['this_month']['net_ngn']:,.0f} NGN

Trends:
  Income vs last month: {summary['trends']['income_change_pct']}%
  Spending vs last month: {summary['trends']['spending_change_pct']}%

Currency Concentration:
  USD: {summary['currency_concentration']['usd_pct']}%
  NGN: {summary['currency_concentration']['ngn_pct']}%

Safe Weekly Spend: ${summary['safe_weekly_spend_usd']:.2f}

Spending by Category:
{cat_list}

Recent Transactions:
{txn_list}"""


def _extract_action(text):
    """Extract action JSON from AI response."""
    match = re.search(r'```action\s*\n({.*?})\s*\n```', text, re.DOTALL)
    if match:
        try:
            data = json.loads(match.group(1))
            return data.get('type', ''), data
        except json.JSONDecodeError:
            pass
    return '', None


def _clean_response(text):
    """Remove action blocks from displayed text."""
    cleaned = re.sub(r'```action\s*\n{.*?}\s*\n```', '', text, flags=re.DOTALL)
    return cleaned.strip()


def _generate_fallback_story(summary):
    """Generate a basic financial story without AI."""
    income_usd = summary['this_month']['income_usd']
    health = summary['health_status']

    return f"""## Your Financial Story

You earned ${income_usd:.2f} in USD and ₦{summary['this_month']['income_ngn']:,.0f} in NGN this month.

Your total spending was ${summary['this_month']['spending_usd']:.2f} USD and ₦{summary['this_month']['spending_ngn']:,.0f} NGN.

Your financial health is **{health}** with a score of {summary['health_score']}/100.

You can safely spend approximately ${summary['safe_weekly_spend_usd']:.0f} this week while keeping your commitments covered.

**Note:** {summary['currency_concentration']['usd_pct']}% of your balance is in USD. Consider diversifying if you have regular NGN expenses."""
