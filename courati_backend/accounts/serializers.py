import logging
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model, authenticate
from django.utils.translation import gettext_lazy as _
from django.db import models
from .models import StudentProfile, AdminProfile, Level, Major
from accounts.models import TeacherProfile, TeacherAssignment
from courses.models import Subject
from .permissions import IsAdminUser

logger = logging.getLogger(__name__)

User = get_user_model()

class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Serializer personnalisé pour l'authentification avec support email/username/phone"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Permettre l'authentification par username, email ou phone
        self.fields['username'] = serializers.CharField(
            label=_("Username/Email/Phone"),
            help_text=_("Entrez votre nom d'utilisateur, email ou numéro de téléphone")
        )

    def validate(self, attrs):
        username_or_email_or_phone = attrs.get('username')
        password = attrs.get('password')
        
        if not username_or_email_or_phone or not password:
            raise serializers.ValidationError(_('Username/Email/Phone et mot de passe sont requis.'))
        
        # Essayer d'abord avec username/email classique
        user = authenticate(username=username_or_email_or_phone, password=password)
        
        # Si pas trouvé, essayer par email
        if not user:
            try:
                user_obj = User.objects.get(email=username_or_email_or_phone)
                user = authenticate(username=user_obj.username, password=password)
            except User.DoesNotExist:
                pass
        
        # Si pas trouvé, essayer par numéro de téléphone (pour étudiants)
        if not user:
            try:
                student_profile = StudentProfile.objects.get(phone_number=username_or_email_or_phone)
                user = authenticate(username=student_profile.user.username, password=password)
            except StudentProfile.DoesNotExist:
                pass
        
        if not user:
            raise serializers.ValidationError(_('Identifiants invalides.'))
        
        if not user.is_active:
            raise serializers.ValidationError(_('Ce compte est désactivé.'))
        
        # Vérifier si l'étudiant a vérifié son compte (maintenant basé sur is_verified du profil)
        if hasattr(user, 'student_profile') and not user.student_profile.is_verified:
            raise serializers.ValidationError(_('Veuillez vérifier votre email avant de vous connecter.'))
        
        # Utiliser la logique parent pour générer les tokens
        attrs['username'] = user.username
        data = super().validate(attrs)
        
        # AJOUTER LES DONNÉES UTILISATEUR ICI
        data['user'] = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'role': user.role,
            'is_staff': user.is_staff,
            'is_active': user.is_active,
            'date_joined': user.date_joined.isoformat() if user.date_joined else None,
        }
        
        # Ajouter le profil étudiant si existe
        if hasattr(user, 'student_profile'):
            profile = user.student_profile
            data['student_profile'] = {
                'id': profile.id,
                'user': profile.user_id,
                'phone_number': profile.phone_number,
                'level': {
                     'id': profile.level.id,
                     'code': profile.level.code,
                     'name': profile.level.name
                } if profile.level else None,
                'major': {
                     'id': profile.major.id,
                     'code': profile.major.code,
                     'name': profile.major.name,
                     'department': profile.major.department
                } if profile.major else None,
                'is_verified': profile.is_verified,
                'created_at': profile.created_at.isoformat(),
                'updated_at': profile.updated_at.isoformat(),
            }
        else:
            data['student_profile'] = None
            
        return data
    
    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        
        # Ajouter des informations personnalisées au token
        token['user_type'] = user.role
        token['email'] = user.email
        
        if hasattr(user, 'student_profile'):
            token['phone_number'] = user.student_profile.phone_number
            token['level_id'] = user.student_profile.level.id if user.student_profile.level else None
            token['major_id'] = user.student_profile.major.id if user.student_profile.major else None
            token['is_verified'] = user.student_profile.is_verified
        
        return token
    
class LevelSerializer(serializers.ModelSerializer):
    """Serializer pour les niveaux"""
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    
    class Meta:
        model = Level
        fields = ['id', 'code', 'name', 'description', 'order', 'is_active', 
                 'created_at', 'updated_at', 'created_by', 'created_by_name']
        read_only_fields = ['created_at', 'updated_at', 'created_by']
    
    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)

class MajorSerializer(serializers.ModelSerializer):
    """Serializer pour les filières"""
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    
    class Meta:
        model = Major
        fields = ['id', 'code', 'name', 'description', 'department', 'order', 
                 'is_active', 'created_at', 'updated_at', 'created_by', 'created_by_name']
        read_only_fields = ['created_at', 'updated_at', 'created_by']
    
    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)

class LevelSimpleSerializer(serializers.ModelSerializer):
    """Serializer simple pour affichage dans les listes de choix"""
    class Meta:
        model = Level
        fields = ['id', 'code', 'name']

class MajorSimpleSerializer(serializers.ModelSerializer):
    """Serializer simple pour affichage dans les listes de choix"""
    class Meta:
        model = Major
        fields = ['id', 'code', 'name', 'department']

