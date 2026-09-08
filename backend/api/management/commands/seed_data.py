"""
Django management command to seed demo data.
Invoked by Railway deployment in Procfile and railway.json.
"""

from django.core.management.base import BaseCommand
from api.seed_data import seed_demo_data


class Command(BaseCommand):
    help = "Seed initial demo users and transactions for NURU"

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("Seeding NURU demo data..."))
        user = seed_demo_data()
        self.stdout.write(
            self.style.SUCCESS(
                f"Successfully seeded demo profile for {user.first_name} {user.last_name} ({user.bmoni_user_id}) with {user.transactions.count()} transactions."
            )
        )
