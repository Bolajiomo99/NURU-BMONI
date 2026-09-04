import os
import mimetypes
from django.contrib import admin
from django.urls import path, re_path, include
from django.http import JsonResponse, FileResponse
from django.conf import settings


def _find_web_dir():
    """Locate the Flutter web build directory, checking multiple candidate paths."""
    candidates = [
        getattr(settings, 'FLUTTER_WEB_DIR', None),
        os.path.join(settings.BASE_DIR, '..', 'nuru_app', 'build', 'web'),
        os.path.join(settings.BASE_DIR, 'nuru_app', 'build', 'web'),
    ]
    for c in candidates:
        if c and os.path.isdir(str(c)):
            return str(c)
    return None


def flutter_web_view(request, path=''):
    web_dir = _find_web_dir()
    if not web_dir:
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

    # Serve the specific file if it exists
    if path:
        requested_file = os.path.join(web_dir, path)
        if os.path.exists(requested_file) and os.path.isfile(requested_file):
            content_type, _ = mimetypes.guess_type(requested_file)
            return FileResponse(open(requested_file, 'rb'), content_type=content_type)

    # Fallback to index.html for SPA routing
    index_file = os.path.join(web_dir, 'index.html')
    if os.path.exists(index_file):
        return FileResponse(open(index_file, 'rb'), content_type='text/html')

    return JsonResponse({
        'status': 'online',
        'app': 'NURU — AI Financial Copilot for BMONI',
        'web_dir_checked': web_dir,
    })


urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('health/', lambda r: JsonResponse({'status': 'online'})),
    path('', flutter_web_view),
    re_path(r'^(?P<path>.*)$', flutter_web_view),
]
