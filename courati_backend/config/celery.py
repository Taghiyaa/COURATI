# 📁 courati_backend/config/celery.py

import os
from celery import Celery
from celery.schedules import crontab

# Configuration Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

# Créer l'application Celery
app = Celery('config')

# Charger la configuration depuis Django settings
app.config_from_object('django.conf:settings', namespace='CELERY')

# Auto-découvrir les tâches dans toutes les apps Django
app.autodiscover_tasks()

# ✅ PLANIFICATION DES TÂCHES AUTOMATIQUES
app.conf.beat_schedule = {
    # Supprimer les notifications de plus de 30 jours
    # S'exécute tous les jours à 3h00 du matin
    'delete-old-notifications-daily': {
        'task': 'notifications.tasks.delete_old_notifications',
        'schedule': crontab(hour=3, minute=0),
    },
}

# Configuration timezone
app.conf.timezone = 'UTC'


@app.task(bind=True, ignore_result=True)
def debug_task(self):
    """Tâche de debug pour tester Celery"""
    print(f'Request: {self.request!r}')