"""
Django settings for NURU project.
AI Financial Copilot for BMONI
"""

import os
from pathlib import Path
from dotenv import load_dotenv

import dj_database_url
from corsheaders.defaults import default_headers

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent


def _csv_env(name, default=''):
    """Read a comma-separated env var into a stripped, non-empty list."""
    return [item.strip() for item in os.getenv(name, default).split(',') if item.strip()]


SECRET_KEY = os.getenv('SECRET_KEY', 'nuru-hackathon-demo-key')
DEBUG = os.getenv('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = _csv_env('ALLOWED_HOSTS') or ['*']

# Railway terminates TLS at the proxy; without this, password-reset links
# and Mono redirect URLs would be built as http://
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')

# Gemini AI Configuration
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')

# Resend (transactional email: OTP codes, password-reset links)
RESEND_API_KEY = os.getenv('RESEND_API_KEY', '')
RESEND_FROM_EMAIL = os.getenv('RESEND_FROM_EMAIL', 'NURU <onboarding@resend.dev>')

# Mono (bank account linking). Sandbox vs live is decided by the key prefix
# (test_sk_… vs live_sk_…), not by the base URL.
MONO_SECRET_KEY = os.getenv('MONO_SECRET_KEY', '')
MONO_BASE_URL = os.getenv('MONO_BASE_URL', 'https://api.withmono.com')
MONO_REDIRECT_URL = os.getenv('MONO_REDIRECT_URL', 'https://nuru-bmoni.up.railway.app/mono/callback')

# Where the Flutter web build is served from, for links inside emails
FRONTEND_BASE_URL = os.getenv('FRONTEND_BASE_URL', 'https://nuru-bmoni.up.railway.app')

# Fernet key for ConnectedAccount.mono_access_token. Falls back to a value
# derived from SECRET_KEY so local dev and tests need no extra secret.
FIELD_ENCRYPTION_KEY = os.getenv('FIELD_ENCRYPTION_KEY', '')

# Auth tunables
OTP_TTL_MINUTES = int(os.getenv('OTP_TTL_MINUTES', '10'))
OTP_MAX_ATTEMPTS = int(os.getenv('OTP_MAX_ATTEMPTS', '5'))
OTP_RESEND_COOLDOWN_SECONDS = int(os.getenv('OTP_RESEND_COOLDOWN_SECONDS', '60'))
PASSWORD_RESET_TTL_MINUTES = int(os.getenv('PASSWORD_RESET_TTL_MINUTES', '60'))

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'api',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    # DRF's APIView.dispatch is csrf_exempt, so this protects /admin/ only
    # and does not affect any API endpoint.
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# Allow Flutter app to connect. Wide open in dev; allowlisted in production so
# an arbitrary site cannot call /api/auth/login/ from a victim's browser.
_cors_origins = _csv_env('CORS_ALLOWED_ORIGINS')
if DEBUG or not _cors_origins:
    CORS_ALLOW_ALL_ORIGINS = True
else:
    CORS_ALLOW_ALL_ORIGINS = False
    CORS_ALLOWED_ORIGINS = _cors_origins

# x-bmoni-user-id is not in django-cors-headers' default list; it works today
# only because the web build is served same-origin and never preflights.
CORS_ALLOW_HEADERS = list(default_headers) + ['x-bmoni-user-id']

ROOT_URLCONF = 'nuru.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'nuru.wsgi.application'

DATABASES = {
    'default': dj_database_url.parse(
        # dj_database_url.config()'s own `default` kwarg only applies when the
        # env var is unset — a *present-but-empty* DATABASE_URL (the state
        # .env.example documents as "falls back to local sqlite3") would
        # otherwise be parsed as-is and blow up with a missing ENGINE.
        # as_posix() so the Windows drive letter and separators survive URL parsing.
        os.getenv('DATABASE_URL') or f"sqlite:///{(BASE_DIR / 'db.sqlite3').as_posix()}",
        conn_max_age=600,
        conn_health_checks=True,
    )
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Africa/Lagos'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Uploaded goal attachments. NOTE: Railway's filesystem is ephemeral, so these
# do not survive a redeploy — move to object storage before relying on them.
MEDIA_URL = 'media/'
MEDIA_ROOT = BASE_DIR / 'media'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Flutter web build served at root URL via WhiteNoise
FLUTTER_WEB_DIR = BASE_DIR.parent / 'nuru_app' / 'build' / 'web'
WHITENOISE_ROOT = str(FLUTTER_WEB_DIR) if FLUTTER_WEB_DIR.exists() else None
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

REST_FRAMEWORK = {
    # TokenAuthentication only. SessionAuthentication runs its own CSRF check
    # independent of MIDDLEWARE, which would 403 anyone logged into /admin/ in
    # the same browser as the same-origin Flutter web app.
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
    ],
    # Stays AllowAny: flipping it would 401 the existing dashboard and chat.
    # New views opt in with an explicit permission_classes = [IsAuthenticated].
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.AllowAny',
    ],
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
}
