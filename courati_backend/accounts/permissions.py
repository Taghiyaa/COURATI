# accounts/permissions.py
from functools import wraps
from django.core.exceptions import PermissionDenied
from django.shortcuts import get_object_or_404
from rest_framework import permissions
from rest_framework.exceptions import PermissionDenied as DRFPermissionDenied


# ========================================
# DECORATORS POUR LES VUES DJANGO
# ========================================

def teacher_required(function):
    """
    Decorator pour restreindre l'accès aux professeurs uniquement
    Usage: @teacher_required
    """
    @wraps(function)
    def wrap(request, *args, **kwargs):
        if not request.user.is_authenticated:
            raise PermissionDenied("Authentification requise")
        
        if request.user.role != 'TEACHER' and request.user.role != 'ADMIN':
            raise PermissionDenied("Accès réservé aux professeurs")
        
        return function(request, *args, **kwargs)
    
    return wrap


def admin_or_teacher_required(function):
    """
    Decorator pour permettre l'accès aux admins et professeurs
    Usage: @admin_or_teacher_required
    """
    @wraps(function)
    def wrap(request, *args, **kwargs):
        if not request.user.is_authenticated:
            raise PermissionDenied("Authentification requise")
        
        if request.user.role not in ['ADMIN', 'TEACHER']:
            raise PermissionDenied("Accès réservé aux administrateurs et professeurs")
        
        return function(request, *args, **kwargs)
    
    return wrap


# ========================================
# FONCTIONS DE VÉRIFICATION
# ========================================

def has_subject_access(user, subject):
    """
    Vérifie si un utilisateur (professeur) a accès à une matière
    
    Args:
        user: Instance User
        subject: Instance Subject
    
    Returns:
        bool: True si accès autorisé, False sinon
    """
    # Admin a accès à tout
    if user.role == 'ADMIN':
        return True
    
    # Professeur doit avoir une assignation active
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        return TeacherAssignment.objects.filter(
            teacher=user,
            subject=subject,
            is_active=True
        ).exists()
    
    return False


def can_upload_document(user, subject):
    """
    Vérifie si un professeur peut uploader des documents pour une matière
    
    Args:
        user: Instance User
        subject: Instance Subject
    
    Returns:
        bool: True si autorisé
    """
    # Admin peut tout faire
    if user.role == 'ADMIN':
        return True
    
    # Vérifier permission spécifique du professeur
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=subject,
            is_active=True
        ).first()
        
        return assignment and assignment.can_upload_documents
    
    return False


def can_edit_subject_content(user, subject):
    """
    Vérifie si un professeur peut modifier le contenu d'une matière
    
    Args:
        user: Instance User
        subject: Instance Subject
    
    Returns:
        bool: True si autorisé
    """
    if user.role == 'ADMIN':
        return True
    
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=subject,
            is_active=True
        ).first()
        
        return assignment and assignment.can_edit_content
    
    return False


def can_delete_document(user, document):
    """
    Vérifie si un utilisateur peut supprimer un document
    
    Args:
        user: Instance User
        document: Instance Document
    
    Returns:
        bool: True si autorisé
    """
    if user.role == 'ADMIN':
        return True
    
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=document.subject,
            is_active=True
        ).first()
        
        return assignment and assignment.can_delete_documents
    
    return False


def can_manage_students(user, subject):
    """
    Vérifie si un professeur peut gérer les étudiants d'une matière
    
    Args:
        user: Instance User
        subject: Instance Subject
    
    Returns:
        bool: True si autorisé
    """
    if user.role == 'ADMIN':
        return True
    
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=subject,
            is_active=True
        ).first()
        
        return assignment and assignment.can_manage_students
    
    return False


def get_teacher_subjects(user):
    """
    Retourne la liste des matières assignées à un professeur
    
    Args:
        user: Instance User (doit être TEACHER)
    
    Returns:
        QuerySet: Liste des Subject
    """
    if user.role != 'TEACHER':
        return []
    
    from .models import TeacherAssignment
    from courses.models import Subject
    
    assignment_ids = TeacherAssignment.objects.filter(
        teacher=user,
        is_active=True
    ).values_list('subject_id', flat=True)
    
    return Subject.objects.filter(id__in=assignment_ids, is_active=True)


# ========================================
# PERMISSIONS POUR DJANGO REST FRAMEWORK
# ========================================

class IsAdminUser(permissions.BasePermission):
    """Permission: Seuls les admins"""
    
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'ADMIN'


class IsTeacherUser(permissions.BasePermission):
    """Permission: Seuls les professeurs"""
    
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'TEACHER'


class IsAdminOrTeacher(permissions.BasePermission):
    """Permission: Admins ou Professeurs"""
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and 
            request.user.role in ['ADMIN', 'TEACHER']
        )


class IsStudentUser(permissions.BasePermission):
    """Permission: Seuls les étudiants"""
    
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'STUDENT'


