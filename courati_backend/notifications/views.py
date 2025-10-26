# notifications/views.py
import logging
from rest_framework import status, permissions, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import action
from django.shortcuts import get_object_or_404

from .models import FCMToken, NotificationPreference, SubjectPreference, NotificationHistory
from .serializers import (
    FCMTokenSerializer, 
    NotificationPreferenceSerializer,
    SubjectPreferenceSerializer,
    NotificationHistorySerializer
)
from courses.models import Subject

logger = logging.getLogger(__name__)


# ========================================
# GESTION DES TOKENS FCM
# ========================================

class FCMTokenRegisterView(APIView):
    """
    Enregistrer ou mettre à jour un token FCM
    POST /api/notifications/fcm-token/
    Body: {"token": "xxx", "device_type": "android"}
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        token = request.data.get('token')
        device_type = request.data.get('device_type', 'android')
        
        logger.info(f"📱 Enregistrement token FCM pour: {user.username}")
        
        if not token:
            return Response({
                'success': False,
                'error': 'Token FCM requis'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            # ✅ CORRECTION : Gérer le cas où le token existe déjà pour un autre user
            
            # 1. Chercher si le token existe déjà
            existing_token = FCMToken.objects.filter(token=token).first()
            
            if existing_token:
                # Le token existe déjà
                if existing_token.user == user:
                    # ✅ Même utilisateur : juste mettre à jour
                    existing_token.device_type = device_type
                    existing_token.is_active = True
                    existing_token.save()
                    
                    logger.info(f"✅ Token FCM mis à jour pour {user.username}")
                    serializer = FCMTokenSerializer(existing_token)
                    
                    return Response({
                        'success': True,
                        'message': 'Token FCM mis à jour avec succès',
                        'token': serializer.data
                    }, status=status.HTTP_200_OK)
                else:
                    # ⚠️ Autre utilisateur : réassigner le token
                    logger.warning(f"⚠️ Token FCM transféré de {existing_token.user.username} à {user.username}")
                    
                    existing_token.user = user
                    existing_token.device_type = device_type
                    existing_token.is_active = True
                    existing_token.save()
                    
                    serializer = FCMTokenSerializer(existing_token)
                    
                    return Response({
                        'success': True,
                        'message': 'Token FCM réassigné avec succès',
                        'token': serializer.data
                    }, status=status.HTTP_200_OK)
            else:
                # ✅ Token n'existe pas : créer un nouveau
                fcm_token = FCMToken.objects.create(
                    user=user,
                    token=token,
                    device_type=device_type,
                    is_active=True
                )
                
                logger.info(f"✅ Token FCM créé pour {user.username}")
                serializer = FCMTokenSerializer(fcm_token)
                
                return Response({
                    'success': True,
                    'message': 'Token FCM créé avec succès',
                    'token': serializer.data
                }, status=status.HTTP_201_CREATED)
            
        except Exception as e:
            logger.error(f"❌ Erreur enregistrement token: {str(e)}")
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class FCMTokenDeleteView(APIView):
    """
    Supprimer un token FCM (déconnexion, désinstallation)
    DELETE /api/notifications/fcm-token/{token}/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def delete(self, request, token):
        user = request.user
        
        try:
            fcm_token = FCMToken.objects.get(token=token, user=user)
            fcm_token.delete()
            
            logger.info(f"🗑️ Token FCM supprimé pour {user.username}")
            
            return Response({
                'success': True,
                'message': 'Token supprimé avec succès'
            })
        
        except FCMToken.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Token non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)


# ========================================
# GESTION DES PRÉFÉRENCES
# ========================================

