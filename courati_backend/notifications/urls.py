# notifications/urls.py
from django.urls import path
from .views import (
    FCMTokenRegisterView,
    FCMTokenDeleteView,
    NotificationPreferenceView,
    SubjectPreferenceListView,
    SubjectPreferenceUpdateView,
    NotificationHistoryListView,
    NotificationMarkAsReadView,
    NotificationMarkAllAsReadView,
)

urlpatterns = [
    # Gestion des tokens FCM
    path('fcm-token/', FCMTokenRegisterView.as_view(), name='fcm-token-register'),
    path('fcm-token/<str:token>/', FCMTokenDeleteView.as_view(), name='fcm-token-delete'),
    
    # Préférences globales
    path('preferences/', NotificationPreferenceView.as_view(), name='notification-preferences'),
    
    # Préférences par matière
    path('subject-preferences/', SubjectPreferenceListView.as_view(), name='subject-preferences-list'),
    path('subject-preferences/<int:pk>/', SubjectPreferenceUpdateView.as_view(), name='subject-preference-update'),
    
    # Historique
    path('history/', NotificationHistoryListView.as_view(), name='notification-history'),
    path('history/<int:pk>/read/', NotificationMarkAsReadView.as_view(), name='notification-mark-read'),
    path('history/mark-all-read/', NotificationMarkAllAsReadView.as_view(), name='notification-mark-all-read'),
]