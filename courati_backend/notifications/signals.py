# notifications/signals.py
import logging
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth import get_user_model

from courses.models import Document, Quiz
from accounts.models import StudentProfile
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
        return  # Uniquement pour les nouveaux documents
    
    document = instance
    subject = document.subject
    
    # ✅ CHANGEMENT : Utiliser print() au lieu de logger.info()
    print(f"📚 Nouveau document détecté: {document.title} ({subject.code})")
    
    # Récupérer tous les étudiants concernés par cette matière
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
        
        # Données supplémentaires (pour deep linking)
        data = {
            'type': 'new_document',
            'document_id': str(document.id),
            'subject_id': str(subject.id),
            'document_type': document.document_type,
        }
        
        # Envoyer la notification
        success = send_push_notification(
            user=student,
            title=title,
            body=body,
            data=data
        )
        
        if success:
            print(f"✅ Notification envoyée à {student.username}")
        else:
            print(f"❌ Échec notification pour {student.username}")


# ========================================
# SIGNAL : NOUVEAU QUIZ
# ========================================

@receiver(post_save, sender=Quiz)
def notify_new_quiz(sender, instance, created, **kwargs):
    """
    Envoyer une notification quand un nouveau quiz est créé
    """
    if not created:
        return  # Uniquement pour les nouveaux quiz
    
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
        
        # Envoyer la notification
        success = send_push_notification(
            user=student,
            title=title,
            body=body,
            data=data
        )
        
        if success:
            print(f"✅ Notification quiz envoyée à {student.username}")
        else:
            print(f"❌ Échec notification quiz pour {student.username}")