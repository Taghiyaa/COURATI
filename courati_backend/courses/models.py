# courses/models.py
from django.db import models
from django.contrib.auth import get_user_model
from django.core.validators import FileExtensionValidator, MaxValueValidator,MinValueValidator
from accounts.models import Level, Major
from django.utils.translation import gettext_lazy as _ 
from django.db.models import Sum

User = get_user_model()

class Subject(models.Model):
    """Matière/Discipline académique"""
    
    # Informations de base
    name = models.CharField(max_length=200, verbose_name="Nom de la matière")
    code = models.CharField(max_length=20, unique=True, verbose_name="Code matière")
    description = models.TextField(blank=True, verbose_name="Description")
    
    # Relations avec niveau et filière
    levels = models.ManyToManyField(Level, verbose_name="Niveaux concernés")
    majors = models.ManyToManyField(Major, verbose_name="Filières concernées")
    
    # Métadonnées académiques
    credits = models.PositiveIntegerField(default=3, verbose_name="Nombre de crédits")
    
    # Statut et visibilité
    is_active = models.BooleanField(default=True, verbose_name="Actif")
    is_featured = models.BooleanField(default=False, verbose_name="Mis en avant")
    
    # Timestamps et ordre
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    order = models.PositiveIntegerField(default=0, verbose_name="Ordre d'affichage")
    
    class Meta:
        verbose_name = "Matière"
        verbose_name_plural = "Matières"
        ordering = ['order', 'name']
        indexes = [
            models.Index(fields=['code']),
            models.Index(fields=['is_active', 'order']),
        ]
    
    def __str__(self):
        return f"{self.code} - {self.name}"
    
    @property
    def total_documents(self):
        return self.documents.filter(is_active=True).count()
    
    @property
    def level_names(self):
        return [level.name for level in self.levels.all()]
    
    @property
    def major_names(self):
        return [major.name for major in self.majors.all()]