class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    phone_number = serializers.CharField(max_length=15)
    level = serializers.PrimaryKeyRelatedField(queryset=Level.objects.filter(is_active=True))
    major = serializers.PrimaryKeyRelatedField(queryset=Major.objects.filter(is_active=True))
    first_name = serializers.CharField(max_length=30, required=False)
    last_name = serializers.CharField(max_length=30, required=False)

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur existe déjà.")
        return value

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Cet email existe déjà.")
        return value

    def validate_phone_number(self, value):
        if StudentProfile.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("Ce numéro de téléphone existe déjà.")
        return value

    def create(self, validated_data):
        # Extraire les données du profil étudiant
        phone_number = validated_data.pop('phone_number')
        level = validated_data.pop('level')
        major = validated_data.pop('major')
        
        # Créer l'utilisateur
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            role='STUDENT',
            is_active=False  # Sera activé après vérification email OTP
        )
        
        # Créer le profil étudiant
        student_profile = StudentProfile.objects.create(
            user=user,
            phone_number=phone_number,
            level=level,
            major=major,
            is_verified=False  # Sera vérifié après confirmation email OTP
        )
        
        return {
            'user': user,
            'student_profile': student_profile
        }

class VerifyOTPSerializer(serializers.Serializer):
    """Serializer pour vérifier l'OTP envoyé par email"""
    email = serializers.EmailField()
    otp = serializers.CharField(max_length=6, min_length=6)
    
    def validate_otp(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("L'OTP doit contenir uniquement des chiffres.")
        return value
    
    def validate_email(self, value):
        """Vérifier que l'email correspond à une inscription en attente"""
        # Cette validation pourrait être optionnelle selon votre logique métier
        return value

class PasswordResetRequestSerializer(serializers.Serializer):
    """Serializer pour demander la réinitialisation par email"""
    email = serializers.EmailField()
    
    def validate_email(self, value):
        """Validation basique du format email (déjà fait par EmailField)"""
        return value

class PasswordResetConfirmSerializer(serializers.Serializer):
    """Serializer pour confirmer la réinitialisation avec OTP email"""
    email = serializers.EmailField()
    otp = serializers.CharField(max_length=6, min_length=6)
    new_password = serializers.CharField(min_length=8, write_only=True)
    confirm_password = serializers.CharField(min_length=8, write_only=True)
    
    def validate_otp(self, value):
        if not value.isdigit():
            raise serializers.ValidationError("L'OTP doit contenir uniquement des chiffres.")
        return value
    
    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError("Les mots de passe ne correspondent pas.")
        return attrs

class AdminRegisterSerializer(serializers.Serializer):
    """Serializer pour l'inscription des administrateurs"""
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    first_name = serializers.CharField(max_length=30)
    last_name = serializers.CharField(max_length=30)
    department = serializers.CharField(max_length=100, required=False)
    phone_number = serializers.CharField(max_length=15, required=False)

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur existe déjà.")
        return value

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Cet email existe déjà.")
        return value

    def create(self, validated_data):
        department = validated_data.pop('department', '')
        phone_number = validated_data.pop('phone_number', '')
        
        # Créer l'utilisateur admin
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data['first_name'],
            last_name=validated_data['last_name'],
            role='ADMIN',
            is_active=True,  # Les admins sont actifs immédiatement
            is_staff=True    # Permettre l'accès à l'admin Django
        )
        
        # Créer le profil admin
        admin_profile = AdminProfile.objects.create(
            user=user,
            department=department,
            phone_number=phone_number
        )
        
        return {
            'user': user,
            'admin_profile': admin_profile
        }
# ========================================
# PROFILE SERIALIZERS - MOBILE (Students)
# ========================================
class UserProfileSerializer(serializers.ModelSerializer):
    """Serializer pour afficher le profil utilisateur"""
    user_type = serializers.SerializerMethodField()
    student_profile = serializers.SerializerMethodField()
    admin_profile = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 
                 'role', 'user_type', 'student_profile', 'admin_profile']
        read_only_fields = ['username', 'role']
    
    def get_user_type(self, obj):
        return obj.get_role_display()
    
    def get_student_profile(self, obj):
        if hasattr(obj, 'student_profile'):
            return StudentProfileSerializer(obj.student_profile).data
        return None
    
    def get_admin_profile(self, obj):
        if hasattr(obj, 'admin_profile'):
            return AdminProfileSerializer(obj.admin_profile).data
        return None

class StudentProfileSerializer(serializers.ModelSerializer):
    level_display = serializers.CharField(source='level.name', read_only=True)
    major_display = serializers.CharField(source='major.name', read_only=True)
    level_details = LevelSimpleSerializer(source='level', read_only=True)
    major_details = MajorSimpleSerializer(source='major', read_only=True)
    
    class Meta:
        model = StudentProfile
        fields = ['phone_number', 'level', 'level_display', 'level_details',
         'major', 'major_display', 'major_details', 'is_verified']

class AdminProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = AdminProfile
        fields = ['department', 'phone_number']

class UpdateProfileSerializer(serializers.Serializer):
    """Serializer pour mettre à jour le profil utilisateur"""
    first_name = serializers.CharField(max_length=30, required=False)
    last_name = serializers.CharField(max_length=30, required=False)
    email = serializers.EmailField(required=False)
    
    # Champs spécifiques aux étudiants
    phone_number = serializers.CharField(max_length=15, required=False)
    level = serializers.PrimaryKeyRelatedField(queryset=Level.objects.filter(is_active=True), required=False)
    major = serializers.PrimaryKeyRelatedField(queryset=Major.objects.filter(is_active=True), required=False)
    
    # Champs spécifiques aux admins
    department = serializers.CharField(max_length=100, required=False)
    
    def validate_email(self, value):
        user = self.context['request'].user
        if User.objects.filter(email=value).exclude(id=user.id).exists():
            raise serializers.ValidationError("Cet email est déjà utilisé.")
        return value
    
    def validate_phone_number(self, value):
        user = self.context['request'].user
        if hasattr(user, 'student_profile'):
            if StudentProfile.objects.filter(phone_number=value).exclude(user=user).exists():
                raise serializers.ValidationError("Ce numéro de téléphone est déjà utilisé.")
        return value
    
    # Dans votre serializers.py, remplacez la méthode update de UpdateProfileSerializer :

