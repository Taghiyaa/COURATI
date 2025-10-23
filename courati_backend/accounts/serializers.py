from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from django.contrib.auth import get_user_model, authenticate
from django.utils.translation import gettext_lazy as _
from .models import StudentProfile, AdminProfile, Level, Major

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