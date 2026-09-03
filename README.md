# NURU — AI Financial Copilot for BMONI

> **"Don't just tell me how much money I have. Tell me what I should do with it."**

NURU turns BMONI from a place where money moves into an intelligent financial experience that helps African freelancers, remote workers, and small business owners understand, plan, and act on their multi-currency income.

---

## Architecture Overview

```
                      NURU App (Flutter)
                             │
            ┌────────────────┴────────────────┐
            │                                 │
     NURU UI (5 Screens)           bmoni_embedded_sdk
            │                       (On-device Signing)
            │                                 │
            └────────────────┬────────────────┘
                             │
                    Django API Engine
                             │
            ┌────────────────┴────────────────┐
            │                                 │
   Gemini 3.1 AI Engine              Analytics Engine
  (Financial Reasoning)           (Health Score: 0-100)
            │                                 │
            └────────────────┬────────────────┘
                             │
                      BMONI REST API
                             │
     ┌───────────────────────┼───────────────────────┐
     │                       │                       │
  Wallets                Balances               Proposals
 (USDB, CNGN)           (USD, NGN)           (TRANSFER, SWAP)
```

---

## Core Value Proposition

Existing fintech applications follow the pattern:  
`Balance → Transactions → Transfer → Convert`

**NURU changes that to:**  
`Money → Understanding → Recommendation → Action`

Instead of building "another wallet," NURU sits on top of BMONI's financial infrastructure as the intelligence decision layer.

---

## The 5-Screen User Flow

1. **Screen 1 — Onboarding (`OnboardingScreen`)**
   - Brand introduction & "Powered by BMONI" trust badge
   - Value propositions (Financial Understanding, Smart Recommendations, On-Device Key Security)

2. **Screen 2 — Financial Dashboard (`DashboardScreen`)**
   - **Financial Health Score** (circular gauge 0-100, color-coded status e.g. `🟢 72/100 Good`)
   - **Multi-currency Balances Card** (USD & NGN with total USD equivalent)
   - **Income vs Spending** breakdown for current month
   - **AI Insight Card** generated dynamically by Gemini
   - **"Explain My Money"** trigger for full financial narrative
   - **Recent Activity** list with category tags

3. **Screen 3 — AI Chat (`ChatScreen`)**
   - Interactive conversation with NURU AI
   - Pre-built suggestion chips (*"Can I afford to send $100 to my family?"*, *"Should I convert $150 USD to NGN?"*)
   - **Embedded Action Cards**: When NURU recommends a financial action, it renders an interactive card: `[ Send $100 → ]`

4. **Screen 4 — Smart Action (`SmartActionScreen`)**
   - Displays recommended BMONI operation details
   - **Financial Justification**: Why NURU recommends this action (safe weekly threshold, cash flow trends)
   - **Before vs After** balance projection & health impact check

5. **Screen 5 — Transaction Confirmation (`ConfirmationScreen`)**
   - Live step-by-step progress pipeline showing the full BMONI lifecycle:
     1. `NURU AI Financial Analysis` ✓
     2. `BMONI Proposal Created` (`POST /v1/users/.../proposals`) ✓
     3. `Admin Approval Vote` (`POST /proposals/.../approve`) ✓
     4. `On-Device Signature` (`bmoni_embedded_sdk`) ✓
     5. `BMONI Settlement Completed` ✅

---

## BMONI API Integration Mapping

| Lifecycle Stage | BMONI Endpoint / SDK Call | NURU Integration Purpose |
|---|---|---|
| **Stage 1: User** | `POST /v1/users` | Register user persona and scope all calls with `bmoniUserId` |
| **Stage 2: Wallet** | `POST /smart-wallets/owner-proof-challenges`<br>`POST /smart-wallets/create-managed` | Provision self-custodied `USDB` and `CNGN` smart wallets |
| **Stage 2: Signing** | `bmoni_embedded_sdk.signMessage`<br>`bmoni_embedded_sdk.signTransactionHash` | Sign owner-proof challenges and proposal hashes on-device |
| **Stage 3: KYC** | `PATCH /v1/users/{userId}/kyc`<br>`POST /kyc/activate` | Submit profile data & activate identity profiles |
| **Stage 4: Rail** | `POST /onboarding/start-nigeria`<br>`POST /onboarding/start-usa` | Activate NGN & USD money-movement rails |
| **Stage 5: Fund** | `GET /smart-wallets/account/balances` | Fetch multi-currency balances for NURU analytics engine |
| **Stage 6: Move Money** | `POST /smart-wallets/{id}/proposals`<br>`POST /proposals/{id}/approve`<br>`POST /proposals/{id}/sign` | Execute AI-recommended transfers & swaps through proposal flow |

---

## Setup & Local Run Instructions

### Prerequisites
- Python 3.10+
- Flutter 3.12+ / Dart 3.12+
- BMONI Sandbox API Key (`pk_a025cacbf33a_...`)
- Google Gemini API Key

### 1. Django Backend Setup

```bash
cd backend

# Create virtual environment & activate
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run migrations & seed demo data
python manage.py migrate
python manage.py shell -c "from api.seed_data import seed_demo_data; seed_demo_data()"

# Start Django backend
python manage.py runserver 0.0.0.0:8000
```

The API will be live at `http://localhost:8000/api/`.

### Key Backend Endpoints
- `GET /api/dashboard/` — Dashboard payload (health score, balances, insights)
- `POST /api/chat/` — AI conversation with structured action extraction
- `GET /api/explain/` — "Explain My Money" story
- `POST /api/action/transfer/` — Execute transfer proposal flow
- `POST /api/action/swap/` — Execute currency conversion proposal flow

### 2. Flutter App Setup

```bash
cd nuru_app

# Fetch dependencies
flutter pub get

# Analyze code quality
flutter analyze

# Run on emulator or connected physical device
flutter run
```

---

## Responsible AI & Security Note

1. **Self-Custody Key Isolation**: Private keys are generated and managed strictly within device hardware (Android Keystore / iOS Secure Enclave). Private keys never leave the device.
2. **Safe Spending Constraint**: NURU AI is bounded by strict financial guardrails. The AI will never recommend an expenditure that breaches the user's calculated safe weekly threshold.
3. **Transparent Decisioning**: AI recommendations include clear "Why NURU Recommends This" rationales grounded in actual income and commitment data.

---

## Presentation Pitch (for Hackathon Judges)

1. **Problem Statement**: Freelancers and small business owners receive funds across multiple currencies (USD, NGN). Existing apps only show balance numbers—users still struggle to know if they can safely spend, convert, or support family.
2. **The Solution**: NURU adds an intelligence layer on top of BMONI's multi-currency infrastructure.
3. **Demo Moment**:
   - Show Dashboard with Health Score 72/100 ("Good")
   - Ask NURU: *"Can I afford to send $100 to my family?"*
   - NURU analyzes cash flow, answers *"Yes"*, and presents an actionable BMONI Transfer Button.
   - Tap button → Review Justification → Execute step-by-step BMONI proposal and signature flow → Completed!
