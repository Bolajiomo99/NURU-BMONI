"""
API App Config
Executes database migrations and initial demo seeding automatically on startup.
"""

import sys
import logging
from django.apps import AppConfig

logger = logging.getLogger(__name__)


class ApiConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'api'

    def ready(self):
        """Auto-run migrations and seed initial data if DB tables do not exist."""
        # Skip during management commands like makemigrations/migrate/check
        if any(cmd in sys.argv for cmd in ('makemigrations', 'migrate', 'test', 'check', 'collectstatic')):
            return

        try:
            from django.core.management import call_command
            from api.models import UserProfile

            # Ensure all migrations are applied
            call_command('migrate', interactive=False)

            # Ensure demo data is seeded if database is fresh
            if UserProfile.objects.count() == 0:
                from api.seed_data import seed_demo_data
                seed_demo_data()
                logger.info("Successfully auto-migrated database and seeded initial demo profiles.")
        except Exception as e:
            logger.warning(f"Startup database migration check skipped or failed: {e}")
