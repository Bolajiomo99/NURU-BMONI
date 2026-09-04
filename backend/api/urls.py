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
)

urlpatterns = [
    # Core NURU endpoints
    path('dashboard/', DashboardView.as_view(), name='dashboard'),
    path('chat/', ChatView.as_view(), name='chat'),
    path('explain/', ExplainView.as_view(), name='explain'),
    path('afford/', AffordabilityCheckView.as_view(), name='afford'),
    path('transactions/', TransactionsView.as_view(), name='transactions'),

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