class Document(models.Model):
    """Document pédagogique lié à une matière"""
    
    DOCUMENT_TYPES = (
    ('COURS', 'Cours'),
    ('TD', 'Travaux dirigés'),
    ('TP', 'Travaux pratiques'),
    ('ARCHIVE', 'Archive'),
)
    
    # Informations de base
    title = models.CharField(max_length=200, verbose_name="Titre du document")
    description = models.TextField(blank=True, verbose_name="Description")
    
    # Relation avec la matière (OBLIGATOIRE)
    subject = models.ForeignKey(
        Subject, 
        on_delete=models.CASCADE, 
        related_name='documents',
        verbose_name="Matière"
    )
    
    # TYPE DU DOCUMENT (COURS/TD/TP/etc.)
    document_type = models.CharField(
        max_length=15, 
        choices=DOCUMENT_TYPES, 
        default='COURS',
        verbose_name="Type de document"
    )
    
    # Fichier
    file = models.FileField(
        upload_to='documents/%Y/%m/',
        validators=[FileExtensionValidator(
            allowed_extensions=['pdf', 'doc', 'docx', 'ppt', 'pptx', 'mp4', 'mp3', 'avi']
        )],
        verbose_name="Fichier"
    )
    file_size = models.PositiveIntegerField(null=True, blank=True, verbose_name="Taille (bytes)")
    
    # Métadonnées
    is_active = models.BooleanField(
        default=True, 
        verbose_name="Visible pour les étudiants",
        help_text="Décocher pour masquer temporairement"
    )
    is_premium = models.BooleanField(
        default=False, 
        verbose_name="Contenu premium",
        help_text="Réservé aux fonctionnalités payantes futures"
    )
    download_count = models.PositiveIntegerField(default=0, verbose_name="Téléchargements")
    view_count = models.PositiveIntegerField(default=0, verbose_name="Consultations")
    
    # Auteur/Créateur
    created_by = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True,
        editable=False,
        verbose_name="Créé par"
    )
    
    # Timestamps et ordre
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    order = models.PositiveIntegerField(default=0, verbose_name="Ordre dans la matière")
    
    class Meta:
        verbose_name = "Document"
        verbose_name_plural = "Documents"
        ordering = ['subject', 'document_type', 'order', 'title']
        indexes = [
            models.Index(fields=['subject', 'is_active']),
            models.Index(fields=['document_type']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        return f"{self.subject.code} - {self.get_document_type_display()} - {self.title}"
    
    def save(self, *args, **kwargs):
        # Calculer automatiquement la taille du fichier
        if self.file:
            self.file_size = self.file.size
        
        # Ordre automatique si non défini
        if not self.order:
            TYPE_ORDER_MAP = {
                'COURS': 100,
                'TD': 200,
                'TP': 300,
                'ARCHIVE': 400
}
            base_order = TYPE_ORDER_MAP.get(self.document_type, 999)
            same_type_count = Document.objects.filter(
                subject=self.subject,
                document_type=self.document_type
            ).count()
            self.order = base_order + same_type_count + 1
        
        super().save(*args, **kwargs)
    
    @property
    def file_size_mb(self):
        if self.file_size:
            return round(self.file_size / (1024 * 1024), 2)
        return 0


class UserFavorite(models.Model):
    """Favoris des utilisateurs"""
    
    FAVORITE_TYPES = (
        ('SUBJECT', 'Matière'),
        ('DOCUMENT', 'Document'),
    )
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorites')
    favorite_type = models.CharField(max_length=10, choices=FAVORITE_TYPES)
    
    # Relations optionnelles
    subject = models.ForeignKey(
        Subject, 
        on_delete=models.CASCADE, 
        null=True, 
        blank=True,
        related_name='favorited_by'
    )
    document = models.ForeignKey(
        Document, 
        on_delete=models.CASCADE, 
        null=True, 
        blank=True,
        related_name='favorited_by'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Favori"
        verbose_name_plural = "Favoris"
        unique_together = [
            ('user', 'subject'),
            ('user', 'document'),
        ]
        indexes = [
            models.Index(fields=['user', 'favorite_type']),
            models.Index(fields=['created_at']),
        ]
    
    def __str__(self):
        if self.subject:
            return f"{self.user.username} - {self.subject.name} (Matière)"
        elif self.document:
            return f"{self.user.username} - {self.document.title} (Document)"
        return f"Favori de {self.user.username}"


class UserProgress(models.Model):
    """Suivi de progression des étudiants"""
    
    PROGRESS_STATUS = (
        ('NOT_STARTED', 'Non commencé'),
        ('IN_PROGRESS', 'En cours'),
        ('COMPLETED', 'Terminé'),
        ('PAUSED', 'En pause'),
    )
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='progress')
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='user_progress')
    document = models.ForeignKey(
        Document, 
        on_delete=models.CASCADE, 
        null=True, 
        blank=True,
        related_name='user_progress'
    )
    
    status = models.CharField(max_length=15, choices=PROGRESS_STATUS, default='NOT_STARTED')
    progress_percentage = models.PositiveIntegerField(
        default=0, 
        validators=[MaxValueValidator(100)]
    )
    
    # Temps passé (en minutes)
    time_spent = models.PositiveIntegerField(default=0, verbose_name="Temps passé (minutes)")
    
    # Timestamps
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    last_accessed = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = "Progression"
        verbose_name_plural = "Progressions"
        unique_together = ['user', 'subject', 'document']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['last_accessed']),
        ]
    
    def __str__(self):
        if self.document:
            return f"{self.user.username} - {self.document.title} ({self.progress_percentage}%)"
        return f"{self.user.username} - {self.subject.name} ({self.progress_percentage}%)"
    

class UserActivity(models.Model):
    """Historique des activités des utilisateurs"""
    
    ACTION_CHOICES = [
        ('download', 'Téléchargement'),
        ('view', 'Consultation'),
        ('favorite', 'Favori ajouté'),
        ('unfavorite', 'Favori retiré'),
    ]
    
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='activities')
    document = models.ForeignKey(Document, on_delete=models.CASCADE, related_name='activities')
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='activities')
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # Données supplémentaires optionnelles
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    user_agent = models.TextField(blank=True)
    
    class Meta:
        verbose_name = "Activité utilisateur"
        verbose_name_plural = "Activités utilisateurs"
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['action', '-created_at']),
            models.Index(fields=['document', '-created_at']),
        ]
    
    def __str__(self):
        return f"{self.user.username} - {self.get_action_display()} - {self.document.title}"

# courses/models.py (à la fin du fichier existant)

