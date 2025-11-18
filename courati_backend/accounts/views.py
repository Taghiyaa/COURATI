import random
import logging
from datetime import timedelta

from django.utils import timezone
from django.core.cache import cache
from django.contrib.auth import get_user_model
from django.utils.translation import gettext_lazy as _
from django.db.models import Count, Sum, Avg, Q, F
from django.shortcuts import get_object_or_404

from rest_framework import status, permissions, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

from .models import StudentProfile, Level, Major
from accounts.models import TeacherProfile, TeacherAssignment
from .serializers import (
    CustomTokenObtainPairSerializer,
    RegisterSerializer,
    VerifyOTPSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    LevelSerializer,
    MajorSerializer,
    LevelSimpleSerializer,
    MajorSimpleSerializer,
    AdminDashboardSerializer
)
from courses.models import Subject, Document, Quiz, QuizAttempt, UserActivity,  UserFavorite
from accounts.permissions import IsAdminPermission
from accounts.serializers import (
    TeacherProfileDetailSerializer,
    TeacherCreateSerializer,
    TeacherUpdateSerializer,
    TeacherAssignmentSerializer,
    StudentCreateSerializer,
    StudentUpdateSerializer,
    StudentAdminListSerializer,
    StudentAdminDetailSerializer,
    StudentStatisticsSerializer,
    BulkStudentActionSerializer,
    
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


# ========================================
# GESTION DES PROFESSEURS (ADMIN)
# ========================================

class TeacherListCreateView(generics.ListCreateAPIView):
    """
    Liste et création des professeurs (Admin uniquement)
    GET /api/auth/admin/teachers/
    POST /api/auth/admin/teachers/
    """
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        """Liste des professeurs avec filtres"""
        queryset = User.objects.filter(role='TEACHER').select_related('teacher_profile')
        
        # Filtrer par statut
        is_active = self.request.query_params.get('is_active', None)
        if is_active is not None:
            queryset = queryset.filter(is_active=is_active.lower() == 'true')
        
        # Recherche par nom
        search = self.request.query_params.get('search', None)
        if search:
            queryset = queryset.filter(
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(username__icontains=search) |
                Q(email__icontains=search)
            )
        
        return queryset.order_by('last_name', 'first_name')
    
    def get_serializer_class(self):
        if self.request.method == 'POST':
            return TeacherCreateSerializer
        return TeacherProfileDetailSerializer
    
    def get(self, request, *args, **kwargs):
        """Liste des professeurs"""
        queryset = self.get_queryset()
        
        # Pagination
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = TeacherProfileDetailSerializer(
                [u.teacher_profile for u in page],
                many=True
            )
            return self.get_paginated_response(serializer.data)
        
        serializer = TeacherProfileDetailSerializer(
            [u.teacher_profile for u in queryset],
            many=True
        )
        
        return Response({
            'success': True,
            'total_teachers': queryset.count(),
            'teachers': serializer.data
        })
    
    def post(self, request, *args, **kwargs):
        """Créer un nouveau professeur avec assignations"""
        logger.info(f"👨‍🏫 Création professeur par admin: {request.user.username}")
        
        serializer = TeacherCreateSerializer(
            data=request.data,
            context={'request': request}
        )
        
        if serializer.is_valid():
            try:
                result = serializer.save()
                user = result['user']
                teacher_profile = result['teacher_profile']
                
                # Retourner le profil complet
                response_serializer = TeacherProfileDetailSerializer(teacher_profile)
                
                logger.info(f"✅ Professeur créé: {user.username}")
                
                return Response({
                    'success': True,
                    'message': f'Professeur {user.get_full_name()} créé avec succès',
                    'teacher': response_serializer.data
                }, status=status.HTTP_201_CREATED)
                
            except Exception as e:
                logger.error(f"❌ Erreur création professeur: {str(e)}")
                return Response({
                    'success': False,
                    'error': 'Erreur lors de la création du professeur',
                    'details': str(e)
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class TeacherDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    Détail, modification et suppression d'un professeur (Admin uniquement)
    GET /api/auth/admin/teachers/{id}/
    PUT/PATCH /api/auth/admin/teachers/{id}/
    DELETE /api/auth/admin/teachers/{id}/
    """
    permission_classes = [IsAdminPermission]
    
    def get_queryset(self):
        return User.objects.filter(role='TEACHER').select_related('teacher_profile')
    
    def get_object(self):
        """Récupérer l'utilisateur professeur par ID"""
        user_id = self.kwargs.get('pk')
        return get_object_or_404(self.get_queryset(), id=user_id)
    
    def get(self, request, *args, **kwargs):
        """Détail d'un professeur"""
        user = self.get_object()
        serializer = TeacherProfileDetailSerializer(user.teacher_profile)
        
        return Response({
            'success': True,
            'teacher': serializer.data
        })
    
    def put(self, request, *args, **kwargs):
        """Mise à jour complète"""
        return self.update_teacher(request, partial=False)
    
    def patch(self, request, *args, **kwargs):
        """Mise à jour partielle"""
        return self.update_teacher(request, partial=True)
    
    def update_teacher(self, request, partial=False):
        """Logique de mise à jour"""
        user = self.get_object()
        logger.info(f"✏️ Mise à jour professeur: {user.username}")
        
        serializer = TeacherUpdateSerializer(
            user,
            data=request.data,
            partial=partial,
            context={'user_id': user.id}
        )
        
        if serializer.is_valid():
            serializer.save()
            
            # Retourner le profil mis à jour
            response_serializer = TeacherProfileDetailSerializer(user.teacher_profile)
            
            return Response({
                'success': True,
                'message': 'Professeur mis à jour avec succès',
                'teacher': response_serializer.data
            })
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)
    
    def delete(self, request, *args, **kwargs):
        """Supprimer un professeur"""
        user = self.get_object()
        username = user.username
        full_name = user.get_full_name()
        
        # Vérifier s'il a des assignations actives
        active_assignments = TeacherAssignment.objects.filter(
            teacher=user,
            is_active=True
        ).count()
        
        if active_assignments > 0:
            return Response({
                'success': False,
                'error': f'Impossible de supprimer ce professeur. Il a {active_assignments} assignation(s) active(s).',
                'suggestion': 'Désactivez d\'abord ses assignations ou transférez-les à un autre professeur'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Supprimer l'utilisateur (cascade sur le profil)
        user.delete()
        
        logger.info(f"🗑️ Professeur supprimé: {username}")
        
        return Response({
            'success': True,
            'message': f'Professeur {full_name} supprimé avec succès'
        })


class TeacherAssignmentsView(APIView):
    """
    Gestion des assignations d'un professeur
    GET /api/auth/admin/teachers/{id}/assignments/
    POST /api/auth/admin/teachers/{id}/assignments/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, teacher_id):
        """Liste des assignations d'un professeur"""
        try:
            teacher = get_object_or_404(User, id=teacher_id, role='TEACHER')
            
            assignments = TeacherAssignment.objects.filter(
                teacher=teacher
            ).select_related('subject').order_by('-is_active', 'subject__name')
            
            serializer = TeacherAssignmentSerializer(assignments, many=True)
            
            return Response({
                'success': True,
                'teacher': {
                    'id': teacher.id,
                    'full_name': teacher.get_full_name(),
                    'email': teacher.email
                },
                'total_assignments': assignments.count(),
                'active_assignments': assignments.filter(is_active=True).count(),
                'assignments': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur assignations professeur: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request, teacher_id):
        """Ajouter une assignation"""
        try:
            teacher = get_object_or_404(User, id=teacher_id, role='TEACHER')
            subject_id = request.data.get('subject_id')
            
            if not subject_id:
                return Response({
                    'success': False,
                    'error': 'subject_id requis'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            subject = get_object_or_404(Subject, id=subject_id, is_active=True)
            
            # Vérifier si l'assignation existe déjà
            existing = TeacherAssignment.objects.filter(
                teacher=teacher,
                subject=subject
            ).first()
            
            if existing:
                if existing.is_active:
                    return Response({
                        'success': False,
                        'error': 'Ce professeur est déjà assigné à cette matière'
                    }, status=status.HTTP_400_BAD_REQUEST)
                else:
                    # Réactiver l'assignation
                    existing.is_active = True
                    existing.save()
                    serializer = TeacherAssignmentSerializer(existing)
                    
                    return Response({
                        'success': True,
                        'message': 'Assignation réactivée',
                        'assignment': serializer.data
                    })
            
            # Créer la nouvelle assignation
            assignment = TeacherAssignment.objects.create(
                teacher=teacher,
                subject=subject,
                can_edit_content=request.data.get('can_edit_content', False),
                can_upload_documents=request.data.get('can_upload_documents', True),
                can_delete_documents=request.data.get('can_delete_documents', False),
                can_manage_students=request.data.get('can_manage_students', True),
                notes=request.data.get('notes', ''),
                assigned_by=request.user,
                is_active=True
            )
            
            serializer = TeacherAssignmentSerializer(assignment)
            
            logger.info(f"✅ Assignation créée: {teacher.username} → {subject.name}")
            
            return Response({
                'success': True,
                'message': f'{teacher.get_full_name()} assigné à {subject.name}',
                'assignment': serializer.data
            }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"❌ Erreur création assignation: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TeacherAssignmentDetailView(APIView):
    """
    Modification et suppression d'une assignation
    PUT/PATCH /api/auth/admin/assignments/{id}/
    DELETE /api/auth/admin/assignments/{id}/
    """
    permission_classes = [IsAdminPermission]
    
    def put(self, request, assignment_id):
        """Mettre à jour une assignation"""
        try:
            assignment = get_object_or_404(TeacherAssignment, id=assignment_id)
            
            # Mettre à jour les permissions
            assignment.can_edit_content = request.data.get('can_edit_content', assignment.can_edit_content)
            assignment.can_upload_documents = request.data.get('can_upload_documents', assignment.can_upload_documents)
            assignment.can_delete_documents = request.data.get('can_delete_documents', assignment.can_delete_documents)
            assignment.can_manage_students = request.data.get('can_manage_students', assignment.can_manage_students)
            assignment.notes = request.data.get('notes', assignment.notes)
            assignment.is_active = request.data.get('is_active', assignment.is_active)
            assignment.save()
            
            serializer = TeacherAssignmentSerializer(assignment)
            
            logger.info(f"✏️ Assignation modifiée: {assignment}")
            
            return Response({
                'success': True,
                'message': 'Assignation mise à jour',
                'assignment': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur modification assignation: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, assignment_id):
        """Supprimer une assignation"""
        try:
            assignment = get_object_or_404(TeacherAssignment, id=assignment_id)
            teacher_name = assignment.teacher.get_full_name()
            subject_name = assignment.subject.name
            
            assignment.delete()
            
            logger.info(f"🗑️ Assignation supprimée: {teacher_name} → {subject_name}")
            
            return Response({
                'success': True,
                'message': f'Assignation de {teacher_name} à {subject_name} supprimée'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression assignation: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# accounts/views.py

class TeacherToggleActiveView(APIView):
    """
    Activer/Désactiver un professeur
    POST /api/auth/admin/teachers/{id}/toggle-active/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request, teacher_id):
        """Toggle is_active d'un professeur"""
        try:
            teacher_user = get_object_or_404(User, id=teacher_id, role='TEACHER')
            
            # Toggle
            teacher_user.is_active = not teacher_user.is_active
            teacher_user.save(update_fields=['is_active'])
            
            status_text = 'activé' if teacher_user.is_active else 'désactivé'
            
            logger.info(f"🔄 Professeur {status_text}: {teacher_user.username}")
            
            return Response({
                'success': True,
                'message': f'Professeur {teacher_user.get_full_name()} {status_text}',
                'is_active': teacher_user.is_active
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur toggle professeur: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# ========================================
# DASHBOARD ADMIN
# ========================================

class AdminDashboardView(APIView):
    """
    Dashboard complet pour l'administrateur
    GET /api/auth/admin/dashboard/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request):
        """Récupérer toutes les statistiques du dashboard"""
        logger.info(f"📊 Dashboard admin: {request.user.username}")
        
        try:
            # Dates pour les calculs
            now = timezone.now()
            thirty_days_ago = now - timedelta(days=30)
            today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
            
            # =====================================
            # 1. STATISTIQUES GÉNÉRALES
            # =====================================
            
            total_users = User.objects.count()
            total_students = User.objects.filter(role='STUDENT').count()
            total_teachers = User.objects.filter(role='TEACHER').count()
            total_admins = User.objects.filter(role='ADMIN').count()
            
            active_students = User.objects.filter(
                role='STUDENT',
                is_active=True
            ).count()
            
            active_teachers = User.objects.filter(
                role='TEACHER',
                is_active=True
            ).count()
            
            # Académique
            total_subjects = Subject.objects.count()
            active_subjects = Subject.objects.filter(is_active=True).count()
            total_levels = Level.objects.count()
            total_majors = Major.objects.count()
            
            # Contenus
            total_documents = Document.objects.count()
            total_quizzes = Quiz.objects.count()
            active_quizzes = Quiz.objects.filter(is_active=True).count()
            
            # Activité 30 derniers jours
            new_students_30d = User.objects.filter(
                role='STUDENT',
                date_joined__gte=thirty_days_ago
            ).count()
            
            new_documents_30d = Document.objects.filter(
                created_at__gte=thirty_days_ago
            ).count()
            
            new_quizzes_30d = Quiz.objects.filter(
                created_at__gte=thirty_days_ago
            ).count()
            
            total_views_30d = UserActivity.objects.filter(
                action='view',
                created_at__gte=thirty_days_ago
            ).count()
            
            total_downloads_30d = UserActivity.objects.filter(
                action='download',
                created_at__gte=thirty_days_ago
            ).count()
            
            quiz_attempts_30d = QuizAttempt.objects.filter(
                started_at__gte=thirty_days_ago
            ).count()
            
            stats_data = {
                'total_users': total_users,
                'total_students': total_students,
                'total_teachers': total_teachers,
                'total_admins': total_admins,
                'active_students': active_students,
                'active_teachers': active_teachers,
                'total_subjects': total_subjects,
                'active_subjects': active_subjects,
                'total_levels': total_levels,
                'total_majors': total_majors,
                'total_documents': total_documents,
                'total_quizzes': total_quizzes,
                'active_quizzes': active_quizzes,
                'new_students_30d': new_students_30d,
                'new_documents_30d': new_documents_30d,
                'new_quizzes_30d': new_quizzes_30d,
                'total_views_30d': total_views_30d,
                'total_downloads_30d': total_downloads_30d,
                'quiz_attempts_30d': quiz_attempts_30d
            }
            
            # =====================================
            # 2. RÉPARTITION PAR FILIÈRE
            # =====================================
            
            students_by_major = []
            total_with_major = StudentProfile.objects.exclude(major__isnull=True).count()
            
            if total_with_major > 0:
                major_stats = StudentProfile.objects.values(
                    'major__id', 'major__name', 'major__code'
                ).annotate(
                    count=Count('id')
                ).order_by('-count')
                
                for stat in major_stats:
                    if stat['major__id']:
                        students_by_major.append({
                            'major_id': stat['major__id'],
                            'major_name': stat['major__name'],
                            'major_code': stat['major__code'],
                            'student_count': stat['count'],
                            'percentage': round((stat['count'] / total_with_major) * 100, 1)
                        })
            
            # =====================================
            # 3. RÉPARTITION PAR NIVEAU
            # =====================================
            
            students_by_level = []
            total_with_level = StudentProfile.objects.exclude(level__isnull=True).count()
            
            if total_with_level > 0:
                level_stats = StudentProfile.objects.values(
                    'level__id', 'level__name', 'level__code'
                ).annotate(
                    count=Count('id')
                ).order_by('level__order')
                
                for stat in level_stats:
                    if stat['level__id']:
                        students_by_level.append({
                            'level_id': stat['level__id'],
                            'level_name': stat['level__name'],
                            'level_code': stat['level__code'],
                            'student_count': stat['count'],
                            'percentage': round((stat['count'] / total_with_level) * 100, 1)
                        })
            
            # =====================================
            # 4. CHRONOLOGIE D'ACTIVITÉ (7 derniers jours)
            # =====================================
            
            activity_timeline = []
            for i in range(6, -1, -1):
                day = now - timedelta(days=i)
                day_start = day.replace(hour=0, minute=0, second=0, microsecond=0)
                day_end = day_start + timedelta(days=1)
                
                activity_timeline.append({
                    'date': day_start.date(),
                    'new_students': User.objects.filter(
                        role='STUDENT',
                        date_joined__gte=day_start,
                        date_joined__lt=day_end
                    ).count(),
                    'new_documents': Document.objects.filter(
                        created_at__gte=day_start,
                        created_at__lt=day_end
                    ).count(),
                    'views': UserActivity.objects.filter(
                        action='view',
                        created_at__gte=day_start,
                        created_at__lt=day_end
                    ).count(),
                    'downloads': UserActivity.objects.filter(
                        action='download',
                        created_at__gte=day_start,
                        created_at__lt=day_end
                    ).count(),
                    'quiz_attempts': QuizAttempt.objects.filter(
                        started_at__gte=day_start,
                        started_at__lt=day_end
                    ).count()
                })
            
            # =====================================
            # 5. TOP MATIÈRES
            # =====================================
            
            top_subjects_data = Subject.objects.annotate(
                document_count=Count('documents', filter=Q(documents__is_active=True), distinct=True),
                view_count=Count('activities', filter=Q(activities__action='view')),
                download_count=Count('activities', filter=Q(activities__action='download'))
            ).order_by('-view_count')[:5]
            
            top_subjects = [{
                'subject_id': s.id,
                'subject_name': s.name,
                'subject_code': s.code,
                'document_count': s.document_count,
                'view_count': s.view_count,
                'download_count': s.download_count
            } for s in top_subjects_data]
            
            # =====================================
            # 6. TOP DOCUMENTS
            # =====================================
            
            top_documents_data = Document.objects.select_related('subject').filter(
                is_active=True
            ).order_by('-view_count')[:10]
            
            top_documents = [{
                'document_id': d.id,
                'document_title': d.title,
                'subject_name': d.subject.name,
                'document_type': d.get_document_type_display(),
                'view_count': d.view_count,
                'download_count': d.download_count
            } for d in top_documents_data]
            
            # =====================================
            # 7. PERFORMANCE DES QUIZ (corrigé)
            # =====================================

            total_attempts = QuizAttempt.objects.count()
            completed_attempts = QuizAttempt.objects.filter(status='COMPLETED').count()

            # Calcul de la note moyenne (normalisée sur 20)
            avg_score_data = QuizAttempt.objects.filter(
                status='COMPLETED'
            ).select_related('quiz')

            average_score = 0
            if avg_score_data.exists():
                scores = []
                for attempt in avg_score_data:
                    total = attempt.quiz.total_points
                    if total > 0:
                        normalized = (float(attempt.score) / float(total)) * 20
                        scores.append(normalized)
                
                if scores:
                    average_score = round(sum(scores) / len(scores), 2)

            # Taux de réussite global
            completed = QuizAttempt.objects.filter(status='COMPLETED').select_related('quiz')

            passed = 0
            for attempt in completed:
                total = attempt.quiz.total_points
                if total > 0:
                    score_percentage = (float(attempt.score) / float(total)) * 100
                    if score_percentage >= attempt.quiz.passing_percentage:
                        passed += 1

            pass_rate = 0
            if completed.count() > 0:
                pass_rate = round((passed / completed.count()) * 100, 1)

            # Quiz les plus difficiles (taux de réussite le plus bas)
            hardest_quizzes = []
            quizzes_with_attempts = Quiz.objects.annotate(
                attempt_count=Count('attempts', filter=Q(attempts__status='COMPLETED'))
            ).filter(attempt_count__gte=3)  # Au moins 3 tentatives

            for quiz in quizzes_with_attempts:
                completed_quiz_attempts = QuizAttempt.objects.filter(
                    quiz=quiz,
                    status='COMPLETED'
                )
                completed_count = completed_quiz_attempts.count()

                if completed_count > 0:
                    passed_quiz = 0
                    for attempt in completed_quiz_attempts:
                        total = attempt.quiz.total_points
                        if total > 0:
                            score_percentage = (float(attempt.score) / float(total)) * 100
                            if score_percentage >= attempt.quiz.passing_percentage:
                                passed_quiz += 1

                    quiz_pass_rate = (passed_quiz / completed_count) * 100
                    hardest_quizzes.append({
                        'quiz_id': quiz.id,
                        'title': quiz.title,
                        'subject': quiz.subject.name,
                        'attempts': completed_count,
                        'pass_rate': round(quiz_pass_rate, 1)
                    })

            # Trier pour obtenir les 5 plus difficiles
            hardest_quizzes = sorted(hardest_quizzes, key=lambda x: x['pass_rate'])[:5]

            # Quiz les plus faciles (taux de réussite le plus élevé)
            easiest_quizzes = sorted(
                [q for q in hardest_quizzes if q['pass_rate'] > 0],
                key=lambda x: x['pass_rate'],
                reverse=True
            )[:5]

            quiz_performance = {
                'total_attempts': total_attempts,
                'completed_attempts': completed_attempts,
                'average_score': average_score,
                'pass_rate': pass_rate,
                'hardest_quizzes': hardest_quizzes,
                'easiest_quizzes': easiest_quizzes
            }

            
            # =====================================
            # 8. ACTIVITÉS RÉCENTES
            # =====================================
            
            recent_activities = []
            
            # Nouveaux étudiants (5 derniers)
            new_students = User.objects.filter(
                role='STUDENT'
            ).order_by('-date_joined')[:5]
            
            for student in new_students:
                recent_activities.append({
                    'activity_type': 'new_student',
                    'title': 'Nouvel étudiant',
                    'description': f'{student.get_full_name()} s\'est inscrit',
                    'user_name': student.get_full_name(),
                    'created_at': student.date_joined,
                    'icon': 'person_add',
                    'color': 'blue'
                })
            
            # Nouveaux documents (5 derniers)
            new_docs = Document.objects.select_related('subject', 'created_by').order_by('-created_at')[:5]
            
            for doc in new_docs:
                recent_activities.append({
                    'activity_type': 'new_document',
                    'title': 'Nouveau document',
                    'description': f'{doc.title}',
                    'subject_name': doc.subject.name,
                    'user_name': doc.created_by.get_full_name() if doc.created_by else 'Système',
                    'created_at': doc.created_at,
                    'icon': 'description',
                    'color': 'green'
                })
            
            # Nouveaux quiz (5 derniers)
            new_quiz = Quiz.objects.select_related('subject', 'created_by').order_by('-created_at')[:5]
            
            for quiz in new_quiz:
                recent_activities.append({
                    'activity_type': 'new_quiz',
                    'title': 'Nouveau quiz',
                    'description': f'{quiz.title}',
                    'subject_name': quiz.subject.name,
                    'user_name': quiz.created_by.get_full_name() if quiz.created_by else 'Système',
                    'created_at': quiz.created_at,
                    'icon': 'quiz',
                    'color': 'purple'
                })
            
            # Trier par date
            recent_activities = sorted(
                recent_activities,
                key=lambda x: x['created_at'],
                reverse=True
            )[:15]
            
            # =====================================
            # 9. SANTÉ DU SYSTÈME
            # =====================================
            
            # Calculer la taille totale des fichiers
            total_size = Document.objects.aggregate(
                total=Sum('file_size')
            )['total'] or 0
            
            total_storage_mb = round(total_size / (1024 * 1024), 2)
            
            # Utilisateurs actifs aujourd'hui
            active_today = UserActivity.objects.filter(
                created_at__gte=today_start
            ).values('user').distinct().count()
            
            # Assignations en attente (professeurs sans matières)
            from accounts.models import TeacherAssignment
            teachers_with_assignments = TeacherAssignment.objects.filter(
                is_active=True
            ).values('teacher').distinct().count()
            
            total_active_teachers = User.objects.filter(
                role='TEACHER',
                is_active=True
            ).count()
            
            pending_assignments = total_active_teachers - teachers_with_assignments
            
            # Professeurs inactifs
            inactive_teachers = User.objects.filter(
                role='TEACHER',
                is_active=False
            ).count()
            
            # Matières sans contenu
            subjects_without_content = Subject.objects.annotate(
                doc_count=Count('documents', filter=Q(documents__is_active=True))
            ).filter(doc_count=0, is_active=True).count()
            
            # Étudiants sans activité (jamais consulté de document)
            students_with_activity = UserActivity.objects.values('user').distinct().count()
            students_without_activity = total_students - students_with_activity
            
            # Déterminer le statut
            warnings = 0
            if pending_assignments > 5:
                warnings += 1
            if inactive_teachers > 10:
                warnings += 1
            if subjects_without_content > 5:
                warnings += 1
            
            if warnings == 0:
                system_status = 'healthy'
            elif warnings <= 2:
                system_status = 'warning'
            else:
                system_status = 'critical'
            
            system_health = {
                'status': system_status,
                'total_storage_mb': total_storage_mb,
                'active_users_today': active_today,
                'pending_assignments': pending_assignments,
                'inactive_teachers': inactive_teachers,
                'subjects_without_content': subjects_without_content,
                'students_without_activity': students_without_activity
            }
            
            # =====================================
            # ASSEMBLAGE FINAL
            # =====================================
            
            dashboard_data = {
                'stats': stats_data,
                'students_by_major': students_by_major,
                'students_by_level': students_by_level,
                'activity_timeline': activity_timeline,
                'top_subjects': top_subjects,
                'top_documents': top_documents,
                'quiz_performance': quiz_performance,
                'recent_activities': recent_activities,
                'system_health': system_health
            }
            
            serializer = AdminDashboardSerializer(dashboard_data)
            
            return Response({
                'success': True,
                'dashboard': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur dashboard admin: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# ========================================
# GESTION DES ÉTUDIANTS (ADMIN)
# ========================================

class AdminStudentListCreateView(APIView):
    """
    Liste et création des étudiants (Admin uniquement)
    GET /api/auth/admin/students/
    POST /api/auth/admin/students/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request):
        """Liste de tous les étudiants avec filtres"""
        logger.info(f"👥 Liste étudiants par admin: {request.user.username}")
        
        try:
            # Récupérer tous les étudiants
            queryset = User.objects.filter(role='STUDENT').select_related(
                'student_profile',
                'student_profile__level',
                'student_profile__major'
            )
            
            # Filtres
            is_active = request.GET.get('is_active', None)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
            # Filtrer par niveau - ✅ Accepte 'level' OU 'level_id'
            level_id = request.GET.get('level') or request.GET.get('level_id')
            if level_id:
                queryset = queryset.filter(student_profile__level_id=level_id)
            
            # Filtrer par filière - ✅ Accepte 'major' OU 'major_id'
            major_id = request.GET.get('major') or request.GET.get('major_id')
            if major_id:
                queryset = queryset.filter(student_profile__major_id=major_id)
            
            # Recherche par nom, email, username ou téléphone
            search = request.GET.get('search', None)
            if search:
                queryset = queryset.filter(
                    Q(first_name__icontains=search) |
                    Q(last_name__icontains=search) |
                    Q(email__icontains=search) |
                    Q(username__icontains=search) |
                    Q(student_profile__phone_number__icontains=search)
                )
            
            # Tri
            order_by = request.GET.get('order_by', '-date_joined')
            allowed_orders = [
                'date_joined', '-date_joined',
                'first_name', '-first_name',
                'last_name', '-last_name',
                'email', '-email'
            ]
            if order_by in allowed_orders:
                queryset = queryset.order_by(order_by)
            
            # Sérialiser les résultats
            serializer = StudentAdminListSerializer(queryset, many=True)
            
            return Response({
                'success': True,
                'total_students': queryset.count(),
                'students': serializer.data,
                'filters_applied': {
                    'is_active': is_active,
                    'level': level_id,
                    'major': major_id,
                    'search': search
                }
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur liste étudiants: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """Créer un nouvel étudiant"""
        logger.info(f"➕ Création étudiant par admin: {request.user.username}")
        logger.info(f"📦 Données reçues: {request.data}")  # ✅ AJOUTÉ pour déboguer
        
        serializer = StudentCreateSerializer(data=request.data)
        
        if serializer.is_valid():
            try:
                user = serializer.save()
                
                # Retourner l'étudiant créé avec détails
                response_serializer = StudentAdminDetailSerializer(user)
                
                logger.info(f"✅ Étudiant créé: {user.username} - {user.get_full_name()}")
                
                return Response({
                    'success': True,
                    'message': f'Étudiant "{user.get_full_name()}" créé avec succès',
                    'student': response_serializer.data
                }, status=status.HTTP_201_CREATED)
                
            except Exception as e:
                logger.error(f"❌ Erreur création étudiant: {str(e)}")
                import traceback
                traceback.print_exc()
                
                return Response({
                    'success': False,
                    'error': 'Erreur lors de la création',
                    'details': str(e)
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        logger.error(f"❌ Erreurs de validation: {serializer.errors}")  # ✅ AJOUTÉ
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)

class AdminStudentDetailView(APIView):
    """
    Détail, modification et suppression d'un étudiant (Admin uniquement)
    GET /api/auth/admin/students/{id}/
    PUT/PATCH /api/auth/admin/students/{id}/
    DELETE /api/auth/admin/students/{id}/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, student_id):
        """Détail d'un étudiant"""
        logger.info(f"📖 Détail étudiant {student_id} par admin: {request.user.username}")
        
        try:
            student = User.objects.select_related(
                'student_profile',
                'student_profile__level',
                'student_profile__major'
            ).get(id=student_id, role='STUDENT')
            
            serializer = StudentAdminDetailSerializer(student)
            
            return Response({
                'success': True,
                'student': serializer.data
            })
            
        except User.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Étudiant non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur détail étudiant: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def put(self, request, student_id):
        """Mise à jour complète"""
        return self.update_student(request, student_id, partial=False)
    
    def patch(self, request, student_id):
        """Mise à jour partielle"""
        return self.update_student(request, student_id, partial=True)
    
    def update_student(self, request, student_id, partial=False):
        """Logique de mise à jour"""
        logger.info(f"✏️ Modification étudiant {student_id} par admin: {request.user.username}")
        
        try:
            student = get_object_or_404(User, id=student_id, role='STUDENT')
            
            serializer = StudentUpdateSerializer(
                student,
                data=request.data,
                partial=partial
            )
            
            if serializer.is_valid():
                serializer.save()
                
                # Retourner l'étudiant mis à jour
                response_serializer = StudentAdminDetailSerializer(student)
                
                logger.info(f"✅ Étudiant modifié: {student.username} - {student.get_full_name()}")
                
                return Response({
                    'success': True,
                    'message': 'Étudiant mis à jour avec succès',
                    'student': response_serializer.data
                })
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"❌ Erreur modification étudiant: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, student_id):
        """Supprimer un étudiant"""
        logger.info(f"🗑️ Suppression étudiant {student_id} par admin: {request.user.username}")
        
        try:
            student = get_object_or_404(User, id=student_id, role='STUDENT')
            
            # Vérifier s'il a des activités
            activity_count = UserActivity.objects.filter(user=student).count()
            quiz_count = QuizAttempt.objects.filter(user=student).count()
            
            if activity_count > 0 or quiz_count > 0:
                return Response({
                    'success': False,
                    'error': f'Impossible de supprimer cet étudiant. Il a {activity_count} activité(s) et {quiz_count} tentative(s) de quiz.',
                    'suggestion': 'Désactivez le compte au lieu de le supprimer pour conserver l\'historique'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            student_name = student.get_full_name()
            student_username = student.username
            student.delete()
            
            logger.info(f"✅ Étudiant supprimé: {student_username} - {student_name}")
            
            return Response({
                'success': True,
                'message': f'Étudiant "{student_name}" supprimé avec succès'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression étudiant: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminStudentStatisticsView(APIView):
    """
    Statistiques détaillées d'un étudiant (Admin uniquement)
    GET /api/auth/admin/students/{id}/statistics/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, student_id):
        """Statistiques complètes d'un étudiant"""
        logger.info(f"📊 Stats étudiant {student_id} par admin: {request.user.username}")
        
        try:
            student = get_object_or_404(User, id=student_id, role='STUDENT')
            
            # Activité
            total_views = UserActivity.objects.filter(user=student, action='view').count()
            total_downloads = UserActivity.objects.filter(user=student, action='download').count()
            total_favorites = UserFavorite.objects.filter(user=student).count()
            
            last_activity_obj = UserActivity.objects.filter(user=student).order_by('-created_at').first()
            last_activity = last_activity_obj.created_at if last_activity_obj else None
            
            # Quiz
            quiz_attempts = QuizAttempt.objects.filter(user=student)
            total_quiz_attempts = quiz_attempts.count()
            completed_quiz_attempts = quiz_attempts.filter(status='COMPLETED').count()
            
            # Score moyen
            avg_score = 0
            if completed_quiz_attempts > 0:
                scores = []
                for attempt in quiz_attempts.filter(status='COMPLETED'):
                    if attempt.quiz.total_points > 0:
                        normalized = (float(attempt.score) / float(attempt.quiz.total_points)) * 20
                        scores.append(normalized)
                
                if scores:
                    avg_score = round(sum(scores) / len(scores), 2)
            
            # Taux de réussite
            passed = quiz_attempts.filter(
                status='COMPLETED',
                score__gte=F('quiz__passing_percentage')
            ).count()
            
            quiz_pass_rate = round((passed / completed_quiz_attempts) * 100, 1) if completed_quiz_attempts > 0 else 0
            
            # Performance par matière
            from courses.models import Subject
            
            subjects = Subject.objects.filter(
                levels=student.student_profile.level,
                majors=student.student_profile.major
            ).distinct()
            
            performance_by_subject = []
            
            for subject in subjects:
                subject_attempts = quiz_attempts.filter(quiz__subject=subject)
                subject_total = subject_attempts.count()
                
                if subject_total == 0:
                    continue
                
                subject_completed = subject_attempts.filter(status='COMPLETED')
                subject_completed_count = subject_completed.count()
                
                # Score moyen
                subject_avg = 0
                if subject_completed_count > 0:
                    scores = []
                    for attempt in subject_completed:
                        if attempt.quiz.total_points > 0:
                            normalized = (float(attempt.score) / float(attempt.quiz.total_points)) * 20
                            scores.append(normalized)
                    
                    if scores:
                        subject_avg = round(sum(scores) / len(scores), 2)
                
                # Taux de réussite
                subject_passed = subject_completed.filter(score__gte=F('quiz__passing_percentage')).count()
                subject_pass_rate = round((subject_passed / subject_completed_count) * 100, 1) if subject_completed_count > 0 else 0
                
                # Activité sur la matière
                subject_views = UserActivity.objects.filter(
                    user=student,
                    subject=subject,
                    action='view'
                ).count()
                
                performance_by_subject.append({
                    'subject_id': subject.id,
                    'subject_name': subject.name,
                    'subject_code': subject.code,
                    'total_attempts': subject_total,
                    'completed_attempts': subject_completed_count,
                    'average_score': subject_avg,
                    'pass_rate': subject_pass_rate,
                    'views': subject_views
                })
            
            # Construire les stats
            stats_data = {
                'student_id': student.id,
                'student_name': student.get_full_name(),
                'student_email': student.email,
                'total_views': total_views,
                'total_downloads': total_downloads,
                'total_favorites': total_favorites,
                'last_activity': last_activity,
                'total_quiz_attempts': total_quiz_attempts,
                'completed_quiz_attempts': completed_quiz_attempts,
                'average_quiz_score': avg_score,
                'quiz_pass_rate': quiz_pass_rate,
                'performance_by_subject': performance_by_subject
            }
            
            serializer = StudentStatisticsSerializer(stats_data)
            
            return Response({
                'success': True,
                'statistics': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur stats étudiant: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminStudentToggleActiveView(APIView):
    """
    Activer/désactiver un étudiant
    POST /api/auth/admin/students/{id}/toggle-active/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request, student_id):
        """Toggle is_active"""
        try:
            student = get_object_or_404(User, id=student_id, role='STUDENT')
            
            student.is_active = not student.is_active
            student.save(update_fields=['is_active'])
            
            status_text = 'activé' if student.is_active else 'désactivé'
            logger.info(f"🔄 Étudiant {status_text}: {student.username}")
            
            return Response({
                'success': True,
                'message': f'Étudiant "{student.get_full_name()}" {status_text}',
                'is_active': student.is_active
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur toggle étudiant: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminStudentBulkActionView(APIView):
    """
    Actions en masse sur les étudiants
    POST /api/auth/admin/students/bulk-action/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request):
        """Effectuer une action en masse"""
        logger.info(f"🔄 Action en masse par admin: {request.user.username}")
        
        serializer = BulkStudentActionSerializer(data=request.data)
        
        if not serializer.is_valid():
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            student_ids = serializer.validated_data['student_ids']
            action = serializer.validated_data['action']
            
            # Récupérer les étudiants
            students = User.objects.filter(id__in=student_ids, role='STUDENT')
            
            if students.count() != len(student_ids):
                return Response({
                    'success': False,
                    'error': 'Certains IDs d\'étudiants sont invalides'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            results = {
                'success_count': 0,
                'error_count': 0,
                'errors': []
            }
            
            # Exécuter l'action
            if action == 'activate':
                count = students.update(is_active=True)
                results['success_count'] = count
                logger.info(f"✅ {count} étudiant(s) activé(s)")
            
            elif action == 'deactivate':
                count = students.update(is_active=False)
                results['success_count'] = count
                logger.info(f"✅ {count} étudiant(s) désactivé(s)")
            
            elif action == 'delete':
                # Vérifier qu'ils n'ont pas d'activités
                for student in students:
                    activity_count = UserActivity.objects.filter(user=student).count()
                    quiz_count = QuizAttempt.objects.filter(user=student).count()
                    
                    if activity_count > 0 or quiz_count > 0:
                        results['error_count'] += 1
                        results['errors'].append({
                            'student_id': student.id,
                            'student_name': student.get_full_name(),
                            'error': 'A des activités ou tentatives de quiz'
                        })
                    else:
                        student.delete()
                        results['success_count'] += 1
                
                logger.info(f"✅ {results['success_count']} étudiant(s) supprimé(s)")
            
            elif action == 'change_level':
                new_level = serializer.validated_data['new_level']
                
                for student in students:
                    student.student_profile.level = new_level
                    student.student_profile.save(update_fields=['level'])
                    results['success_count'] += 1
                
                logger.info(f"✅ {results['success_count']} étudiant(s) changé(s) de niveau")
            
            elif action == 'change_major':
                new_major = serializer.validated_data['new_major']
                
                for student in students:
                    student.student_profile.major = new_major
                    student.student_profile.save(update_fields=['major'])
                    results['success_count'] += 1
                
                logger.info(f"✅ {results['success_count']} étudiant(s) changé(s) de filière")
            
            return Response({
                'success': True,
                'message': f'Action "{action}" effectuée sur {results["success_count"]} étudiant(s)',
                'results': results
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur action en masse: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminStudentExportView(APIView):
    """
    Export des étudiants en CSV
    GET /api/auth/admin/students/export/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request):
        """Exporter les étudiants en CSV"""
        logger.info(f"📥 Export étudiants par admin: {request.user.username}")
        
        try:
            import csv
            from django.http import HttpResponse
            
            # Créer la réponse HTTP
            response = HttpResponse(content_type='text/csv; charset=utf-8')
            response['Content-Disposition'] = 'attachment; filename="etudiants.csv"'
            
            # Ajouter le BOM UTF-8 pour Excel
            response.write('\ufeff')
            
            writer = csv.writer(response)
            
            # En-têtes (sans "Numéro étudiant")
            writer.writerow([
                'ID',
                'Nom d\'utilisateur',
                'Email',
                'Prénom',
                'Nom',
                'Niveau',
                'Filière',
                'Téléphone',
                'Actif',
                'Date d\'inscription'
            ])
            
            # Récupérer les étudiants avec filtres
            queryset = User.objects.filter(role='STUDENT').select_related(
                'student_profile',
                'student_profile__level',
                'student_profile__major'
            )
            
            # Appliquer les mêmes filtres que la liste
            level_id = request.GET.get('level', None)
            if level_id:
                queryset = queryset.filter(student_profile__level_id=level_id)
            
            major_id = request.GET.get('major', None)
            if major_id:
                queryset = queryset.filter(student_profile__major_id=major_id)
            
            is_active = request.GET.get('is_active', None)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
            # Écrire les données
            for student in queryset:
                profile = student.student_profile if hasattr(student, 'student_profile') else None
                writer.writerow([
                    student.id,
                    student.username,
                    student.email,
                    student.first_name,
                    student.last_name,
                    profile.level.name if profile and profile.level else '',
                    profile.major.name if profile and profile.major else '',
                    profile.phone_number if profile else '',
                    'Oui' if student.is_active else 'Non',
                    student.date_joined.strftime('%Y-%m-%d %H:%M')
                ])
            
            logger.info(f"✅ Export de {queryset.count()} étudiant(s)")
            
            return response
            
        except Exception as e:
            logger.error(f"❌ Erreur export étudiants: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)