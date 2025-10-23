# accounts/services/sms_service.py
import logging
from twilio.rest import Client
from twilio.base.exceptions import TwilioException
from django.conf import settings

logger = logging.getLogger(__name__)

class TwilioVerifyService:
    """Service pour envoyer des SMS OTP via Twilio Verify"""
    
    def __init__(self):
        self.account_sid = settings.TWILIO_ACCOUNT_SID
        self.auth_token = settings.TWILIO_AUTH_TOKEN
        self.service_sid = settings.TWILIO_VERIFY_SERVICE_SID
        
        if not all([self.account_sid, self.auth_token, self.service_sid]):
            raise ValueError("❌ Configuration Twilio manquante dans les variables d'environnement")
        
        self.client = Client(self.account_sid, self.auth_token)
        logger.info("✅ Service Twilio Verify initialisé")
    
    def send_verification_code(self, phone_number: str) -> dict:
        """
        Envoie un code de vérification via Twilio Verify
        
        Args:
            phone_number (str): Numéro au format international (+222...)
            
        Returns:
            dict: {'success': bool, 'message': str, 'sid': str, 'status': str}
        """
        try:
            logger.info(f"📱 Envoi SMS OTP vers: {phone_number}")
            
            verification = self.client.verify.v2.services(self.service_sid).verifications.create(
                to=phone_number,
                channel='sms'
            )
            
            logger.info(f"✅ SMS envoyé avec succès. SID: {verification.sid}, Status: {verification.status}")
            
            return {
                'success': True,
                'message': f'Code de vérification envoyé à {phone_number}',
                'sid': verification.sid,
                'status': verification.status,
                'to': verification.to,
                'channel': verification.channel
            }
            
        except TwilioException as e:
            error_code = getattr(e, 'code', 'Unknown')
            error_msg = str(e)
            
            logger.error(f"❌ Erreur Twilio ({error_code}): {error_msg}")
            
            # Messages d'erreur plus clairs pour l'utilisateur
            user_message = self._get_user_friendly_error(error_code, error_msg)
            
            return {
                'success': False,
                'message': user_message,
                'sid': None,
                'error_code': error_code,
                'error_details': error_msg
            }
        except Exception as e:
            logger.error(f"❌ Erreur générale lors de l'envoi SMS: {e}")
            return {
                'success': False,
                'message': 'Erreur interne lors de l\'envoi du SMS',
                'sid': None,
                'error_details': str(e)
            }
    
    def check_verification_code(self, phone_number: str, code: str) -> dict:
        """
        Vérifie un code OTP
        
        Args:
            phone_number (str): Numéro de téléphone
            code (str): Code à vérifier
            
        Returns:
            dict: {'success': bool, 'valid': bool, 'message': str}
        """
        try:
            logger.info(f"🔍 Vérification OTP pour: {phone_number}")
            
            verification_check = self.client.verify.v2.services(self.service_sid).verification_checks.create(
                to=phone_number,
                code=code
            )
            
            is_valid = verification_check.status == 'approved'
            
            if is_valid:
                logger.info(f"✅ Code OTP valide pour: {phone_number}")
                return {
                    'success': True,
                    'valid': True,
                    'message': 'Code de vérification valide',
                    'status': verification_check.status
                }
            else:
                logger.warning(f"❌ Code OTP invalide pour: {phone_number} - Status: {verification_check.status}")
                return {
                    'success': True,
                    'valid': False,
                    'message': 'Code de vérification invalide ou expiré',
                    'status': verification_check.status
                }
                
        except TwilioException as e:
            error_code = getattr(e, 'code', 'Unknown')
            error_msg = str(e)
            
            logger.error(f"❌ Erreur vérification Twilio ({error_code}): {error_msg}")
            
            user_message = self._get_user_friendly_error(error_code, error_msg)
            
            return {
                'success': False,
                'valid': False,
                'message': user_message,
                'error_code': error_code
            }
        except Exception as e:
            logger.error(f"❌ Erreur générale lors de la vérification: {e}")
            return {
                'success': False,
                'valid': False,
                'message': 'Erreur interne lors de la vérification',
                'error_details': str(e)
            }
    
    def _get_user_friendly_error(self, error_code, error_msg):
        """Convertit les codes d'erreur Twilio en messages utilisateur"""
        
        error_messages = {
            20003: "Accès non autorisé - Vérifiez vos credentials Twilio",
            20404: "Numéro de téléphone non trouvé ou invalide",
            60200: "Numéro de téléphone invalide",
            60202: "Le message n'a pas pu être envoyé à ce numéro",
            60203: "Limite internationale dépassée pour ce numéro",
            60208: "Ce numéro ne peut pas recevoir de SMS",
            60212: "Le code est invalide",
            60202: "Trop de tentatives de vérification",
            60023: "Ce numéro est sur liste noire",
        }
        
        # Vérification par code d'erreur
        if error_code in error_messages:
            return error_messages[error_code]
        
        # Vérification par contenu du message
        if "invalid phone number" in error_msg.lower():
            return "Le numéro de téléphone n'est pas valide"
        elif "not a valid country code" in error_msg.lower():
            return "Code pays invalide - Utilisez le format +222..."
        elif "blocked" in error_msg.lower():
            return "Ce numéro est bloqué ou non autorisé"
        elif "rate limit" in error_msg.lower():
            return "Trop de tentatives - Veuillez patienter"
        
        # Message par défaut
        return "Impossible d'envoyer le SMS - Vérifiez votre numéro"
    
    def get_service_info(self) -> dict:
        """Récupère les informations du service Verify"""
        try:
            service = self.client.verify.v2.services(self.service_sid).fetch()
            
            return {
                'success': True,
                'service_name': service.friendly_name,
                'service_sid': service.sid,
                'status': 'active'
            }
        except TwilioException as e:
            return {
                'success': False,
                'error': str(e)
            }

# Instance singleton du service
try:
    verify_service = TwilioVerifyService()
    print("🚀 Service Twilio Verify chargé avec succès")
except Exception as e:
    print(f"⚠️ Impossible de charger Twilio Verify: {e}")
    verify_service = None