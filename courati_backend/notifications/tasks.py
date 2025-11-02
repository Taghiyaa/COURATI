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

# ✅ NOUVELLE TÂCHE : ENVOYER LES NOTIFICATIONS DE QUIZ
@shared_task(name='notifications.tasks.send_quiz_notifications')
def send_quiz_notifications(quiz_id):
    """
    ⚡ TÂCHE ASYNCHRONE
    Envoyer les notifications pour un nouveau quiz
    Exécuté en arrière-plan par Celery
    """
    from django.contrib.auth import get_user_model
    from courses.models import Quiz
    from .models import NotificationHistory, SubjectPreference
    from .services import send_push_notification
    
    User = get_user_model()
    
    logger.info(f"🔄 [CELERY] Traitement des notifications pour quiz #{quiz_id}")
    
    try:
        # Récupérer le quiz
        quiz = Quiz.objects.select_related('subject').get(id=quiz_id)
        subject = quiz.subject
        
        logger.info(f"📝 [CELERY] Quiz: {quiz.title} ({subject.code})")
        
        # Récupérer tous les étudiants concernés
        students = User.objects.filter(
            role='STUDENT',
            student_profile__level__in=subject.levels.all(),
            student_profile__major__in=subject.majors.all(),
            is_active=True
        ).distinct()
        
        logger.info(f"👥 [CELERY] {students.count()} étudiants concernés")
        
        success_count = 0
        db_count = 0
        
        # Envoyer la notification à chaque étudiant
        for student in students:
            # Vérifier les préférences globales
            prefs = getattr(student, 'notification_preference', None)
            if not prefs or not prefs.notifications_enabled or not prefs.quiz_enabled:
                logger.info(f"⏭️ [CELERY] Notifications désactivées pour {student.username}")
                continue
            
            # Vérifier les préférences par matière
            subject_pref = SubjectPreference.objects.filter(
                user=student,
                subject=subject
            ).first()
            
            if subject_pref and not subject_pref.notifications_enabled:
                logger.info(f"⏭️ [CELERY] Notifs désactivées pour {subject.code} par {student.username}")
                continue
            
            # Construire le message
            title = "📝 Nouveau quiz disponible !"
            body = f"{quiz.title} en {subject.name}"
            
            data = {
                'type': 'new_quiz',
                'quiz_id': str(quiz.id),
                'subject_id': str(subject.id),
            }
            
            # ✅ ÉTAPE 1 : Enregistrer en BDD
            try:
                notification_history = NotificationHistory.objects.create(
                    user=student,
                    notification_type='new_quiz',
                    title=title,
                    message=body,
                    data=data
                )
                db_count += 1
                logger.info(f"💾 [CELERY] Notification #{notification_history.id} enregistrée pour {student.username}")
            except Exception as e:
                logger.error(f"❌ [CELERY] Erreur BDD pour {student.username}: {e}")
                continue
            
            # ✅ ÉTAPE 2 : Envoyer push notification
            try:
                success = send_push_notification(
                    user=student,
                    title=title,
                    body=body,
                    data=data
                )
                
                if success:
                    success_count += 1
                    logger.info(f"✅ [CELERY] Push envoyé à {student.username}")
                else:
                    logger.warning(f"⚠️ [CELERY] Push échoué pour {student.username}")
            except Exception as e:
                logger.error(f"❌ [CELERY] Erreur push pour {student.username}: {e}")
        
        logger.info(f"✅ [CELERY] Traitement terminé: {db_count} en BDD, {success_count} push envoyés")
        
        return {
            'success': True,
            'quiz_id': quiz_id,
            'quiz_title': quiz.title,
            'students_notified': students.count(),
            'db_saved': db_count,
            'push_sent': success_count,
        }
        
    except Quiz.DoesNotExist:
        logger.error(f"❌ [CELERY] Quiz #{quiz_id} non trouvé")
        return {
            'success': False,
            'error': 'Quiz not found'
        }
    except Exception as e:
        logger.error(f"❌ [CELERY] Erreur globale: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        return {
            'success': False,
            'error': str(e)
        }