class Quiz(models.Model):
    """Quiz pour évaluer les connaissances des étudiants"""
    subject = models.ForeignKey(
        Subject, 
        on_delete=models.CASCADE,
        related_name='quizzes',
        verbose_name=_('matière')
    )
    title = models.CharField(_('titre'), max_length=200)
    description = models.TextField(_('description'), blank=True)
    duration_minutes = models.PositiveIntegerField(
        _('durée (minutes)'),
        default=15,
        help_text="Temps alloué pour compléter le quiz"
    )
    
    # MODIFIÉ : Utiliser un pourcentage au lieu d'un score absolu
    passing_percentage = models.DecimalField(
        _('pourcentage de réussite'),
        max_digits=5,
        decimal_places=2,
        default=50.00,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Pourcentage minimum requis pour réussir (ex: 50 = 50%, 60 = 60%)"
    )
    
    max_attempts = models.PositiveIntegerField(
        _('tentatives maximales'),
        default=3,
        help_text="Nombre de fois que l'étudiant peut passer le quiz"
    )
    show_correction = models.BooleanField(
        _('afficher la correction'),
        default=True,
        help_text="Montrer les bonnes réponses après soumission"
    )
    is_active = models.BooleanField(_('actif'), default=True)
    available_from = models.DateTimeField(
        _('disponible à partir de'),
        null=True,
        blank=True
    )
    available_until = models.DateTimeField(
        _('disponible jusqu\'à'),
        null=True,
        blank=True
    )
    created_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_quizzes'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('quiz')
        verbose_name_plural = _('quiz')
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.subject.code} - {self.title}"
    
    @property
    def total_points(self):
        """Calcule le total des points du quiz"""
        return self.questions.aggregate(
            total=models.Sum('points')
        )['total'] or 0
    
    @property
    def question_count(self):
        """Nombre de questions dans le quiz"""
        return self.questions.count()
    
    @property
    def passing_score(self):
        """Score de passage en points bruts à partir du pourcentage"""
        total = self.total_points
        if total > 0:
            return (float(total) * float(self.passing_percentage)) / 100
        return 0
    
    @property
    def passing_score_normalized(self):
        """Score de passage normalisé sur 20"""
        if self.total_points > 0:
            return (float(self.passing_score) / float(self.total_points)) * 20
        return (float(self.passing_percentage) * 20) / 100


class Question(models.Model):
    """Question d'un quiz"""
    QUESTION_TYPES = [
        ('QCM', 'Choix multiple (une réponse)'),
        ('TRUE_FALSE', 'Vrai/Faux'),
        ('MULTIPLE', 'Choix multiples (plusieurs réponses)'),
    ]
    
    quiz = models.ForeignKey(
        Quiz,
        on_delete=models.CASCADE,
        related_name='questions',
        verbose_name=_('quiz')
    )
    text = models.TextField(_('question'))
    question_type = models.CharField(
        _('type de question'),
        max_length=20,
        choices=QUESTION_TYPES,
        default='QCM'
    )
    points = models.DecimalField(
        _('points'),
        max_digits=5,
        decimal_places=2,
        default=2.00
    )
    order = models.PositiveIntegerField(_('ordre'), default=0)
    explanation = models.TextField(
        _('explication'),
        blank=True,
        help_text="Explication de la bonne réponse (optionnel)"
    )
    
    class Meta:
        verbose_name = _('question')
        verbose_name_plural = _('questions')
        ordering = ['order', 'id']
    
    def __str__(self):
        return f"Q{self.order} - {self.text[:50]}"


class Choice(models.Model):
    """Choix de réponse pour une question"""
    question = models.ForeignKey(
        Question,
        on_delete=models.CASCADE,
        related_name='choices',
        verbose_name=_('question')
    )
    text = models.CharField(_('texte'), max_length=500)
    is_correct = models.BooleanField(_('réponse correcte'), default=False)
    order = models.PositiveIntegerField(_('ordre'), default=0)
    
    class Meta:
        verbose_name = _('choix')
        verbose_name_plural = _('choix')
        ordering = ['order', 'id']
    
    def __str__(self):
        status = "✓" if self.is_correct else "✗"
        return f"{status} {self.text[:30]}"


