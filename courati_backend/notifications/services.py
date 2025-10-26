# notifications/services.py
import logging
from firebase_admin import messaging
from django.utils import timezone

from .models import FCMToken, NotificationHistory

logger = logging.getLogger(__name__)


def send_push_notification(user, title, body, data=None):
    """
    Envoyer une notification push via Firebase
    """
    from firebase_admin import messaging
    import logging
    
    logger = logging.getLogger(__name__)
    
    logger.info(f"📤 Tentative d'envoi notification à {user.username}")
    logger.info(f"   Titre: {title}")
    logger.info(f"   Body: {body}")
    logger.info(f"   Data: {data}")
    
    # Récupérer les tokens FCM actifs de l'utilisateur
    tokens = FCMToken.objects.filter(user=user, is_active=True)
    
    logger.info(f"🔑 {tokens.count()} token(s) FCM actif(s) pour {user.username}")
    
    if not tokens.exists():
        logger.warning(f"⚠️ Aucun token FCM actif pour {user.username}")
        return False
    
    success_count = 0
    
    for fcm_token in tokens:
        logger.info(f"📱 Envoi vers token: {fcm_token.token[:50]}...")
        
        try:
            # ✅ Convertir toutes les valeurs en string
            clean_data = {}
            if data:
                for key, value in data.items():
                    clean_data[key] = str(value) if value is not None else ''
            
            logger.info(f"📦 Data nettoyée: {clean_data}")
            
            # Construire le message
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=clean_data,
                token=fcm_token.token,
            )
            
            logger.info(f"✉️ Message construit, envoi en cours...")
            
            # Envoyer via Firebase
            response = messaging.send(message)
            
            logger.info(f"✅ Notification envoyée à {user.username}: {response}")
            success_count += 1
            
        except messaging.UnregisteredError as e:
            logger.warning(f"⚠️ Token invalide pour {user.username}: {str(e)}")
            fcm_token.is_active = False
            fcm_token.save()
            
        except messaging.SenderIdMismatchError as e:
            logger.error(f"❌ Sender ID mismatch pour {user.username}: {str(e)}")
            fcm_token.is_active = False
            fcm_token.save()
            
        except Exception as e:
            logger.error(f"❌ Erreur envoi notification à {user.username}")
            logger.error(f"   Type: {type(e).__name__}")
            logger.error(f"   Message: {str(e)}")
            
            import traceback
            logger.error(f"   Traceback: {traceback.format_exc()}")
            
            # Si c'est une erreur réseau, on continue
            if "Connection" in str(type(e).__name__) or "Transport" in str(type(e).__name__):
                logger.warning(f"⚠️ Erreur réseau temporaire, le token reste actif")
                continue
            
            # Pour les autres erreurs, désactiver le token
            logger.warning(f"⚠️ Désactivation du token à cause de l'erreur")
            fcm_token.is_active = False
            fcm_token.save()
    
    if success_count > 0:
        logger.info(f"✅ {success_count} notification(s) envoyée(s) avec succès")
        return True
    else:
        logger.error(f"❌ Aucune notification envoyée")
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