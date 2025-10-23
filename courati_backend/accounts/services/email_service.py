import logging
import random
from django.core.mail import send_mail
from django.conf import settings
from django.core.cache import cache
from django.template.loader import render_to_string
from django.utils.html import strip_tags

logger = logging.getLogger(__name__)

class EmailOTPService:
    @staticmethod
    def generate_otp():
        """Génère un code OTP à 6 chiffres"""
        return ''.join([str(random.randint(0, 9)) for _ in range(6)])
    
    @staticmethod
    def send_otp_email(email, purpose='registration', user_name=None):
        """
        Envoie un OTP par email
        
        Args:
            email (str): Email destinataire
            purpose (str): 'registration' ou 'password_reset'
            user_name (str): Nom de l'utilisateur (optionnel)
        
        Returns:
            dict: {'success': bool, 'otp': str, 'message': str}
        """
        otp = EmailOTPService.generate_otp()
        
        # Stocker l'OTP dans le cache (10 minutes)
        cache_key = f"email_otp_{email}_{purpose}"
        cache.set(cache_key, otp, timeout=600)
        
        try:
            # Configuration des sujets et messages selon le contexte
            if purpose == 'registration':
                subject = 'Bienvenue sur Courati - Code de vérification'
                greeting = f'Bonjour{f" {user_name}" if user_name else ""},'
                message_text = f"""
{greeting}

Bienvenue sur Courati ! Pour finaliser votre inscription, veuillez utiliser le code de vérification suivant :

Code de vérification : {otp}

Ce code est valide pendant 10 minutes.

Si vous n'avez pas créé de compte sur Courati, ignorez cet email.

L'équipe Courati
                """
            elif purpose == 'password_reset':
                subject = 'Courati - Réinitialisation de mot de passe'
                greeting = f'Bonjour{f" {user_name}" if user_name else ""},'
                message_text = f"""
{greeting}

Vous avez demandé la réinitialisation de votre mot de passe Courati.

Code de vérification : {otp}

Ce code est valide pendant 10 minutes.

Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.

L'équipe Courati
                """
            else:
                subject = 'Courati - Code de vérification'
                message_text = f"""
Votre code de vérification Courati est : {otp}

Ce code expire dans 10 minutes.
                """
            
            # Envoyer l'email
            send_mail(
                subject=subject,
                message=message_text,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
            
            logger.info(f"✅ OTP email envoyé à {email} pour {purpose}")
            
            return {
                'success': True, 
                'otp': otp,
                'message': f'Code de vérification envoyé à {email}',
                'expires_in_minutes': 10
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur envoi email à {email}: {e}")
            # Nettoyer le cache en cas d'erreur
            cache.delete(cache_key)
            
            return {
                'success': False, 
                'error': str(e),
                'message': 'Impossible d\'envoyer l\'email de vérification'
            }
    
    @staticmethod
    def verify_otp(email, otp, purpose='registration'):
        """
        Vérifie un code OTP
        
        Args:
            email (str): Email de l'utilisateur
            otp (str): Code OTP fourni
            purpose (str): Context de vérification
        
        Returns:
            bool: True si le code est valide
        """
        cache_key = f"email_otp_{email}_{purpose}"
        stored_otp = cache.get(cache_key)
        
        logger.info(f"🔍 Vérification OTP pour {email}: fourni={otp}, stocké={stored_otp}")
        
        if stored_otp and stored_otp == str(otp).strip():
            # Supprimer le code après usage réussi
            cache.delete(cache_key)
            logger.info(f"✅ OTP valide pour {email}")
            return True
        else:
            logger.warning(f"❌ OTP invalide pour {email}")
            return False
    
    @staticmethod
    def get_remaining_time(email, purpose='registration'):
        """
        Récupère le temps restant avant expiration de l'OTP
        
        Returns:
            int: Secondes restantes, ou 0 si expiré/inexistant
        """
        cache_key = f"email_otp_{email}_{purpose}"
        # Cette méthode nécessite une implémentation de cache qui supporte TTL
        # Pour l'instant, on retourne une valeur par défaut
        return 600 if cache.get(cache_key) else 0

# Instance par défaut
email_otp_service = EmailOTPService()