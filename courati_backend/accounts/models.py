# accounts/models.py
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils.translation import gettext_lazy as _
from django.db.models.signals import pre_save
from django.dispatch import receiver

class UserManager(BaseUserManager):
    def create_user(self, username, email, password=None, **extra_fields):
        if not email:
            raise ValueError('The Email field must be set')
        email = self.normalize_email(email)
        user = self.model(username=username, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'ADMIN')
        return self.create_user(username, email, password, **extra_fields)

class User(AbstractUser):
    ROLE_CHOICES = [
        ('ADMIN', 'Administrateur'),
        ('STUDENT', 'Étudiant'),
        ('TEACHER', 'Professeur'),  # NOUVEAU
    ]
    
    email = models.EmailField(_('email address'), unique=True)
    role = models.CharField(_('rôle'), max_length=10, choices=ROLE_CHOICES, default='STUDENT')
    
    objects = UserManager()
    
    USERNAME_FIELD = 'username'
    EMAIL_FIELD = 'email'
    REQUIRED_FIELDS = ['email']
    
    def is_admin(self):
        return self.role == 'ADMIN'
    
    def is_student(self):
        return self.role == 'STUDENT'
    
    def is_teacher(self):  # NOUVEAU
        return self.role == 'TEACHER'
    
    def get_full_name(self):
        full_name = f'{self.first_name} {self.last_name}'
        return full_name.strip() or self.username
    
    class Meta:
        swappable = 'AUTH_USER_MODEL'

class Level(models.Model):
    code = models.CharField(_('code'), max_length=10, unique=True)
    name = models.CharField(_('nom'), max_length=50)
    description = models.TextField(_('description'), blank=True)
    order = models.PositiveIntegerField(_('ordre'), default=0)
    is_active = models.BooleanField(_('actif'), default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, 
                                  related_name='created_levels')
    
    class Meta:
        verbose_name = _('niveau')
        verbose_name_plural = _('niveaux')
        ordering = ['order', 'code']
    
    def __str__(self):
        return f"{self.code} - {self.name}"

class Major(models.Model):
    code = models.CharField(_('code'), max_length=10, unique=True)
    name = models.CharField(_('nom'), max_length=100)
    description = models.TextField(_('description'), blank=True)
    department = models.CharField(_('département'), max_length=100, blank=True)
    order = models.PositiveIntegerField(_('ordre'), default=0)
    is_active = models.BooleanField(_('actif'), default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True,
                                  related_name='created_majors')
    
    class Meta:
        verbose_name = _('filière')
        verbose_name_plural = _('filières')
        ordering = ['order', 'name']
    
    def __str__(self):
        return f"{self.code} - {self.name}"

class StudentProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='student_profile')
    phone_number = models.CharField(_('numéro de téléphone'), max_length=15, unique=True)
    level = models.ForeignKey(Level, on_delete=models.PROTECT, 
                         verbose_name=_('niveau'), null=True, blank=True)
    major = models.ForeignKey(Major, on_delete=models.PROTECT,
                         verbose_name=_('filière'), null=True, blank=True)
    is_verified = models.BooleanField(_('vérifié'), default=False)
    otp = models.CharField(max_length=6, null=True, blank=True)
    otp_expiry = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def level_display(self):
        return self.level.name if self.level else "Non défini"
    
    @property
    def major_display(self):
        return self.major.name if self.major else "Non définie"

    def __str__(self):
        return f"{self.user.get_full_name()} ({self.phone_number})"

    class Meta:
        verbose_name = _('profil étudiant')
        verbose_name_plural = _('profils étudiants')

class AdminProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='admin_profile')
    department = models.CharField(_('département'), max_length=100, blank=True)
    phone_number = models.CharField(_('numéro de téléphone'), max_length=15, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"Admin: {self.user.get_full_name()}"
    
    class Meta:
        verbose_name = _('profil administrateur')
        verbose_name_plural = _('profils administrateurs')

# ========================================
# NOUVEAUX MODÈLES POUR LES PROFESSEURS
# ========================================

class TeacherProfile(models.Model):
    """Profil pour les professeurs"""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='teacher_profile')
    phone_number = models.CharField(_('numéro de téléphone'), max_length=15, blank=True)
    specialization = models.CharField(_('spécialisation'), max_length=200, blank=True,
                                    help_text="Ex: Intelligence Artificielle, Algèbre, etc.")
    bio = models.TextField(_('biographie'), blank=True,
                          help_text="Courte présentation du professeur")
    office = models.CharField(_('bureau'), max_length=50, blank=True,
                            help_text="Numéro de bureau")
    office_hours = models.CharField(_('heures de permanence'), max_length=200, blank=True,
                                   help_text="Ex: Lundi 14h-16h, Mercredi 10h-12h")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"Prof: {self.user.get_full_name()}"
    
    class Meta:
        verbose_name = _('profil professeur')
        verbose_name_plural = _('profils professeurs')

