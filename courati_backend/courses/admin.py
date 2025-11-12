# courses/admin.py
from django.contrib import admin
from django.utils.html import format_html
from django.urls import reverse, path
from django.utils.safestring import mark_safe
from django.db.models import Count, Q, Avg
from django.http import HttpResponse
from django.utils.safestring import mark_safe
import csv

from .models import (
    Subject, Document, UserFavorite, UserProgress, UserActivity,
    Quiz, Question, Choice, QuizAttempt, StudentAnswer, StudentProject, ProjectTask,
)
from accounts.permissions import get_teacher_subjects


# ==================== INLINES ====================

class DocumentInline(admin.TabularInline):
    """Inline pour afficher les documents dans l'interface matière"""
    model = Document
    extra = 0
    fields = ['title', 'document_type', 'file', 'is_active', 'order']
    readonly_fields = []
    
    def get_queryset(self, request):
        qs = super().get_queryset(request).filter(is_active=True)
        
        if request.user.role == 'TEACHER':
            teacher_subjects = get_teacher_subjects(request.user)
            return qs.filter(subject__in=teacher_subjects)
        
        return qs
    
    def has_add_permission(self, request, obj=None):
        if request.user.role == 'ADMIN':
            return True
        if request.user.role == 'TEACHER' and obj:
            from accounts.permissions import can_upload_document
            return can_upload_document(request.user, obj)
        return False


class ChoiceInline(admin.TabularInline):
    """Inline pour gérer les choix de réponse directement dans la question"""
    model = Choice
    extra = 4  # 4 choix par défaut
    fields = ['text', 'is_correct', 'order']
    ordering = ['order']


class QuestionInline(admin.StackedInline):
    model = Question
    extra = 5  # 5 questions à la fois
    fields = ['order', 'text', 'question_type', 'points']
    classes = ['collapse'] 


# ==================== ADMIN MATIÈRES ====================

