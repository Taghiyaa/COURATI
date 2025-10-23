import random
import logging
from datetime import timedelta

from django.utils import timezone
from django.core.cache import cache
from django.contrib.auth import get_user_model
from django.utils.translation import gettext_lazy as _

from rest_framework import status, permissions, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

from .models import StudentProfile, Level, Major
from .serializers import (
    CustomTokenObtainPairSerializer,
    RegisterSerializer,
    VerifyOTPSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    LevelSerializer,
    MajorSerializer,
    LevelSimpleSerializer,
    MajorSimpleSerializer
)

# Import du service Email OTP
try:
    from .services.email_service import EmailOTPService
    EMAIL_OTP_AVAILABLE = True
    print(" Service Email OTP activé")
except ImportError as e:
    EMAIL_OTP_AVAILABLE = False
    print(f" Service Email OTP non trouvé: {e}")

logger = logging.getLogger(__name__)
User = get_user_model()

# PERMISSION PERSONNALISÉE
class IsAdminPermission(permissions.BasePermission):
    """Permission personnalisée pour les administrateurs"""
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.is_admin()

# ========================================
# NOUVELLES VUES POUR LA GESTION ADMIN
# ========================================

# GESTION DES NIVEAUX
class LevelListCreateView(generics.ListCreateAPIView):
    """Liste et création des niveaux (Admin uniquement)"""
    serializer_class = LevelSerializer
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        is_active = self.request.query_params.get('is_active', None)
        queryset = Level.objects.all()
        
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        return queryset.order_by('order', 'code')

class LevelDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Détail, modification et suppression d'un niveau (Admin uniquement)"""
    queryset = Level.objects.all()
    serializer_class = LevelSerializer
    permission_classes = [IsAdminPermission]
    
    def destroy(self, request, *args, **kwargs):
        level = self.get_object()
        
        # Vérifier s'il y a des étudiants avec ce niveau
        student_count = StudentProfile.objects.filter(level=level).count()
        if student_count > 0:
            return Response({
                'error': f'Impossible de supprimer ce niveau. {student_count} étudiant(s) l\'utilisent encore.',
                'student_count': student_count
            }, status=status.HTTP_400_BAD_REQUEST)
        
        return super().destroy(request, *args, **kwargs)

# GESTION DES FILIÈRES
class MajorListCreateView(generics.ListCreateAPIView):
    """Liste et création des filières (Admin uniquement)"""
    serializer_class = MajorSerializer
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        queryset = Major.objects.all()
        
        is_active = self.request.query_params.get('is_active', None)
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        department = self.request.query_params.get('department', None)
        if department:
            queryset = queryset.filter(department__icontains=department)
        
        return queryset.order_by('order', 'name')

class MajorDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Détail, modification et suppression d'une filière (Admin uniquement)"""
    queryset = Major.objects.all()
    serializer_class = MajorSerializer
    permission_classes = [IsAdminPermission]
    
    def destroy(self, request, *args, **kwargs):
        major = self.get_object()
        
        # Vérifier s'il y a des étudiants avec cette filière
        student_count = StudentProfile.objects.filter(major=major).count()
        if student_count > 0:
            return Response({
                'error': f'Impossible de supprimer cette filière. {student_count} étudiant(s) l\'utilisent encore.',
                'student_count': student_count
            }, status=status.HTTP_400_BAD_REQUEST)
        
        return super().destroy(request, *args, **kwargs)

# ========================================
# APIS PUBLIQUES POUR LES CHOIX
# ========================================

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_levels(request):
    """API publique pour récupérer les niveaux actifs"""
    levels = Level.objects.filter(is_active=True).order_by('order', 'code')
    serializer = LevelSimpleSerializer(levels, many=True)
    
    return Response({
        'success': True,
        'count': len(serializer.data),
        'levels': serializer.data
    })

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_majors(request):
    """API publique pour récupérer les filières actives"""
    # Permettre de filtrer par département
    department = request.GET.get('department', None)
    majors = Major.objects.filter(is_active=True)
    
    if department:
        majors = majors.filter(department__icontains=department)
    
    majors = majors.order_by('order', 'name')
    serializer = MajorSimpleSerializer(majors, many=True)
    
    return Response({
        'success': True,
        'count': len(serializer.data),
        'majors': serializer.data,
        'filtered_by_department': department
    })

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_registration_choices(request):
    """API publique pour récupérer tous les choix nécessaires à l'inscription"""
    levels = Level.objects.filter(is_active=True).order_by('order', 'code')
    majors = Major.objects.filter(is_active=True).order_by('order', 'name')
    
    return Response({
        'success': True,
        'choices': {
            'levels': LevelSimpleSerializer(levels, many=True).data,
            'majors': MajorSimpleSerializer(majors, many=True).data
        },
        'counts': {
            'levels': levels.count(),
            'majors': majors.count()
        }
    })