class NotificationPreferenceView(APIView):
    """
    Récupérer et modifier les préférences de notifications
    GET /api/notifications/preferences/
    PUT /api/notifications/preferences/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """Récupérer les préférences"""
        user = request.user
        
        # Créer les préférences par défaut si elles n'existent pas
        preference, created = NotificationPreference.objects.get_or_create(
            user=user,
            defaults={
                'notifications_enabled': True,
                'new_content_enabled': True,
                'quiz_enabled': True,
                'deadline_reminders_enabled': True,
            }
        )
        
        serializer = NotificationPreferenceSerializer(preference)
        
        return Response({
            'success': True,
            'preferences': serializer.data
        })
    
    def put(self, request):
        """Modifier les préférences"""
        user = request.user
        
        preference, created = NotificationPreference.objects.get_or_create(user=user)
        
        serializer = NotificationPreferenceSerializer(
            preference, 
            data=request.data, 
            partial=True
        )
        
        if serializer.is_valid():
            serializer.save()
            
            logger.info(f"✏️ Préférences mises à jour pour {user.username}")
            
            return Response({
                'success': True,
                'message': 'Préférences mises à jour',
                'preferences': serializer.data
            })
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class SubjectPreferenceListView(APIView):
    """
    Liste des préférences par matière
    GET /api/notifications/subject-preferences/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Récupérer toutes les matières accessibles à l'étudiant
        if user.is_student():
            try:
                student_profile = user.student_profile
                subjects = Subject.objects.filter(
                    levels=student_profile.level,
                    majors=student_profile.major,
                    is_active=True
                )
            except:
                subjects = Subject.objects.none()
        else:
            subjects = Subject.objects.filter(is_active=True)
        
        # Créer les préférences manquantes
        for subject in subjects:
            SubjectPreference.objects.get_or_create(
                user=user,
                subject=subject,
                defaults={'notifications_enabled': True}
            )
        
        # Récupérer toutes les préférences
        preferences = SubjectPreference.objects.filter(
            user=user,
            subject__in=subjects
        ).select_related('subject')
        
        serializer = SubjectPreferenceSerializer(preferences, many=True)
        
        return Response({
            'success': True,
            'total': preferences.count(),
            'subject_preferences': serializer.data
        })


class SubjectPreferenceUpdateView(APIView):
    """
    Modifier une préférence de matière
    PUT /api/notifications/subject-preferences/{id}/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def put(self, request, pk):
        user = request.user
        
        preference = get_object_or_404(SubjectPreference, id=pk, user=user)
        
        serializer = SubjectPreferenceSerializer(
            preference,
            data=request.data,
            partial=True
        )
        
        if serializer.is_valid():
            serializer.save()
            
            logger.info(f"✏️ Préférence matière mise à jour: {preference.subject.code} pour {user.username}")
            
            return Response({
                'success': True,
                'message': 'Préférence mise à jour',
                'preference': serializer.data
            })
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


# ========================================
# HISTORIQUE DES NOTIFICATIONS
# ========================================

class NotificationHistoryListView(APIView):
    """
    Liste des notifications reçues
    GET /api/notifications/history/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        
        # Récupérer les notifications des 30 derniers jours
        notifications = NotificationHistory.objects.filter(
            user=user
        ).order_by('-sent_at')[:100]
        
        serializer = NotificationHistorySerializer(notifications, many=True)
        
        # Statistiques
        unread_count = NotificationHistory.objects.filter(
            user=user,
            read=False
        ).count()
        
        return Response({
            'success': True,
            'total': notifications.count(),
            'unread_count': unread_count,
            'notifications': serializer.data
        })


class NotificationMarkAsReadView(APIView):
    """
    Marquer une notification comme lue
    PATCH /api/notifications/history/{id}/read/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def patch(self, request, pk):
        user = request.user
        
        notification = get_object_or_404(
            NotificationHistory,
            id=pk,
            user=user
        )
        
        notification.read = True
        notification.save(update_fields=['read'])
        
        return Response({
            'success': True,
            'message': 'Notification marquée comme lue'
        })


class NotificationMarkAllAsReadView(APIView):
    """
    Marquer toutes les notifications comme lues
    POST /api/notifications/history/mark-all-read/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        user = request.user
        
        updated = NotificationHistory.objects.filter(
            user=user,
            read=False
        ).update(read=True)
        
        return Response({
            'success': True,
            'message': f'{updated} notifications marquées comme lues'
        })