def update(self, instance, validated_data):
    # Mettre à jour les champs de l'utilisateur
    user_fields = ['first_name', 'last_name', 'email']
    for field in user_fields:
        if field in validated_data:
            setattr(instance, field, validated_data[field])
    instance.save()
    
    # Mettre à jour le profil spécifique
    if instance.is_student() and hasattr(instance, 'student_profile'):
        profile = instance.student_profile
        student_fields = ['phone_number', 'level', 'major']
        for field in student_fields:  # Corrigé : était student_fields au lieu de field
            if field in validated_data:
                setattr(profile, field, validated_data[field])
        profile.save()
    
    elif instance.is_admin() and hasattr(instance, 'admin_profile'):
        profile = instance.admin_profile
        admin_fields = ['department', 'phone_number']
        for field in admin_fields:  # Corrigé : était student_fields au lieu de admin_fields
            if field in validated_data:
                setattr(profile, field, validated_data[field])
        profile.save()
    
    return instance

class TeacherAssignmentSerializer(serializers.ModelSerializer):
    """Serializer pour les assignations professeur-matière"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    
    class Meta:
        model = TeacherAssignment
        fields = [
            'id',
            'subject',
            'subject_name',
            'subject_code',
            'can_edit_content',
            'can_upload_documents',
            'can_delete_documents',
            'can_manage_students',
            'is_active',
            'assigned_date',
            'notes'
        ]
        read_only_fields = ['id', 'assigned_date']


class TeacherProfileDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé pour le profil professeur"""
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)
    full_name = serializers.CharField(source='user.get_full_name', read_only=True)
    first_name = serializers.CharField(source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    is_active = serializers.BooleanField(source='user.is_active', read_only=True)
    assignments = TeacherAssignmentSerializer(source='user.teacher_assignments', many=True, read_only=True)
    total_subjects = serializers.SerializerMethodField()
    
    class Meta:
        model = TeacherProfile
        fields = [
            'id',
            'user_id',
            'username',
            'email',
            'full_name',
            'first_name',
            'last_name',
            'phone_number',
            'specialization',
            'bio',
            'office',
            'office_hours',
            'is_active',
            'assignments',
            'total_subjects',
            'created_at',
            'updated_at'
        ]
    
    def get_total_subjects(self, obj):
        """Nombre de matières assignées"""
        return TeacherAssignment.objects.filter(
            teacher=obj.user,
            is_active=True
        ).count()


class TeacherCreateSerializer(serializers.Serializer):
    """Serializer pour créer un professeur avec assignations"""
    # Informations utilisateur
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(min_length=8, write_only=True)
    first_name = serializers.CharField(max_length=30)
    last_name = serializers.CharField(max_length=30)
    
    # Informations profil professeur
    phone_number = serializers.CharField(max_length=15, required=False, allow_blank=True)
    specialization = serializers.CharField(max_length=200, required=False, allow_blank=True)
    bio = serializers.CharField(required=False, allow_blank=True)
    office = serializers.CharField(max_length=50, required=False, allow_blank=True)
    office_hours = serializers.CharField(max_length=200, required=False, allow_blank=True)
    
    # Assignations de matières (liste d'objets)
    subject_assignments = serializers.ListField(
        child=serializers.DictField(),
        required=False,
        allow_empty=True,
        help_text="Liste des matières à assigner avec permissions"
    )
    
    def validate_username(self, value):
        """Vérifier l'unicité du nom d'utilisateur"""
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur existe déjà.")
        return value
    
    def validate_email(self, value):
        """Vérifier l'unicité de l'email"""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Cet email existe déjà.")
        return value
    
    def validate_subject_assignments(self, value):
        """
        Valider les assignations de matières
        Format attendu :
        [
            {
                "subject_id": 1,
                "can_edit_content": false,
                "can_upload_documents": true,
                "can_delete_documents": false,
                "can_manage_students": true,
                "notes": "Cours principal"
            }
        ]
        """
        for assignment in value:
            if 'subject_id' not in assignment:
                raise serializers.ValidationError(
                    "Chaque assignation doit contenir 'subject_id'"
                )
            
            # Vérifier que la matière existe
            try:
                Subject.objects.get(id=assignment['subject_id'], is_active=True)
            except Subject.DoesNotExist:
                raise serializers.ValidationError(
                    f"Matière avec ID {assignment['subject_id']} non trouvée"
                )
        
        return value
    
    def create(self, validated_data):
        """Créer le professeur avec ses assignations"""
        from django.db import transaction
        
        # Extraire les assignations
        subject_assignments = validated_data.pop('subject_assignments', [])
        
        # Extraire les données du profil
        phone_number = validated_data.pop('phone_number', '')
        specialization = validated_data.pop('specialization', '')
        bio = validated_data.pop('bio', '')
        office = validated_data.pop('office', '')
        office_hours = validated_data.pop('office_hours', '')
        
        # Extraire le mot de passe
        password = validated_data.pop('password')
        
        with transaction.atomic():
            # ✅ CORRECTION : Créer l'utilisateur professeur
            user = User.objects.create(
                username=validated_data['username'],
                email=validated_data['email'],
                first_name=validated_data['first_name'],
                last_name=validated_data['last_name'],
                role='TEACHER',
                is_active=True
            )
            # Définir le mot de passe de manière sécurisée
            user.set_password(password)
            user.save()
            
            # ✅ CORRECTION : Utiliser get_or_create pour éviter les doublons
            teacher_profile, created = TeacherProfile.objects.get_or_create(
                user=user,
                defaults={
                    'phone_number': phone_number,
                    'specialization': specialization,
                    'bio': bio,
                    'office': office,
                    'office_hours': office_hours
                }
            )
            
            # Si le profil existait déjà, le mettre à jour
            if not created:
                teacher_profile.phone_number = phone_number
                teacher_profile.specialization = specialization
                teacher_profile.bio = bio
                teacher_profile.office = office
                teacher_profile.office_hours = office_hours
                teacher_profile.save()
            
            # ✅ Créer les assignations de matières
            assigned_by = None
            if self.context.get('request'):
                assigned_by = self.context['request'].user
            
            for assignment_data in subject_assignments:
                subject = Subject.objects.get(id=assignment_data['subject_id'])
                
                # ✅ CORRECTION : Utiliser get_or_create pour éviter les doublons
                TeacherAssignment.objects.get_or_create(
                    teacher=user,
                    subject=subject,
                    defaults={
                        'can_edit_content': assignment_data.get('can_edit_content', False),
                        'can_upload_documents': assignment_data.get('can_upload_documents', True),
                        'can_delete_documents': assignment_data.get('can_delete_documents', False),
                        'can_manage_students': assignment_data.get('can_manage_students', True),
                        'notes': assignment_data.get('notes', ''),
                        'assigned_by': assigned_by,
                        'is_active': True
                    }
                )
            
            logger.info(f"✅ Professeur créé: {user.username} avec {len(subject_assignments)} assignation(s)")
            
            return {
                'user': user,
                'teacher_profile': teacher_profile
            }

class TeacherUpdateSerializer(serializers.Serializer):
    """Serializer pour mettre à jour un professeur"""
    # Informations utilisateur
    first_name = serializers.CharField(max_length=30, required=False)
    last_name = serializers.CharField(max_length=30, required=False)
    email = serializers.EmailField(required=False)
    is_active = serializers.BooleanField(required=False)
    
    # Informations profil professeur
    phone_number = serializers.CharField(max_length=15, required=False)
    specialization = serializers.CharField(max_length=200, required=False)
    bio = serializers.CharField(required=False)
    office = serializers.CharField(max_length=50, required=False)
    office_hours = serializers.CharField(max_length=200, required=False)
    
    def validate_email(self, value):
        user_id = self.context.get('user_id')
        if User.objects.filter(email=value).exclude(id=user_id).exists():
            raise serializers.ValidationError("Cet email est déjà utilisé.")
        return value
    
    def update(self, instance, validated_data):
        """Mettre à jour l'utilisateur et son profil"""
        user = instance
        
        # Mettre à jour l'utilisateur
        user_fields = ['first_name', 'last_name', 'email', 'is_active']
        for field in user_fields:
            if field in validated_data:
                setattr(user, field, validated_data[field])
        user.save()
        
        # Mettre à jour le profil professeur
        if hasattr(user, 'teacher_profile'):
            profile = user.teacher_profile
            profile_fields = ['phone_number', 'specialization', 'bio', 'office', 'office_hours']
            
            for field in profile_fields:
                if field in validated_data:
                    setattr(profile, field, validated_data[field])
            profile.save()
        
        return user


# ========================================
# SERIALIZERS POUR LE DASHBOARD ADMIN
# ========================================

class DashboardStatsSerializer(serializers.Serializer):
    """Serializer pour les statistiques globales du dashboard"""
    
    # Statistiques utilisateurs
    total_users = serializers.IntegerField()
    total_students = serializers.IntegerField()
    total_teachers = serializers.IntegerField()
    total_admins = serializers.IntegerField()
    active_students = serializers.IntegerField()
    active_teachers = serializers.IntegerField()
    
    # Statistiques académiques
    total_subjects = serializers.IntegerField()
    active_subjects = serializers.IntegerField()
    total_levels = serializers.IntegerField()
    total_majors = serializers.IntegerField()
    
    # Statistiques contenus
    total_documents = serializers.IntegerField()
    total_quizzes = serializers.IntegerField()
    active_quizzes = serializers.IntegerField()
    
    # Activité récente (30 derniers jours)
    new_students_30d = serializers.IntegerField()
    new_documents_30d = serializers.IntegerField()
    new_quizzes_30d = serializers.IntegerField()
    total_views_30d = serializers.IntegerField()
    total_downloads_30d = serializers.IntegerField()
    quiz_attempts_30d = serializers.IntegerField()


class StudentsByMajorSerializer(serializers.Serializer):
    """Répartition des étudiants par filière"""
    major_id = serializers.IntegerField()
    major_name = serializers.CharField()
    major_code = serializers.CharField()
    student_count = serializers.IntegerField()
    percentage = serializers.FloatField()


class StudentsByLevelSerializer(serializers.Serializer):
    """Répartition des étudiants par niveau"""
    level_id = serializers.IntegerField()
    level_name = serializers.CharField()
    level_code = serializers.CharField()
    student_count = serializers.IntegerField()
    percentage = serializers.FloatField()


class ActivityTimelineSerializer(serializers.Serializer):
    """Activité sur une période"""
    date = serializers.DateField()
    new_students = serializers.IntegerField()
    new_documents = serializers.IntegerField()
    views = serializers.IntegerField()
    downloads = serializers.IntegerField()
    quiz_attempts = serializers.IntegerField()


class TopSubjectSerializer(serializers.Serializer):
    """Top matières par activité"""
    subject_id = serializers.IntegerField()
    subject_name = serializers.CharField()
    subject_code = serializers.CharField()
    document_count = serializers.IntegerField()
    view_count = serializers.IntegerField()
    download_count = serializers.IntegerField()


class TopDocumentSerializer(serializers.Serializer):
    """Top documents les plus consultés"""
    document_id = serializers.IntegerField()
    document_title = serializers.CharField()
    subject_name = serializers.CharField()
    document_type = serializers.CharField()
    view_count = serializers.IntegerField()
    download_count = serializers.IntegerField()


class QuizPerformanceSerializer(serializers.Serializer):
    """Performance globale des quiz"""
    total_attempts = serializers.IntegerField()
    completed_attempts = serializers.IntegerField()
    average_score = serializers.FloatField()
    pass_rate = serializers.FloatField()
    
    # Quiz les plus difficiles
    hardest_quizzes = serializers.ListField()
    # Quiz les plus faciles
    easiest_quizzes = serializers.ListField()


class RecentActivitySerializer(serializers.Serializer):
    """Activités récentes"""
    activity_type = serializers.CharField()  # 'new_student', 'new_document', 'new_quiz', etc.
    title = serializers.CharField()
    description = serializers.CharField()
    user_name = serializers.CharField(required=False)
    subject_name = serializers.CharField(required=False)
    created_at = serializers.DateTimeField()
    icon = serializers.CharField()
    color = serializers.CharField()


class SystemHealthSerializer(serializers.Serializer):
    """État de santé du système"""
    status = serializers.CharField()  # 'healthy', 'warning', 'critical'
    total_storage_mb = serializers.FloatField()
    active_users_today = serializers.IntegerField()
    pending_assignments = serializers.IntegerField()
    inactive_teachers = serializers.IntegerField()
    subjects_without_content = serializers.IntegerField()
    students_without_activity = serializers.IntegerField()


class AdminDashboardSerializer(serializers.Serializer):
    """Serializer complet pour le dashboard admin"""
    stats = DashboardStatsSerializer()
    students_by_major = StudentsByMajorSerializer(many=True)
    students_by_level = StudentsByLevelSerializer(many=True)
    activity_timeline = ActivityTimelineSerializer(many=True)
    top_subjects = TopSubjectSerializer(many=True)
    top_documents = TopDocumentSerializer(many=True)
    quiz_performance = QuizPerformanceSerializer()
    recent_activities = RecentActivitySerializer(many=True)
    system_health = SystemHealthSerializer()

# ========================================
# SERIALIZERS POUR LA GESTION ADMIN DES ÉTUDIANTS
# ========================================

class StudentCreateSerializer(serializers.ModelSerializer):
    """
    Serializer pour créer un étudiant via l'admin
    POST /api/auth/admin/students/
    """
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    
    # Champs du profil StudentProfile
    level = serializers.PrimaryKeyRelatedField(
        queryset=Level.objects.all(),
        required=True
    )
    major = serializers.PrimaryKeyRelatedField(
        queryset=Major.objects.all(),
        required=True
    )
    phone_number = serializers.CharField(
        max_length=15,
        required=True  # ✅ OBLIGATOIRE car unique dans le modèle
    )
    
    class Meta:
        model = User
        fields = [
            'username', 'email', 'password',
            'first_name', 'last_name',
            'level', 'major', 'phone_number'
        ]
    
    def validate_username(self, value):
        """Vérifier l'unicité du nom d'utilisateur"""
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Ce nom d'utilisateur existe déjà.")
        return value
    
    def validate_email(self, value):
        """Vérifier l'unicité de l'email"""
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError("Cet email est déjà utilisé.")
        return value
    
    def validate_phone_number(self, value):
        """Vérifier l'unicité du téléphone"""
        if StudentProfile.objects.filter(phone_number=value).exists():
            raise serializers.ValidationError("Ce numéro de téléphone est déjà utilisé.")
        return value
    
    def create(self, validated_data):
        """Créer l'utilisateur et son profil étudiant"""
        # Extraire les champs du profil
        level = validated_data.pop('level')
        major = validated_data.pop('major')
        phone_number = validated_data.pop('phone_number')
        
        # Extraire le mot de passe
        password = validated_data.pop('password')
        
        # Créer l'utilisateur
        user = User.objects.create(
            **validated_data,
            role='STUDENT',
            is_active=True
        )
        user.set_password(password)
        user.save()
        
        # Créer le profil étudiant
        StudentProfile.objects.create(
            user=user,
            phone_number=phone_number,
            level=level,
            major=major,
            is_verified=True  # Créé par admin = automatiquement vérifié
        )
        
        logger.info(f"✅ Étudiant créé par admin: {user.username}")
        return user


class StudentUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour modifier un étudiant"""
    
    # Champs du User
    first_name = serializers.CharField(max_length=150, required=False)
    last_name = serializers.CharField(max_length=150, required=False)
    email = serializers.EmailField(required=False)
    is_active = serializers.BooleanField(required=False)
    
    # Champs du StudentProfile (SEULEMENT ceux qui existent)
    level = serializers.PrimaryKeyRelatedField(
        queryset=Level.objects.filter(is_active=True),
        required=False
    )
    major = serializers.PrimaryKeyRelatedField(
        queryset=Major.objects.filter(is_active=True),
        required=False
    )
    phone_number = serializers.CharField(max_length=15, required=False)
    
    class Meta:
        model = User
        fields = [
            'first_name', 'last_name', 'email', 'is_active',
            'level', 'major', 'phone_number'
        ]
    
    def validate_email(self, value):
        """Vérifier l'unicité de l'email (sauf pour l'utilisateur actuel)"""
        instance = self.instance
        if User.objects.filter(email=value).exclude(id=instance.id).exists():
            raise serializers.ValidationError("Cet email est déjà utilisé.")
        return value
    
    def validate_phone_number(self, value):
        """Vérifier l'unicité du téléphone"""
        instance = self.instance
        if StudentProfile.objects.filter(phone_number=value).exclude(user=instance).exists():
            raise serializers.ValidationError("Ce numéro de téléphone est déjà utilisé.")
        return value
    
    def update(self, instance, validated_data):
        """Mettre à jour l'utilisateur et son profil"""
        # Extraire les champs du profil
        profile_fields = ['level', 'major', 'phone_number']
        
        profile_data = {}
        for field in profile_fields:
            if field in validated_data:
                profile_data[field] = validated_data.pop(field)
        
        # Mettre à jour l'utilisateur
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Mettre à jour le profil
        if profile_data:
            profile = instance.student_profile
            for attr, value in profile_data.items():
                setattr(profile, attr, value)
            profile.save()
        
        return instance


class StudentAdminListSerializer(serializers.ModelSerializer):
    """Serializer simple pour la liste des étudiants (Admin)"""
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    level_name = serializers.CharField(source='student_profile.level.name', read_only=True)
    major_name = serializers.CharField(source='student_profile.major.name', read_only=True)
    phone_number = serializers.CharField(source='student_profile.phone_number', read_only=True)
    
    # ✅ IDs pour pré-remplir les formulaires
    level_id = serializers.SerializerMethodField()
    major_id = serializers.SerializerMethodField()
    
    # Statistiques
    total_documents_viewed = serializers.SerializerMethodField()
    total_quiz_attempts = serializers.SerializerMethodField()
    last_activity = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'full_name',
            'first_name',
            'last_name',
            'level_name',
            'major_name',
            'level_id',
            'major_id',
            'phone_number',  # ✅ Plus de student_id
            'is_active',
            'date_joined',
            'total_documents_viewed',
            'total_quiz_attempts',
            'last_activity'
        ]
    
    def get_level_id(self, obj):
        """Récupérer l'ID du niveau de manière sécurisée"""
        try:
            if hasattr(obj, 'student_profile') and obj.student_profile.level:
                return obj.student_profile.level.id
        except Exception as e:
            logger.error(f"❌ Erreur get_level_id: {str(e)}")
        return None
    
    def get_major_id(self, obj):
        """Récupérer l'ID de la filière de manière sécurisée"""
        try:
            if hasattr(obj, 'student_profile') and obj.student_profile.major:
                return obj.student_profile.major.id
        except Exception as e:
            logger.error(f"❌ Erreur get_major_id: {str(e)}")
        return None
    
    def get_total_documents_viewed(self, obj):
        """Nombre de documents consultés"""
        from courses.models import UserActivity
        return UserActivity.objects.filter(
            user=obj,
            action='view'
        ).count()
    
    def get_total_quiz_attempts(self, obj):
        """Nombre de tentatives de quiz"""
        from courses.models import QuizAttempt
        return QuizAttempt.objects.filter(user=obj).count()
    
    def get_last_activity(self, obj):
        """Dernière activité"""
        from courses.models import UserActivity
        last = UserActivity.objects.filter(user=obj).order_by('-created_at').first()
        return last.created_at if last else None


class StudentAdminDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé pour un étudiant (Admin)"""
    full_name = serializers.CharField(source='get_full_name', read_only=True)
    
    # Profil - Objets complets
    level = LevelSerializer(source='student_profile.level', read_only=True)
    major = MajorSerializer(source='student_profile.major', read_only=True)
    
    # ✅ CORRECTION : Gérer les cas où level ou major sont None
    level_id = serializers.SerializerMethodField()
    major_id = serializers.SerializerMethodField()
    
    phone_number = serializers.CharField(source='student_profile.phone_number', read_only=True)
    is_verified = serializers.BooleanField(source='student_profile.is_verified', read_only=True)
    
    # Statistiques détaillées
    statistics = serializers.SerializerMethodField()
    recent_activities = serializers.SerializerMethodField()
    quiz_performance = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'full_name', 'first_name', 'last_name',
            'is_active', 'date_joined', 'last_login',
            'level', 'major', 'level_id', 'major_id',
            'phone_number', 'is_verified',
            'statistics', 'recent_activities', 'quiz_performance'
        ]
    
    def get_level_id(self, obj):
        """Récupérer l'ID du niveau de manière sécurisée"""
        try:
            if hasattr(obj, 'student_profile') and obj.student_profile.level:
                return obj.student_profile.level.id
        except Exception as e:
            logger.error(f"❌ Erreur get_level_id: {str(e)}")
        return None
    
    def get_major_id(self, obj):
        """Récupérer l'ID de la filière de manière sécurisée"""
        try:
            if hasattr(obj, 'student_profile') and obj.student_profile.major:
                return obj.student_profile.major.id
        except Exception as e:
            logger.error(f"❌ Erreur get_major_id: {str(e)}")
        return None
    
    def get_statistics(self, obj):
        """Statistiques globales de l'étudiant"""
        from courses.models import UserActivity, QuizAttempt, UserFavorite
        
        try:
            # Documents
            total_views = UserActivity.objects.filter(user=obj, action='view').count()
            total_downloads = UserActivity.objects.filter(user=obj, action='download').count()
            total_favorites = UserFavorite.objects.filter(user=obj).count()
            
            # Quiz
            quiz_attempts = QuizAttempt.objects.filter(user=obj)
            total_attempts = quiz_attempts.count()
            completed_attempts = quiz_attempts.filter(status='COMPLETED')
            completed_count = completed_attempts.count()
            
            # Score moyen et taux de réussite
            avg_score = 0
            passed = 0
            
            if completed_count > 0:
                scores = []
                for attempt in completed_attempts.select_related('quiz'):
                    total_points = attempt.quiz.total_points
                    if total_points and total_points > 0:
                        normalized = (float(attempt.score) / float(total_points)) * 20
                        scores.append(normalized)
                        
                        percentage = (float(attempt.score) / float(total_points)) * 100
                        if percentage >= float(attempt.quiz.passing_percentage):
                            passed += 1
                
                if scores:
                    avg_score = round(sum(scores) / len(scores), 2)
            
            pass_rate = round((passed / completed_count) * 100, 1) if completed_count > 0 else 0
            
            return {
                'total_views': total_views,
                'total_downloads': total_downloads,
                'total_favorites': total_favorites,
                'total_quiz_attempts': total_attempts,
                'completed_quiz_attempts': completed_count,
                'average_quiz_score': avg_score,
                'quiz_pass_rate': pass_rate
            }
            
        except Exception as e:
            logger.error(f"❌ Erreur get_statistics: {str(e)}")
            return {
                'total_views': 0, 'total_downloads': 0, 'total_favorites': 0,
                'total_quiz_attempts': 0, 'completed_quiz_attempts': 0,
                'average_quiz_score': 0, 'quiz_pass_rate': 0
            }
    
    def get_recent_activities(self, obj):
        """Activités récentes de l'étudiant"""
        from courses.models import UserActivity
        
        try:
            activities = UserActivity.objects.filter(
                user=obj
            ).select_related('document', 'subject').order_by('-created_at')[:10]
            
            return [{
                'id': a.id,
                'action': a.action,
                'document_title': a.document.title if a.document else None,
                'subject_name': a.subject.name if a.subject else None,
                'created_at': a.created_at
            } for a in activities]
            
        except Exception as e:
            logger.error(f"❌ Erreur get_recent_activities: {str(e)}")
            return []
    
    def get_quiz_performance(self, obj):
        """Performance aux quiz par matière"""
        from courses.models import QuizAttempt, Subject
        
        try:
            if not hasattr(obj, 'student_profile'):
                return []
            
            profile = obj.student_profile
            if not profile.level or not profile.major:
                return []
            
            subjects = Subject.objects.filter(
                levels=profile.level,
                majors=profile.major
            ).distinct()
            
            performance = []
            
            for subject in subjects:
                attempts = QuizAttempt.objects.filter(
                    user=obj,
                    quiz__subject=subject
                ).select_related('quiz')
                
                total = attempts.count()
                if total == 0:
                    continue
                
                completed = attempts.filter(status='COMPLETED')
                completed_count = completed.count()
                
                if completed_count == 0:
                    performance.append({
                        'subject_id': subject.id,
                        'subject_name': subject.name,
                        'subject_code': subject.code,
                        'total_attempts': total,
                        'completed_attempts': 0,
                        'average_score': 0,
                        'pass_rate': 0
                    })
                    continue
                
                scores = []
                passed = 0
                
                for attempt in completed:
                    total_points = attempt.quiz.total_points
                    if total_points and total_points > 0:
                        normalized = (float(attempt.score) / float(total_points)) * 20
                        scores.append(normalized)
                        
                        percentage = (float(attempt.score) / float(total_points)) * 100
                        if percentage >= float(attempt.quiz.passing_percentage):
                            passed += 1
                
                avg_score = round(sum(scores) / len(scores), 2) if scores else 0
                pass_rate = round((passed / completed_count) * 100, 1)
                
                performance.append({
                    'subject_id': subject.id,
                    'subject_name': subject.name,
                    'subject_code': subject.code,
                    'total_attempts': total,
                    'completed_attempts': completed_count,
                    'average_score': avg_score,
                    'pass_rate': pass_rate
                })
            
            return performance
            
        except Exception as e:
            logger.error(f"❌ Erreur get_quiz_performance: {str(e)}")
            return []

class StudentStatisticsSerializer(serializers.Serializer):
    """Statistiques détaillées d'un étudiant"""
    student_id = serializers.IntegerField()
    student_name = serializers.CharField()
    student_email = serializers.EmailField()
    
    # Activité
    total_views = serializers.IntegerField()
    total_downloads = serializers.IntegerField()
    total_favorites = serializers.IntegerField()
    last_activity = serializers.DateTimeField()
    
    # Quiz
    total_quiz_attempts = serializers.IntegerField()
    completed_quiz_attempts = serializers.IntegerField()
    average_quiz_score = serializers.FloatField()
    quiz_pass_rate = serializers.FloatField()
    
    # Par matière
    performance_by_subject = serializers.ListField()


class BulkStudentActionSerializer(serializers.Serializer):
    """Serializer pour les actions en masse sur les étudiants"""
    student_ids = serializers.ListField(
        child=serializers.IntegerField(),
        min_length=1
    )
    action = serializers.ChoiceField(choices=[
        'activate',
        'deactivate',
        'delete',
        'change_level',
        'change_major'
    ])
    
    # Champs optionnels selon l'action
    new_level = serializers.PrimaryKeyRelatedField(
        queryset=Level.objects.all(),
        required=False
    )
    new_major = serializers.PrimaryKeyRelatedField(
        queryset=Major.objects.all(),
        required=False
    )
    
    def validate(self, data):
        """Validation selon l'action"""
        action = data.get('action')
        
        if action == 'change_level' and 'new_level' not in data:
            raise serializers.ValidationError({
                'new_level': 'Le nouveau niveau est requis pour cette action'
            })
        
        if action == 'change_major' and 'new_major' not in data:
            raise serializers.ValidationError({
                'new_major': 'La nouvelle filière est requise pour cette action'
            })
        
        return data

# ========================================
# PROFILE SERIALIZERS - WEB (Admin/Teacher)
# ========================================

class WebUserProfileSerializer(serializers.ModelSerializer):
    """
    Serializer User pour interface WEB uniquement
    Différent de UserProfileSerializer qui est utilisé par le mobile
    """
    role_display = serializers.CharField(source='get_role_display', read_only=True)
    
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'role_display', 'date_joined'
        ]
        read_only_fields = ['id', 'username', 'email', 'role', 'date_joined']


