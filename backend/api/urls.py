"""NURU API URL Configuration."""

from django.urls import path
from .views import (
    DashboardView,
    ChatView,
    ExplainView,
    AffordabilityCheckView,
    TransferActionView,
    SwapActionView,
    BmoniUserView,
    BmoniBalancesView,
    BmoniLoginView,
    SeedDataView,
    TransactionsView,
    SecurityStatusView,
    PinSetupView,
    PinVerifyView,
    FaceEnrollView,
    FaceVerifyView,
)

urlpatterns = [
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

    # Action endpoints
    path('action/transfer/', TransferActionView.as_view(), name='action-transfer'),
    path('action/swap/', SwapActionView.as_view(), name='action-swap'),

    # BMONI proxy endpoints
    path('bmoni/user/', BmoniUserView.as_view(), name='bmoni-user'),
    path('bmoni/login/', BmoniLoginView.as_view(), name='bmoni-login'),
    path('bmoni/balances/', BmoniBalancesView.as_view(), name='bmoni-balances'),

    # Admin / Demo
    path('seed/', SeedDataView.as_view(), name='seed'),
]