@shared_task(name='notifications.tasks.send_document_notifications')
def send_document_notifications(document_id):
    """
    ⚡ TÂCHE ASYNCHRONE
    Envoyer les notifications pour un nouveau document
    """
    from django.contrib.auth import get_user_model
    from courses.models import Document
    from .models import NotificationHistory, SubjectPreference
    from .services import send_push_notification
    
    User = get_user_model()
    
    logger.info(f"🔄 [CELERY] Traitement des notifications pour document #{document_id}")
    
    try:
        document = Document.objects.select_related('subject').get(id=document_id)
        subject = document.subject
        
        logger.info(f"📚 [CELERY] Document: {document.title} ({subject.code})")
        
        students = User.objects.filter(
            role='STUDENT',
            student_profile__level__in=subject.levels.all(),
            student_profile__major__in=subject.majors.all(),
            is_active=True
        ).distinct()
        
        logger.info(f"👥 [CELERY] {students.count()} étudiants concernés")
        
        success_count = 0
        db_count = 0
        
        for student in students:
            prefs = getattr(student, 'notification_preference', None)
            if not prefs or not prefs.notifications_enabled or not prefs.new_content_enabled:
                logger.info(f"⏭️ [CELERY] Notifications désactivées pour {student.username}")
                continue
            
            subject_pref = SubjectPreference.objects.filter(
                user=student,
                subject=subject
            ).first()
            
            if subject_pref and not subject_pref.notifications_enabled:
                logger.info(f"⏭️ [CELERY] Notifs désactivées pour {subject.code} par {student.username}")
                continue
            
            doc_type_display = document.get_document_type_display()
            title = f"📚 Nouveau {doc_type_display.lower()} disponible !"
            body = f"{document.title} en {subject.name}"
            
            # ✅ ENRICHIR LES DATA AVEC TOUTES LES INFOS DE LA MATIÈRE
            data = {
                'type': 'new_document',
                'document_id': str(document.id),
                'subject_id': str(subject.id),
                'document_type': document.document_type,
                # ✅ AJOUT DES INFOS DE LA MATIÈRE
                'subject_name': subject.name,
                'subject_code': subject.code,
                'subject_credits': str(subject.credits),
                'subject_is_featured': str(subject.is_featured),
            }
            
            try:
                notification_history = NotificationHistory.objects.create(
                    user=student,
                    notification_type='new_document',
                    title=title,
                    message=body,
                    data=data  # ← Data enrichie
                )
                db_count += 1
                logger.info(f"💾 [CELERY] Notification #{notification_history.id} enregistrée pour {student.username}")
            except Exception as e:
                logger.error(f"❌ [CELERY] Erreur BDD pour {student.username}: {e}")
                continue
            
            try:
                success = send_push_notification(
                    user=student,
                    title=title,
                    body=body,
                    data=data  # ← Data enrichie
                )
                
                if success:
                    success_count += 1
                    logger.info(f"✅ [CELERY] Push envoyé à {student.username}")
                else:
                    logger.warning(f"⚠️ [CELERY] Push échoué pour {student.username}")
            except Exception as e:
                logger.error(f"❌ [CELERY] Erreur push pour {student.username}: {e}")
        
        logger.info(f"✅ [CELERY] Traitement terminé: {db_count} en BDD, {success_count} push envoyés")
        
        return {
            'success': True,
            'document_id': document_id,
            'document_title': document.title,
            'document_type': document.document_type,
            'students_notified': students.count(),
            'db_saved': db_count,
            'push_sent': success_count,
        }
        
    except Document.DoesNotExist:
        logger.error(f"❌ [CELERY] Document #{document_id} non trouvé")
        return {'success': False, 'error': 'Document not found'}
    except Exception as e:
        logger.error(f"❌ [CELERY] Erreur globale: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        return {'success': False, 'error': str(e)}