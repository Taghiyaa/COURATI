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


# ========================================
# SIGNAL : NOUVEAU DOCUMENT
# ========================================

@receiver(post_save, sender=Document)
def notify_new_document(sender, instance, created, **kwargs):
    """
    Envoyer une notification quand un nouveau document est uploadé
    """
    if not created:
        return
    
    document = instance
    subject = document.subject
    
    print(f"📚 Nouveau document détecté: {document.title} ({subject.code})")
    
    # Récupérer tous les étudiants concernés
    students = User.objects.filter(
        role='STUDENT',
        student_profile__level__in=subject.levels.all(),
        student_profile__major__in=subject.majors.all(),
        is_active=True
    ).distinct()
    
    print(f"👥 {students.count()} étudiants concernés")
    
    # Envoyer la notification à chaque étudiant
    for student in students:
        # Vérifier les préférences globales
        prefs = getattr(student, 'notification_preference', None)
        if not prefs or not prefs.notifications_enabled or not prefs.new_content_enabled:
            print(f"⏭️ Notifications désactivées pour {student.username}")
            continue
        
        # Vérifier les préférences par matière
        from .models import SubjectPreference
        subject_pref = SubjectPreference.objects.filter(
            user=student,
            subject=subject
        ).first()
        
        if subject_pref and not subject_pref.notifications_enabled:
            print(f"⏭️ Notifications désactivées pour {subject.code} par {student.username}")
            continue
        
        # Construire le titre et message
        doc_type_display = document.get_document_type_display()
        title = f"📚 Nouveau {doc_type_display.lower()} disponible !"
        body = f"{document.title} en {subject.name}"
        
        # Données supplémentaires
        data = {
            'type': 'new_document',
            'document_id': str(document.id),
            'subject_id': str(subject.id),
            'document_type': document.document_type,
        }
        
        # ✅ ÉTAPE 1 : ENREGISTRER dans NotificationHistory (BDD)
        try:
            notification_history = NotificationHistory.objects.create(
                user=student,
                notification_type='new_document',
                title=title,
                message=body,
                data=data
            )
            print(f"💾 Notification #{notification_history.id} enregistrée en BDD pour {student.username}")
        except Exception as e:
            print(f"❌ Erreur enregistrement BDD pour {student.username}: {e}")
            continue
        
        # ✅ ÉTAPE 2 : Envoyer la notification push (Firebase)
        success = send_push_notification(
            user=student,
            title=title,
            body=body,
            data=data
        )
        
        if success:
            print(f"✅ Notification push envoyée à {student.username}")
        else:
            print(f"⚠️ Échec notification push pour {student.username} (mais enregistrée en BDD)")


# ========================================
# SIGNAL : NOUVEAU QUIZ
# ========================================

@receiver(post_save, sender=Quiz)
def notify_new_quiz(sender, instance, created, **kwargs):
    """
    Envoyer une notification quand un nouveau quiz est créé
    """
    if not created:
        return
    
    quiz = instance
    subject = quiz.subject
    
    print(f"📝 Nouveau quiz détecté: {quiz.title} ({subject.code})")
    
    # Récupérer tous les étudiants concernés
    students = User.objects.filter(
        role='STUDENT',
        student_profile__level__in=subject.levels.all(),
        student_profile__major__in=subject.majors.all(),
        is_active=True
    ).distinct()
    
    print(f"👥 {students.count()} étudiants concernés")
    
    # Envoyer la notification à chaque étudiant
    for student in students:
        # Vérifier les préférences globales
        prefs = getattr(student, 'notification_preference', None)
        if not prefs or not prefs.notifications_enabled or not prefs.quiz_enabled:
            print(f"⏭️ Notifications quiz désactivées pour {student.username}")
            continue
        
        # Vérifier les préférences par matière
        from .models import SubjectPreference
        subject_pref = SubjectPreference.objects.filter(
            user=student,
            subject=subject
        ).first()
        
        if subject_pref and not subject_pref.notifications_enabled:
            print(f"⏭️ Notifications désactivées pour {subject.code} par {student.username}")
            continue
        
        # Construire le titre et message
        title = "📝 Nouveau quiz disponible !"
        body = f"{quiz.title} en {subject.name}"
        
        # Données supplémentaires
        data = {
            'type': 'new_quiz',
            'quiz_id': str(quiz.id),
            'subject_id': str(subject.id),
        }
        
        # ✅ ÉTAPE 1 : ENREGISTRER dans NotificationHistory (BDD)
        try:
            notification_history = NotificationHistory.objects.create(
                user=student,
                notification_type='new_quiz',
                title=title,
                message=body,
                data=data
            )
            print(f"💾 Notification quiz #{notification_history.id} enregistrée en BDD pour {student.username}")
        except Exception as e:
            print(f"❌ Erreur enregistrement BDD pour {student.username}: {e}")
            continue
        
        # ✅ ÉTAPE 2 : Envoyer la notification push (Firebase)
        success = send_push_notification(
            user=student,
            title=title,
            body=body,
            data=data
        )
        
        if success:
            print(f"✅ Notification quiz push envoyée à {student.username}")
        else:
            print(f"⚠️ Échec notification quiz push pour {student.username} (mais enregistrée en BDD)")


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