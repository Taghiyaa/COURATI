# accounts/signals.py
from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import Permission
from django.contrib.contenttypes.models import ContentType
from .models import User, TeacherProfile
from courses.models import Subject, Document


@receiver(post_save, sender=User)
def setup_teacher_permissions(sender, instance, created, **kwargs):
    """
    Attribuer automatiquement les permissions nécessaires 
    quand un utilisateur TEACHER est créé
    """
    if instance.role == 'TEACHER':
        # Permissions pour les documents
        doc_ct = ContentType.objects.get_for_model(Document)
        doc_permissions = Permission.objects.filter(
            content_type=doc_ct,
            codename__in=['add_document', 'change_document', 'delete_document', 'view_document']
        )
        
        # Permissions pour les matières (view seulement)
        subject_ct = ContentType.objects.get_for_model(Subject)
        subject_permission = Permission.objects.filter(
            content_type=subject_ct,
            codename='view_subject'
        )
        
        # CORRECTION: Utiliser + au lieu de | pour concaténer les listes
        all_permissions = list(doc_permissions) + list(subject_permission)
        instance.user_permissions.set(all_permissions)
        
        # Créer automatiquement le profil professeur si inexistant
        TeacherProfile.objects.get_or_create(user=instance)