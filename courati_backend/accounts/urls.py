from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # ========================================
    # AUTHENTIFICATION
    # ========================================
    path('login/', views.CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', views.LogoutView.as_view(), name='logout'),
    
    # ========================================
    # INSCRIPTION ET VÉRIFICATION
    # ========================================
    path('register/', views.RegisterView.as_view(), name='register'),
    path('verify-otp/', views.VerifyOTPView.as_view(), name='verify_otp'),
    
    # ========================================
    # RÉINITIALISATION MOT DE PASSE
    # ========================================
    path('password-reset-request/', views.PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset-confirm/', views.PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    
    # ========================================
    # PROFIL UTILISATEUR (MOBILE - Étudiants)
    # ========================================
    path('profile/', views.UserProfileView.as_view(), name='user_profile'),
    path('change-password/', views.ChangePasswordView.as_view(), name='change_password'),
    
    # ========================================
    # PROFIL WEB (Admin/Teacher)
    # ========================================
    path('web/profile/', views.ProfileView.as_view(), name='web_profile'),
    path('web/profile/change-password/', views.WebChangePasswordView.as_view(), name='web_change_password'),
    path('web/profile/stats/', views.ProfileStatsView.as_view(), name='web_profile_stats'),

    # ========================================
    # APIS PUBLIQUES
    # ========================================
    path('choices/levels/', views.get_levels, name='get_levels'),
    path('choices/majors/', views.get_majors, name='get_majors'),
    path('choices/registration/', views.get_registration_choices, name='get_registration_choices'),
    path('levels/', views.get_levels, name='levels'),
    path('majors/', views.get_majors, name='majors'),
    
    # ========================================
    # GESTION ADMIN - NIVEAUX
    # ========================================
    path('admin/levels/', views.LevelListCreateView.as_view(), name='admin_levels'),
    path('admin/levels/<int:pk>/', views.LevelDetailView.as_view(), name='admin_level_detail'),
    
    # ========================================
    # GESTION ADMIN - FILIÈRES
    # ========================================
    path('admin/majors/', views.MajorListCreateView.as_view(), name='admin_majors'),
    path('admin/majors/<int:pk>/', views.MajorDetailView.as_view(), name='admin_major_detail'),

    # ========================================
    # GESTION ADMIN - PROFESSEURS
    # ========================================
    path('admin/teachers/', views.TeacherListCreateView.as_view(), name='admin_teachers'),
    path('admin/teachers/<int:pk>/', views.TeacherDetailView.as_view(), name='admin_teacher_detail'),
    path('admin/teachers/<int:teacher_id>/assignments/', views.TeacherAssignmentsView.as_view(), name='teacher_assignments'),
    path('admin/assignments/<int:assignment_id>/', views.TeacherAssignmentDetailView.as_view(), name='assignment_detail'),
    path('admin/teachers/<int:teacher_id>/toggle-active/', views.TeacherToggleActiveView.as_view(), name='teacher_toggle_active'),

    # ========================================
    # DASHBOARD ADMIN
    # ========================================
    path('admin/dashboard/', views.AdminDashboardView.as_view(), name='admin_dashboard'),

    # ========================================
    # GESTION ÉTUDIANTS (ADMIN)
    # ========================================
    path('admin/students/', views.AdminStudentListCreateView.as_view(), name='admin_students'),
    path('admin/students/<int:student_id>/', views.AdminStudentDetailView.as_view(), name='admin_student_detail'),
    path('admin/students/<int:student_id>/statistics/', views.AdminStudentStatisticsView.as_view(), name='admin_student_statistics'),
    path('admin/students/<int:student_id>/toggle-active/', views.AdminStudentToggleActiveView.as_view(), name='admin_student_toggle_active'),
    path('admin/students/bulk-action/', views.AdminStudentBulkActionView.as_view(), name='admin_students_bulk_action'),
    path('admin/students/export/', views.AdminStudentExportView.as_view(), name='admin_students_export'),
]