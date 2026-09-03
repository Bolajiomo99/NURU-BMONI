web: ([ -d backend ] && cd backend || true) && python manage.py migrate && python manage.py collectstatic --noinput && gunicorn nuru.wsgi:application --bind 0.0.0.0:$PORT