class HasSubjectAccess(permissions.BasePermission):
    """
    Permission: Vérifie l'accès à une matière
    Utiliser avec detail views qui ont un subject_id
    """
    
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        # Admin a accès à tout
        if request.user.role == 'ADMIN':
            return True
        
        # Récupérer le subject_id depuis l'URL
        subject_id = view.kwargs.get('pk') or view.kwargs.get('subject_id')
        if not subject_id:
            return False
        
        from courses.models import Subject
        try:
            subject = Subject.objects.get(id=subject_id)
            return has_subject_access(request.user, subject)
        except Subject.DoesNotExist:
            return False
    
    def has_object_permission(self, request, view, obj):
        """Vérification au niveau objet"""
        if request.user.role == 'ADMIN':
            return True
        
        # obj peut être un Subject ou un Document
        subject = obj if hasattr(obj, 'name') else obj.subject
        return has_subject_access(request.user, subject)


class CanUploadDocument(permissions.BasePermission):
    """Permission: Peut uploader des documents"""
    
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        if request.user.role == 'ADMIN':
            return True
        
        # Pour les uploads, le subject_id est généralement dans les données POST
        subject_id = request.data.get('subject') or view.kwargs.get('subject_id')
        if not subject_id:
            return False
        
        from courses.models import Subject
        try:
            subject = Subject.objects.get(id=subject_id)
            return can_upload_document(request.user, subject)
        except Subject.DoesNotExist:
            return False


class CanEditSubjectContent(permissions.BasePermission):
    """Permission: Peut modifier le contenu d'une matière"""
    
    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        
        if request.user.role == 'ADMIN':
            return True
        
        # Seules les méthodes PUT/PATCH nécessitent cette permission
        if request.method in ['PUT', 'PATCH']:
            return can_edit_subject_content(request.user, obj)
        
        return True


class CanDeleteDocument(permissions.BasePermission):
    """Permission: Peut supprimer des documents"""
    
    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        
        if request.user.role == 'ADMIN':
            return True
        
        if request.method == 'DELETE':
            return can_delete_document(request.user, obj)
        
        return True


class CanManageStudents(permissions.BasePermission):
    """Permission: Peut gérer les étudiants d'une matière"""
    
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        if request.user.role == 'ADMIN':
            return True
        
        subject_id = view.kwargs.get('subject_id')
        if not subject_id:
            return False
        
        from courses.models import Subject
        try:
            subject = Subject.objects.get(id=subject_id)
            return can_manage_students(request.user, subject)
        except Subject.DoesNotExist:
            return False


# ========================================
# PERMISSION COMPOSITE
# ========================================

class TeacherSubjectPermission(permissions.BasePermission):
    """
    Permission composite pour gérer tous les cas d'usage professeur
    - GET: Lecture si assigné
    - POST: Upload si can_upload_documents
    - PUT/PATCH: Modification si can_edit_content
    - DELETE: Suppression si can_delete_documents
    """
    
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        # Admin peut tout faire
        if request.user.role == 'ADMIN':
            return True
        
        # Professeur doit avoir une assignation
        if request.user.role == 'TEACHER':
            return True
        
        return False
    
    def has_object_permission(self, request, view, obj):
        if request.user.role == 'ADMIN':
            return True
        
        # Déterminer le subject
        subject = obj if hasattr(obj, 'name') else getattr(obj, 'subject', None)
        
        if not subject:
            return False
        
        # Vérifier selon la méthode HTTP
        if request.method in permissions.SAFE_METHODS:
            return has_subject_access(request.user, subject)
        elif request.method == 'POST':
            return can_upload_document(request.user, subject)
        elif request.method in ['PUT', 'PATCH']:
            return can_edit_subject_content(request.user, subject)
        elif request.method == 'DELETE':
            if hasattr(obj, 'subject'):  # C'est un document
                return can_delete_document(request.user, obj)
            return False
        
        return False



# ========================================
# PERMISSIONS POUR LES QUIZ
# ========================================

def can_create_quiz(user, subject):
    """
    Vérifie si un utilisateur peut créer un quiz pour une matière
    
    Args:
        user: Instance User
        subject: Instance Subject
    
    Returns:
        bool: True si autorisé
    """
    # Admin peut tout faire
    if user.role == 'ADMIN':
        return True
    
    # Professeur doit avoir les permissions d'édition de contenu
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=subject,
            is_active=True
        ).first()
        
        # Peut créer un quiz s'il peut éditer le contenu
        return assignment and assignment.can_edit_content
    
    return False


def can_edit_quiz(user, quiz):
    """
    Vérifie si un utilisateur peut modifier un quiz
    
    Args:
        user: Instance User
        quiz: Instance Quiz
    
    Returns:
        bool: True si autorisé
    """
    if user.role == 'ADMIN':
        return True
    
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=quiz.subject,
            is_active=True
        ).first()
        
        return assignment and assignment.can_edit_content
    
    return False