class QuizAttempt(models.Model):
    """Tentative de quiz par un étudiant"""
    STATUS_CHOICES = [
        ('IN_PROGRESS', 'En cours'),
        ('COMPLETED', 'Terminé'),
        ('ABANDONED', 'Abandonné'),
    ]
    
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='quiz_attempts'
    )
    quiz = models.ForeignKey(
        Quiz,
        on_delete=models.CASCADE,
        related_name='attempts'
    )
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default='IN_PROGRESS'
    )
    score = models.DecimalField(
        _('score'),
        max_digits=5,
        decimal_places=2,
        null=True,
        blank=True
    )
    attempt_number = models.PositiveIntegerField(_('numéro de tentative'))
    started_at = models.DateTimeField(auto_now_add=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        verbose_name = _('tentative de quiz')
        verbose_name_plural = _('tentatives de quiz')
        ordering = ['-started_at']
        unique_together = ['user', 'quiz', 'attempt_number']
    
    def __str__(self):
        return f"{self.user.username} - {self.quiz.title} (#{self.attempt_number})"
    
    @property
    def is_passed(self):
        """Vérifie si le quiz est réussi"""
        if self.score is None:
            return False
        
        total = float(self.quiz.total_points)
        if total == 0:
            return False

        # convertit le score en pourcentage
        score_percentage = (float(self.score) / total) * 100

        return score_percentage >= float(self.quiz.passing_percentage)

    
    @property
    def time_spent(self):
        """Calcule le temps passé"""
        if self.completed_at:
            return (self.completed_at - self.started_at).total_seconds() / 60
        return None


class StudentAnswer(models.Model):
    """Réponse d'un étudiant à une question"""
    attempt = models.ForeignKey(
        QuizAttempt,
        on_delete=models.CASCADE,
        related_name='answers'
    )
    question = models.ForeignKey(Question, on_delete=models.CASCADE)
    selected_choices = models.ManyToManyField(
        Choice,
        verbose_name=_('choix sélectionnés')
    )
    is_correct = models.BooleanField(_('correct'), default=False)
    points_earned = models.DecimalField(
        _('points obtenus'),
        max_digits=5,
        decimal_places=2,
        default=0.00
    )
    answered_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = _('réponse étudiant')
        verbose_name_plural = _('réponses étudiants')
        unique_together = ['attempt', 'question']
    
    def __str__(self):
        return f"{self.attempt.user.username} - Q{self.question.order}"

# ========================================
# MODELS POUR LA GESTION DE PROJETS ÉTUDIANTS
# ========================================

class StudentProject(models.Model):
    """Projet personnel étudiant pour organiser son travail"""
    
    STATUS_CHOICES = [
        ('NOT_STARTED', 'Non démarré'),
        ('IN_PROGRESS', 'En cours'),
        ('COMPLETED', 'Terminé'),
        ('ARCHIVED', 'Archivé'),
    ]
    
    PRIORITY_CHOICES = [
        ('LOW', 'Faible'),
        ('MEDIUM', 'Moyenne'),
        ('HIGH', 'Haute'),
        ('URGENT', 'Urgente'),
    ]
    
    # Relations
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE, 
        related_name='student_projects',
        verbose_name=_('utilisateur')
    )
    subject = models.ForeignKey(
        Subject, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='student_projects',
        verbose_name=_('matière associée'),
        help_text="Matière liée au projet (optionnel)"
    )
    
    # Informations principales
    title = models.CharField(_('titre'), max_length=200)
    description = models.TextField(_('description'), blank=True)
    
    # Statut et priorité
    status = models.CharField(
        _('statut'),
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='NOT_STARTED'
    )
    priority = models.CharField(
        _('priorité'),
        max_length=20, 
        choices=PRIORITY_CHOICES, 
        default='MEDIUM'
    )
    
    # Dates
    start_date = models.DateField(
        _('date de début'),
        null=True, 
        blank=True
    )
    due_date = models.DateField(
        _('échéance'),
        null=True, 
        blank=True
    )
    completed_at = models.DateTimeField(
        _('terminé le'),
        null=True, 
        blank=True
    )
    
    # Progression
    progress_percentage = models.IntegerField(
        _('progression (%)'),
        default=0,
        validators=[MinValueValidator(0), MaxValueValidator(100)],
        help_text="Calculé automatiquement basé sur les tâches"
    )
    
    # Personnalisation
    color = models.CharField(
        _('couleur'),
        max_length=7, 
        default='#3B82F6',
        help_text="Couleur hex pour l'interface (ex: #3B82F6)"
    )
    is_favorite = models.BooleanField(
        _('favori'),
        default=False
    )
    order = models.IntegerField(
        _('ordre'),
        default=0, 
        help_text="Ordre d'affichage personnalisé"
    )
    
    # Metadata
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('projet étudiant')
        verbose_name_plural = _('projets étudiants')
        ordering = ['-is_favorite', 'order', '-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['due_date']),
        ]
    
    def __str__(self):
        return f"{self.title} - {self.user.username}"
    
    def update_progress(self):
        """Recalculer automatiquement la progression basée sur les tâches"""
        from django.utils import timezone
        
        total_tasks = self.tasks.count()
        
        if total_tasks == 0:
            self.progress_percentage = 0
        else:
            completed_tasks = self.tasks.filter(status='DONE').count()
            self.progress_percentage = int((completed_tasks / total_tasks) * 100)
        
        # Auto-update du statut du projet
        if self.progress_percentage == 100:
            self.status = 'COMPLETED'
            if not self.completed_at:
                self.completed_at = timezone.now()
        elif self.progress_percentage > 0:
            self.status = 'IN_PROGRESS'
        else:
            self.status = 'NOT_STARTED'
        
        self.save(update_fields=['progress_percentage', 'status', 'completed_at'])
    
    @property
    def is_overdue(self):
        """Vérifier si le projet est en retard"""
        from django.utils import timezone
        
        if not self.due_date:
            return False
        return (
            self.due_date < timezone.now().date() and
            self.status in ['NOT_STARTED', 'IN_PROGRESS']
        )
    
    @property
    def days_until_due(self):
        """Nombre de jours restants jusqu'à l'échéance"""
        from django.utils import timezone
        
        if not self.due_date:
            return None
        delta = self.due_date - timezone.now().date()
        return delta.days
    
    @property
    def total_tasks(self):
        """Nombre total de tâches"""
        return self.tasks.count()
    
    @property
    def completed_tasks_count(self):
        """Nombre de tâches terminées"""
        return self.tasks.filter(status='DONE').count()


