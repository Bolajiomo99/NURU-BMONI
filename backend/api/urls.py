"""NURU API URL Configuration."""

from django.urls import path
from .auth_views import (
    ForgotPasswordView,
    LoginView,
    MeView,
    ResendOtpView,
    ResetPasswordView,
    SignupView,
    VerifyOtpView,
)
from .mono_views import (
    MonoAccountsView,
    MonoCallbackView,
    MonoInitiateView,
)
from .onboarding_views import (
    BusinessGoalDetailView,
    BusinessGoalListCreateView,
    BusinessProfileView,
    LoanDetailView,
    LoanListCreateView,
    OnboardingStatusView,
)
from .views import (
    DashboardView,
    ChatView,
    ExplainView,
    AffordabilityCheckView,
    TransferActionView,
    SwapActionView,
    SeedDataView,
    TransactionsView,
    SecurityStatusView,
    PinSetupView,
    PinVerifyView,
    FaceEnrollView,
    FaceVerifyView,
    ResetSandbox2FAView,
)

urlpatterns = [
    # Auth
    path('auth/signup/', SignupView.as_view(), name='auth-signup'),
    path('auth/verify-otp/', VerifyOtpView.as_view(), name='auth-verify-otp'),
    path('auth/resend-otp/', ResendOtpView.as_view(), name='auth-resend-otp'),
    path('auth/login/', LoginView.as_view(), name='auth-login'),
    path('auth/forgot-password/', ForgotPasswordView.as_view(), name='auth-forgot-password'),
    path('auth/reset-password/', ResetPasswordView.as_view(), name='auth-reset-password'),
    path('auth/me/', MeView.as_view(), name='auth-me'),

    # Onboarding
    path('onboarding/business/', BusinessProfileView.as_view(), name='onboarding-business'),
    path('onboarding/goals/', BusinessGoalListCreateView.as_view(), name='onboarding-goals'),
    path('onboarding/goals/<int:pk>/', BusinessGoalDetailView.as_view(), name='onboarding-goal-detail'),
    path('onboarding/loans/', LoanListCreateView.as_view(), name='onboarding-loans'),
    path('onboarding/loans/<int:pk>/', LoanDetailView.as_view(), name='onboarding-loan-detail'),
    path('onboarding/status/', OnboardingStatusView.as_view(), name='onboarding-status'),

    # Mono account linking
    path('mono/connect/initiate/', MonoInitiateView.as_view(), name='mono-initiate'),
    path('mono/connect/callback/', MonoCallbackView.as_view(), name='mono-callback'),
    path('mono/accounts/', MonoAccountsView.as_view(), name='mono-accounts'),

    # Core NURU endpoints
    path('dashboard/', DashboardView.as_view(), name='dashboard'),
    path('chat/', ChatView.as_view(), name='chat'),
    path('explain/', ExplainView.as_view(), name='explain'),
    path('afford/', AffordabilityCheckView.as_view(), name='afford'),
    path('transactions/', TransactionsView.as_view(), name='transactions'),

    # 2FA Security: PIN & Face Recognition
    path('auth/security-status/', SecurityStatusView.as_view(), name='security-status'),
    path('auth/pin/setup/', PinSetupView.as_view(), name='pin-setup'),
    path('auth/pin/verify/', PinVerifyView.as_view(), name='pin-verify'),
    path('auth/face/enroll/', FaceEnrollView.as_view(), name='face-enroll'),
    path('auth/face/verify/', FaceVerifyView.as_view(), name='face-verify'),
    path('auth/sandbox/reset-2fa/', ResetSandbox2FAView.as_view(), name='sandbox-reset-2fa'),

    # Action endpoints
    path('action/transfer/', TransferActionView.as_view(), name='action-transfer'),
    path('action/swap/', SwapActionView.as_view(), name='action-swap'),

    # Admin / Demo
    path('seed/', SeedDataView.as_view(), name='seed'),
]