def can_delete_quiz(user, quiz):
    """
    Vérifie si un utilisateur peut supprimer un quiz
    
    Args:
        user: Instance User
        quiz: Instance Quiz
    
    Returns:
        bool: True si autorisé
    """
    if user.role == 'ADMIN':
        return True
    
    if user.role == 'TEACHER':
        from .models import TeacherAssignment
        assignment = TeacherAssignment.objects.filter(
            teacher=user,
            subject=quiz.subject,
            is_active=True
        ).first()
        
        # Peut supprimer s'il peut supprimer des documents
        return assignment and assignment.can_delete_documents
    
    return False


def can_view_quiz_statistics(user, quiz):
    """
    Vérifie si un utilisateur peut voir les statistiques d'un quiz
    
    Args:
        user: Instance User
        quiz: Instance Quiz
    
    Returns:
        bool: True si autorisé
    """
    if user.role == 'ADMIN':
        return True
    
    # Professeur assigné à la matière peut voir les stats
    if user.role == 'TEACHER':
        return has_subject_access(user, quiz.subject)
    
    return False


def can_take_quiz(user, quiz):
    """
    Vérifie si un étudiant peut passer un quiz
    
    Args:
        user: Instance User
        quiz: Instance Quiz
    
    Returns:
        bool: True si autorisé
    """
    # Seuls les étudiants peuvent passer les quiz
    if user.role != 'STUDENT':
        return False
    
    # Vérifier si le quiz est actif
    if not quiz.is_active:
        return False
    
    # Vérifier la disponibilité temporelle
    from django.utils import timezone
    now = timezone.now()
    
    if quiz.available_from and now < quiz.available_from:
        return False
    
    if quiz.available_until and now > quiz.available_until:
        return False
    
    # Vérifier que l'étudiant a accès à la matière
    try:
        student_profile = user.student_profile
        
        # Vérifier que le niveau et la filière correspondent
        return (
            student_profile.level in quiz.subject.levels.all() and
            student_profile.major in quiz.subject.majors.all()
        )
    except:
        return False


def has_quiz_attempts_left(user, quiz):
    """
    Vérifie si un étudiant a encore des tentatives disponibles
    
    Args:
        user: Instance User
        quiz: Instance Quiz
    
    Returns:
        bool: True si des tentatives restantes
    """
    from courses.models import QuizAttempt
    
    attempts_count = QuizAttempt.objects.filter(
        user=user,
        quiz=quiz
    ).count()
    
    return attempts_count < quiz.max_attempts


# ========================================
# PERMISSIONS DRF POUR LES QUIZ
# ========================================

class CanCreateQuiz(permissions.BasePermission):
    """Permission: Peut créer un quiz"""
    
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        if request.user.role == 'ADMIN':
            return True
        
        # Pour la création, le subject_id est dans les données
        subject_id = request.data.get('subject')
        if not subject_id:
            return False
        
        from courses.models import Subject
        try:
            subject = Subject.objects.get(id=subject_id)
            return can_create_quiz(request.user, subject)
        except Subject.DoesNotExist:
            return False


class CanManageQuiz(permissions.BasePermission):
    """
    Permission composite pour gérer les quiz
    - GET: Lecture si assigné à la matière
    - POST: Création si can_edit_content
    - PUT/PATCH: Modification si can_edit_content
    - DELETE: Suppression si can_delete_documents
    """
    
    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        
        # Admin peut tout faire
        if request.user.role == 'ADMIN':
            return True
        
        # Professeur et étudiant peuvent lire
        if request.method in permissions.SAFE_METHODS:
            return request.user.role in ['TEACHER', 'STUDENT']
        
        # Seuls prof et admin peuvent créer/modifier/supprimer
        return request.user.role == 'TEACHER'
    
    def has_object_permission(self, request, view, obj):
        if request.user.role == 'ADMIN':
            return True
        
        quiz = obj
        
        # Lecture
        if request.method in permissions.SAFE_METHODS:
            # Professeur : accès si assigné
            if request.user.role == 'TEACHER':
                return has_subject_access(request.user, quiz.subject)
            # Étudiant : peut voir si peut passer le quiz
            if request.user.role == 'STUDENT':
                return can_take_quiz(request.user, quiz)
            return False
        
        # Modification
        if request.method in ['PUT', 'PATCH']:
            return can_edit_quiz(request.user, quiz)
        
        # Suppression
        if request.method == 'DELETE':
            return can_delete_quiz(request.user, quiz)
        
        return False


class CanTakeQuiz(permissions.BasePermission):
    """Permission: Étudiant peut passer un quiz"""
    
    def has_permission(self, request, view):
        return (
            request.user.is_authenticated and 
            request.user.role == 'STUDENT'
        )
    
    def has_object_permission(self, request, view, obj):
        # obj est le quiz
        return can_take_quiz(request.user, obj)


class CanViewQuizStatistics(permissions.BasePermission):
    """Permission: Peut voir les statistiques d'un quiz"""
    
    def has_object_permission(self, request, view, obj):
        if not request.user.is_authenticated:
            return False
        
        return can_view_quiz_statistics(request.user, obj)


# Alias pour IsAdminPermission (utilisé dans les nouvelles vues)
IsAdminPermission = IsAdminUser