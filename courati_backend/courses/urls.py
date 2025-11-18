# courses/urls.py

from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

app_name = 'courses'

# Créer le router pour les ViewSets
router = DefaultRouter()
router.register(r'quizzes', views.QuizViewSet, basename='quiz')
router.register(r'attempts', views.QuizAttemptViewSet, basename='attempt')

# ✅ NOUVEAU : Routes pour les projets
router.register(r'projects', views.StudentProjectViewSet, basename='project')
router.register(r'tasks', views.ProjectTaskViewSet, basename='task')

urlpatterns = [
    # ========================================
    # APIs ÉTUDIANTS - Consultation des cours
    # ========================================
    path('my-subjects/', views.StudentSubjectsView.as_view(), name='student-subjects'),
    # Route pour récupérer UNE matière par ID
    path('subjects/<int:subject_id>/', views.SubjectDetailAPIView.as_view(), name='subject-detail'),
    path('subjects/<int:subject_id>/documents/', views.SubjectDocumentsView.as_view(), name='subject-documents'),
    
    # Gestion des favoris
    path('favorites/', views.UserFavoritesView.as_view(), name='user-favorites'),
    
    # Gestion des téléchargements et consultations
    path('documents/<int:document_id>/download/', views.DocumentDownloadView.as_view(), name='document-download'),
    path('documents/<int:document_id>/view/', views.DocumentViewTrackingView.as_view(), name='document-view-tracking'),
    
    # Historique
    path('history/', views.UserHistoryView.as_view(), name='user-history'),
    path('consultation-history/', views.DocumentConsultationHistoryView.as_view(), name='consultation-history'),
    
    # Page d'accueil personnalisée
    path('home/', views.PersonalizedHomeView.as_view(), name='personalized-home'),
    
    # APIs publiques
    path('choices/document-types/', views.get_document_types, name='document-types'),
    
    # ========================================
    # APIs PROFESSEURS - Gestion des matières
    # ========================================
    path('teacher/my-subjects/', views.TeacherSubjectsView.as_view(), name='teacher-subjects'),
    path('teacher/subjects/<int:subject_id>/students/', views.TeacherSubjectStudentsView.as_view(), name='teacher-subject-students'),
    path('teacher/subjects/<int:subject_id>/upload/', views.TeacherUploadDocumentView.as_view(), name='teacher-upload-document'),
    path('teacher/subjects/<int:subject_id>/statistics/', views.TeacherSubjectStatisticsView.as_view(), name='teacher-subject-statistics'),
    path('teacher/documents/<int:document_id>/delete/', views.TeacherDeleteDocumentView.as_view(), name='teacher-delete-document'),

    # NOUVEAU - APIs PROFESSEURS - Gestion des quiz
    path('teacher/quizzes/', views.TeacherQuizListCreateView.as_view(), name='teacher-quizzes'),
    path('teacher/quizzes/<int:quiz_id>/', views.TeacherQuizDetailView.as_view(), name='teacher-quiz-detail'),

    # NOUVEAU - APIs PROFESSEURS 
    path('teacher/dashboard/', views.TeacherDashboardView.as_view(), name='teacher-dashboard'),
    path('teacher/quizzes/<int:quiz_id>/attempts/', views.TeacherQuizAttemptsView.as_view(), name='teacher-quiz-attempts'),
    path('teacher/subjects/<int:subject_id>/documents/', views.TeacherSubjectDocumentsView.as_view(), name='teacher-subject-documents'),
    path('teacher/documents/<int:document_id>/update/', views.TeacherUpdateDocumentView.as_view(), name='teacher-update-document'),
    path('teacher/subjects/<int:subject_id>/update/', views.TeacherUpdateSubjectView.as_view(), name='teacher-update-subject'),

    # ========================================
    # APIs ADMIN - Gestion des matières
    # ========================================
    path('admin/subjects/', views.AdminSubjectListCreateView.as_view(), name='admin-subjects'),
    path('admin/subjects/<int:subject_id>/', views.AdminSubjectDetailView.as_view(), name='admin-subject-detail'),
    path('admin/subjects/<int:subject_id>/statistics/', views.AdminSubjectStatisticsView.as_view(), name='admin-subject-stats'),
    path('admin/subjects/<int:subject_id>/toggle-active/', views.AdminSubjectToggleActiveView.as_view(), name='admin-subject-toggle-active'),
    path('admin/subjects/<int:subject_id>/toggle-featured/', views.AdminSubjectToggleFeaturedView.as_view(), name='admin-subject-toggle-featured'),

    #  APIs ADMIN - Gestion des quiz
    path('admin/quizzes/', views.AdminQuizListCreateView.as_view(), name='admin-quizzes'),
    path('admin/quizzes/<int:quiz_id>/', views.AdminQuizDetailView.as_view(), name='admin-quiz-detail'),
    path('admin/quizzes/<int:quiz_id>/toggle-active/', views.AdminQuizToggleActiveView.as_view(), name='admin-quiz-toggle-active'),
    
    # ========================================
    # APIs QUIZ & PROJETS - ViewSets
    # ========================================
    path('', include(router.urls)),  # Inclut quiz, attempts, projects, tasks
]