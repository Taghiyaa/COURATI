# 📁 courati_backend/notifications/tasks.py

from celery import shared_task
from django.utils import timezone
from datetime import timedelta
from .models import NotificationHistory
import logging

logger = logging.getLogger(__name__)


@shared_task(name='notifications.tasks.delete_old_notifications')
def delete_old_notifications():
    """
    ✨ TÂCHE AUTOMATIQUE
    Supprime les notifications de plus de 30 jours
    S'exécute automatiquement tous les jours à 3h00
    """
    logger.info("🗑️ [CELERY] Démarrage suppression des anciennes notifications...")
    
    # Date seuil : il y a 30 jours
    threshold = timezone.now() - timedelta(days=30)
    
    # Chercher les notifications à supprimer
    to_delete = NotificationHistory.objects.filter(sent_at__lt=threshold)
    count = to_delete.count()
    
    if count == 0:
        logger.info("✅ [CELERY] Aucune notification à supprimer")
        return {
            'success': True,
            'deleted': 0,
            'message': 'Aucune notification à supprimer'
        }
    
    # Supprimer
    to_delete.delete()
    
    logger.info(f"✅ [CELERY] {count} notification(s) supprimée(s) (>30 jours)")
    
    return {
        'success': True,
        'deleted': count,
        'message': f'{count} notifications supprimées',
        'threshold': threshold.isoformat()
    }


@shared_task(name='notifications.tasks.test_celery')
def test_celery():
    """
    🧪 Tâche de test pour vérifier que Celery fonctionne
    """
    logger.info("🧪 [CELERY] Test de Celery en cours...")
    
    total = NotificationHistory.objects.count()
    logger.info(f"📊 [CELERY] Total notifications en BDD: {total}")
    
    return {
        'success': True,
        'total_notifications': total,
        'message': 'Celery fonctionne correctement!',
        'timestamp': timezone.now().isoformat()
    }