class ProjectTask(models.Model):
    """Tâche liée à un projet étudiant"""
    
    STATUS_CHOICES = [
        ('TODO', 'À faire'),
        ('IN_PROGRESS', 'En cours'),
        ('DONE', 'Terminé'),
    ]
    
    # Relations
    project = models.ForeignKey(
        StudentProject, 
        on_delete=models.CASCADE, 
        related_name='tasks',
        verbose_name=_('projet')
    )
    
    # Informations principales
    title = models.CharField(_('titre'), max_length=200)
    description = models.TextField(_('description'), blank=True)
    
    # Statut
    status = models.CharField(
        _('statut'),
        max_length=20, 
        choices=STATUS_CHOICES, 
        default='TODO'
    )
    
    # Dates
    due_date = models.DateTimeField(
        _('échéance'),
        null=True, 
        blank=True
    )
    completed_at = models.DateTimeField(
        _('terminée le'),
        null=True, 
        blank=True
    )
    
    # Ordre dans le Kanban
    order = models.IntegerField(
        _('ordre'),
        default=0,
        help_text="Position dans la colonne Kanban"
    )
    
    # Metadata
    is_important = models.BooleanField(
        _('importante'),
        default=False,
        help_text="Marquer comme prioritaire"
    )
    estimated_hours = models.DecimalField(
        _('temps estimé (heures)'),
        max_digits=5, 
        decimal_places=2, 
        null=True, 
        blank=True
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('tâche de projet')
        verbose_name_plural = _('tâches de projet')
        ordering = ['order', '-is_important', 'created_at']
        indexes = [
            models.Index(fields=['project', 'status']),
            models.Index(fields=['project', 'order']),
            models.Index(fields=['due_date']),
        ]
    
    def __str__(self):
        return f"{self.title} ({self.project.title})"
    
    def save(self, *args, **kwargs):
        """Override pour mettre à jour completed_at et recalculer la progression"""
        from django.utils import timezone
        
        # Mettre à jour completed_at automatiquement
        if self.status == 'DONE' and not self.completed_at:
            self.completed_at = timezone.now()
        elif self.status != 'DONE':
            self.completed_at = None
        
        super().save(*args, **kwargs)
        
        # Recalculer la progression du projet parent
        self.project.update_progress()
    
    def delete(self, *args, **kwargs):
        """Override pour recalculer la progression après suppression"""
        project = self.project
        super().delete(*args, **kwargs)
        # Recalculer après suppression
        project.update_progress()
    
    @property
    def is_overdue(self):
        """Vérifier si la tâche est en retard"""
        from django.utils import timezone
        
        if not self.due_date:
            return False
        return (
            self.due_date < timezone.now() and
            self.status != 'DONE'
        )