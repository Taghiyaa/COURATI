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
    
    # ========================================
    # APIs QUIZ & PROJETS - ViewSets
    # ========================================
    path('', include(router.urls)),  # Inclut quiz, attempts, projects, tasks
]