# notifications/services.py
import logging
from firebase_admin import messaging
from django.utils import timezone

from .models import FCMToken, NotificationHistory

logger = logging.getLogger(__name__)


def send_push_notification(user, title, body, data=None):
    """
    Envoie une notification push via Firebase
    
    Args:
        user: Utilisateur destinataire
        title: Titre de la notification
        body: Corps du message
        data: Dict de données supplémentaires (optionnel)
    
    Returns:
        bool: True si succès, False sinon
    """
    # ✅ CHANGEMENT IMPORTANT : Créer l'historique AVANT d'essayer d'envoyer
    # Comme ça, même si l'envoi échoue, on garde une trace
    notification_history = NotificationHistory.objects.create(
        user=user,
        notification_type=data.get('type', 'unknown') if data else 'unknown',
        title=title,
        message=body,
        data=data,
    )
    logger.info(f"📝 Historique enregistré pour {user.username}")
    
    try:
        # 1. Récupérer le token FCM de l'utilisateur
        fcm_token = FCMToken.objects.filter(
            user=user, 
            is_active=True
        ).first()
        
        if not fcm_token:
            logger.warning(f"⚠️ Aucun token FCM actif pour {user.username}")
            return False
        
        # 2. Vérifier les préférences
        prefs = getattr(user, 'notification_preference', None)
        if prefs and not prefs.notifications_enabled:
            logger.info(f"🔕 Notifications désactivées pour {user.username}")
            return False
        
        # 3. Vérifier heures silencieuses
        if prefs and prefs.quiet_hours_enabled:
            if is_quiet_hours(prefs):
                logger.info(f"😴 Heures silencieuses pour {user.username}")
                return False
        
        # 4. Construire le message FCM
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=fcm_token.token,
        )
        
        # 5. Envoyer via Firebase
        response = messaging.send(message)
        
        logger.info(f"✅ Notification Firebase envoyée à {user.username}: {response}")
        return True
        
    except messaging.UnregisteredError:
        # Token invalide ou app désinstallée
        logger.warning(f"🔄 Token FCM invalide pour {user.username}, désactivation")
        if fcm_token:
            fcm_token.is_active = False
            fcm_token.save()
        return False
    
    except messaging.InvalidArgumentError as e:
        # Token mal formé (comme notre token de test)
        logger.error(f"❌ Token FCM mal formé pour {user.username}: {e}")
        if fcm_token:
            fcm_token.is_active = False
            fcm_token.save()
        return False
        
    except Exception as e:
        logger.error(f"❌ Erreur envoi Firebase à {user.username}: {e}")
        return False


def is_quiet_hours(prefs):
    """Vérifie si on est dans les heures silencieuses"""
    if not prefs.quiet_hours_enabled:
        return False
    
    if not prefs.quiet_hours_start or not prefs.quiet_hours_end:
        return False
    
    now = timezone.now().time()
    start = prefs.quiet_hours_start
    end = prefs.quiet_hours_end
    
    # Gérer le cas où les heures silencieuses traversent minuit
    if start < end:
        return start <= now <= end
    else:
        return now >= start or now <= end