@admin.register(Subject)
class SubjectAdmin(admin.ModelAdmin):
    """Interface admin pour les matières"""
    
    list_display = [
        'code', 'name', 'get_levels', 'get_majors', 
        'credits', 'is_active', 'is_featured', 
        'document_stats', 'created_at'
    ]
    list_filter = [
        'is_active', 'is_featured', 
        'levels', 'majors', 'created_at'
    ]
    search_fields = ['name', 'code', 'description']
    filter_horizontal = ['levels', 'majors']
    readonly_fields = ['created_at', 'updated_at', 'document_stats']
    
    fieldsets = (
        ('Informations principales', {
            'fields': ('name', 'code', 'description'),
        }),
        ('Classification académique', {
            'fields': ('levels', 'majors', 'credits'),
        }),
        ('Gestion', {
            'fields': ('is_active', 'is_featured', 'order')
        }),
        ('Statistiques', {
            'fields': ('document_stats', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )
    
    inlines = [DocumentInline]
    
    def get_queryset(self, request):
        qs = super().get_queryset(request).prefetch_related('levels', 'majors')
        
        if request.user.role == 'ADMIN':
            return qs
        
        if request.user.role == 'TEACHER':
            return get_teacher_subjects(request.user)
        
        return qs.none()
    
    def has_add_permission(self, request):
        return request.user.role == 'ADMIN'
    
    def has_change_permission(self, request, obj=None):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            if obj is None:
                return True
            from accounts.permissions import has_subject_access
            return has_subject_access(request.user, obj)
        
        return False
    
    def has_delete_permission(self, request, obj=None):
        return request.user.role == 'ADMIN'
    
    def has_view_permission(self, request, obj=None):
        if request.user.role in ['ADMIN', 'TEACHER']:
            return True
        return False
    
    def get_levels(self, obj):
        return ", ".join([level.name for level in obj.levels.all()[:3]])
    get_levels.short_description = 'Niveaux'
    
    def get_majors(self, obj):
        return ", ".join([major.name for major in obj.majors.all()[:2]])
    get_majors.short_description = 'Filières'
    
    def document_stats(self, obj):
        if obj.pk:
            stats = obj.documents.filter(is_active=True).values('document_type').annotate(
                count=Count('id')
            )
            
            if not stats:
                return "Aucun document"
                
            stats_html = []
            for stat in stats:
                doc_type = stat['document_type']
                count = stat['count']
                stats_html.append(f"<span style='margin-right:10px;'><strong>{doc_type}:</strong> {count}</span>")
            
            return format_html("".join(stats_html))
        return "Nouvelle matière"
    document_stats.short_description = 'Documents par type'


# ==================== ADMIN DOCUMENTS ====================

@admin.register(Document)
class DocumentAdmin(admin.ModelAdmin):
    """Interface admin pour les documents avec permissions professeurs"""
    
    list_display = [
        'title', 'subject_link', 'document_type', 'file_size_display',
        'download_count', 'is_active', 'created_at'
    ]
    list_filter = [
        'document_type',
        'is_active', 
        'subject',
        'created_at'
    ]
    search_fields = [
        'title', 'description', 
        'subject__name', 'subject__code'
    ]
    list_editable = ['is_active']
    readonly_fields = ['created_at', 'updated_at', 'file_size', 'download_count', 'view_count']
    
    fieldsets = (
        ('Document', {
            'fields': ('title', 'description', 'subject', 'document_type'),
        }),
        ('Fichier', {
            'fields': ('file', 'file_size'),
        }),
        ('Paramètres', {
            'fields': ('is_active', 'is_premium', 'order')
        }),
        ('Statistiques', {
            'fields': ('view_count', 'download_count', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )
    
    def get_queryset(self, request):
        qs = super().get_queryset(request).select_related('subject', 'created_by')
        
        if request.user.role == 'ADMIN':
            return qs
        
        if request.user.role == 'TEACHER':
            teacher_subjects = get_teacher_subjects(request.user)
            return qs.filter(subject__in=teacher_subjects)
        
        return qs.none()
    
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "subject":
            if request.user.role == 'TEACHER':
                kwargs["queryset"] = get_teacher_subjects(request.user)
            elif request.user.role == 'ADMIN':
                kwargs["queryset"] = Subject.objects.filter(is_active=True)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)
    
    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
    
    def has_add_permission(self, request):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            teacher_subjects = get_teacher_subjects(request.user)
            return teacher_subjects.exists()
        
        return False
    
    def has_change_permission(self, request, obj=None):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            if obj is None:
                return True
            from accounts.permissions import has_subject_access
            return has_subject_access(request.user, obj.subject)
        
        return False
    
    def has_delete_permission(self, request, obj=None):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            if obj is None:
                return True
            from accounts.permissions import has_subject_access
            return has_subject_access(request.user, obj.subject)
        
        return False
    
    def has_view_permission(self, request, obj=None):
        if request.user.role in ['ADMIN', 'TEACHER']:
            return True
        return False
    
    def subject_link(self, obj):
        url = reverse('admin:courses_subject_change', args=[obj.subject.id])
        return format_html(
            '<a href="{}">{} ({})</a>', 
            url, obj.subject.name, obj.subject.code
        )
    subject_link.short_description = 'Matière'
    
    def file_size_display(self, obj):
        if obj.file_size:
            return f"{obj.file_size_mb} MB"
        return "N/A"
    file_size_display.short_description = 'Taille'


# ==================== ADMIN QUIZ ====================

@admin.register(Question)
class QuestionAdmin(admin.ModelAdmin):
    list_display = ['get_question_preview', 'quiz', 'question_type', 'points', 'order', 'choice_count']
    list_filter = ['question_type', 'quiz__subject', 'quiz']
    search_fields = ['text', 'quiz__title']
    ordering = ['quiz', 'order']
    inlines = [ChoiceInline]
    
    fieldsets = (
        ('Informations générales', {
            'fields': ('quiz', 'question_type', 'points', 'order')
        }),
        ('Question', {
            'fields': ('text', 'explanation'),
            'description': 'L\'explication sera affichée après la correction'
        }),
    )
    
    def get_question_preview(self, obj):
        preview = obj.text[:60] + '...' if len(obj.text) > 60 else obj.text
        return format_html('<strong>Q{}</strong>: {}', obj.order, preview)
    get_question_preview.short_description = 'Question'
    
    def choice_count(self, obj):
        count = obj.choices.count()
        correct = obj.choices.filter(is_correct=True).count()
        return format_html(
            '<span style="color: {};">{} choix ({} correcte(s))</span>',
            'red' if correct == 0 else 'green',
            count,
            correct
        )
    choice_count.short_description = 'Choix'


@admin.register(Choice)
class ChoiceAdmin(admin.ModelAdmin):
    list_display = ['get_choice_preview', 'question', 'is_correct_display', 'order']
    list_filter = ['is_correct', 'question__quiz']
    search_fields = ['text', 'question__text']
    ordering = ['question', 'order']
    
    def get_choice_preview(self, obj):
        return obj.text[:50] + '...' if len(obj.text) > 50 else obj.text
    get_choice_preview.short_description = 'Texte du choix'
    
    def is_correct_display(self, obj):
        if obj.is_correct:
            return format_html('<span style="color: green; font-weight: bold;">✓ Correcte</span>')
        return format_html('<span style="color: gray;">✗ Incorrecte</span>')
    is_correct_display.short_description = 'Statut'


@admin.register(Quiz)
class QuizAdmin(admin.ModelAdmin):
    list_display = [
        'title', 
        'subject', 
        'duration_minutes', 
        'passing_percentage_display',
        'total_points_display',
        'question_count_display',
        'is_active',
        'statistics_link',
        'created_at'
    ]
    list_filter = ['is_active', 'subject', 'created_at', 'show_correction']
    search_fields = ['title', 'description', 'subject__name']
    readonly_fields = ['created_by', 'created_at', 'updated_at', 'statistics_summary']
    inlines = [QuestionInline]
    
    fieldsets = (
        ('Informations de base', {
            'fields': ('title', 'description', 'subject', 'is_active'),
            'description': '⚠️ Créez d\'abord le quiz, puis ajoutez les CHOIX en cliquant sur chaque question ci-dessous après sauvegarde.'
        }),
        
        ('Configuration du quiz', {
            'fields': (
                'duration_minutes', 
                'passing_percentage',
                'max_attempts', 
                'show_correction'
            ),
            'description': 'Le score de passage est calculé automatiquement : passing_percentage × total_points / 100'
        }),
        ('Disponibilité', {
            'fields': ('available_from', 'available_until'),
            'classes': ('collapse',),
            'description': 'Laisser vide pour une disponibilité immédiate et illimitée'
        }),
        ('Métadonnées', {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',),
        }),
        ('Statistiques', {
            'fields': ('statistics_summary',),
            'classes': ('collapse',),
        }),
    )
    
    actions = ['duplicate_quiz', 'activate_quizzes', 'deactivate_quizzes', 'export_statistics']
    
    # ✅ INDENTATION CORRECTE - 4 espaces depuis le début
    def passing_percentage_display(self, obj):
        """Affiche le pourcentage de réussite"""
        return f"{obj.passing_percentage}%"
    passing_percentage_display.short_description = "% requis"

    def total_points_display(self, obj):
        """Affiche le score de passage calculé et le total"""
        passing = float(obj.passing_percentage)
        total = float(obj.total_points)
        percentage = float(obj.passing_percentage)
        
        if total > 0:
           
            return mark_safe(
                f'<strong>{passing:.1f}/{total:.0f} pts</strong> '
                f'<span style="color: gray;">({percentage:.0f}%)</span>'
            )
        return mark_safe('<span style="color: red;">⚠ Aucune question</span>')
    total_points_display.short_description = "Score requis"
    def get_queryset(self, request):
        qs = super().get_queryset(request)
        
        if request.user.role == 'ADMIN':
            return qs
        
        if request.user.role == 'TEACHER':
            teacher_subjects = get_teacher_subjects(request.user)
            return qs.filter(subject__in=teacher_subjects)
        
        return qs.none()
    
    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        if db_field.name == "subject":
            if request.user.role == 'TEACHER':
                kwargs["queryset"] = get_teacher_subjects(request.user)
            elif request.user.role == 'ADMIN':
                kwargs["queryset"] = Subject.objects.filter(is_active=True)
        return super().formfield_for_foreignkey(db_field, request, **kwargs)
    
    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)
    
    def has_add_permission(self, request):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            teacher_subjects = get_teacher_subjects(request.user)
            return teacher_subjects.exists()
        
        return False
    
    def has_change_permission(self, request, obj=None):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            if obj is None:
                return True
            from accounts.permissions import has_subject_access
            return has_subject_access(request.user, obj.subject)
        
        return False
    
    def has_delete_permission(self, request, obj=None):
        if request.user.role == 'ADMIN':
            return True
        
        if request.user.role == 'TEACHER':
            if obj is None:
                return True
            from accounts.permissions import has_subject_access
            return has_subject_access(request.user, obj.subject)
        
        return False
    
    def question_count_display(self, obj):
        count = obj.question_count
        if count == 0:
            return format_html('<span style="color: red;">⚠ Aucune question</span>')
        return format_html('<span style="color: green;">{} questions</span>', count)
    question_count_display.short_description = 'Questions'
    
    
    def statistics_link(self, obj):
        if obj.pk:
            attempts_count = QuizAttempt.objects.filter(quiz=obj, status='COMPLETED').count()
            if attempts_count > 0:
                url = reverse('admin:courses_quiz_statistics', args=[obj.pk])
                return format_html(
                    '<a href="{}" style="color: blue;">📊 {} tentatives</a>',
                    url,
                    attempts_count
                )
            return format_html('<span style="color: gray;">Pas encore de tentatives</span>')
        return '-'
    statistics_link.short_description = 'Statistiques'
    
    def statistics_summary(self, obj):
        if not obj.pk:
            return "Les statistiques seront disponibles après création du quiz"
        
        attempts = QuizAttempt.objects.filter(quiz=obj)
        completed = attempts.filter(status='COMPLETED')
        
        if completed.count() == 0:
            return mark_safe('<p style="color: gray;">Aucune tentative complétée pour le moment</p>')
        
        avg_score = completed.aggregate(avg=Avg('score'))['avg'] or 0
        passed = completed.filter(score__gte=obj.passing_percentage).count()
        pass_rate = (passed / completed.count() * 100) if completed.count() > 0 else 0
        
        html = f"""
        <div style="background: #f8f9fa; padding: 15px; border-radius: 5px;">
            <h3 style="margin-top: 0;">📊 Résumé des statistiques</h3>
            <ul style="list-style: none; padding: 0;">
                <li><strong>Total tentatives :</strong> {attempts.count()}</li>
                <li><strong>Tentatives complétées :</strong> {completed.count()}</li>
                <li><strong>Note moyenne :</strong> {avg_score:.2f}/{obj.total_points}</li>
                <li><strong>Taux de réussite :</strong> {pass_rate:.1f}% ({passed}/{completed.count()})</li>
            </ul>
            <a href="{reverse('admin:courses_quiz_statistics', args=[obj.pk])}" 
               style="background: #0066cc; color: white; padding: 8px 15px; 
                      text-decoration: none; border-radius: 3px; display: inline-block;">
                Voir statistiques détaillées
            </a>
        </div>
        """
        return mark_safe(html)
    statistics_summary.short_description = 'Statistiques du quiz'
    
    def duplicate_quiz(self, request, queryset):
        for quiz in queryset:
            new_quiz = Quiz.objects.get(pk=quiz.pk)
            new_quiz.pk = None
            new_quiz.title = f"{quiz.title} (Copie)"
            new_quiz.is_active = False
            new_quiz.created_by = request.user
            new_quiz.save()
            
            for question in quiz.questions.all():
                old_question_id = question.pk
                question.pk = None
                question.quiz = new_quiz
                question.save()
                
                for choice in Question.objects.get(pk=old_question_id).choices.all():
                    choice.pk = None
                    choice.question = question
                    choice.save()
        
        self.message_user(request, f"{queryset.count()} quiz dupliqué(s) avec succès")
    duplicate_quiz.short_description = "Dupliquer les quiz sélectionnés"
    
    def activate_quizzes(self, request, queryset):
        updated = queryset.update(is_active=True)
        self.message_user(request, f"{updated} quiz activé(s)")
    activate_quizzes.short_description = "Activer les quiz sélectionnés"
    
    def deactivate_quizzes(self, request, queryset):
        updated = queryset.update(is_active=False)
        self.message_user(request, f"{updated} quiz désactivé(s)")
    deactivate_quizzes.short_description = "Désactiver les quiz sélectionnés"
    
    def export_statistics(self, request, queryset):
        response = HttpResponse(content_type='text/csv')
        response['Content-Disposition'] = 'attachment; filename="quiz_statistics.csv"'
        response.write('\ufeff'.encode('utf8'))
        
        writer = csv.writer(response, delimiter=';')
        writer.writerow([
            'Quiz', 'Matière', 'Total tentatives', 'Complétées',
            'Note moyenne', 'Taux de réussite (%)'
        ])
        
        for quiz in queryset:
            attempts = QuizAttempt.objects.filter(quiz=quiz)
            completed = attempts.filter(status='COMPLETED')
            avg_score = completed.aggregate(avg=Avg('score'))['avg'] or 0
            passed = completed.filter(score__gte=quiz.passing_percentage).count()
            pass_rate = (passed / completed.count() * 100) if completed.count() > 0 else 0
            
            writer.writerow([
                quiz.title,
                quiz.subject.name,
                attempts.count(),
                completed.count(),
                f"{avg_score:.2f}",
                f"{pass_rate:.1f}"
            ])
        
        return response
    export_statistics.short_description = "Exporter les statistiques (CSV)"
    
    def get_urls(self):
        urls = super().get_urls()
        custom_urls = [
            path(
                '<int:quiz_id>/statistics/',
                self.admin_site.admin_view(self.statistics_view),
                name='courses_quiz_statistics',
            ),
        ]
        return custom_urls + urls
    
    def statistics_view(self, request, quiz_id):
        from django.shortcuts import render
        
        quiz = Quiz.objects.get(pk=quiz_id)
        attempts = QuizAttempt.objects.filter(quiz=quiz)
        completed = attempts.filter(status='COMPLETED')
        
        stats = {
            'quiz': quiz,
            'total_attempts': attempts.count(),
            'completed_attempts': completed.count(),
            'in_progress': attempts.filter(status='IN_PROGRESS').count(),
            'abandoned': attempts.filter(status='ABANDONED').count(),
        }
        
        if completed.count() > 0:
            avg_score = completed.aggregate(avg=Avg('score'))['avg'] or 0
            passed = completed.filter(score__gte=quiz.passing_percentage).count()
            stats['average_score'] = avg_score
            stats['pass_rate'] = (passed / completed.count() * 100)
            stats['passed_count'] = passed
            stats['failed_count'] = completed.count() - passed
        
        question_stats = []
        for question in quiz.questions.all():
            answers = StudentAnswer.objects.filter(question=question)
            total = answers.count()
            correct = answers.filter(is_correct=True).count()
            error_rate = ((total - correct) / total * 100) if total > 0 else 0
            
            question_stats.append({
                'question': question,
                'total_answers': total,
                'correct_answers': correct,
                'error_rate': error_rate
            })
        
        question_stats.sort(key=lambda x: x['error_rate'], reverse=True)
        stats['question_stats'] = question_stats
        stats['recent_attempts'] = completed.select_related('user').order_by('-completed_at')[:10]
        
        return render(request, 'admin/quiz_statistics.html', stats)
        


# courses/admin.py

@admin.register(QuizAttempt)
class QuizAttemptAdmin(admin.ModelAdmin):
    list_display = [
        'user',
        'quiz',
        'get_major_display',  # ← NOUVEAU
        'status_display',
        'score_display',
        'attempt_number',
        'started_at',
        'time_spent_display'
    ]
    list_filter = [
        'status', 
        'quiz', 
        'quiz__subject__majors',  # ← NOUVEAU : Filtrer par filière
        'started_at'
    ]
    search_fields = ['user__username', 'user__email', 'quiz__title']
    readonly_fields = [
        'user', 'quiz', 'attempt_number', 
        'started_at', 'completed_at', 
        'user_profile_info',  # ← NOUVEAU
        'answers_summary'
    ]
    
    fieldsets = (
        ('Informations générales', {
            'fields': ('user', 'user_profile_info', 'quiz', 'status', 'attempt_number')  # ← MODIFIÉ
        }),
        ('Résultats', {
            'fields': ('score', 'started_at', 'completed_at'),
        }),
        ('Détails des réponses', {
            'fields': ('answers_summary',),
            'classes': ('collapse',)
        }),
    )
    
    # ✅ NOUVEAU : Afficher la filière de l'étudiant
    def get_major_display(self, obj):
        """Affiche la filière de l'étudiant AU MOMENT de la tentative"""
        try:
            profile = obj.user.student_profile
            major_name = profile.major.name if profile.major else "Non définie"
            
            # Vérifier si le quiz est toujours dans cette filière
            quiz_majors = obj.quiz.subject.majors.all()
            is_current = profile.major in quiz_majors if profile.major else False
            
            if is_current:
                return format_html(
                    '<span style="color: green;">✓ {}</span>',
                    major_name
                )
            else:
                return format_html(
                    '<span style="color: orange;" title="Filière changée">⚠ {}</span>',
                    major_name
                )
        except:
            return format_html('<span style="color: gray;">-</span>')
    get_major_display.short_description = 'Filière actuelle'
    
    # ✅ NOUVEAU : Afficher info profil complet
    def user_profile_info(self, obj):
        """Affiche le profil complet de l'étudiant"""
        try:
            profile = obj.user.student_profile
            
            html = '<div style="background: #f8f9fa; padding: 10px; border-radius: 5px;">'
            html += f'<p><strong>Niveau actuel:</strong> {profile.level.name if profile.level else "Non défini"}</p>'
            html += f'<p><strong>Filière actuelle:</strong> {profile.major.name if profile.major else "Non définie"}</p>'
            
            # Vérifier si la tentative correspond à la filière actuelle
            quiz_majors = obj.quiz.subject.majors.all()
            quiz_levels = obj.quiz.subject.levels.all()
            
            is_major_match = profile.major in quiz_majors if profile.major else False
            is_level_match = profile.level in quiz_levels if profile.level else False
            
            if is_major_match and is_level_match:
                html += '<p style="color: green;"><strong>✓ Correspondance:</strong> Quiz de la filière actuelle</p>'
            else:
                html += '<p style="color: orange;"><strong>⚠ Attention:</strong> Quiz d\'une ancienne filière</p>'
                if not is_major_match:
                    html += f'<p style="color: gray; font-size: 0.9em;">Filière du quiz: {", ".join([m.name for m in quiz_majors])}</p>'
            
            html += '</div>'
            return mark_safe(html)
        except:
            return "Profil non disponible"
    user_profile_info.short_description = 'Profil étudiant'
    
    def status_display(self, obj):
        colors = {
            'COMPLETED': 'green',
            'IN_PROGRESS': 'orange',
            'ABANDONED': 'red'
        }
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            colors.get(obj.status, 'gray'),
            obj.get_status_display()
        )
    status_display.short_description = 'Statut'
    
    def score_display(self, obj):
        if obj.score is None:
            return '-'
        
        color = 'green' if obj.is_passed else 'red'
        icon = '✓' if obj.is_passed else '✗'
        return format_html(
            '<span style="color: {}; font-weight: bold;">{} {}/{}</span>',
            color, icon, obj.score, obj.quiz.total_points
        )
    score_display.short_description = 'Score'
    
    def time_spent_display(self, obj):
        time = obj.time_spent
        if time:
            return f"{int(time)} min"
        return '-'
    time_spent_display.short_description = 'Temps passé'
    
    def answers_summary(self, obj):
        if obj.status != 'COMPLETED':
            return "Quiz non terminé"
        
        answers = obj.answers.select_related('question').prefetch_related('selected_choices')
        
        html = '<div style="background: #f8f9fa; padding: 15px; border-radius: 5px;">'
        html += '<h3>Réponses de l\'étudiant</h3>'
        
        for answer in answers:
            color = 'green' if answer.is_correct else 'red'
            icon = '✓' if answer.is_correct else '✗'
            
            html += f'<div style="margin-bottom: 15px; padding: 10px; background: white; border-left: 3px solid {color};">'
            html += f'<p><strong>{icon} Question {answer.question.order}:</strong> {answer.question.text[:100]}</p>'
            html += f'<p><strong>Points obtenus:</strong> {answer.points_earned}/{answer.question.points}</p>'
            
            selected = answer.selected_choices.all()
            if selected:
                html += '<p><strong>Choix sélectionné(s):</strong></p><ul>'
                for choice in selected:
                    check = '✓' if choice.is_correct else '✗'
                    html += f'<li>{check} {choice.text}</li>'
                html += '</ul>'
            
            html += '</div>'
        
        html += '</div>'
        return mark_safe(html)
    answers_summary.short_description = 'Détail des réponses'
    
    def has_add_permission(self, request):
        return False


@admin.register(StudentAnswer)
class StudentAnswerAdmin(admin.ModelAdmin):
    list_display = ['attempt', 'question', 'is_correct_display', 'points_earned', 'answered_at']
    list_filter = ['is_correct', 'attempt__quiz']
    search_fields = ['attempt__user__username', 'question__text']
    readonly_fields = ['attempt', 'question', 'selected_choices_display', 'is_correct', 'points_earned', 'answered_at']
    
    def is_correct_display(self, obj):
        if obj.is_correct:
            return format_html('<span style="color: green; font-weight: bold;">✓ Correct</span>')
        return format_html('<span style="color: red; font-weight: bold;">✗ Incorrect</span>')
    is_correct_display.short_description = 'Résultat'
    
    def selected_choices_display(self, obj):
        choices = obj.selected_choices.all()
        html = '<ul>'
        for choice in choices:
            check = '✓' if choice.is_correct else '✗'
            color = 'green' if choice.is_correct else 'red'
            html += f'<li style="color: {color};">{check} {choice.text}</li>'
        html += '</ul>'
        return mark_safe(html)
    selected_choices_display.short_description = 'Choix sélectionnés'
    
    def has_add_permission(self, request):
        return False


# ==================== ADMIN AUTRES MODÈLES ====================

@admin.register(UserFavorite)
class UserFavoriteAdmin(admin.ModelAdmin):
    list_display = ['user', 'favorite_type', 'get_favorite_name', 'created_at']
    list_filter = ['favorite_type', 'created_at']
    search_fields = ['user__username', 'subject__name', 'document__title']
    readonly_fields = ['created_at']
    
    def get_favorite_name(self, obj):
        if obj.subject:
            return f"{obj.subject.name} (Matière)"
        elif obj.document:
            return f"{obj.document.title} (Document)"
        return "N/A"
    get_favorite_name.short_description = 'Favori'


@admin.register(UserProgress)
class UserProgressAdmin(admin.ModelAdmin):
    list_display = [
        'user', 'subject', 'document', 'status', 'progress_percentage',
        'last_accessed'
    ]
    list_filter = [
        'status', 'subject', 'last_accessed', 'created_at'
    ]
    search_fields = ['user__username', 'subject__name', 'document__title']
    readonly_fields = ['created_at', 'last_accessed']
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related(
            'user', 'subject', 'document'
        )


@admin.register(UserActivity)
class UserActivityAdmin(admin.ModelAdmin):
    list_display = [
        'user', 'action', 'document_name', 'subject_name', 
        'created_at', 'ip_address'
    ]
    list_filter = [
        'action', 'created_at', 'subject'
    ]
    search_fields = [
        'user__username', 'document__title', 'subject__name'
    ]
    readonly_fields = ['created_at', 'ip_address', 'user_agent']
    date_hierarchy = 'created_at'
    
    def document_name(self, obj):
        return obj.document.title
    document_name.short_description = 'Document'
    
    def subject_name(self, obj):
        return obj.subject.name
    subject_name.short_description = 'Matière'
    
    def get_queryset(self, request):
        return super().get_queryset(request).select_related(
            'user', 'document', 'subject'
        )

# ========================================
# ADMIN POUR GESTION DE PROJETS
# ========================================

@admin.register(StudentProject)
class StudentProjectAdmin(admin.ModelAdmin):
    list_display = [
        'title', 
        'user', 
        'subject',
        'status', 
        'priority', 
        'progress_percentage',
        'due_date',
        'is_favorite',
        'created_at'
    ]
    list_filter = [
        'status', 
        'priority', 
        'is_favorite', 
        'created_at',
        'subject'
    ]
    search_fields = [
        'title', 
        'description', 
        'user__username',
        'user__first_name',
        'user__last_name'
    ]
    readonly_fields = [
        'progress_percentage', 
        'completed_at', 
        'created_at', 
        'updated_at'
    ]
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('Informations principales', {
            'fields': ('user', 'subject', 'title', 'description')
        }),
        ('Statut', {
            'fields': ('status', 'priority', 'progress_percentage')
        }),
        ('Dates', {
            'fields': ('start_date', 'due_date', 'completed_at')
        }),
        ('Personnalisation', {
            'fields': ('color', 'is_favorite', 'order')
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_queryset(self, request):
        """Optimiser les requêtes"""
        qs = super().get_queryset(request)
        return qs.select_related('user', 'subject').prefetch_related('tasks')


@admin.register(ProjectTask)
class ProjectTaskAdmin(admin.ModelAdmin):
    list_display = [
        'title',
        'project',
        'status',
        'is_important',
        'due_date',
        'completed_at',
        'order',
        'created_at'
    ]
    list_filter = [
        'status', 
        'is_important', 
        'created_at',
        'project__user'
    ]
    search_fields = [
        'title', 
        'description', 
        'project__title',
        'project__user__username'
    ]
    readonly_fields = [
        'completed_at', 
        'created_at', 
        'updated_at'
    ]
    date_hierarchy = 'created_at'
    
    fieldsets = (
        ('Informations principales', {
            'fields': ('project', 'title', 'description')
        }),
        ('Statut', {
            'fields': ('status', 'is_important', 'order')
        }),
        ('Dates', {
            'fields': ('due_date', 'completed_at', 'estimated_hours')
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_queryset(self, request):
        """Optimiser les requêtes"""
        qs = super().get_queryset(request)
        return qs.select_related('project', 'project__user')


# ==================== CONFIGURATION DU SITE ADMIN ====================

admin.site.site_header = "Administration Courati"
admin.site.site_title = "Courati Admin"
admin.site.index_title = "Gestion de la plateforme éducative"