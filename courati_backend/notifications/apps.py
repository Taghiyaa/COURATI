# notifications/apps.py
from django.apps import AppConfig


class NotificationsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'notifications'
    verbose_name = 'Notifications Push'
    
    def ready(self):
        """Importer les signals quand l'app est prête"""
        print("🔔 Chargement des signals notifications...")
        import notifications.signals
        print("✅ Signals notifications chargés !")