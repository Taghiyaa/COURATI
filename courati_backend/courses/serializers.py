# courses/serializers.py
from rest_framework import serializers
from django.utils import timezone
from django.db.models import Avg, Count, Q, Max, Sum, F
from django.db import models  # Ajoutez cette ligne
from accounts.serializers import LevelSimpleSerializer, MajorSimpleSerializer,LevelSerializer, MajorSerializer
from accounts.models import Level, Major
from .models import Subject, Document, UserActivity, UserFavorite, UserProgress,Quiz, Question, Choice, QuizAttempt, StudentAnswer, StudentProject, ProjectTask




class TeacherInfoSerializer(serializers.Serializer):
    """Serializer pour afficher les infos des professeurs assignés"""
    id = serializers.IntegerField()
    full_name = serializers.CharField()
    email = serializers.EmailField()
    specialization = serializers.CharField(required=False)
    can_upload_documents = serializers.BooleanField()
    can_edit_content = serializers.BooleanField()
    can_manage_students = serializers.BooleanField()


class SubjectSimpleSerializer(serializers.ModelSerializer):
    """Serializer simple pour les matières (listes)"""
    level_names = serializers.ReadOnlyField()
    major_names = serializers.ReadOnlyField()
    document_count = serializers.IntegerField(read_only=True)
    is_favorite = serializers.SerializerMethodField()
    assigned_teachers = serializers.SerializerMethodField()  # NOUVEAU
    
    class Meta:
        model = Subject
        fields = [
            'id', 'name', 'code', 'credits', 'is_featured', 
            'level_names', 'major_names', 'document_count', 
            'is_favorite', 'assigned_teachers'
        ]
    
    def get_is_favorite(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            user_favorites = self.context.get('user_favorites', [])
            return obj.id in user_favorites
        return False
    
    def get_assigned_teachers(self, obj):
        """Retourne la liste des professeurs assignés à cette matière"""
        from accounts.models import TeacherAssignment
        
        assignments = TeacherAssignment.objects.filter(
            subject=obj,
            is_active=True
        ).select_related('teacher', 'teacher__teacher_profile')
        
        teachers = []
        for assignment in assignments:
            teacher_data = {
                'id': assignment.teacher.id,
                'full_name': assignment.teacher.get_full_name(),
                'email': assignment.teacher.email,
            }
            
            # Ajouter la spécialisation si disponible
            if hasattr(assignment.teacher, 'teacher_profile'):
                teacher_data['specialization'] = assignment.teacher.teacher_profile.specialization
            
            teachers.append(teacher_data)
        
        return teachers


class SubjectDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé pour une matière avec infos professeurs"""
    levels = LevelSimpleSerializer(many=True, read_only=True)
    majors = MajorSimpleSerializer(many=True, read_only=True)
    documents = serializers.SerializerMethodField()
    document_count = serializers.IntegerField(read_only=True)
    is_favorite = serializers.SerializerMethodField()
    assigned_teachers = serializers.SerializerMethodField()
    user_permissions = serializers.SerializerMethodField()  # NOUVEAU
    
    class Meta:
        model = Subject
        fields = [
            'id', 'name', 'code', 'description', 'credits',
            'is_featured', 'levels', 'majors', 'documents',
            'document_count', 'is_favorite', 'assigned_teachers',
            'user_permissions', 'created_at', 'updated_at'
        ]
    
    def get_documents(self, obj):
        from .models import Document
        documents = Document.objects.filter(
            subject=obj,
            is_active=True
        ).order_by('order', '-created_at')
        
        return DocumentSerializer(
            documents,
            many=True,
            context=self.context
        ).data
    
    def get_is_favorite(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            from .models import UserFavorite
            return UserFavorite.objects.filter(
                user=request.user,
                subject=obj,
                favorite_type='SUBJECT'
            ).exists()
        return False
    
    def get_assigned_teachers(self, obj):
        """Liste complète des professeurs avec leurs permissions"""
        from accounts.models import TeacherAssignment
        
        assignments = TeacherAssignment.objects.filter(
            subject=obj,
            is_active=True
        ).select_related('teacher', 'teacher__teacher_profile')
        
        teachers = []
        for assignment in assignments:
            teacher_data = {
                'id': assignment.teacher.id,
                'full_name': assignment.teacher.get_full_name(),
                'email': assignment.teacher.email,
                'can_upload_documents': assignment.can_upload_documents,
                'can_edit_content': assignment.can_edit_content,
                'can_manage_students': assignment.can_manage_students,
            }
            
            if hasattr(assignment.teacher, 'teacher_profile'):
                profile = assignment.teacher.teacher_profile
                teacher_data.update({
                    'specialization': profile.specialization,
                    'office': profile.office,
                    'office_hours': profile.office_hours,
                })
            
            teachers.append(teacher_data)
        
        return teachers
    
    def get_user_permissions(self, obj):
        """Retourne les permissions de l'utilisateur actuel sur cette matière"""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return None
        
        user = request.user
        
        # Admin a toutes les permissions
        if user.role == 'ADMIN':
            return {
                'can_view': True,
                'can_edit_content': True,
                'can_upload_documents': True,
                'can_delete_documents': True,
                'can_manage_students': True,
            }
        
        # Professeur : récupérer ses permissions
        if user.role == 'TEACHER':
            from accounts.models import TeacherAssignment
            try:
                assignment = TeacherAssignment.objects.get(
                    teacher=user,
                    subject=obj,
                    is_active=True
                )
                return {
                    'can_view': True,
                    'can_edit_content': assignment.can_edit_content,
                    'can_upload_documents': assignment.can_upload_documents,
                    'can_delete_documents': assignment.can_delete_documents,
                    'can_manage_students': assignment.can_manage_students,
                }
            except TeacherAssignment.DoesNotExist:
                return None
        
        # Étudiant : lecture seule
        if user.role == 'STUDENT':
            return {
                'can_view': True,
                'can_edit_content': False,
                'can_upload_documents': False,
                'can_delete_documents': False,
                'can_manage_students': False,
            }
        
        return None


class DocumentSerializer(serializers.ModelSerializer):
    """Serializer pour les documents - avec info créateur"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    created_by_role = serializers.CharField(source='created_by.role', read_only=True)  # NOUVEAU
    document_type_display = serializers.CharField(source='get_document_type_display', read_only=True)
    # ✅ AJOUT : Exposer file_size en bytes
    file_size = serializers.IntegerField(read_only=True)
    file_size_mb = serializers.ReadOnlyField()
    
    # ✅ AJOUT : Alias pour compatibilité frontend
    views_count = serializers.IntegerField(source='view_count', read_only=True)
    downloads_count = serializers.IntegerField(source='download_count', read_only=True)

    file_size_mb = serializers.ReadOnlyField()
    file_url = serializers.SerializerMethodField()
    is_favorite = serializers.SerializerMethodField()
    user_progress = serializers.SerializerMethodField()
    user_can_delete = serializers.SerializerMethodField()  # NOUVEAU
    is_viewed = serializers.SerializerMethodField()
    
    class Meta:
        model = Document
        fields = [
            'id', 'title', 'description', 'subject', 'subject_name', 
            'subject_code', 'document_type', 'document_type_display',
            'file', 'file_url', 'file_size',  # ✅ AJOUTÉ
            'file_size_mb', 
            'is_active', 'is_premium', 
            'download_count', 'view_count',
            'views_count',  # ✅ AJOUTÉ (alias)
            'downloads_count',  # ✅ AJOUTÉ (alias)
            'created_by', 'created_by_name', 'created_by_role',
            'is_favorite', 'user_progress', 'user_can_delete', 'is_viewed',
            'order', 'created_at', 'updated_at'
        ]
        read_only_fields = ['created_by', 'download_count', 'view_count', 'created_at', 'updated_at']
    
    def get_file_url(self, obj):
        if obj.file:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.file.url)
            return obj.file.url
        return None
    
    def get_is_favorite(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            user_favorites = self.context.get('user_favorites', [])
            return obj.id in user_favorites
        return False
    
    def get_user_progress(self, obj):
        user_progress = self.context.get('user_progress', {})
        if obj.id in user_progress:
            progress = user_progress[obj.id]
            return {
                'status': progress['status'],
                'progress_percentage': progress['progress_percentage']
            }
        return None
    
    def get_user_can_delete(self, obj):
        """Vérifie si l'utilisateur peut supprimer ce document"""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        
        from accounts.permissions import can_delete_document
        return can_delete_document(request.user, obj)

    def get_is_viewed(self, obj):
        """Vérifie si l'utilisateur a consulté ce document"""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        
        # Vérifier dans le contexte d'abord (optimisation)
        user_viewed = self.context.get('user_viewed', set())
        if user_viewed:
            return obj.id in user_viewed
        
        # Sinon requête directe
        from .models import UserProgress
        return UserProgress.objects.filter(
            user=request.user,
            document=obj,
            status__in=['IN_PROGRESS', 'COMPLETED']
        ).exists()


class TeacherSubjectSerializer(serializers.ModelSerializer):
    """Serializer spécial pour les matières d'un professeur"""
    level_names = serializers.ReadOnlyField()
    major_names = serializers.ReadOnlyField()
    document_count = serializers.IntegerField(read_only=True)
    student_count = serializers.SerializerMethodField()
    my_permissions = serializers.SerializerMethodField()
    
    class Meta:
        model = Subject
        fields = [
            'id', 'name', 'code', 'description', 'credits',
            'level_names', 'major_names', 'document_count',
            'student_count', 'my_permissions', 'is_active'
        ]
    
    def get_student_count(self, obj):
        """Nombre d'étudiants inscrits à cette matière"""
        from accounts.models import StudentProfile
        
        # Étudiants dont le niveau ET la filière correspondent
        count = StudentProfile.objects.filter(
            level__in=obj.levels.all(),
            major__in=obj.majors.all()
        ).count()
        
        return count
    
    def get_my_permissions(self, obj):
        """Permissions du professeur actuel sur cette matière"""
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return None
        
        from accounts.models import TeacherAssignment
        try:
            assignment = TeacherAssignment.objects.get(
                teacher=request.user,
                subject=obj,
                is_active=True
            )
            return {
                'can_edit_content': assignment.can_edit_content,
                'can_upload_documents': assignment.can_upload_documents,
                'can_delete_documents': assignment.can_delete_documents,
                'can_manage_students': assignment.can_manage_students,
            }
        except TeacherAssignment.DoesNotExist:
            return None


# ... (garder tous les autres serializers existants)

class UserFavoriteSerializer(serializers.ModelSerializer):
    subject_info = serializers.SerializerMethodField()
    document_info = serializers.SerializerMethodField()
    
    class Meta:
        model = UserFavorite
        fields = ['id', 'favorite_type', 'subject_info', 'document_info', 'created_at']
    
    def get_subject_info(self, obj):
        if obj.subject:
            return {
                'id': obj.subject.id,
                'name': obj.subject.name,
                'code': obj.subject.code,
                'credits': obj.subject.credits
            }
        return None
    
    def get_document_info(self, obj):
        if obj.document:
            return {
                'id': obj.document.id,
                'title': obj.document.title,
                'type': obj.document.document_type,
                'subject_name': obj.document.subject.name,
                'file_size_mb': obj.document.file_size_mb
            }
        return None


class UserProgressSerializer(serializers.ModelSerializer):
    subject_info = serializers.SerializerMethodField()
    document_info = serializers.SerializerMethodField()
    time_spent_hours = serializers.SerializerMethodField()
    
    class Meta:
        model = UserProgress
        fields = [
            'id', 'subject_info', 'document_info', 'status',
            'progress_percentage', 'time_spent', 'time_spent_hours',
            'started_at', 'completed_at', 'last_accessed'
        ]
    
    def get_subject_info(self, obj):
        return {
            'id': obj.subject.id,
            'name': obj.subject.name,
            'code': obj.subject.code
        }
    
    def get_document_info(self, obj):
        if obj.document:
            return {
                'id': obj.document.id,
                'title': obj.document.title,
                'type': obj.document.document_type
            }
        return None
    
    def get_time_spent_hours(self, obj):
        return round(obj.time_spent / 60, 1) if obj.time_spent else 0


class UserActivitySerializer(serializers.ModelSerializer):
    document_name = serializers.CharField(source='document.title', read_only=True)
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    document_info = serializers.SerializerMethodField()
    action_display = serializers.CharField(source='get_action_display', read_only=True)
    
    class Meta:
        model = UserActivity
        fields = [
            'id', 'action', 'action_display', 'created_at', 
            'document_name', 'subject_name', 'document_info'
        ]
    
    def get_document_info(self, obj):
        return {
            'id': obj.document.id,
            'title': obj.document.title,
            'type': obj.document.document_type,
            'type_display': obj.document.get_document_type_display(),
            'size_mb': obj.document.file_size_mb,
        }


class ConsultationDocumentSerializer(serializers.ModelSerializer):
    document_type_display = serializers.CharField(source='get_document_type_display', read_only=True)
    is_favorite = serializers.SerializerMethodField()
    
    class Meta:
        model = Document
        fields = [
            'id', 'title', 'document_type', 'document_type_display', 
            'file_size_mb', 'is_favorite', 'view_count', 'download_count'
        ]
    
    def get_is_favorite(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            user_favorites = self.context.get('user_favorites', [])
            return obj.id in user_favorites
        return False


class ConsultationSubjectSerializer(serializers.ModelSerializer):
    class Meta:
        model = Subject
        fields = ['id', 'name', 'code']


class ConsultationActivitySerializer(serializers.ModelSerializer):
    document = ConsultationDocumentSerializer(read_only=True)
    subject = ConsultationSubjectSerializer(read_only=True)
    action_display = serializers.SerializerMethodField()
    consulted_at = serializers.DateTimeField(source='created_at', read_only=True)
    
    class Meta:
        model = UserActivity
        fields = [
            'id', 'document', 'subject', 'action', 'action_display', 
            'consulted_at', 'ip_address'
        ]
    
    def get_action_display(self, obj):
        action_mapping = {
            'view': 'Consulté',
            'download': 'Téléchargé',
        }
        return action_mapping.get(obj.action, obj.get_action_display())


class ConsultationStatsSerializer(serializers.Serializer):
    total_consultations = serializers.IntegerField()
    total_views = serializers.IntegerField()
    total_downloads = serializers.IntegerField()
    unique_documents = serializers.IntegerField()


class ConsultationHistoryResponseSerializer(serializers.Serializer):
    success = serializers.BooleanField()
    consultations = ConsultationActivitySerializer(many=True)
    stats = ConsultationStatsSerializer()
    filters = serializers.DictField()


class PersonalizedHomeSerializer(serializers.Serializer):
    def to_representation(self, instance):
        user = instance['user']
        student_profile = instance['student_profile']
        
        return {
            'user_info': {
                'username': user.username,
                'full_name': f"{user.first_name} {user.last_name}".strip() or user.username,
                'level': student_profile.level.name if student_profile.level else None,
                'major': student_profile.major.name if student_profile.major else None,
                'is_verified': student_profile.is_verified
            },
            'recommended_subjects': SubjectSimpleSerializer(
                instance['recommended_subjects'], 
                many=True, 
                context=self.context
            ).data,
            'in_progress_subjects': SubjectSimpleSerializer(
                instance['in_progress_subjects'], 
                many=True, 
                context=self.context
            ).data,
            'recent_documents': DocumentSerializer(
                instance['recent_documents'], 
                many=True, 
                context=self.context
            ).data,
            'recent_favorites': UserFavoriteSerializer(
                instance['recent_favorites'], 
                many=True
            ).data,
            'stats': instance['stats'],
            'subject_progress': instance.get('subject_progress', {}),  # ✅ AJOUTER CETTE LIGNE
            'quick_actions': [
                {
                    'title': 'Mes Cours',
                    'description': 'Accéder à vos matières',
                    'icon': 'school',
                    'route': '/courses'
                },
                {
                    'title': 'Favoris',
                    'description': 'Vos contenus préférés',
                    'icon': 'favorite',
                    'route': '/favorites'
                },
                {
                    'title': 'Progression',
                    'description': 'Suivre votre avancement',
                    'icon': 'trending_up',
                    'route': '/progress'
                }
            ]
        }



class ChoiceSerializer(serializers.ModelSerializer):
    """Serializer pour les choix de réponse"""
    class Meta:
        model = Choice
        fields = ['id', 'text', 'order']
        # is_correct n'est pas exposé aux étudiants avant correction


class ChoiceWithAnswerSerializer(serializers.ModelSerializer):
    """Serializer avec la réponse correcte (pour la correction)"""
    class Meta:
        model = Choice
        fields = ['id', 'text', 'is_correct', 'order']


class QuestionSerializer(serializers.ModelSerializer):
    """Serializer pour les questions (sans réponse)"""
    choices = ChoiceSerializer(many=True, read_only=True)
    
    class Meta:
        model = Question
        fields = ['id', 'text', 'question_type', 'points', 'order', 'choices']


class QuestionWithAnswerSerializer(serializers.ModelSerializer):
    """Serializer avec les bonnes réponses (pour correction)"""
    choices = ChoiceWithAnswerSerializer(many=True, read_only=True)
    
    class Meta:
        model = Question
        fields = ['id', 'text', 'question_type', 'points', 'order', 'explanation', 'choices']


# courses/serializers.py

class QuizListSerializer(serializers.ModelSerializer):
    """Serializer pour la liste des quiz (vue d'ensemble)"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    question_count = serializers.IntegerField(read_only=True)
    total_points = serializers.DecimalField(max_digits=5, decimal_places=2, read_only=True)
    
    # Champs calculés à partir du pourcentage
    passing_percentage_normalized = serializers.SerializerMethodField()
    
    # Informations spécifiques à l'étudiant connecté
    user_best_score = serializers.SerializerMethodField()
    user_attempts_count = serializers.SerializerMethodField()
    user_last_attempt = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()
    can_attempt = serializers.SerializerMethodField()
    
    # ✅ NOUVEAU : Pourcentage de réussite
    best_score_percentage = serializers.SerializerMethodField()
    remaining_attempts = serializers.SerializerMethodField()
    
    class Meta:
        model = Quiz
        fields = [
            'id', 'title', 'description', 'subject_name', 'subject_code',
            'duration_minutes', 'passing_percentage', 'passing_percentage_normalized',
            'max_attempts', 'question_count', 'total_points', 'is_active',
            'available_from', 'available_until',
            'user_best_score', 'user_attempts_count', 'user_last_attempt',
            'best_score_percentage', 'remaining_attempts',
            'is_available', 'can_attempt'
        ]
    
    def get_passing_percentage_normalized(self, obj):
        """Score de passage normalisé sur 20"""
        # Calculer manuellement au lieu d'utiliser la property
        return round((float(obj.passing_percentage) * 20) / 100, 2)
    
    def get_user_best_score(self, obj):
        """Meilleur score de l'étudiant - NORMALISÉ sur 20"""
        user = self.context.get('request').user
        if not user.is_authenticated:
            return None
        
        # ✅ SIMPLIFIÉ : Pas de vérification de filière (déjà filtré dans la vue)
        attempts = QuizAttempt.objects.filter(
            user=user, 
            quiz=obj, 
            status='COMPLETED'
        )
        
        if not attempts.exists():
            return None
        
        # Récupérer le meilleur score brut
        best = attempts.aggregate(best=Max('score'))['best']
        
        if best is None:
            return None
        
        # Normaliser sur 20
        total_points = obj.total_points
        if total_points and total_points > 0:
            normalized_score = (float(best) / float(total_points)) * 20
            return round(normalized_score, 2)
        
        return float(best)
    
    def get_user_attempts_count(self, obj):
        """Nombre de tentatives de l'étudiant"""
        user = self.context.get('request').user
        if not user.is_authenticated:
            return 0
        
        # ✅ SIMPLIFIÉ
        return QuizAttempt.objects.filter(user=user, quiz=obj).count()
    
    def get_user_last_attempt(self, obj):
        """Date de la dernière tentative"""
        user = self.context.get('request').user
        if not user.is_authenticated:
            return None
        
        # ✅ SIMPLIFIÉ
        last = QuizAttempt.objects.filter(
            user=user, 
            quiz=obj
        ).order_by('-started_at').first()
        
        if last:
            return last.started_at
        return None
    
    def get_best_score_percentage(self, obj):
        """Pourcentage du meilleur score"""
        user = self.context.get('request').user
        if not user.is_authenticated:
            return 0
        
        attempts = QuizAttempt.objects.filter(
            user=user, 
            quiz=obj, 
            status='COMPLETED'
        )
        
        if not attempts.exists():
            return 0
        
        best = attempts.aggregate(best=Max('score'))['best']
        
        if best is None or not obj.total_points or obj.total_points == 0:
            return 0
        
        percentage = (float(best) / float(obj.total_points)) * 100
        return round(percentage, 1)
    
    def get_remaining_attempts(self, obj):
        """Nombre de tentatives restantes"""
        attempts_count = self.get_user_attempts_count(obj)
        return max(0, obj.max_attempts - attempts_count)
    
    def get_is_available(self, obj):
        """Le quiz est-il disponible maintenant ?"""
        now = timezone.now()
        if obj.available_from and now < obj.available_from:
            return False
        if obj.available_until and now > obj.available_until:
            return False
        return obj.is_active
    
    def get_can_attempt(self, obj):
        """L'étudiant peut-il passer le quiz ?"""
        user = self.context.get('request').user
        if not user.is_authenticated:
            return False
        
        attempts_count = self.get_user_attempts_count(obj)
        return attempts_count < obj.max_attempts and self.get_is_available(obj)

class QuizDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé pour démarrer un quiz"""
    questions = QuestionSerializer(many=True, read_only=True)
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    question_count = serializers.IntegerField(read_only=True)
    total_points = serializers.DecimalField(max_digits=5, decimal_places=2, read_only=True)
    passing_percentage_normalized = serializers.SerializerMethodField()
    
    class Meta:
        model = Quiz
        fields = [
            'id', 'title', 'description', 
            'subject_name', 'subject_code',
            'duration_minutes', 'passing_percentage',
            'passing_percentage_normalized', 'max_attempts', 
            'show_correction', 'question_count', 'total_points',
            'questions'
        ]
    
    def get_passing_percentage_normalized(self, obj):
        """Score de passage normalisé sur 20"""
        return round((float(obj.passing_percentage) * 20) / 100, 2)

class StudentAnswerSerializer(serializers.ModelSerializer):
    """Serializer pour soumettre une réponse"""
    class Meta:
        model = StudentAnswer
        fields = ['question', 'selected_choices']


class QuizAttemptCreateSerializer(serializers.ModelSerializer):
    """Serializer pour créer une tentative"""
    class Meta:
        model = QuizAttempt
        fields = ['quiz']
    
    def create(self, validated_data):
        user = self.context['request'].user
        quiz = validated_data['quiz']
        
        # Vérifier le nombre de tentatives
        attempts_count = QuizAttempt.objects.filter(user=user, quiz=quiz).count()
        if attempts_count >= quiz.max_attempts:
            raise serializers.ValidationError("Nombre maximum de tentatives atteint")
        
        # Vérifier la disponibilité
        now = timezone.now()
        if quiz.available_from and now < quiz.available_from:
            raise serializers.ValidationError("Ce quiz n'est pas encore disponible")
        if quiz.available_until and now > quiz.available_until:
            raise serializers.ValidationError("Ce quiz n'est plus disponible")
        
        # Créer la tentative
        attempt = QuizAttempt.objects.create(
            user=user,
            quiz=quiz,
            attempt_number=attempts_count + 1,
            status='IN_PROGRESS'
        )
        return attempt


class QuizAttemptSerializer(serializers.ModelSerializer):
    """Serializer pour afficher une tentative en cours"""
    quiz_title = serializers.CharField(source='quiz.title', read_only=True)
    duration_minutes = serializers.IntegerField(source='quiz.duration_minutes', read_only=True)
    
    class Meta:
        model = QuizAttempt
        fields = [
            'id', 'quiz', 'quiz_title', 'status', 'attempt_number',
            'started_at', 'duration_minutes'
        ]


class QuizSubmitSerializer(serializers.Serializer):
    """Serializer pour soumettre un quiz complet"""
    answers = serializers.ListField(
        child=serializers.DictField(
            child=serializers.CharField()
        )
    )
    
    def validate_answers(self, value):
        """
        Format attendu:
        [
            {"question_id": 1, "selected_choices": [1, 2]},
            {"question_id": 2, "selected_choices": [3]},
        ]
        """
        for answer in value:
            if 'question_id' not in answer or 'selected_choices' not in answer:
                raise serializers.ValidationError(
                    "Chaque réponse doit contenir 'question_id' et 'selected_choices'"
                )
        return value


# courses/serializers.py

class QuizResultSerializer(serializers.ModelSerializer):
    """Serializer pour les résultats d'un quiz"""
    quiz_title = serializers.CharField(source='quiz.title', read_only=True)
    passing_percentage = serializers.SerializerMethodField()
    is_passed = serializers.BooleanField(read_only=True)
    time_spent = serializers.FloatField(read_only=True)
    total_questions = serializers.SerializerMethodField()
    correct_answers = serializers.SerializerMethodField()
    wrong_answers = serializers.SerializerMethodField()
    score_normalized = serializers.SerializerMethodField()  # NOUVEAU
    
    class Meta:
        model = QuizAttempt
        fields = [
            'id', 'quiz_title', 'score', 'score_normalized',  # AJOUTÉ score_normalized
            'passing_percentage', 'is_passed',
            'attempt_number', 'started_at', 'completed_at', 'time_spent',
            'total_questions', 'correct_answers', 'wrong_answers'
        ]
    
    def get_score_normalized(self, obj):
        """Score normalisé sur 20"""
        total_points = obj.quiz.total_points
        if total_points and total_points > 0:
            return round((float(obj.score) / float(total_points)) * 20, 2)
        return float(obj.score)
    
    def get_passing_percentage(self, obj):
        """Passing score normalisé sur 20"""
        return round((float(obj.quiz.passing_percentage) * 20) / 100, 2)
    
    def get_total_questions(self, obj):
        return obj.quiz.question_count
    
    def get_correct_answers(self, obj):
        return obj.answers.filter(is_correct=True).count()
    
    def get_wrong_answers(self, obj):
        return obj.answers.filter(is_correct=False).count()


class QuizCorrectionSerializer(serializers.ModelSerializer):
    """Serializer pour afficher la correction détaillée"""
    questions = serializers.SerializerMethodField()
    
    class Meta:
        model = QuizAttempt
        fields = ['id', 'quiz', 'score', 'questions']
    
    def get_questions(self, obj):
        """Retourne les questions avec les réponses de l'étudiant"""
        questions_data = []
        
        for question in obj.quiz.questions.all():
            student_answer = obj.answers.filter(question=question).first()
            
            question_data = QuestionWithAnswerSerializer(question).data
            question_data['student_selected'] = []
            question_data['is_correct'] = False
            question_data['points_earned'] = 0
            
            if student_answer:
                question_data['student_selected'] = [
                    choice.id for choice in student_answer.selected_choices.all()
                ]
                question_data['is_correct'] = student_answer.is_correct
                question_data['points_earned'] = float(student_answer.points_earned)
            
            questions_data.append(question_data)
        
        return questions_data


# Serializers pour les statistiques professeur
class QuizStatisticsSerializer(serializers.ModelSerializer):
    """Statistiques d'un quiz pour le professeur"""
    total_attempts = serializers.IntegerField()
    completed_attempts = serializers.IntegerField()
    average_score = serializers.DecimalField(max_digits=5, decimal_places=2)
    pass_rate = serializers.FloatField()
    question_statistics = serializers.SerializerMethodField()
    
    class Meta:
        model = Quiz
        fields = [
            'id', 'title', 'total_attempts', 'completed_attempts',
            'average_score', 'pass_rate', 'question_statistics'
        ]
    
    def get_question_statistics(self, obj):
        """Statistiques par question"""
        questions_stats = []
        
        for question in obj.questions.all():
            total_answers = StudentAnswer.objects.filter(question=question).count()
            correct_answers = StudentAnswer.objects.filter(
                question=question, 
                is_correct=True
            ).count()
            
            error_rate = 0
            if total_answers > 0:
                error_rate = ((total_answers - correct_answers) / total_answers) * 100
            
            questions_stats.append({
                'question_id': question.id,
                'question_text': question.text[:50],
                'total_answers': total_answers,
                'correct_answers': correct_answers,
                'error_rate': round(error_rate, 2)
            })
        
        # Trier par taux d'erreur décroissant
        questions_stats.sort(key=lambda x: x['error_rate'], reverse=True)
        return questions_stats

# ========================================
# SERIALIZERS POUR LA GESTION DE PROJETS
# ========================================

class ProjectTaskSerializer(serializers.ModelSerializer):
    """Serializer pour les tâches de projet"""
    is_overdue = serializers.ReadOnlyField()
    
    class Meta:
        model = ProjectTask
        fields = [
            'id',
            'project',
            'title',
            'description',
            'status',
            'due_date',
            'completed_at',
            'order',
            'is_important',
            'estimated_hours',
            'is_overdue',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'completed_at', 'created_at', 'updated_at']
    
    def validate_project(self, value):
        """Vérifier que l'utilisateur possède ce projet"""
        user = self.context['request'].user
        if value.user != user:
            raise serializers.ValidationError(
                "Vous ne pouvez pas ajouter une tâche à un projet qui ne vous appartient pas."
            )
        return value


class StudentProjectListSerializer(serializers.ModelSerializer):
    """Serializer simplifié pour la liste des projets"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    subject_color = serializers.SerializerMethodField()
    
    # Propriétés calculées
    is_overdue = serializers.ReadOnlyField()
    days_until_due = serializers.ReadOnlyField()
    total_tasks = serializers.ReadOnlyField()
    completed_tasks_count = serializers.ReadOnlyField()
    
    # Informations de statut
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    priority_display = serializers.CharField(source='get_priority_display', read_only=True)
    
    class Meta:
        model = StudentProject
        fields = [
            'id',
            'title',
            'description',
            'subject',
            'subject_name',
            'subject_code',
            'subject_color',
            'status',
            'status_display',
            'priority',
            'priority_display',
            'start_date',
            'due_date',
            'completed_at',
            'progress_percentage',
            'color',
            'is_favorite',
            'order',
            'is_overdue',
            'days_until_due',
            'total_tasks',
            'completed_tasks_count',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id', 
            'progress_percentage', 
            'completed_at', 
            'created_at', 
            'updated_at'
        ]
    
    def get_subject_color(self, obj):
        """Retourner une couleur par défaut si pas de matière"""
        if obj.subject:
            # Vous pouvez ajouter un champ color au modèle Subject
            # Pour l'instant, retourner la couleur du projet
            return obj.color
        return obj.color


class StudentProjectDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé avec les tâches incluses"""
    tasks = ProjectTaskSerializer(many=True, read_only=True)
    subject_info = serializers.SerializerMethodField()
    
    # Propriétés calculées
    is_overdue = serializers.ReadOnlyField()
    days_until_due = serializers.ReadOnlyField()
    total_tasks = serializers.ReadOnlyField()
    completed_tasks_count = serializers.ReadOnlyField()
    
    # Informations de statut
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    priority_display = serializers.CharField(source='get_priority_display', read_only=True)
    
    # Statistiques des tâches par statut
    tasks_by_status = serializers.SerializerMethodField()
    
    class Meta:
        model = StudentProject
        fields = [
            'id',
            'title',
            'description',
            'subject',
            'subject_info',
            'status',
            'status_display',
            'priority',
            'priority_display',
            'start_date',
            'due_date',
            'completed_at',
            'progress_percentage',
            'color',
            'is_favorite',
            'order',
            'is_overdue',
            'days_until_due',
            'total_tasks',
            'completed_tasks_count',
            'tasks',
            'tasks_by_status',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id', 
            'progress_percentage', 
            'completed_at', 
            'created_at', 
            'updated_at'
        ]
    
    def get_subject_info(self, obj):
        """Informations détaillées sur la matière"""
        if obj.subject:
            return {
                'id': obj.subject.id,
                'name': obj.subject.name,
                'code': obj.subject.code,
            }
        return None
    
    def get_tasks_by_status(self, obj):
        """Compter les tâches par statut pour le Kanban"""
        tasks = obj.tasks.all()
        return {
            'todo': tasks.filter(status='TODO').count(),
            'in_progress': tasks.filter(status='IN_PROGRESS').count(),
            'done': tasks.filter(status='DONE').count(),
        }


class ProjectTaskCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour créer/modifier une tâche"""
    
    class Meta:
        model = ProjectTask
        fields = [
            'id',
            'project',
            'title',
            'description',
            'status',
            'due_date',
            'order',
            'is_important',
            'estimated_hours',
        ]
        read_only_fields = ['id']
    
    def validate_project(self, value):
        """Vérifier que l'utilisateur possède ce projet"""
        user = self.context['request'].user
        if value.user != user:
            raise serializers.ValidationError(
                "Vous ne pouvez pas ajouter une tâche à un projet qui ne vous appartient pas."
            )
        return value


class ProjectTaskMoveSerializer(serializers.Serializer):
    """Serializer pour déplacer une tâche (drag & drop)"""
    status = serializers.ChoiceField(
        choices=['TODO', 'IN_PROGRESS', 'DONE'],
        required=True
    )
    order = serializers.IntegerField(required=False, default=0)
    
    def validate_status(self, value):
        """Vérifier que le statut est valide"""
        if value not in ['TODO', 'IN_PROGRESS', 'DONE']:
            raise serializers.ValidationError("Statut invalide.")
        return value


class ProjectStatisticsSerializer(serializers.Serializer):
    """Serializer pour les statistiques globales"""
    total_projects = serializers.IntegerField()
    active_projects = serializers.IntegerField()
    completed_projects = serializers.IntegerField()
    archived_projects = serializers.IntegerField()
    overdue_projects = serializers.IntegerField()
    total_tasks = serializers.IntegerField()
    completed_tasks = serializers.IntegerField()
    completion_rate = serializers.FloatField()


# ========================================
# SERIALIZERS POUR LA GESTION ADMIN DES MATIÈRES
# ========================================

class SubjectCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour créer/modifier une matière"""
    levels = serializers.PrimaryKeyRelatedField(
        queryset=Level.objects.filter(is_active=True),
        many=True,
        required=True
    )
    majors = serializers.PrimaryKeyRelatedField(
        queryset=Major.objects.filter(is_active=True),
        many=True,
        required=True
    )
    
    class Meta:
        model = Subject
        fields = [
            'id',
            'name',
            'code',
            'description',
            'levels',
            'majors',
            'credits',
            'is_active',
            'is_featured',
            'order'
        ]
        read_only_fields = ['id']
    
    def validate_code(self, value):
        """Vérifier l'unicité du code"""
        instance = self.instance
        if instance:
            # Modification : exclure la matière actuelle
            if Subject.objects.filter(code=value).exclude(id=instance.id).exists():
                raise serializers.ValidationError("Ce code matière existe déjà.")
        else:
            # Création : vérifier l'unicité
            if Subject.objects.filter(code=value).exists():
                raise serializers.ValidationError("Ce code matière existe déjà.")
        return value
    
    def validate(self, data):
        """Validation croisée"""
        if 'levels' in data and not data['levels']:
            raise serializers.ValidationError({
                'levels': 'Au moins un niveau doit être sélectionné'
            })
        
        if 'majors' in data and not data['majors']:
            raise serializers.ValidationError({
                'majors': 'Au moins une filière doit être sélectionnée'
            })
        
        return data


class SubjectAdminDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé pour l'admin avec toutes les infos"""
    levels = LevelSerializer(many=True, read_only=True)
    majors = MajorSerializer(many=True, read_only=True)
    
    # Statistiques
    total_documents = serializers.IntegerField(read_only=True)
    total_quizzes = serializers.IntegerField(read_only=True)
    total_students = serializers.SerializerMethodField()
    assigned_teachers = serializers.SerializerMethodField()
    
    # Activité récente
    recent_activity = serializers.SerializerMethodField()
    
    class Meta:
        model = Subject
        fields = [
            'id',
            'name',
            'code',
            'description',
            'levels',
            'majors',
            'credits',
            'is_active',
            'is_featured',
            'order',
            'total_documents',
            'total_quizzes',
            'total_students',
            'assigned_teachers',
            'recent_activity',
            'created_at',
            'updated_at'
        ]
    
    def get_total_students(self, obj):
        """Nombre d'étudiants concernés par cette matière"""
        from accounts.models import StudentProfile
        
        return StudentProfile.objects.filter(
            level__in=obj.levels.all(),
            major__in=obj.majors.all()
        ).distinct().count()
    
    def get_assigned_teachers(self, obj):
        """Liste des professeurs assignés"""
        from accounts.models import TeacherAssignment
        
        assignments = TeacherAssignment.objects.filter(
            subject=obj,
            is_active=True
        ).select_related('teacher', 'teacher__teacher_profile')
        
        return [{
            'id': a.teacher.id,
            'full_name': a.teacher.get_full_name(),
            'email': a.teacher.email,
            'can_upload_documents': a.can_upload_documents,
            'can_edit_content': a.can_edit_content,
            'can_manage_students': a.can_manage_students
        } for a in assignments]
    
    def get_recent_activity(self, obj):
        """Activités récentes (7 derniers jours)"""
        from datetime import timedelta
        from django.utils import timezone
        
        week_ago = timezone.now() - timedelta(days=7)
        
        # Documents récents
        recent_docs = Document.objects.filter(
            subject=obj,
            created_at__gte=week_ago
        ).count()
        
        # Consultations récentes
        recent_views = UserActivity.objects.filter(
            subject=obj,
            action='view',
            created_at__gte=week_ago
        ).count()
        
        # Téléchargements récents
        recent_downloads = UserActivity.objects.filter(
            subject=obj,
            action='download',
            created_at__gte=week_ago
        ).count()
        
        return {
            'new_documents': recent_docs,
            'views': recent_views,
            'downloads': recent_downloads
        }


class SubjectAdminListSerializer(serializers.ModelSerializer):
    """Serializer simple pour la liste admin"""
    level_names = serializers.SerializerMethodField()
    major_names = serializers.SerializerMethodField()
    total_documents = serializers.IntegerField(read_only=True)
    total_teachers = serializers.SerializerMethodField()
    
    class Meta:
        model = Subject
        fields = [
            'id',
            'name',
            'code',
            'description',
            'level_names',
            'major_names',
            'credits',
            'is_active',
            'is_featured',
            'order',
            'total_documents',
            'total_teachers',
            'created_at'
        ]
    
    def get_level_names(self, obj):
        return [level.name for level in obj.levels.all()]
    
    def get_major_names(self, obj):
        return [major.name for major in obj.majors.all()]
    
    def get_total_teachers(self, obj):
        from accounts.models import TeacherAssignment
        return TeacherAssignment.objects.filter(
            subject=obj,
            is_active=True
        ).count()


class SubjectStatisticsSerializer(serializers.Serializer):
    """Serializer pour les statistiques d'une matière"""
    subject_id = serializers.IntegerField()
    subject_name = serializers.CharField()
    subject_code = serializers.CharField()
    
    # Documents
    total_documents = serializers.IntegerField()
    documents_by_type = serializers.DictField()
    most_viewed_documents = serializers.ListField()
    
    # Quiz
    total_quizzes = serializers.IntegerField()
    active_quizzes = serializers.IntegerField()
    average_quiz_score = serializers.FloatField()
    
    # Étudiants
    total_students = serializers.IntegerField()
    active_students = serializers.IntegerField()
    
    # Professeurs
    total_teachers = serializers.IntegerField()
    
    # Activité
    total_views = serializers.IntegerField()
    total_downloads = serializers.IntegerField()
    views_last_30_days = serializers.IntegerField()


# ========================================
# SERIALIZERS POUR LA GESTION DES QUIZ (ADMIN + PROFESSEUR)
# ========================================

class ChoiceCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour créer/modifier un choix de réponse"""
    
    class Meta:
        model = Choice
        fields = ['id', 'text', 'is_correct', 'order']
        read_only_fields = ['id']
    
    def validate_text(self, value):
        """Vérifier que le texte n'est pas vide"""
        if not value or not value.strip():
            raise serializers.ValidationError("Le texte du choix ne peut pas être vide.")
        return value.strip()


class QuestionCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour créer/modifier une question avec ses choix"""
    choices = ChoiceCreateUpdateSerializer(many=True)
    
    class Meta:
        model = Question
        fields = ['id', 'text', 'question_type', 'points', 'order', 'explanation', 'choices']
        read_only_fields = ['id']
    
    def validate_text(self, value):
        """Vérifier que la question n'est pas vide"""
        if not value or not value.strip():
            raise serializers.ValidationError("Le texte de la question ne peut pas être vide.")
        return value.strip()
    
    def validate_points(self, value):
        """Vérifier que les points sont positifs"""
        if value <= 0:
            raise serializers.ValidationError("Les points doivent être supérieurs à 0.")
        return value
    
    def validate(self, data):
        """Validation croisée"""
        choices = data.get('choices', [])
        question_type = data.get('question_type')
        
        # Vérifier qu'il y a au moins 2 choix
        if len(choices) < 2:
            raise serializers.ValidationError({
                'choices': 'Une question doit avoir au moins 2 choix de réponse.'
            })
        
        # Vérifier qu'il y a au moins une bonne réponse
        correct_choices = [c for c in choices if c.get('is_correct', False)]
        if not correct_choices:
            raise serializers.ValidationError({
                'choices': 'Au moins un choix doit être marqué comme correct.'
            })
        
        # Validation selon le type de question
        if question_type == 'QCM':
            # QCM : une seule bonne réponse
            if len(correct_choices) != 1:
                raise serializers.ValidationError({
                    'choices': 'Un QCM doit avoir exactement UNE bonne réponse.'
                })
        
        elif question_type == 'TRUE_FALSE':
            # Vrai/Faux : exactement 2 choix, 1 correct
            if len(choices) != 2:
                raise serializers.ValidationError({
                    'choices': 'Une question Vrai/Faux doit avoir exactement 2 choix.'
                })
            if len(correct_choices) != 1:
                raise serializers.ValidationError({
                    'choices': 'Une question Vrai/Faux doit avoir exactement 1 bonne réponse.'
                })
        
        elif question_type == 'MULTIPLE':
            # Choix multiples : au moins 2 bonnes réponses
            if len(correct_choices) < 2:
                raise serializers.ValidationError({
                    'choices': 'Une question à choix multiples doit avoir au moins 2 bonnes réponses.'
                })
        
        return data
    
    def create(self, validated_data):
        """Créer la question avec ses choix"""
        choices_data = validated_data.pop('choices')
        question = Question.objects.create(**validated_data)
        
        # Créer les choix
        for choice_data in choices_data:
            Choice.objects.create(question=question, **choice_data)
        
        return question
    
    def update(self, instance, validated_data):
        """Mettre à jour la question et ses choix"""
        choices_data = validated_data.pop('choices', None)
        
        # Mettre à jour les champs de la question
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Mettre à jour les choix si fournis
        if choices_data is not None:
            # Supprimer les anciens choix
            instance.choices.all().delete()
            
            # Créer les nouveaux choix
            for choice_data in choices_data:
                Choice.objects.create(question=instance, **choice_data)
        
        return instance


class QuizCreateUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour créer/modifier un quiz complet avec questions"""
    questions = QuestionCreateUpdateSerializer(many=True, required=False)
    
    class Meta:
        model = Quiz
        fields = [
            'id',
            'subject',
            'title',
            'description',
            'duration_minutes',
            'passing_percentage',
            'max_attempts',
            'show_correction',
            'is_active',
            'available_from',
            'available_until',
            'questions'
        ]
        read_only_fields = ['id', 'created_by', 'created_at', 'updated_at']
    
    def validate_title(self, value):
        """Vérifier que le titre n'est pas vide"""
        if not value or not value.strip():
            raise serializers.ValidationError("Le titre ne peut pas être vide.")
        return value.strip()
    
    def validate_duration_minutes(self, value):
        """Vérifier la durée"""
        if value < 1:
            raise serializers.ValidationError("La durée doit être d'au moins 1 minute.")
        if value > 180:
            raise serializers.ValidationError("La durée ne peut pas dépasser 180 minutes (3 heures).")
        return value
    
    def validate_passing_percentage(self, value):
        """Vérifier le pourcentage de réussite"""
        if value < 0 or value > 100:
            raise serializers.ValidationError("Le pourcentage doit être entre 0 et 100.")
        return value
    
    def validate_max_attempts(self, value):
        """Vérifier le nombre de tentatives"""
        if value < 1:
            raise serializers.ValidationError("Il doit y avoir au moins 1 tentative autorisée.")
        if value > 10:
            raise serializers.ValidationError("Le nombre maximum de tentatives ne peut pas dépasser 10.")
        return value
    
    def validate(self, data):
        """Validation croisée"""
        # Vérifier les dates
        available_from = data.get('available_from')
        available_until = data.get('available_until')
        
        if available_from and available_until:
            if available_from >= available_until:
                raise serializers.ValidationError({
                    'available_until': 'La date de fin doit être après la date de début.'
                })
        
        return data
    
    def create(self, validated_data):
        """Créer le quiz avec ses questions"""
        questions_data = validated_data.pop('questions', [])
        
        # Ajouter le créateur
        request = self.context.get('request')
        if request and request.user:
            validated_data['created_by'] = request.user
        
        # Créer le quiz
        quiz = Quiz.objects.create(**validated_data)
        
        # Créer les questions
        for question_data in questions_data:
            choices_data = question_data.pop('choices')
            question = Question.objects.create(quiz=quiz, **question_data)
            
            # Créer les choix
            for choice_data in choices_data:
                Choice.objects.create(question=question, **choice_data)
        
        return quiz
    
    def update(self, instance, validated_data):
        """Mettre à jour le quiz"""
        questions_data = validated_data.pop('questions', None)
        
        # Mettre à jour les champs du quiz
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Mettre à jour les questions si fournies
        if questions_data is not None:
            # Supprimer les anciennes questions (cascade sur les choix)
            instance.questions.all().delete()
            
            # Créer les nouvelles questions
            for question_data in questions_data:
                choices_data = question_data.pop('choices')
                question = Question.objects.create(quiz=instance, **question_data)
                
                # Créer les choix
                for choice_data in choices_data:
                    Choice.objects.create(question=question, **choice_data)
        
        return instance


class QuizAdminListSerializer(serializers.ModelSerializer):
    """Serializer simple pour la liste des quiz (Admin)"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    
    # ✅ Ces champs utiliseront les propriétés du modèle
    question_count = serializers.ReadOnlyField()
    total_attempts = serializers.SerializerMethodField()
    
    class Meta:
        model = Quiz
        fields = [
            'id',
            'title',
            'subject',
            'subject_name',
            'subject_code',
            'duration_minutes',
            'passing_percentage',
            'max_attempts',
            'is_active',
            'question_count',
            'total_attempts',
            'created_by_name',
            'created_at',
            'available_from',
            'available_until'
        ]
    
    def get_total_attempts(self, obj):
        """Compter les tentatives"""
        return obj.attempts.count()


class QuizAdminDetailSerializer(serializers.ModelSerializer):
    """Serializer détaillé pour un quiz (Admin)"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    created_by_name = serializers.CharField(source='created_by.get_full_name', read_only=True)
    questions = QuestionWithAnswerSerializer(many=True, read_only=True)
    question_count = serializers.IntegerField(read_only=True)
    total_points = serializers.SerializerMethodField()

    
    # Statistiques
    total_attempts = serializers.SerializerMethodField()
    completed_attempts = serializers.SerializerMethodField()
    average_score = serializers.SerializerMethodField()
    pass_rate = serializers.SerializerMethodField()
    
    class Meta:
        model = Quiz
        fields = [
            'id',
            'title',
            'description',
            'subject',
            'subject_name',
            'subject_code',
            'duration_minutes',
            'passing_percentage',
            'max_attempts',
            'show_correction',
            'is_active',
            'available_from',
            'available_until',
            'question_count',
            'total_points',
            'questions',
            'total_attempts',
            'completed_attempts',
            'average_score',
            'pass_rate',
            'created_by',
            'created_by_name',
            'created_at',
            'updated_at'
        ]

    def get_total_points(self, obj):
        """Total des points du quiz"""
        return float(obj.total_points)
    
    def get_total_attempts(self, obj):
        """Nombre total de tentatives"""
        return QuizAttempt.objects.filter(quiz=obj).count()
    
    def get_completed_attempts(self, obj):
        """Nombre de tentatives terminées"""
        return QuizAttempt.objects.filter(quiz=obj, status='COMPLETED').count()
    
    def get_average_score(self, obj):
        """Score moyen"""
        avg = QuizAttempt.objects.filter(
            quiz=obj,
            status='COMPLETED'
        ).aggregate(avg=Avg('score'))['avg']
        
        if avg and obj.total_points > 0:
            # Normaliser sur 20
            return round((float(avg) / float(obj.total_points)) * 20, 2)
        return 0
    
    def get_pass_rate(self, obj):
        """Taux de réussite"""
        completed = QuizAttempt.objects.filter(quiz=obj, status='COMPLETED')
        total = completed.count()
        
        if total == 0:
            return 0
        
        passed = completed.filter(score__gte=obj.passing_percentage).count()
        return round((passed / total) * 100, 1)


# ========================================
# SERIALIZERS POUR LE DASHBOARD PROFESSEUR
# ========================================

class TeacherDashboardStatsSerializer(serializers.Serializer):
    """Statistiques pour le dashboard du professeur"""
    
    # Matières
    total_subjects = serializers.IntegerField()
    active_subjects = serializers.IntegerField()
    
    # Documents
    total_documents = serializers.IntegerField()
    my_documents = serializers.IntegerField()
    documents_this_month = serializers.IntegerField()
    
    # Quiz
    total_quizzes = serializers.IntegerField()
    active_quizzes = serializers.IntegerField()
    quizzes_this_month = serializers.IntegerField()
    
    # Étudiants
    total_students = serializers.IntegerField()
    active_students = serializers.IntegerField()
    
    # Activité récente
    views_this_week = serializers.IntegerField()
    downloads_this_week = serializers.IntegerField()
    quiz_attempts_this_week = serializers.IntegerField()


class TeacherSubjectPerformanceSerializer(serializers.Serializer):
    """Performance par matière pour le professeur"""
    subject_id = serializers.IntegerField()
    subject_name = serializers.CharField()
    subject_code = serializers.CharField()
    
    # Contenus
    document_count = serializers.IntegerField()
    quiz_count = serializers.IntegerField()
    
    # Étudiants
    student_count = serializers.IntegerField()
    active_students = serializers.IntegerField()
    
    # Activité
    total_views = serializers.IntegerField()
    total_downloads = serializers.IntegerField()
    quiz_attempts = serializers.IntegerField()
    
    # Performance quiz
    average_quiz_score = serializers.FloatField()
    quiz_pass_rate = serializers.FloatField()


class TeacherRecentActivitySerializer(serializers.Serializer):
    """Activités récentes du professeur"""
    activity_type = serializers.CharField()
    title = serializers.CharField()
    description = serializers.CharField()
    subject_name = serializers.CharField(required=False)
    student_name = serializers.CharField(required=False)
    created_at = serializers.DateTimeField()
    icon = serializers.CharField()
    color = serializers.CharField()


class TeacherQuizAttemptListSerializer(serializers.ModelSerializer):
    """Liste des tentatives de quiz pour un professeur"""
    student_name = serializers.CharField(source='user.get_full_name', read_only=True)
    student_email = serializers.EmailField(source='user.email', read_only=True)
    quiz_title = serializers.CharField(source='quiz.title', read_only=True)
    quiz_passing_percentage = serializers.DecimalField(
        source='quiz.passing_percentage',
        max_digits=5,
        decimal_places=2,
        read_only=True
    )
    score_percentage = serializers.SerializerMethodField()
    is_passed = serializers.SerializerMethodField()
    duration_seconds = serializers.SerializerMethodField()
    
    class Meta:
        model = QuizAttempt
        fields = [
            'id',
            'user',
            'student_name',
            'student_email',
            'quiz',
            'quiz_title',
            'status',
            'score',
            'quiz_passing_percentage',
            'score_percentage',
            'is_passed',
            'started_at',
            'completed_at',
            'duration_seconds'
        ]
    
    def get_score_percentage(self, obj):
        """Calculer le pourcentage de score"""
        # ✅ CORRECTION : Vérifier que total_points et score ne sont pas None
        if obj.quiz.total_points and obj.quiz.total_points > 0 and obj.score is not None:
            return round((float(obj.score) / float(obj.quiz.total_points)) * 100, 1)
        return 0
    
    def get_is_passed(self, obj):
        """Vérifier si l'étudiant a réussi"""
        if obj.status == 'COMPLETED':
            # ✅ CORRECTION : Vérifier que total_points n'est pas None
            if obj.quiz.total_points and obj.quiz.total_points > 0 and obj.score is not None:
                percentage = (float(obj.score) / float(obj.quiz.total_points)) * 100
                return percentage >= float(obj.quiz.passing_percentage)
            return False
        return None
    
    def get_duration_seconds(self, obj):
        """Calculer la durée en secondes"""
        if obj.completed_at and obj.started_at:
            delta = obj.completed_at - obj.started_at
            return int(delta.total_seconds())
        return None


class TeacherStudentProgressSerializer(serializers.Serializer):
    """Progression d'un étudiant pour un professeur"""
    student_id = serializers.IntegerField()
    student_name = serializers.CharField()
    student_email = serializers.EmailField()
    level = serializers.CharField()
    major = serializers.CharField()
    
    # Activité générale
    total_views = serializers.IntegerField()
    total_downloads = serializers.IntegerField()
    last_activity = serializers.DateTimeField()
    
    # Quiz
    quiz_attempts = serializers.IntegerField()
    quiz_completed = serializers.IntegerField()
    average_score = serializers.FloatField()
    quizzes_passed = serializers.IntegerField()
    
    # Par matière
    subjects_progress = serializers.ListField()


# courses/serializers.py

class DocumentUpdateSerializer(serializers.ModelSerializer):
    """Serializer pour modifier un document (professeur)"""
    
    class Meta:
        model = Document
        fields = [
            'title',
            'description',
            'document_type',
            'is_active'
        ]
    
    def validate_title(self, value):
        """Le titre est obligatoire"""
        if not value or not value.strip():
            raise serializers.ValidationError("Le titre est obligatoire")
        return value.strip()
    
    def validate_document_type(self, value):
        """Valider le type de document"""
        valid_types = ['COURS', 'TD', 'TP', 'ARCHIVE']
        if value not in valid_types:
            raise serializers.ValidationError(
                f"Type invalide. Choisissez parmi: {', '.join(valid_types)}"
            )
        return value


class SubjectUpdateByTeacherSerializer(serializers.ModelSerializer):
    """Serializer pour qu'un professeur modifie une matière (si permission)"""
    
    class Meta:
        model = Subject
        fields = [
            'description',
            'is_featured'
        ]
    
    def validate(self, data):
        """Vérifier que le professeur a la permission can_edit_content"""
        request = self.context.get('request')
        subject = self.instance
        
        if request and request.user.role == 'TEACHER':
            from accounts.permissions import can_edit_subject_content
            if not can_edit_subject_content(request.user, subject):
                raise serializers.ValidationError(
                    "Vous n'avez pas la permission de modifier cette matière"
                )
        
        return data