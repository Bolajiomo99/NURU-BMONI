import os
from django.contrib import admin
from django.urls import path, re_path, include
from django.http import JsonResponse, FileResponse
from django.conf import settings


def flutter_web_view(request, path=''):
    web_dir = os.path.join(settings.BASE_DIR, '..', 'nuru_app', 'build', 'web')
    requested_file = os.path.join(web_dir, path) if path else os.path.join(web_dir, 'index.html')
    if os.path.exists(requested_file) and os.path.isfile(requested_file):
        return FileResponse(open(requested_file, 'rb'))
    
    # Fallback to index.html for SPA routing
    index_file = os.path.join(web_dir, 'index.html')
    if os.path.exists(index_file):
        return FileResponse(open(index_file, 'rb'))
    
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
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('health/', lambda r: JsonResponse({'status': 'online'})),
    path('', flutter_web_view),
    re_path(r'^(?P<path>.*)$', flutter_web_view),
]
