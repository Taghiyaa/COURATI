# notifications/signals.py
import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

from courses.models import Document, Quiz
from accounts.models import StudentProfile
from .models import NotificationHistory  # ✅ AJOUT CRUCIAL
from .services import send_push_notification

logger = logging.getLogger(__name__)
User = get_user_model()


@receiver(post_save, sender=Document)
def notify_new_document(sender, instance, created, **kwargs):
    """
    ⚡ Déclencher une tâche Celery quand un nouveau document est uploadé
    Version asynchrone - ne bloque PAS l'admin !
    """
    if not created:
        return
    
    document = instance
    
    print(f"📚 Nouveau document détecté: {document.title} ({document.subject.code})")
    print(f"🚀 Lancement de la tâche Celery en arrière-plan...")
    
    # ✅ LANCER LA TÂCHE CELERY (asynchrone)
    from .tasks import send_document_notifications
    
    # Utiliser .delay() pour l'exécution asynchrone
    result = send_document_notifications.delay(document.id)
    
    print(f"✅ Tâche Celery lancée avec ID: {result.id}")
    print(f"⚡ L'admin peut continuer à travailler, les notifications s'envoient en arrière-plan!")


# ========================================
# SIGNAL : NOUVEAU QUIZ (VERSION CELERY)
# ========================================

@receiver(post_save, sender=Quiz)
def notify_new_quiz(sender, instance, created, **kwargs):
    """
    ⚡ Déclencher une tâche Celery quand un nouveau quiz est créé
    Version asynchrone - ne bloque PAS l'admin !
    """
    if not created:
        return
    
    quiz = instance
    
    print(f"📝 Nouveau quiz détecté: {quiz.title} ({quiz.subject.code})")
    print(f"🚀 Lancement de la tâche Celery en arrière-plan...")
    
    # ✅ LANCER LA TÂCHE CELERY (asynchrone)
    from .tasks import send_quiz_notifications
    
    # Utiliser .delay() pour l'exécution asynchrone
    result = send_quiz_notifications.delay(quiz.id)
    
    print(f"✅ Tâche Celery lancée avec ID: {result.id}")
    print(f"⚡ L'admin peut continuer à travailler, les notifications s'envoient en arrière-plan!")


# ========================================
# SIGNAL : CRÉER PRÉFÉRENCES PAR DÉFAUT
# ========================================

@receiver(post_save, sender=User)
def create_default_notification_preferences(sender, instance, created, **kwargs):
    """
    Créer automatiquement les préférences de notification pour chaque nouvel utilisateur
    avec tous les types de notifications activés par défaut
    """
    if created:
        from .models import NotificationPreference
        
        NotificationPreference.objects.get_or_create(
            user=instance,
            defaults={
                'notifications_enabled': True,
                'new_content_enabled': True,
                'quiz_enabled': True,  # ✅ FORCÉ À TRUE
                'deadline_reminders_enabled': True,
            }
        )
        
        logger.info(f"✅ Préférences de notification créées pour {instance.username}")