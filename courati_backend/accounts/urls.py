from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # Authentification
    path('login/', views.CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('logout/', views.LogoutView.as_view(), name='logout'),
    # Inscription et vérification
    path('register/', views.RegisterView.as_view(), name='register'),
    path('verify-otp/', views.VerifyOTPView.as_view(), name='verify_otp'),
    
    # Réinitialisation mot de passe - URLS CORRIGÉES
    path('password-reset-request/', views.PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset-confirm/', views.PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    
    # Profil utilisateur
    path('profile/', views.UserProfileView.as_view(), name='user_profile'),
    # changer mot de pass
    path('change-password/', views.ChangePasswordView.as_view(), name='change_password'),

    # APIs publiques pour les choix (mobile app)
    path('choices/levels/', views.get_levels, name='get_levels'),
    path('choices/majors/', views.get_majors, name='get_majors'),
    path('choices/registration/', views.get_registration_choices, name='get_registration_choices'),
    
    # Gestion admin des niveaux
    path('admin/levels/', views.LevelListCreateView.as_view(), name='admin_levels'),
    path('admin/levels/<int:pk>/', views.LevelDetailView.as_view(), name='admin_level_detail'),
    
    # Gestion admin des filières
    path('admin/majors/', views.MajorListCreateView.as_view(), name='admin_majors'),
    path('admin/majors/<int:pk>/', views.MajorDetailView.as_view(), name='admin_major_detail'),
]
