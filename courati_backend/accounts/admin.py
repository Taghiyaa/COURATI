# accounts/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.translation import gettext_lazy as _
from django.utils.html import format_html
from .models import (
    User, StudentProfile, AdminProfile, 
    Level, Major, TeacherProfile, TeacherAssignment
)

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    """Administration personnalisée pour le modèle User"""
    
    list_display = ('username', 'email', 'first_name', 'last_name', 'role', 'is_active', 'date_joined')
    list_filter = ('role', 'is_active', 'is_staff', 'is_superuser', 'date_joined')
    search_fields = ('username', 'email', 'first_name', 'last_name')
    ordering = ('-date_joined',)
    
    fieldsets = (
        (None, {'fields': ('username', 'password')}),
        (_('Informations personnelles'), {'fields': ('first_name', 'last_name', 'email', 'role')}),
        (_('Permissions'), {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
        }),
        (_('Dates importantes'), {'fields': ('last_login', 'date_joined')}),
    )
    
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'role', 'password1', 'password2'),
        }),
    )
    
    actions = ['make_active', 'make_inactive']
    
    def make_active(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, f"{queryset.count()} utilisateurs activés.")
    make_active.short_description = "Activer les utilisateurs sélectionnés"
    
    def make_inactive(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} utilisateurs désactivés.")
    make_inactive.short_description = "Désactiver les utilisateurs sélectionnés"

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('get_full_name', 'phone_number', 'level', 'major', 'is_verified', 'created_at')
    list_filter = ('level', 'major', 'is_verified', 'created_at')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name', 'phone_number')
    ordering = ('-created_at',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        (_('Utilisateur'), {'fields': ('user',)}),
        (_('Informations étudiant'), {'fields': ('phone_number', 'level', 'major', 'is_verified')}),
        (_('Vérification OTP'), {
            'fields': ('otp', 'otp_expiry'),
            'classes': ('collapse',)
        }),
        (_('Dates'), {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_full_name(self, obj):
        return obj.user.get_full_name()
    get_full_name.short_description = 'Nom complet'
    get_full_name.admin_order_field = 'user__first_name'
    
    actions = ['verify_students', 'unverify_students', 'clear_otp']
    
    def verify_students(self, request, queryset):
        queryset.update(is_verified=True, otp=None, otp_expiry=None)
        self.message_user(request, f"{queryset.count()} étudiants vérifiés.")
    verify_students.short_description = "Vérifier les étudiants sélectionnés"
    
    def unverify_students(self, request, queryset):
        queryset.update(is_verified=False)
        self.message_user(request, f"{queryset.count()} étudiants non vérifiés.")
    unverify_students.short_description = "Annuler la vérification"
    
    def clear_otp(self, request, queryset):
        queryset.update(otp=None, otp_expiry=None)
        self.message_user(request, f"OTP supprimé pour {queryset.count()} étudiants.")
    clear_otp.short_description = "Supprimer les OTP"

@admin.register(AdminProfile)
class AdminProfileAdmin(admin.ModelAdmin):
    list_display = ('get_full_name', 'department', 'phone_number', 'created_at')
    list_filter = ('department', 'created_at')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name', 'department')
    ordering = ('-created_at',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        (_('Utilisateur'), {'fields': ('user',)}),
        (_('Informations administrateur'), {'fields': ('department', 'phone_number')}),
        (_('Dates'), {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_full_name(self, obj):
        return obj.user.get_full_name()
    get_full_name.short_description = 'Nom complet'
    get_full_name.admin_order_field = 'user__first_name'

@admin.register(Level)
class LevelAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'order', 'is_active', 'created_by', 'created_at')
    list_filter = ('is_active', 'created_by', 'created_at')
    search_fields = ('code', 'name', 'description')
    ordering = ('order', 'code')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        (_('Informations principales'), {'fields': ('code', 'name', 'description')}),
        (_('Configuration'), {'fields': ('order', 'is_active')}),
        (_('Métadonnées'), {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['activate_levels', 'deactivate_levels']
    
    def activate_levels(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, f"{queryset.count()} niveaux activés.")
    activate_levels.short_description = "Activer les niveaux sélectionnés"
    
    def deactivate_levels(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} niveaux désactivés.")
    deactivate_levels.short_description = "Désactiver les niveaux sélectionnés"
    
    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)

@admin.register(Major)
class MajorAdmin(admin.ModelAdmin):
    list_display = ('code', 'name', 'department', 'order', 'is_active', 'created_by', 'created_at')
    list_filter = ('is_active', 'department', 'created_by', 'created_at')
    search_fields = ('code', 'name', 'description', 'department')
    ordering = ('order', 'name')
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        (_('Informations principales'), {'fields': ('code', 'name', 'description')}),
        (_('Organisation'), {'fields': ('department', 'order', 'is_active')}),
        (_('Métadonnées'), {
            'fields': ('created_by', 'created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    actions = ['activate_majors', 'deactivate_majors']
    
    def activate_majors(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, f"{queryset.count()} filières activées.")
    activate_majors.short_description = "Activer les filières sélectionnées"
    
    def deactivate_majors(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} filières désactivées.")
    deactivate_majors.short_description = "Désactiver les filières sélectionnées"
    
    def save_model(self, request, obj, form, change):
        if not change:
            obj.created_by = request.user
        super().save_model(request, obj, form, change)

# ========================================
# ADMINISTRATION DES PROFESSEURS
# ========================================

@admin.register(TeacherProfile)
class TeacherProfileAdmin(admin.ModelAdmin):
    """Administration pour les profils professeurs"""
    
    list_display = ('get_full_name', 'specialization', 'phone_number', 'office', 'get_subjects_count', 'created_at')
    list_filter = ('specialization', 'created_at')
    search_fields = ('user__username', 'user__email', 'user__first_name', 'user__last_name', 'specialization')
    ordering = ('-created_at',)
    readonly_fields = ('created_at', 'updated_at')
    
    fieldsets = (
        (_('Utilisateur'), {'fields': ('user',)}),
        (_('Informations professeur'), {
            'fields': ('phone_number', 'specialization', 'bio')
        }),
        (_('Bureau et permanence'), {
            'fields': ('office', 'office_hours')
        }),
        (_('Dates'), {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def get_full_name(self, obj):
        return obj.user.get_full_name()
    get_full_name.short_description = 'Nom complet'
    get_full_name.admin_order_field = 'user__first_name'
    
    def get_subjects_count(self, obj):
        count = obj.user.teacher_assignments.filter(is_active=True).count()
        return format_html('<span style="font-weight:bold;">{}</span>', count)
    get_subjects_count.short_description = 'Matières assignées'

    def formfield_for_foreignkey(self, db_field, request, **kwargs):
        """Filtrer pour n'afficher que les professeurs dans le champ user"""
        if db_field.name == "user":
            kwargs["queryset"] = User.objects.filter(role='TEACHER')
        return super().formfield_for_foreignkey(db_field, request, **kwargs)

class TeacherAssignmentInline(admin.TabularInline):
    """Inline pour voir les assignations dans Subject admin"""
    model = TeacherAssignment
    extra = 1
    fields = ('teacher', 'can_edit_content', 'can_upload_documents', 'can_delete_documents', 'can_manage_students', 'is_active')
    readonly_fields = ('assigned_date',)

@admin.register(TeacherAssignment)
class TeacherAssignmentAdmin(admin.ModelAdmin):
    """Administration pour les assignations professeur-matière"""
    
    list_display = (
        'get_teacher_name', 
        'get_subject_name', 
        'can_upload_documents', 
        'can_edit_content',
        'can_manage_students',
        'is_active', 
        'assigned_date'
    )
    list_filter = (
        'is_active', 
        'can_edit_content', 
        'can_upload_documents', 
        'can_delete_documents',
        'can_manage_students',
        'assigned_date'
    )
    search_fields = (
        'teacher__username', 
        'teacher__first_name', 
        'teacher__last_name',
        'subject__name', 
        'subject__code'
    )
    ordering = ('-assigned_date',)
    readonly_fields = ('assigned_date', 'assigned_by')
    
    fieldsets = (
        (_('Assignation'), {
            'fields': ('teacher', 'subject', 'is_active')
        }),
        (_('Permissions'), {
            'fields': (
                'can_edit_content',
                'can_upload_documents',
                'can_delete_documents',
                'can_manage_students'
            ),
            'description': 'Définissez les permissions du professeur pour cette matière'
        }),
        (_('Informations'), {
            'fields': ('notes', 'assigned_by', 'assigned_date'),
            'classes': ('collapse',)
        }),
    )
    
    def get_teacher_name(self, obj):
        return obj.teacher.get_full_name()
    get_teacher_name.short_description = 'Professeur'
    get_teacher_name.admin_order_field = 'teacher__first_name'
    
    def get_subject_name(self, obj):
        return f"{obj.subject.code} - {obj.subject.name}"
    get_subject_name.short_description = 'Matière'
    get_subject_name.admin_order_field = 'subject__name'
    
    def save_model(self, request, obj, form, change):
        if not change:
            obj.assigned_by = request.user
        super().save_model(request, obj, form, change)
    
    actions = ['activate_assignments', 'deactivate_assignments', 'grant_full_permissions']
    
    def activate_assignments(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, f"{queryset.count()} assignations activées.")
    activate_assignments.short_description = "Activer les assignations"
    
    def deactivate_assignments(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} assignations désactivées.")
    deactivate_assignments.short_description = "Désactiver les assignations"
    
    def grant_full_permissions(self, request, queryset):
        queryset.update(
            can_edit_content=True,
            can_upload_documents=True,
            can_delete_documents=True,
            can_manage_students=True
        )
        self.message_user(request, f"Toutes les permissions accordées pour {queryset.count()} assignations.")
    grant_full_permissions.short_description = "Accorder toutes les permissions"

# Configuration de l'admin Django
admin.site.site_header = "Administration Courati"
admin.site.site_title = "Courati Admin"
admin.site.index_title = "Panneau d'administration"