class TeacherAssignment(models.Model):
    """Assignation d'un professeur à une matière avec permissions"""
    teacher = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        limit_choices_to={'role': 'TEACHER'},
        related_name='teacher_assignments',
        verbose_name=_('professeur')
    )
    subject = models.ForeignKey(
        'courses.Subject',  # Relation vers Subject
        on_delete=models.CASCADE,
        related_name='teacher_assignments',
        verbose_name=_('matière')
    )
    
    # Permissions granulaires
    can_edit_content = models.BooleanField(
        _('peut modifier le contenu'),
        default=False,
        help_text="Peut modifier les informations de la matière"
    )
    can_upload_documents = models.BooleanField(
        _('peut uploader des documents'),
        default=True,
        help_text="Peut ajouter des documents (PDF, etc.)"
    )
    can_delete_documents = models.BooleanField(
        _('peut supprimer des documents'),
        default=False,
        help_text="Peut supprimer des documents"
    )
    can_manage_students = models.BooleanField(
        _('peut gérer les étudiants'),
        default=True,
        help_text="Peut voir la liste et progression des étudiants"
    )
    
    # Métadonnées
    assigned_date = models.DateTimeField(_('date d\'assignation'), auto_now_add=True)
    assigned_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_teachers',
        verbose_name=_('assigné par')
    )
    notes = models.TextField(_('notes'), blank=True,
                            help_text="Notes internes sur cette assignation")
    is_active = models.BooleanField(_('actif'), default=True)
    
    class Meta:
        verbose_name = _('assignation professeur')
        verbose_name_plural = _('assignations professeurs')
        unique_together = ['teacher', 'subject']
        ordering = ['-assigned_date']
    
    def __str__(self):
        return f"{self.teacher.get_full_name()} → {self.subject.name}"
    
    def save(self, *args, **kwargs):
        # Vérifier que l'utilisateur est bien un professeur
        if self.teacher.role != 'TEACHER':
            raise ValueError("L'utilisateur doit avoir le rôle TEACHER")
        super().save(*args, **kwargs)



@receiver(pre_save, sender=StudentProfile)
def handle_major_change(sender, instance, **kwargs):
    """
    Gère le changement de filière d'un étudiant
    - Conservation des QuizAttempt (isolation par filière dans l'API)
    - Suppression des favoris non pertinents
    """
    if not instance.pk:
        return
        
    try:
        old_profile = StudentProfile.objects.get(pk=instance.pk)
        
        # Vérifier si la filière a réellement changé
        if old_profile.major != instance.major:
            from courses.models import UserFavorite, Subject
            
            # Récupérer les matières de chaque filière
            old_subjects = Subject.objects.filter(
                majors=old_profile.major,
                is_active=True
            )
            new_subjects = Subject.objects.filter(
                majors=instance.major,
                is_active=True
            )
            
            # Identifier les matières qui ne sont plus pertinentes
            removed_subject_ids = old_subjects.exclude(
                id__in=new_subjects.values_list('id', flat=True)
            ).values_list('id', flat=True)
            
            if removed_subject_ids:
                # Supprimer les favoris documents
                deleted_docs = UserFavorite.objects.filter(
                    user=instance.user,
                    document__subject_id__in=removed_subject_ids,
                    favorite_type='DOCUMENT'
                ).delete()[0]
                
                # Supprimer les favoris matières
                deleted_subjects_fav = UserFavorite.objects.filter(
                    user=instance.user,
                    subject_id__in=removed_subject_ids,
                    favorite_type='SUBJECT'
                ).delete()[0]
                
                total_deleted = deleted_docs + deleted_subjects_fav
                
                # Log pour monitoring
                print(f"=" * 60)
                print(f"📚 CHANGEMENT DE FILIÈRE DÉTECTÉ")
                print(f"Étudiant: {instance.user.username} ({instance.user.email})")
                print(f"Ancienne filière: {old_profile.major.name} ({old_profile.major.code})")
                print(f"Nouvelle filière: {instance.major.name} ({instance.major.code})")
                print(f"✅ Quiz: CONSERVÉS (isolation automatique dans l'API)")
                print(f"❤️  Favoris supprimés: {total_deleted} ({deleted_docs} docs, {deleted_subjects_fav} matières)")
                print(f"📊 Matières retirées: {len(removed_subject_ids)}")
                print(f"=" * 60)
            else:
                print(f"ℹ️  Changement de filière pour {instance.user.username} : Aucune matière commune supprimée")
                
    except StudentProfile.DoesNotExist:
        pass
    except Exception as e:
        print(f"⚠️  Erreur dans handle_major_change: {str(e)}")
        # Ne pas bloquer la sauvegarde en cas d'erreur dans le signal
        pass