class WebAdminProfileDetailSerializer(serializers.ModelSerializer):
    """
    Profil admin détaillé pour interface WEB
    Différent de AdminProfileSerializer qui est simple (mobile)
    """
    user = WebUserProfileSerializer(read_only=True)
    
    class Meta:
        model = AdminProfile
        fields = ['user', 'department', 'phone_number', 'created_at', 'updated_at']


class WebTeacherProfileDetailSerializer(serializers.ModelSerializer):
    """
    Profil teacher détaillé pour interface WEB
    Spécifique aux professeurs
    """
    user = WebUserProfileSerializer(read_only=True)
    assigned_subjects_count = serializers.SerializerMethodField()
    
    class Meta:
        model = TeacherProfile
        fields = [
            'user', 'phone_number', 'specialization', 'bio', 
            'office', 'office_hours', 'assigned_subjects_count',
            'created_at', 'updated_at'
        ]
    
    def get_assigned_subjects_count(self, obj):
        """Nombre de matières assignées au professeur"""
        return TeacherAssignment.objects.filter(
            teacher=obj.user, 
            is_active=True
        ).count()


class WebUpdateProfileSerializer(serializers.Serializer):
    """
    Mise à jour profil pour interface WEB (Admin/Teacher uniquement)
    Différent de UpdateProfileSerializer qui gère aussi les étudiants
    """
    # Champs User (communs)
    first_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    last_name = serializers.CharField(max_length=150, required=False, allow_blank=True)
    phone_number = serializers.CharField(max_length=15, required=False, allow_blank=True)
    
    # Champs Admin
    department = serializers.CharField(max_length=100, required=False, allow_blank=True)
    
    # Champs Teacher
    specialization = serializers.CharField(max_length=200, required=False, allow_blank=True)
    bio = serializers.CharField(required=False, allow_blank=True)
    office = serializers.CharField(max_length=50, required=False, allow_blank=True)
    office_hours = serializers.CharField(max_length=200, required=False, allow_blank=True)


class WebChangePasswordSerializer(serializers.Serializer):
    """
    Changement de mot de passe pour interface WEB (Admin/Teacher)
    Utilise old_password au lieu de current_password
    """
    old_password = serializers.CharField(required=True, write_only=True)
    new_password = serializers.CharField(required=True, min_length=8, write_only=True)
    confirm_password = serializers.CharField(required=True, write_only=True)
    
    def validate(self, data):
        if data['new_password'] != data['confirm_password']:
            raise serializers.ValidationError({
                'confirm_password': 'Les mots de passe ne correspondent pas'
            })
        return data
    
    def validate_new_password(self, value):
        if len(value) < 8:
            raise serializers.ValidationError(
                'Le mot de passe doit contenir au moins 8 caractères'
            )
        return value