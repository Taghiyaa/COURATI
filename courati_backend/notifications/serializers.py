# notifications/serializers.py
from rest_framework import serializers
from .models import FCMToken, NotificationPreference, SubjectPreference, NotificationHistory


class FCMTokenSerializer(serializers.ModelSerializer):
    """Serializer pour enregistrer/gérer les tokens FCM"""
    
    class Meta:
        model = FCMToken
        fields = ['id', 'token', 'device_type', 'created_at', 'last_used', 'is_active']
        read_only_fields = ['id', 'created_at', 'last_used', 'is_active']
    
    def create(self, validated_data):
        """Créer ou mettre à jour un token existant"""
        user = self.context['request'].user
        token = validated_data.get('token')
        device_type = validated_data.get('device_type', 'android')
        
        # ✅ CORRECTION : Lookup sur user ET token
        fcm_token, created = FCMToken.objects.update_or_create(
            user=user,     # ✅ Lookup : user
            token=token,   # ✅ Lookup : token
            defaults={
                'device_type': device_type,
                'is_active': True
            }
        )
        
        # Log pour debug
        action = 'créé' if created else 'mis à jour'
        logger.info(f"Token FCM {action} pour {user.username}")
        
        return fcm_token


class SubjectPreferenceSerializer(serializers.ModelSerializer):
    """Serializer pour les préférences par matière"""
    subject_name = serializers.CharField(source='subject.name', read_only=True)
    subject_code = serializers.CharField(source='subject.code', read_only=True)
    
    class Meta:
        model = SubjectPreference
        fields = [
            'id', 'subject', 'subject_name', 'subject_code', 
            'notifications_enabled', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class NotificationPreferenceSerializer(serializers.ModelSerializer):
    """Serializer pour les préférences globales"""
    subject_preferences = SubjectPreferenceSerializer(
        source='user.subject_notification_preferences',
        many=True, 
        read_only=True
    )
    
    class Meta:
        model = NotificationPreference
        fields = [
            'id',
            'notifications_enabled',
            'new_content_enabled',
            'quiz_enabled',
            'deadline_reminders_enabled',
            'quiet_hours_enabled',
            'quiet_hours_start',
            'quiet_hours_end',
            'subject_preferences',
            'created_at',
            'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class NotificationHistorySerializer(serializers.ModelSerializer):
    """Serializer pour l'historique des notifications"""
    notification_type_display = serializers.CharField(
        source='get_notification_type_display', 
        read_only=True
    )
    
    class Meta:
        model = NotificationHistory
        fields = [
            'id',
            'notification_type',
            'notification_type_display',
            'title',
            'message',
            'data',
            'sent_at',
            'read',
            'clicked'
        ]
        read_only_fields = ['id', 'sent_at']