# notifications/models.py
from django.db import models
from django.contrib.auth import get_user_model
from django.utils.translation import gettext_lazy as _

User = get_user_model()

class FCMToken(models.Model):
    """Token FCM pour envoyer des notifications push"""
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name='fcm_tokens'
    )
    token = models.CharField(
        _('token FCM'),
        max_length=255, 
        unique=True
    )
    device_type = models.CharField(
        _('type d\'appareil'),
        max_length=20,
        choices=[
            ('android', 'Android'),
            ('ios', 'iOS'),
        ]
    )
    created_at = models.DateTimeField(auto_now_add=True)
    last_used = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(
        _('actif'),
        default=True
    )
    
    class Meta:
        verbose_name = _('token FCM')
        verbose_name_plural = _('tokens FCM')
        ordering = ['-last_used']
    
    def __str__(self):
        return f"{self.user.username} - {self.device_type} - {'✓' if self.is_active else '✗'}"


class NotificationPreference(models.Model):
    """Préférences de notifications d'un utilisateur"""
    user = models.OneToOneField(
        User, 
        on_delete=models.CASCADE,
        related_name='notification_preference'
    )
    
    # Toggle global
    notifications_enabled = models.BooleanField(
        _('notifications activées'),
        default=True
    )
    
    # Par type de notification
    new_content_enabled = models.BooleanField(
        _('nouveaux contenus (cours/TD/TP)'),
        default=True
    )
    quiz_enabled = models.BooleanField(
        _('nouveaux quiz'),
        default=True
    )
    deadline_reminders_enabled = models.BooleanField(
        _('rappels de deadlines'),
        default=True
    )
    
    # Heures silencieuses (optionnel)
    quiet_hours_enabled = models.BooleanField(
        _('mode silencieux activé'),
        default=False
    )
    quiet_hours_start = models.TimeField(
        _('début mode silencieux'),
        null=True, 
        blank=True
    )
    quiet_hours_end = models.TimeField(
        _('fin mode silencieux'),
        null=True, 
        blank=True
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('préférence de notification')
        verbose_name_plural = _('préférences de notifications')
    
    def __str__(self):
        return f"Préférences de {self.user.username}"


class SubjectPreference(models.Model):
    """Préférences de notifications par matière"""
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name='subject_notification_preferences'
    )
    subject = models.ForeignKey(
        'courses.Subject', 
        on_delete=models.CASCADE,
        related_name='notification_preferences'
    )
    notifications_enabled = models.BooleanField(
        _('notifications activées pour cette matière'),
        default=True
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('préférence matière')
        verbose_name_plural = _('préférences matières')
        unique_together = ['user', 'subject']
    
    def __str__(self):
        status = '✓' if self.notifications_enabled else '✗'
        return f"{self.user.username} - {self.subject.code} {status}"


class NotificationHistory(models.Model):
    """Historique des notifications envoyées"""
    
    NOTIFICATION_TYPES = [
        ('new_document', 'Nouveau document'),
        ('new_quiz', 'Nouveau quiz'),
        ('quiz_closing', 'Quiz bientôt fermé'),
        ('project_reminder', 'Rappel projet'),
    ]
    
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name='notification_history'
    )
    notification_type = models.CharField(
        _('type'),
        max_length=50, 
        choices=NOTIFICATION_TYPES
    )
    title = models.CharField(
        _('titre'),
        max_length=255
    )
    message = models.TextField(_('message'))
    
    # Métadonnées (JSON pour flexibilité)
    data = models.JSONField(
        _('données supplémentaires'),
        null=True, 
        blank=True,
        help_text="IDs des documents, quiz, projets, etc."
    )
    
    # Statut
    sent_at = models.DateTimeField(auto_now_add=True)
    read = models.BooleanField(
        _('lu'),
        default=False
    )
    clicked = models.BooleanField(
        _('cliqué'),
        default=False
    )
    
    class Meta:
        verbose_name = _('notification')
        verbose_name_plural = _('notifications')
        ordering = ['-sent_at']
        indexes = [
            models.Index(fields=['user', '-sent_at']),
            models.Index(fields=['user', 'read']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.get_notification_type_display()} - {self.sent_at.strftime('%d/%m/%Y %H:%M')}"