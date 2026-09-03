from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse

def root_health_view(request):
    return JsonResponse({
        'status': 'online',
        'app': 'NURU — AI Financial Copilot for BMONI',
        'backend': 'Django REST Framework',
        'bmoni_sandbox': 'https://embedded-dev.bmoni.com',
        'endpoints': {
            'dashboard': '/api/dashboard/',
            'chat': '/api/chat/',
            'explain': '/api/explain/',
            'transactions': '/api/transactions/',
        }
    })

urlpatterns = [
    path('', root_health_view),
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
]