class RegisterView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        logger.info(f"📝 Inscription: {request.data.get('username', 'Unknown')}")
        
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            try:
                # Récupérer les données validées
                registration_data = serializer.validated_data
                email = registration_data['email']
                phone_number = registration_data['phone_number']
                level = registration_data['level']
                major = registration_data['major']
                
                # Vérifier que le username/email/phone n'existent pas déjà
                if User.objects.filter(username=registration_data['username']).exists():
                    return Response({
                        "success": False,
                        "error": "Ce nom d'utilisateur existe déjà."
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if User.objects.filter(email=email).exists():
                    return Response({
                        "success": False,
                        "error": "Cet email existe déjà."
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                if StudentProfile.objects.filter(phone_number=phone_number).exists():
                    return Response({
                        "success": False,
                        "error": "Ce numéro de téléphone existe déjà."
                    }, status=status.HTTP_400_BAD_REQUEST)
                
                # Stocker les données d'inscription dans le cache (15 minutes)
                registration_key = f"pending_registration_{email}"
                cache_data = {
                    'username': registration_data['username'],
                    'email': email,
                    'password': registration_data['password'],
                    'phone_number': phone_number,
                    'level_id': level.id,  # ✅ Stocker l'ID
                    'major_id': major.id,
                    'first_name': registration_data.get('first_name', ''),
                    'last_name': registration_data.get('last_name', ''),
                    'timestamp': timezone.now().isoformat(),
                    'expires_at': (timezone.now() + timedelta(minutes=15)).isoformat()
                }
                
                cache.set(registration_key, cache_data, timeout=900)  # 15 minutes
                logger.info(f"📦 Données d'inscription mises en cache pour: {email}")
                
                if EMAIL_OTP_AVAILABLE:
                    # 📧 Envoyer OTP par email
                    user_name = f"{registration_data.get('first_name', '')} {registration_data.get('last_name', '')}".strip()
                    otp_result = EmailOTPService.send_otp_email(
                        email=email, 
                        purpose='registration',
                        user_name=user_name if user_name else None
                    )
                    
                    if otp_result['success']:
                        logger.info(f"✅ Email OTP envoyé à: {email}")
                        
                        return Response({
                            "success": True,
                            "message": "Un code de vérification a été envoyé à votre email.",
                            "email": email,
                            "method": "email_otp",
                            "expires_in_minutes": 10,
                            "instructions": "Vérifiez votre boîte email et entrez le code reçu"
                        }, status=status.HTTP_201_CREATED)
                    else:
                        logger.error(f"❌ Échec envoi email: {otp_result.get('message', 'Erreur inconnue')}")
                        cache.delete(registration_key)  # Nettoyer le cache
                        return Response({
                            "success": False,
                            "error": "Impossible d'envoyer l'email de vérification.",
                            "details": otp_result.get('message', 'Erreur email'),
                            "suggestion": "Vérifiez que votre email est correct"
                        }, status=status.HTTP_400_BAD_REQUEST)
                else:
                    # Mode développement console
                    otp = ''.join([str(random.randint(0, 9)) for _ in range(6)])
                    cache.set(f"dev_otp_{email}", otp, timeout=900)
                    
                    self.log_otp_console(email, otp)
                    
                    return Response({
                        "success": True,
                        "message": "Code OTP généré (mode développement).",
                        "email": email,
                        "method": "console_simulation",
                        "expires_in_minutes": 15,
                        "dev_note": "Regardez la console Django pour le code OTP"
                    }, status=status.HTTP_201_CREATED)
                        
            except Exception as e:
                logger.error(f"❌ Erreur inscription: {e}")
                return Response({
                    "success": False,
                    "error": "Erreur interne du serveur"
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
                
        logger.warning(f"❌ Données inscription invalides: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    def log_otp_console(self, email, otp):
        """Affichage console stylisé pour le développement"""
        print("\n" + "="*70)
        print("📧 MODE DÉVELOPPEMENT - SIMULATION EMAIL OTP")
        print("="*70)
        print(f"📧 Destinataire : {email}")
        print(f"🔢 Code OTP     : {otp}")
        print(f"💬 Sujet        : Code de vérification Courati")
        print(f"⏰ Expire dans  : 10 minutes")
        print("="*70)
        print("📧 Pour emails réels, configurez SMTP dans settings.py")
        print("="*70 + "\n")

class VerifyOTPView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email', 'Unknown')  # Changé de phone_number à email
        logger.info(f"🔍 Vérification OTP: {email}")
        
        serializer = VerifyOTPSerializer(data=request.data)
        if serializer.is_valid():
            email = serializer.validated_data['email']  # Changé de phone_number
            code = serializer.validated_data['otp']
            
            # Récupérer les données d'inscription depuis le cache
            registration_key = f"pending_registration_{email}"
            registration_data = cache.get(registration_key)
            
            if not registration_data:
                logger.warning(f"❌ Session expirée pour: {email}")
                return Response({
                    "success": False,
                    "error": "Session d'inscription expirée. Veuillez recommencer l'inscription.",
                    "suggestion": "Retournez à la page d'inscription",
                    "redirect_to": "registration"
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Vérifier que la session n'est pas expirée
            expires_at = timezone.datetime.fromisoformat(registration_data['expires_at'])
            if timezone.now() > expires_at:
                cache.delete(registration_key)
                return Response({
                    "success": False,
                    "error": "Session d'inscription expirée.",
                    "redirect_to": "registration"
                }, status=status.HTTP_400_BAD_REQUEST)
            
            otp_valid = False
            
            if EMAIL_OTP_AVAILABLE:
                # 📧 Vérification avec service email
                logger.info(f"🔍 Vérification Email OTP pour: {email}")
                
                if EmailOTPService.verify_otp(email, code, 'registration'):
                    otp_valid = True
                    logger.info(f"✅ Code email valide pour: {email}")
                else:
                    logger.warning(f"❌ Code email invalide pour: {email}")
            else:
                # Mode développement
                dev_otp = cache.get(f"dev_otp_{email}")
                if dev_otp and dev_otp == code:
                    otp_valid = True
                    logger.info(f"✅ Code console valide pour: {email}")
                    cache.delete(f"dev_otp_{email}")
                else:
                    logger.warning(f"❌ Code console invalide pour: {email}")
            
            if otp_valid:
                try:
                    # Récupérer les objets Level et Major depuis leurs IDs
                    level = Level.objects.get(id=registration_data['level_id'])
                    major = Major.objects.get(id=registration_data['major_id'])
                    # CRÉER l'utilisateur après vérification OTP réussie
                    user = User.objects.create_user(
                        username=registration_data['username'],
                        email=registration_data['email'],
                        password=registration_data['password'],
                        first_name=registration_data['first_name'],
                        last_name=registration_data['last_name'],
                        role='STUDENT',
                        is_active=True  # Directement actif car OTP vérifié
                    )
                    
                    # Créer le profil étudiant
                    student_profile = StudentProfile.objects.create(
                        user=user,
                        phone_number=registration_data['phone_number'],
                        level=level,
                        major=major,
                        is_verified=True  # Directement vérifié car OTP vérifié
                    )
                    
                    # Nettoyer le cache
                    cache.delete(registration_key)
                    
                    logger.info(f"✅ Compte créé avec succès: {user.username}")
                    
                    # Retourner sans tokens - redirection vers login
                    return Response({
                        "success": True,
                        "message": "Félicitations ! Votre compte Courati a été créé avec succès.",
                        "username": user.username,
                        "email": user.email,
                        "phone_number": student_profile.phone_number,
                        "user_info": {
                         "full_name": f"{user.first_name} {user.last_name}".strip(),
                         "level": level.name,  # ✅ Utiliser l'objet level récupéré
                         "major": major.name   # ✅ Utiliser l'objet major récupéré
                    },
                        "can_login": True,
                        "redirect_to": "login",
                        "next_step": "Vous pouvez maintenant vous connecter avec vos identifiants"
                    }, status=status.HTTP_201_CREATED)
                    
                except Exception as e:
                    logger.error(f"❌ Erreur création utilisateur: {e}")
                    cache.delete(registration_key)
                    return Response({
                        "success": False,
                        "error": "Erreur lors de la création du compte",
                        "details": str(e)
                    }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            else:
                return Response({
                    "success": False,
                    "error": "Code OTP invalide ou expiré.",
                    "suggestion": "Vérifiez le code dans votre email"
                }, status=status.HTTP_400_BAD_REQUEST)
                
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer
    
    def post(self, request, *args, **kwargs):
        logger.info(f"🚪 Tentative connexion: {request.data.get('username', 'Unknown')}")
        
        try:
            response = super().post(request, *args, **kwargs)
            if response.status_code == 200:
                logger.info(f"✅ Connexion réussie: {request.data.get('username', 'Unknown')}")
            return response
        except Exception as e:
            logger.warning(f"❌ Connexion échouée: {request.data.get('username', 'Unknown')} - {str(e)}")
            return Response({
                "error": "Identifiants invalides.",
                "suggestion": "Vérifiez vos identifiants"
            }, status=status.HTTP_401_UNAUTHORIZED)

class PasswordResetRequestView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email', 'Unknown')  # Changé pour email
        logger.info(f"🔄 Demande reset: {email}")
        
        # Modifier le serializer pour utiliser email au lieu de phone_number
        email = request.data.get('email')
        if not email:
            return Response({
                "error": "Email requis"
            }, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            # Chercher par email au lieu de phone_number
            user = User.objects.get(email=email, is_active=True)
            
            if EMAIL_OTP_AVAILABLE:
                otp_result = EmailOTPService.send_otp_email(
                    email=email, 
                    purpose='password_reset',
                    user_name=f"{user.first_name} {user.last_name}".strip() or user.username
                )
                
                if otp_result['success']:
                    logger.info(f"✅ Email reset envoyé à: {email}")
                    return Response({
                        "success": True,
                        "message": "Un code de réinitialisation a été envoyé à votre email.",
                        "method": "email_otp",
                        "expires_in_minutes": 10
                    }, status=status.HTTP_200_OK)
                else:
                    return Response({
                        "success": False,
                        "error": "Impossible d'envoyer l'email de réinitialisation."
                    }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            else:
                # Mode développement
                otp = ''.join([str(random.randint(0, 9)) for _ in range(6)])
                cache.set(f"reset_otp_{email}", otp, timeout=600)
                
                print(f"\n🔄 CODE RESET: {otp} pour {email}\n")
                
                return Response({
                    "success": True,
                    "message": "Un code de réinitialisation a été généré (mode développement).",
                    "method": "console_simulation",
                    "dev_note": "Regardez la console Django pour le code"
                }, status=status.HTTP_200_OK)
                
        except User.DoesNotExist:
            # Réponse identique pour sécurité
            return Response({
                "message": "Si un compte existe avec cet email, un code a été envoyé."
            }, status=status.HTTP_200_OK)

class PasswordResetConfirmView(APIView):
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        email = request.data.get('email', 'Unknown')
        logger.info(f"🔒 Confirmation reset: {email}")
        
        email = request.data.get('email')
        code = request.data.get('otp')
        new_password = request.data.get('new_password')
        
        if not all([email, code, new_password]):
            return Response({
                "error": "Email, code OTP et nouveau mot de passe requis"
            }, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            user = User.objects.get(email=email)
            otp_valid = False
            
            if EMAIL_OTP_AVAILABLE:
                if EmailOTPService.verify_otp(email, code, 'password_reset'):
                    otp_valid = True
            else:
                reset_otp = cache.get(f"reset_otp_{email}")
                if reset_otp and reset_otp == code:
                    otp_valid = True
                    cache.delete(f"reset_otp_{email}")
            
            if otp_valid:
                user.set_password(new_password)
                user.save()
                
                logger.info(f"✅ Password reset: {user.username}")
                return Response({
                    "success": True,
                    "message": "Mot de passe réinitialisé avec succès !",
                    "can_login": True,
                    "next_step": "Vous pouvez maintenant vous connecter avec votre nouveau mot de passe"
                }, status=status.HTTP_200_OK)
            else:
                return Response({
                    "success": False,
                    "error": "Code de réinitialisation invalide ou expiré."
                }, status=status.HTTP_400_BAD_REQUEST)
                    
        except User.DoesNotExist:
            return Response({
                "success": False,
                "error": "Utilisateur non trouvé."
            }, status=status.HTTP_404_NOT_FOUND)

# Dans votre views.py, remplacez la classe UserProfileView existante par celle-ci :

class UserProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        logger.info(f"👤 Récupération profil: {user.username}")
        
        if user.is_student():
            try:
                student_profile = user.student_profile
                return Response({
                    'success': True,
                    'user_type': 'student',
                    'username': user.username,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'phone_number': student_profile.phone_number,
                    'level': {
                        'id': student_profile.level.id if student_profile.level else None,
                        'code': student_profile.level.code if student_profile.level else None,
                        'name': student_profile.level.name if student_profile.level else None
                    },
                    'major': {
                        'id': student_profile.major.id if student_profile.major else None,
                        'code': student_profile.major.code if student_profile.major else None,
                        'name': student_profile.major.name if student_profile.major else None,
                        'department': student_profile.major.department if student_profile.major else None
                    },
                    'is_verified': student_profile.is_verified,
                    'date_joined': user.date_joined.isoformat(),
                })
            except StudentProfile.DoesNotExist:
                return Response({
                    "error": "Profil étudiant non trouvé."
                }, status=status.HTTP_404_NOT_FOUND)
        
        elif user.is_admin():
            return Response({
                'success': True,
                'user_type': 'admin',
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'is_staff': user.is_staff,
                'is_superuser': user.is_superuser,
                'date_joined': user.date_joined.isoformat()
            })
        
        return Response({
            "error": "Type d'utilisateur non reconnu."
        }, status=status.HTTP_400_BAD_REQUEST)
    
    def put(self, request):
        """Mise à jour du profil - CORRIGÉE pour supporter les nouvelles relations"""
        user = request.user
        logger.info(f"✏️ Mise à jour profil: {user.username}")
        
        try:
            data = request.data
            logger.info(f"Données reçues: {data}")
            
            # Mettre à jour les champs utilisateur
            user_fields = ['first_name', 'last_name', 'email', 'username']
            user_updated = False
            
            for field in user_fields:
                if field in data:
                    if field == 'username':
                        if User.objects.filter(username=data[field]).exclude(id=user.id).exists():
                            return Response({
                                'success': False,
                                'error': 'Ce nom d\'utilisateur existe déjà'
                            }, status=status.HTTP_400_BAD_REQUEST)
                    elif field == 'email':
                        if User.objects.filter(email=data[field]).exclude(id=user.id).exists():
                            return Response({
                                'success': False,
                                'error': 'Cet email existe déjà'
                            }, status=status.HTTP_400_BAD_REQUEST)
                    
                    setattr(user, field, data[field])
                    user_updated = True
            
            if user_updated:
                user.save()
            
            # Mettre à jour le profil spécifique
            profile_updated = False
            
            if user.is_student() and hasattr(user, 'student_profile'):
                profile = user.student_profile
                
                # Gérer phone_number
                if 'phone_number' in data:
                    if StudentProfile.objects.filter(phone_number=data['phone_number']).exclude(user=user).exists():
                        return Response({
                            'success': False,
                            'error': 'Ce numéro de téléphone existe déjà'
                        }, status=status.HTTP_400_BAD_REQUEST)
                    profile.phone_number = data['phone_number']
                    profile_updated = True
                
                # Gérer level (ID)
                if 'level' in data:
                    try:
                        level = Level.objects.get(id=data['level'], is_active=True)
                        profile.level = level
                        profile_updated = True
                    except Level.DoesNotExist:
                        return Response({
                            'success': False,
                            'error': 'Niveau introuvable ou inactif'
                        }, status=status.HTTP_400_BAD_REQUEST)
                
                # Gérer major (ID)
                if 'major' in data:
                    try:
                        major = Major.objects.get(id=data['major'], is_active=True)
                        profile.major = major
                        profile_updated = True
                    except Major.DoesNotExist:
                        return Response({
                            'success': False,
                            'error': 'Filière introuvable ou inactive'
                        }, status=status.HTTP_400_BAD_REQUEST)
                
                if profile_updated:
                    profile.save()
            
            elif user.is_admin() and hasattr(user, 'admin_profile'):
                profile = user.admin_profile
                admin_fields = ['department', 'phone_number']
                
                for field in admin_fields:
                    if field in data:
                        setattr(profile, field, data[field])
                        profile_updated = True
                
                if profile_updated:
                    profile.save()
            
            # Retourner les nouvelles données
            if user.is_student():
                try:
                    student_profile = user.student_profile
                    return Response({
                        'success': True,
                        'message': 'Profil mis à jour avec succès',
                        'user_type': 'student',
                        'username': user.username,
                        'email': user.email,
                        'first_name': user.first_name,
                        'last_name': user.last_name,
                        'phone_number': student_profile.phone_number,
                        'level': {
                            'id': student_profile.level.id if student_profile.level else None,
                            'code': student_profile.level.code if student_profile.level else None,
                            'name': student_profile.level.name if student_profile.level else None
                        },
                        'major': {
                            'id': student_profile.major.id if student_profile.major else None,
                            'code': student_profile.major.code if student_profile.major else None,
                            'name': student_profile.major.name if student_profile.major else None,
                            'department': student_profile.major.department if student_profile.major else None
                        },
                        'is_verified': student_profile.is_verified,
                        'date_joined': user.date_joined.isoformat(),
                    }, status=status.HTTP_200_OK)
                except StudentProfile.DoesNotExist:
                    return Response({
                        "error": "Profil étudiant non trouvé."
                    }, status=status.HTTP_404_NOT_FOUND)
            
            elif user.is_admin():
                return Response({
                    'success': True,
                    'message': 'Profil mis à jour avec succès',
                    'user_type': 'admin',
                    'username': user.username,
                    'email': user.email,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'is_staff': user.is_staff,
                    'is_superuser': user.is_superuser,
                    'date_joined': user.date_joined.isoformat()
                }, status=status.HTTP_200_OK)
                
        except Exception as e:
            logger.error(f"❌ Erreur mise à jour profil {user.username}: {str(e)}")
            import traceback
            traceback.print_exc()
            return Response({
                'success': False,
                'error': 'Erreur serveur lors de la mise à jour',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

class ChangePasswordView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        logger.info(f"🔒 Changement mot de passe: {user.username}")
        
        current_password = request.data.get('current_password')
        new_password = request.data.get('new_password')
        confirm_password = request.data.get('confirm_password')
        
        if not all([current_password, new_password, confirm_password]):
            return Response({
                'error': 'Tous les champs sont requis'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Vérifier l'ancien mot de passe
        if not user.check_password(current_password):
            return Response({
                'error': 'Mot de passe actuel incorrect'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Vérifier que les nouveaux mots de passe correspondent
        if new_password != confirm_password:
            return Response({
                'error': 'Les nouveaux mots de passe ne correspondent pas'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validation du nouveau mot de passe
        if len(new_password) < 8:
            return Response({
                'error': 'Le nouveau mot de passe doit contenir au moins 8 caractères'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Vérifier que le nouveau mot de passe est différent
        if user.check_password(new_password):
            return Response({
                'error': 'Le nouveau mot de passe doit être différent de l\'ancien'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Changer le mot de passe
        user.set_password(new_password)
        user.save()
        
        logger.info(f"✅ Mot de passe changé: {user.username}")
        return Response({
            'success': True,
            'message': 'Mot de passe modifié avec succès'
        }, status=status.HTTP_200_OK)

class LogoutView(APIView):
    """
    Déconnexion avec blacklist du refresh token
    POST /api/auth/logout/
    Body: {"refresh": "refresh_token_here"}
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        logger.info(f"🚪 Déconnexion: {user.username}")
        
        try:
            # Récupérer le refresh token depuis le body
            refresh_token = request.data.get('refresh')
            
            if not refresh_token:
                return Response({
                    'success': False,
                    'error': 'Refresh token requis'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Blacklister le refresh token
            token = RefreshToken(refresh_token)
            token.blacklist()
            
            logger.info(f"✅ Déconnexion réussie: {user.username}")
            
            return Response({
                'success': True,
                'message': 'Déconnexion réussie'
            }, status=status.HTTP_200_OK)
            
        except TokenError as e:
            logger.warning(f"⚠️ Token invalide lors de la déconnexion: {user.username}")
            return Response({
                'success': False,
                'error': 'Token invalide ou déjà expiré',
                'details': str(e)
            }, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            logger.error(f"❌ Erreur déconnexion {user.username}: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur lors de la déconnexion'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)