# courses/views.py
import logging
from django.db.models import Q, Count, Avg, Max, Sum
from django.utils import timezone
from django.shortcuts import get_object_or_404
from datetime import datetime, timedelta

from rest_framework import status, permissions, viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes, action

from accounts.models import StudentProfile
from .models import (
    Subject, Document, UserActivity, UserFavorite, UserProgress,
    Quiz, Question, Choice, QuizAttempt, StudentAnswer,
    StudentProject, ProjectTask  
)
from .serializers import (
    # Serializers existants
    SubjectSimpleSerializer, DocumentSerializer, UserActivitySerializer,
    UserFavoriteSerializer, UserProgressSerializer, ConsultationActivitySerializer, 
    ConsultationStatsSerializer, ConsultationDocumentSerializer,
    ConsultationSubjectSerializer, ConsultationHistoryResponseSerializer,
    PersonalizedHomeSerializer, TeacherSubjectSerializer,
    
    # Nouveaux serializers Quiz
    QuizListSerializer, QuizDetailSerializer, QuizAttemptCreateSerializer,
    QuizAttemptSerializer, QuizSubmitSerializer, QuizResultSerializer,
    QuizCorrectionSerializer, QuizStatisticsSerializer,

    # ✅ AJOUTER CES LIGNES - Serializers Projets
    ProjectTaskSerializer,
    ProjectTaskCreateUpdateSerializer,
    ProjectTaskMoveSerializer,
    StudentProjectListSerializer,
    StudentProjectDetailSerializer,
    ProjectStatisticsSerializer
)

# Permissions personnalisées
from accounts.permissions import (
    IsTeacherUser, IsAdminOrTeacher, HasSubjectAccess,
    TeacherSubjectPermission, has_subject_access,
    can_upload_document, get_teacher_subjects,
    can_manage_students, can_delete_document
)

logger = logging.getLogger(__name__)

# ========================================
# VUES ÉTUDIANTS - CONSULTATION DES COURS
# ========================================

class StudentSubjectsView(APIView):
    """Matières personnalisées pour l'étudiant connecté"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        logger.info(f"📚 Récupération matières pour: {user.username}")
        
        if not user.is_student():
            return Response({
                'error': 'Seuls les étudiants peuvent accéder à cette ressource'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            user_level = student_profile.level
            user_major = student_profile.major
            
            if not user_level or not user_major:
                return Response({
                    'error': 'Profil étudiant incomplet. Niveau ou filière manquant.',
                    'suggestion': 'Complétez votre profil dans les paramètres'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Filtrer les matières selon le niveau et la filière de l'étudiant
            subjects = Subject.objects.filter(
                levels=user_level,
                majors=user_major,
                is_active=True
            ).prefetch_related('levels', 'majors').annotate(
                document_count=Count('documents', filter=Q(documents__is_active=True))
            ).order_by('order', 'name')
            
            # Paramètres de filtrage optionnels
            is_featured = request.GET.get('featured', None)
            if is_featured and is_featured.lower() == 'true':
                subjects = subjects.filter(is_featured=True)
            
            # Récupérer les favoris de l'utilisateur
            user_favorites = UserFavorite.objects.filter(
                user=user,
                favorite_type='SUBJECT',
                subject__in=subjects
            ).values_list('subject_id', flat=True)
            
            serializer = SubjectSimpleSerializer(subjects, many=True, context={
                'request': request,
                'user_favorites': list(user_favorites)
            })
            
            return Response({
                'success': True,
                'student_info': {
                    'level': user_level.name,
                    'major': user_major.name,
                },
                'total_subjects': subjects.count(),
                'subjects': serializer.data,
                'filters_applied': {
                    'featured_only': is_featured
                }
            })
            
        except StudentProfile.DoesNotExist:
            return Response({
                'error': 'Profil étudiant non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur récupération matières pour {user.username}: {str(e)}")
            return Response({
                'error': 'Erreur serveur lors de la récupération des matières',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SubjectDocumentsView(APIView):
    """Documents d'une matière spécifique pour l'étudiant"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, subject_id):
        user = request.user
        logger.info(f"📄 Documents matière {subject_id} pour: {user.username}")
        
        if not user.is_student():
            return Response({
                'error': 'Accès refusé'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            
            # Vérifier que l'étudiant peut accéder à cette matière
            subject = Subject.objects.get(
                id=subject_id,
                levels=student_profile.level,
                majors=student_profile.major,
                is_active=True
            )
            
            # Récupérer les documents de la matière
            documents = Document.objects.filter(
                subject=subject,
                is_active=True
            ).select_related('created_by').order_by('order', 'title')
            
            # Filtres optionnels
            doc_type = request.GET.get('type', None)
            if doc_type:
                documents = documents.filter(document_type=doc_type)
            
            # Récupérer les favoris de l'utilisateur
            user_doc_favorites = UserFavorite.objects.filter(
                user=user,
                favorite_type='DOCUMENT',
                document__in=documents
            ).values_list('document_id', flat=True)
            
            # ✅ AJOUTER : Récupérer les documents consultés
            user_viewed_docs = UserProgress.objects.filter(
                user=user,
                subject=subject,
                document__in=documents,
                status__in=['IN_PROGRESS', 'COMPLETED']
            ).values_list('document_id', flat=True)
            
            # Récupérer la progression
            user_progress = UserProgress.objects.filter(
                user=user,
                subject=subject,
                document__in=documents
            ).values('document_id', 'status', 'progress_percentage')
            
            progress_dict = {p['document_id']: p for p in user_progress}
            
            # ✅ Sérialiser avec TOUS les contextes
            serializer = DocumentSerializer(documents, many=True, context={
                'request': request,
                'user_favorites': list(user_doc_favorites),
                'user_progress': progress_dict,
                'user_viewed': set(user_viewed_docs),  # ✅ LIGNE AJOUTÉE
            })
            
            return Response({
                'success': True,
                'subject': {
                    'id': subject.id,
                    'name': subject.name,
                    'code': subject.code,
                    'credits': subject.credits
                },
                'total_documents': documents.count(),
                'documents': serializer.data,
                'document_types': [choice[0] for choice in Document.DOCUMENT_TYPES]
            })
            
        except Subject.DoesNotExist:
            return Response({
                'error': 'Matière non trouvée ou non accessible pour votre profil'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur documents matière {subject_id}: {str(e)}")
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# GESTION DES FAVORIS
# ========================================

class UserFavoritesView(APIView):
    """Gestion des favoris de l'utilisateur"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        """Récupérer tous les favoris de l'utilisateur"""
        user = request.user
        
        favorites = UserFavorite.objects.filter(user=user).select_related(
            'subject', 'document', 'document__subject'
        ).order_by('-created_at')
        
        serializer = UserFavoriteSerializer(favorites, many=True)
        
        return Response({
            'success': True,
            'total_favorites': favorites.count(),
            'favorites': serializer.data
        })

    def post(self, request):
        """Toggle un favori (ajouter ou supprimer)"""
        user = request.user
        favorite_type = request.data.get('type')
        object_id = request.data.get('id')
        
        if favorite_type == 'DOCUMENT':
            try:
                document = Document.objects.get(id=object_id, is_active=True)
                
                favorite = UserFavorite.objects.filter(
                    user=user,
                    favorite_type='DOCUMENT',
                    document=document
                ).first()
                
                if favorite:
                    favorite.delete()
                    # Enregistrer l'activité
                    UserActivity.objects.create(
                        user=user,
                        document=document,
                        subject=document.subject,
                        action='unfavorite'
                    )
                    return Response({
                        'success': True,
                        'message': f'Document "{document.title}" retiré des favoris',
                        'action': 'removed',
                        'is_favorite': False
                    })
                else:
                    UserFavorite.objects.create(
                        user=user,
                        favorite_type='DOCUMENT',
                        document=document
                    )
                    # Enregistrer l'activité
                    UserActivity.objects.create(
                        user=user,
                        document=document,
                        subject=document.subject,
                        action='favorite'
                    )
                    return Response({
                        'success': True,
                        'message': f'Document "{document.title}" ajouté aux favoris',
                        'action': 'added',
                        'is_favorite': True
                    })
                    
            except Document.DoesNotExist:
                return Response({
                    'error': 'Document non trouvé'
                }, status=status.HTTP_404_NOT_FOUND)

# ========================================
# GESTION DES TÉLÉCHARGEMENTS
# ========================================

class DocumentDownloadView(APIView):
    """Téléchargement de documents avec suivi"""
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request, document_id):  # CHANGÉ: de GET à POST
        user = request.user
        
        if not user.is_student():
            return Response({
                'error': 'Seuls les étudiants peuvent télécharger des documents'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            
            # Vérifier l'accès au document
            document = Document.objects.select_related('subject').get(
                id=document_id,
                is_active=True,
                subject__levels=student_profile.level,
                subject__majors=student_profile.major,
                subject__is_active=True
            )
            
            # Enregistrer l'activité de téléchargement
            UserActivity.objects.create(
                user=user,
                document=document,
                subject=document.subject,
                action='download',
                ip_address=self.get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', '')
            )
            
            # Incrémenter le compteur de téléchargements
            document.download_count += 1
            document.save(update_fields=['download_count'])
            
            # Mettre à jour la progression
            progress, created = UserProgress.objects.get_or_create(
                user=user,
                subject=document.subject,
                document=document,
                defaults={
                    'status': 'IN_PROGRESS',
                    'started_at': timezone.now()
                }
            )
            
            if created or progress.status == 'NOT_STARTED':
                progress.status = 'IN_PROGRESS'
                progress.started_at = timezone.now()
                progress.save()
            
            progress.last_accessed = timezone.now()
            progress.save(update_fields=['last_accessed'])
            
            logger.info(f"📥 Téléchargement: {document.title} par {user.username}")
            
            return Response({
                'success': True,
                'download_url': request.build_absolute_uri(document.file.url),
                'document': {
                    'id': document.id,
                    'title': document.title,
                    'file_size_mb': document.file_size_mb,
                    'type': document.document_type,
                    'type_display': document.get_document_type_display()
                },
                'message': 'Document prêt au téléchargement'
            })
            
        except Document.DoesNotExist:
            return Response({
                'error': 'Document non trouvé ou non accessible'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur téléchargement document {document_id}: {str(e)}")
            return Response({
                'error': 'Erreur serveur lors du téléchargement',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def get_client_ip(self, request):
        """Récupérer l'adresse IP du client"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip
# ========================================
# PAGE D'ACCUEIL PERSONNALISÉE
# ========================================

class PersonalizedHomeView(APIView):
    """Page d'accueil personnalisée selon le profil étudiant"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        logger.info(f"🏠 Page d'accueil personnalisée pour: {user.username}")
        
        if not user.is_student():
            return Response({
                'error': 'Fonctionnalité réservée aux étudiants'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            
            if not student_profile.level or not student_profile.major:
                return Response({
                    'error': 'Profil incomplet',
                    'message': 'Veuillez compléter votre profil (niveau et filière)',
                    'action_required': True,
                    'redirect_to': 'profile_completion'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Matières recommandées pour ce profil
            recommended_subjects = Subject.objects.filter(
                levels=student_profile.level,
                majors=student_profile.major,
                is_active=True
            ).prefetch_related('levels', 'majors').annotate(
                document_count=Count('documents', filter=Q(documents__is_active=True))
            ).order_by('-is_featured', 'order')[:6]
            
            # Matières en cours (avec progression)
            in_progress_subjects = Subject.objects.filter(
                user_progress__user=user,
                user_progress__status='IN_PROGRESS'
            ).distinct()[:4]
            
            # Documents récents pour ce profil
            recent_documents = Document.objects.filter(
                subject__levels=student_profile.level,
                subject__majors=student_profile.major,
                is_active=True
            ).select_related('subject').order_by('-created_at')[:5]
            
            # Favoris récents
            recent_favorites = UserFavorite.objects.filter(
                user=user
            ).select_related('subject', 'document').order_by('-created_at')[:5]
            
            # ✅ AMÉLIORATION : Statistiques avec progression globale ET par matière
            total_subjects = Subject.objects.filter(
                levels=student_profile.level,
                majors=student_profile.major,
                is_active=True
            ).count()

            # Total de documents disponibles pour ce profil
            total_documents = Document.objects.filter(
                subject__levels=student_profile.level,
                subject__majors=student_profile.major,
                subject__is_active=True,
                is_active=True
            ).count()

            # Documents consultés (IN_PROGRESS ou COMPLETED)
            viewed_documents = UserProgress.objects.filter(
                user=user,
                status__in=['IN_PROGRESS', 'COMPLETED']
            ).values('document').distinct().count()

            # Calcul de la progression réelle
            if total_documents > 0:
                completion_rate = round((viewed_documents / total_documents) * 100, 1)
            else:
                completion_rate = 0.0

            # ✨ NOUVEAU : Progression détaillée par matière
            subject_progress = {}
            completed_subjects = 0

            for subject in Subject.objects.filter(
                levels=student_profile.level,
                majors=student_profile.major,
                is_active=True
            ):
                subject_docs = Document.objects.filter(
                    subject=subject,
                    is_active=True
                ).count()
                
                if subject_docs > 0:
                    viewed_in_subject = UserProgress.objects.filter(
                        user=user,
                        subject=subject,
                        status__in=['IN_PROGRESS', 'COMPLETED']
                    ).values('document').distinct().count()
                    
                    # ✅ Calculer le taux de progression pour cette matière
                    subject_rate = round((viewed_in_subject / subject_docs) * 100, 1)
                    
                    # ✅ Stocker dans le dictionnaire
                    subject_progress[str(subject.id)] = {
                        'viewed_documents': viewed_in_subject,
                        'total_documents': subject_docs,
                        'completion_rate': subject_rate,
                        'is_completed': viewed_in_subject == subject_docs
                    }
                    
                    # Compter les matières complétées à 100%
                    if viewed_in_subject == subject_docs:
                        completed_subjects += 1

            total_favorites = UserFavorite.objects.filter(user=user).count()

            serializer = PersonalizedHomeSerializer({
                'user': user,
                'student_profile': student_profile,
                'recommended_subjects': recommended_subjects,
                'in_progress_subjects': in_progress_subjects,
                'recent_documents': recent_documents,
                'recent_favorites': recent_favorites,
                'stats': {
                    'total_subjects': total_subjects,
                    'completed_subjects': completed_subjects,
                    'total_favorites': total_favorites,
                    'completion_rate': completion_rate,
                    'total_documents': total_documents,
                    'viewed_documents': viewed_documents,
                },
                # ✅ NOUVEAU CHAMP : Progression par matière
                'subject_progress': subject_progress
            })
            
            return Response({
                'success': True,
                'personalized': True,
                'data': serializer.data
            })
            
        except StudentProfile.DoesNotExist:
            return Response({
                'error': 'Profil étudiant non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur page d'accueil pour {user.username}: {str(e)}")
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# APIS PUBLIQUES POUR LES CHOIX
# ========================================

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_document_types(request):
    """API publique pour récupérer les types de documents"""
    return Response({
        'success': True,
        'document_types': [
            {'value': choice[0], 'label': choice[1]} 
            for choice in Document.DOCUMENT_TYPES
        ]
    })

class UserHistoryView(APIView):
    """Historique des activités de l'utilisateur"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        logger.info(f"📊 Récupération historique pour: {user.username}")
        
        try:
            # Récupérer les activités des 30 derniers jours par défaut
            from datetime import datetime, timedelta
            days_ago = int(request.GET.get('days', 30))
            since_date = datetime.now() - timedelta(days=days_ago)
            
            activities = UserActivity.objects.filter(
                user=user,
                created_at__gte=since_date
            ).select_related('document', 'subject').order_by('-created_at')
            
            # Filtrer par type d'action si spécifié
            action_filter = request.GET.get('action')
            if action_filter and action_filter in ['download', 'view', 'favorite', 'unfavorite']:
                activities = activities.filter(action=action_filter)
            
            # Limiter le nombre de résultats
            limit = int(request.GET.get('limit', 100))
            activities = activities[:limit]
            
            serializer = UserActivitySerializer(activities, many=True)
            
            # Statistiques rapides
            stats = {
                'total_downloads': UserActivity.objects.filter(user=user, action='download').count(),
                'total_views': UserActivity.objects.filter(user=user, action='view').count(),
                'total_favorites': UserFavorite.objects.filter(user=user).count(),
                'last_activity': activities.first().created_at if activities.exists() else None
            }
            
            return Response({
                'success': True,
                'history': serializer.data,
                'total': activities.count(),
                'stats': stats,
                'filters': {
                    'days': days_ago,
                    'action': action_filter,
                    'limit': limit
                }
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur récupération historique: {str(e)}")
            return Response({
                'success': False,
                'message': f'Erreur lors de la récupération de l\'historique: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class DocumentViewTrackingView(APIView):
    """Suivi des consultations de documents + URL de visualisation"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, document_id):
        """Obtenir l'URL de visualisation du document"""
        user = request.user
        
        if not user.is_student():
            return Response({
                'success': False,
                'message': 'Seuls les étudiants peuvent consulter les documents'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            
            # Vérifier l'accès au document
            document = Document.objects.select_related('subject').get(
                id=document_id,
                is_active=True,
                subject__levels=student_profile.level,
                subject__majors=student_profile.major,
                subject__is_active=True
            )
            
            # Générer l'URL de visualisation
            if document.file:
                view_url = request.build_absolute_uri(document.file.url)
                
                return Response({
                    'success': True,
                    'view_url': view_url,
                    'document_info': {
                        'id': document.id,
                        'title': document.title,
                        'type': document.document_type,
                        'type_display': document.get_document_type_display(),
                        'size': document.file.size if hasattr(document.file, 'size') else 0,
                    }
                })
            else:
                return Response({
                    'success': False,
                    'message': 'Fichier non disponible'
                }, status=status.HTTP_404_NOT_FOUND)
                
        except Document.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Document non trouvé ou non accessible'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur get view URL document {document_id}: {str(e)}")
            return Response({
                'success': False,
                'message': f'Erreur serveur: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request, document_id):
        """Marquer un document comme consulté"""
        user = request.user
        
        if not user.is_student():
            return Response({
                'success': False,
                'message': 'Seuls les étudiants peuvent consulter les documents'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            
            # Vérifier l'accès au document
            document = Document.objects.select_related('subject').get(
                id=document_id,
                is_active=True,
                subject__levels=student_profile.level,
                subject__majors=student_profile.major,
                subject__is_active=True
            )
            
            # Enregistrer l'activité de consultation
            UserActivity.objects.create(
                user=user,
                document=document,
                subject=document.subject,
                action='view',
                ip_address=self.get_client_ip(request),
                user_agent=request.META.get('HTTP_USER_AGENT', '')
            )
            
            # Incrémenter le compteur de vues (si le champ existe)
            if hasattr(document, 'view_count'):
                document.view_count += 1
                document.save(update_fields=['view_count'])
            
            # Mettre à jour la progression si nécessaire
            progress, created = UserProgress.objects.get_or_create(
                user=user,
                subject=document.subject,
                document=document,
                defaults={
                    'status': 'IN_PROGRESS',
                    'started_at': timezone.now()
                }
            )
            
            progress.last_accessed = timezone.now()
            progress.save(update_fields=['last_accessed'])
            
            logger.info(f"👁 Consultation: {document.title} par {user.username}")
            
            return Response({
                'success': True,
                'message': 'Consultation enregistrée',
                'document_info': {
                    'id': document.id,
                    'title': document.title,
                    'view_count': getattr(document, 'view_count', 0)
                }
            })
            
        except Document.DoesNotExist:
            return Response({
                'success': False,
                'message': 'Document non trouvé ou non accessible'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur enregistrement consultation {document_id}: {str(e)}")
            return Response({
                'success': False,
                'message': f'Erreur serveur: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def get_client_ip(self, request):
        """Récupérer l'adresse IP du client"""
        x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        if x_forwarded_for:
            ip = x_forwarded_for.split(',')[0]
        else:
            ip = request.META.get('REMOTE_ADDR')
        return ip

# Ajouter cette nouvelle vue dans courses/views.py

class DocumentConsultationHistoryView(APIView):
    """Historique spécifique des consultations de documents"""
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        user = request.user
        logger.info(f"📖 Historique consultations pour: {user.username}")
        
        try:
            # Récupérer uniquement les consultations (view et download)
            consultations = UserActivity.objects.filter(
                user=user,
                action__in=['view', 'download']
            ).select_related(
                'document', 
                'subject'
            )
            
            # CORRECTION: Appliquer TOUS les filtres AVANT le slice (.order_by, .filter, etc.)
            
            # Filtrer par période si spécifié
            days_ago = int(request.GET.get('days', 30))
            if days_ago > 0:
                from datetime import datetime, timedelta
                since_date = datetime.now() - timedelta(days=days_ago)
                consultations = consultations.filter(created_at__gte=since_date)
            
            # Ordonner AVANT de faire le slice
            consultations = consultations.order_by('-created_at')
            
            # Limiter les résultats EN DERNIER
            limit = int(request.GET.get('limit', 50))
            consultations = consultations[:limit]
            
            # Récupérer les favoris de l'utilisateur pour ces documents
            document_ids = [c.document.id for c in consultations if c.document]
            user_favorites = UserFavorite.objects.filter(
                user=user,
                favorite_type='DOCUMENT',
                document_id__in=document_ids
            ).values_list('document_id', flat=True)
            
            # Sérialiser les consultations avec le contexte des favoris
            serializer = ConsultationActivitySerializer(
                consultations, 
                many=True, 
                context={
                    'request': request,
                    'user_favorites': list(user_favorites)
                }
            )
            
            # CORRECTION: Calculer les statistiques sur des QuerySet séparés (pas sur le slice)
            all_consultations = UserActivity.objects.filter(
                user=user,
                action__in=['view', 'download']
            )
            
            if days_ago > 0:
                all_consultations = all_consultations.filter(created_at__gte=since_date)
            
            total_views = all_consultations.filter(action='view').count()
            total_downloads = all_consultations.filter(action='download').count()
            unique_documents = all_consultations.values('document').distinct().count()
            
            stats_data = {
                'total_consultations': all_consultations.count(),
                'total_views': total_views,
                'total_downloads': total_downloads,
                'unique_documents': unique_documents
            }
            
            stats_serializer = ConsultationStatsSerializer(stats_data)
            
            return Response({
                'success': True,
                'consultations': serializer.data,
                'stats': stats_serializer.data,
                'filters': {
                    'days': days_ago,
                    'limit': limit
                }
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur historique consultations: {str(e)}")
            return Response({
                'success': False,
                'message': f'Erreur lors de la récupération de l\'historique: {str(e)}'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    def delete(self, request):
        """Effacer l'historique de consultation"""
        user = request.user
        
        try:
            # Supprimer uniquement les consultations (view/download)
            deleted_count = UserActivity.objects.filter(
                user=user,
                action__in=['view', 'download']
            ).delete()[0]
            
            logger.info(f"🗑 Historique effacé pour {user.username}: {deleted_count} entrées")
            
            return Response({
                'success': True,
                'message': f'{deleted_count} consultations supprimées de votre historique'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression historique: {str(e)}")
            return Response({
                'success': False,
                'message': 'Erreur lors de la suppression de l\'historique'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    
    # ========================================
# VUES PROFESSEURS - GESTION DES MATIÈRES
# ========================================

from accounts.permissions import (
    IsTeacherUser, IsAdminOrTeacher, HasSubjectAccess,
    TeacherSubjectPermission, has_subject_access,
    can_upload_document, get_teacher_subjects
)
from .serializers import TeacherSubjectSerializer


class TeacherSubjectsView(APIView):
    """Liste des matières assignées à un professeur"""
    permission_classes = [IsTeacherUser]
    
    def get(self, request):
        user = request.user
        logger.info(f"👨‍🏫 Matières du professeur: {user.username}")
        
        try:
            # Récupérer les matières assignées
            subjects = get_teacher_subjects(user)
            
            # Annoter avec le nombre de documents
            subjects = subjects.annotate(
                document_count=Count('documents', filter=Q(documents__is_active=True))
            ).order_by('name')
            
            serializer = TeacherSubjectSerializer(
                subjects, 
                many=True, 
                context={'request': request}
            )
            
            return Response({
                'success': True,
                'teacher_info': {
                    'name': user.get_full_name(),
                    'email': user.email,
                },
                'total_subjects': subjects.count(),
                'subjects': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur matières professeur {user.username}: {str(e)}")
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TeacherSubjectStudentsView(APIView):
    """Liste des étudiants d'une matière pour un professeur"""
    permission_classes = [IsTeacherUser]
    
    def get(self, request, subject_id):
        user = request.user
        logger.info(f"👥 Étudiants matière {subject_id} par prof: {user.username}")
        
        try:
            # Vérifier l'accès à la matière
            subject = Subject.objects.get(id=subject_id, is_active=True)
            
            if not has_subject_access(user, subject):
                return Response({
                    'error': 'Vous n\'avez pas accès à cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Vérifier la permission de gestion étudiants
            from accounts.permissions import can_manage_students
            if not can_manage_students(user, subject):
                return Response({
                    'error': 'Vous n\'avez pas la permission de voir les étudiants'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Récupérer les étudiants concernés par cette matière
            students = StudentProfile.objects.filter(
                level__in=subject.levels.all(),
                major__in=subject.majors.all()
            ).select_related('user', 'level', 'major')
            
            # Enrichir avec les progressions
            students_data = []
            for student in students:
                # Progression dans cette matière
                progress_docs = UserProgress.objects.filter(
                    user=student.user,
                    subject=subject
                )
                
                total_docs = Document.objects.filter(
                    subject=subject,
                    is_active=True
                ).count()
                
                viewed_docs = progress_docs.filter(
                    status__in=['IN_PROGRESS', 'COMPLETED']
                ).count()
                
                students_data.append({
                    'id': student.user.id,
                    'full_name': student.user.get_full_name(),
                    'email': student.user.email,
                    'level': student.level.name if student.level else None,
                    'major': student.major.name if student.major else None,
                    'progress': {
                        'total_documents': total_docs,
                        'viewed_documents': viewed_docs,
                        'completion_rate': round((viewed_docs / total_docs * 100) if total_docs > 0 else 0, 1)
                    }
                })
            
            return Response({
                'success': True,
                'subject': {
                    'id': subject.id,
                    'name': subject.name,
                    'code': subject.code
                },
                'total_students': len(students_data),
                'students': students_data
            })
            
        except Subject.DoesNotExist:
            return Response({
                'error': 'Matière non trouvée'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur étudiants matière {subject_id}: {str(e)}")
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TeacherUploadDocumentView(APIView):
    """Upload de document par un professeur"""
    permission_classes = [IsTeacherUser]
    
    def post(self, request, subject_id):
        user = request.user
        logger.info(f"📤 Upload document matière {subject_id} par: {user.username}")
        
        try:
            # Vérifier l'accès et la permission
            subject = Subject.objects.get(id=subject_id, is_active=True)
            
            if not can_upload_document(user, subject):
                return Response({
                    'error': 'Vous n\'avez pas la permission d\'uploader des documents pour cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Créer le document
            title = request.data.get('title')
            description = request.data.get('description', '')
            document_type = request.data.get('document_type', 'COURS')
            file = request.FILES.get('file')
            
            if not title or not file:
                return Response({
                    'error': 'Titre et fichier requis'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            document = Document.objects.create(
                subject=subject,
                title=title,
                description=description,
                document_type=document_type,
                file=file,
                created_by=user,
                is_active=True
            )
            
            serializer = DocumentSerializer(document, context={'request': request})
            
            logger.info(f"✅ Document créé: {document.title} par {user.username}")
            
            return Response({
                'success': True,
                'message': f'Document "{title}" ajouté avec succès',
                'document': serializer.data
            }, status=status.HTTP_201_CREATED)
            
        except Subject.DoesNotExist:
            return Response({
                'error': 'Matière non trouvée'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur upload document: {str(e)}")
            return Response({
                'error': 'Erreur lors de l\'upload',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TeacherDeleteDocumentView(APIView):
    """Suppression de document par un professeur"""
    permission_classes = [IsTeacherUser]
    
    def delete(self, request, document_id):
        user = request.user
        logger.info(f"🗑 Suppression document {document_id} par: {user.username}")
        
        try:
            document = Document.objects.select_related('subject').get(id=document_id)
            
            # Vérifier la permission de suppression
            from accounts.permissions import can_delete_document
            if not can_delete_document(user, document):
                return Response({
                    'error': 'Vous n\'avez pas la permission de supprimer ce document'
                }, status=status.HTTP_403_FORBIDDEN)
            
            document_title = document.title
            document.delete()
            
            logger.info(f"✅ Document supprimé: {document_title} par {user.username}")
            
            return Response({
                'success': True,
                'message': f'Document "{document_title}" supprimé avec succès'
            })
            
        except Document.DoesNotExist:
            return Response({
                'error': 'Document non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur suppression document: {str(e)}")
            return Response({
                'error': 'Erreur lors de la suppression',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TeacherSubjectStatisticsView(APIView):
    """Statistiques d'une matière pour un professeur"""
    permission_classes = [IsTeacherUser]
    
    def get(self, request, subject_id):
        user = request.user
        logger.info(f"📊 Stats matière {subject_id} par prof: {user.username}")
        
        try:
            subject = Subject.objects.get(id=subject_id, is_active=True)
            
            if not has_subject_access(user, subject):
                return Response({
                    'error': 'Accès refusé'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Statistiques des documents
            total_documents = Document.objects.filter(
                subject=subject,
                is_active=True
            ).count()
            
            total_views = UserActivity.objects.filter(
                subject=subject,
                action='view'
            ).count()
            
            total_downloads = UserActivity.objects.filter(
                subject=subject,
                action='download'
            ).count()
            
            # Top 5 documents les plus consultés
            top_documents = Document.objects.filter(
                subject=subject,
                is_active=True
            ).order_by('-view_count')[:5]
            
            top_docs_data = [{
                'id': doc.id,
                'title': doc.title,
                'views': doc.view_count,
                'downloads': doc.download_count
            } for doc in top_documents]
            
            # Nombre d'étudiants
            student_count = StudentProfile.objects.filter(
                level__in=subject.levels.all(),
                major__in=subject.majors.all()
            ).count()
            
            return Response({
                'success': True,
                'subject': {
                    'id': subject.id,
                    'name': subject.name,
                    'code': subject.code
                },
                'statistics': {
                    'total_documents': total_documents,
                    'total_views': total_views,
                    'total_downloads': total_downloads,
                    'student_count': student_count,
                    'top_documents': top_docs_data
                }
            })
            
        except Subject.DoesNotExist:
            return Response({
                'error': 'Matière non trouvée'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur stats matière: {str(e)}")
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# courses/views.py - REMPLACER tout le QuizViewSet

class QuizViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet pour gérer les quiz
    
    Liste: GET /api/quiz/
    Détail: GET /api/quiz/{id}/
    Démarrer: POST /api/quiz/{id}/start/
    Soumettre: POST /api/quiz/{id}/submit/
    Résultats: GET /api/quiz/{id}/results/
    Correction: GET /api/quiz/{id}/correction/{attempt_id}/
    Mes Quiz: GET /api/quiz/my_quizzes/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """
        Récupérer les quiz en fonction du rôle ET de la filière actuelle
        ✅ ISOLATION PAR FILIÈRE POUR LES ÉTUDIANTS
        """
        user = self.request.user
    
        if user.is_staff or user.role == 'ADMIN':
            return Quiz.objects.all()
        elif user.role == 'TEACHER':
            teacher_subjects = get_teacher_subjects(user)
            return Quiz.objects.filter(subject__in=teacher_subjects)
        else:
            # ÉTUDIANT : FILTRAGE PAR NIVEAU ET FILIÈRE ACTUELS
            try:
                student_profile = user.student_profile
                return Quiz.objects.filter(
                    is_active=True,
                    subject__levels=student_profile.level,
                    subject__majors=student_profile.major
                ).distinct()
            except AttributeError:
                return Quiz.objects.none()
    
    def get_serializer_class(self):
        if self.action == 'list':
            return QuizListSerializer
        return QuizDetailSerializer
    
    @action(detail=True, methods=['post'])
    def start(self, request, pk=None):
        """
        Démarrer une nouvelle tentative de quiz
        POST /api/quiz/{id}/start/
        """
        quiz = self.get_object()

        if quiz.question_count == 0:
            return Response(
                {
                    'error': 'Ce quiz ne contient aucune question',
                    'message': 'Le quiz doit contenir au moins une question.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Vérifier si l'utilisateur peut passer le quiz
        attempts_count = QuizAttempt.objects.filter(
            user=request.user, 
            quiz=quiz
        ).count()
        
        if attempts_count >= quiz.max_attempts:
            return Response(
                {'error': f'Vous avez déjà utilisé vos {quiz.max_attempts} tentatives'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Vérifier la disponibilité
        now = timezone.now()
        if quiz.available_from and now < quiz.available_from:
            return Response(
                {'error': 'Ce quiz n\'est pas encore disponible'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if quiz.available_until and now > quiz.available_until:
            return Response(
                {'error': 'Ce quiz n\'est plus disponible'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Vérifier s'il y a déjà une tentative en cours
        ongoing = QuizAttempt.objects.filter(
            user=request.user,
            quiz=quiz,
            status='IN_PROGRESS'
        ).first()
        
        if ongoing:
            # Vérifier si la tentative est expirée (optionnel mais recommandé)
            duration_seconds = quiz.duration_minutes * 60
            elapsed = (timezone.now() - ongoing.started_at).total_seconds()
            
            if elapsed > duration_seconds + 300:  # 5 minutes de grâce
                # Auto-abandonner la tentative expirée
                ongoing.status = 'ABANDONED'
                ongoing.completed_at = timezone.now()
                ongoing.save()
            else:
                # Retourner la tentative en cours AVEC le quiz
                attempt_serializer = QuizAttemptSerializer(ongoing)
                quiz_serializer = QuizDetailSerializer(quiz)
                
                return Response({
                    'message': 'Reprise de votre tentative en cours',
                    'attempt': attempt_serializer.data,
                    'quiz': quiz_serializer.data
                })
        
        # Créer une nouvelle tentative
        attempt = QuizAttempt.objects.create(
            user=request.user,
            quiz=quiz,
            attempt_number=attempts_count + 1,
            status='IN_PROGRESS',
            started_at=timezone.now()
        )
        
        attempt_serializer = QuizAttemptSerializer(attempt)
        quiz_serializer = QuizDetailSerializer(quiz)
        
        return Response({
            'attempt': attempt_serializer.data,
            'quiz': quiz_serializer.data
        }, status=status.HTTP_201_CREATED)
    
    @action(detail=True, methods=['post'])
    def submit(self, request, pk=None):
        """
        Soumettre les réponses du quiz
        POST /api/quiz/{id}/submit/
        
        Body:
        {
            "attempt_id": 123,
            "answers": [
                {"question_id": 1, "selected_choices": [1]},
                {"question_id": 2, "selected_choices": [3, 4]}
            ]
        }
        """
        quiz = self.get_object()
        attempt_id = request.data.get('attempt_id')
        answers_data = request.data.get('answers', [])
        
        # Récupérer la tentative
        attempt = get_object_or_404(
            QuizAttempt,
            id=attempt_id,
            user=request.user,
            quiz=quiz,
            status='IN_PROGRESS'
        )
        
        # Calculer le score
        total_score = 0
        
        for answer_data in answers_data:
            question_id = answer_data.get('question_id')
            selected_choice_ids = answer_data.get('selected_choices', [])
            
            question = get_object_or_404(Question, id=question_id, quiz=quiz)
            
            # Récupérer les bonnes réponses
            correct_choices = set(
                question.choices.filter(is_correct=True).values_list('id', flat=True)
            )
            selected_choices_set = set(selected_choice_ids)
            
            # Vérifier si la réponse est correcte
            is_correct = correct_choices == selected_choices_set
            points_earned = question.points if is_correct else 0
            total_score += points_earned
            
            # Enregistrer la réponse
            student_answer = StudentAnswer.objects.create(
                attempt=attempt,
                question=question,
                is_correct=is_correct,
                points_earned=points_earned
            )
            
            # Ajouter les choix sélectionnés
            if selected_choice_ids:
                choices = Choice.objects.filter(id__in=selected_choice_ids)
                student_answer.selected_choices.set(choices)
        
        # Mettre à jour la tentative
        attempt.score = total_score
        attempt.status = 'COMPLETED'
        attempt.completed_at = timezone.now()
        attempt.save()
        
        # Retourner les résultats
        result_serializer = QuizResultSerializer(attempt)
        
        return Response({
            'message': 'Quiz soumis avec succès',
            'results': result_serializer.data
        }, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=['get'])
    def results(self, request, pk=None):
        """
        Obtenir tous les résultats d'un étudiant pour ce quiz
        GET /api/quiz/{id}/results/
        ✅ AVEC VÉRIFICATION FILIÈRE
        """
        quiz = self.get_object()
        user = request.user
        
        # ✅ VÉRIFICATION FILIÈRE ACTUELLE
        try:
            student_profile = user.student_profile
            
            if not (quiz.subject.levels.filter(id=student_profile.level.id).exists() and
                    quiz.subject.majors.filter(id=student_profile.major.id).exists()):
                return Response({
                    'error': 'Ce quiz n\'est pas accessible avec votre filière actuelle',
                    'message': 'Vous avez peut-être changé de filière'
                }, status=status.HTTP_403_FORBIDDEN)
        
        except AttributeError:
            return Response({
                'error': 'Profil étudiant non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        
        # Récupérer les tentatives
        attempts = QuizAttempt.objects.filter(
            user=user,
            quiz=quiz,
            status='COMPLETED'
        ).order_by('-started_at')
        
        serializer = QuizResultSerializer(attempts, many=True)
        
        return Response({
            'quiz_title': quiz.title,
            'subject': {
                'name': quiz.subject.name,
                'code': quiz.subject.code
            },
            'attempts': serializer.data,
            'total_attempts': attempts.count()
        })
    
    @action(detail=True, methods=['get'], url_path='correction/(?P<attempt_id>[^/.]+)')
    def correction(self, request, pk=None, attempt_id=None):
        """
        Voir la correction détaillée d'une tentative
        GET /api/quiz/{id}/correction/{attempt_id}/
        ✅ AVEC VÉRIFICATION FILIÈRE
        """
        quiz = self.get_object()
        user = request.user
        
        if not quiz.show_correction:
            return Response(
                {'error': 'La correction n\'est pas disponible pour ce quiz'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # ✅ VÉRIFICATION FILIÈRE ACTUELLE
        try:
            student_profile = user.student_profile
            
            if not (quiz.subject.levels.filter(id=student_profile.level.id).exists() and
                    quiz.subject.majors.filter(id=student_profile.major.id).exists()):
                return Response({
                    'error': 'Ce quiz n\'est pas accessible avec votre filière actuelle'
                }, status=status.HTTP_403_FORBIDDEN)
        
        except AttributeError:
            return Response({
                'error': 'Profil étudiant non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        
        attempt = get_object_or_404(
            QuizAttempt,
            id=attempt_id,
            user=user,
            quiz=quiz,
            status='COMPLETED'
        )
        
        serializer = QuizCorrectionSerializer(attempt)
        return Response(serializer.data)
    
    @action(detail=True, methods=['get'])
    def statistics(self, request, pk=None):
        """
        Statistiques du quiz (pour les professeurs uniquement)
        GET /api/quiz/{id}/statistics/
        """
        if not request.user.is_staff:
            return Response(
                {'error': 'Accès réservé aux enseignants'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        quiz = self.get_object()
        
        # Calculer les statistiques
        attempts = QuizAttempt.objects.filter(quiz=quiz)
        completed = attempts.filter(status='COMPLETED')
        
        stats = {
            'total_attempts': attempts.count(),
            'completed_attempts': completed.count(),
            'average_score': completed.aggregate(avg=Avg('score'))['avg'] or 0,
            'pass_rate': 0
        }
        
        if completed.count() > 0:
            passed = completed.filter(score__gte=quiz.passing_score).count()
            stats['pass_rate'] = (passed / completed.count()) * 100
        
        # Ajouter les statistiques au quiz
        quiz.total_attempts = stats['total_attempts']
        quiz.completed_attempts = stats['completed_attempts']
        quiz.average_score = stats['average_score']
        quiz.pass_rate = stats['pass_rate']
        
        serializer = QuizStatisticsSerializer(quiz)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def my_quizzes(self, request):
        """
        Récupérer tous les quiz de l'étudiant avec son statut
        GET /api/quiz/my_quizzes/
        
        ✅ ISOLATION : Affiche uniquement les quiz de la filière ACTUELLE
        """
        user = request.user
        
        # Vérifier que c'est un étudiant
        if not user.is_student():
            return Response({
                'error': 'Cette ressource est réservée aux étudiants'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            
            # Vérifier profil complet
            if not student_profile.level or not student_profile.major:
                return Response({
                    'error': 'Profil incomplet',
                    'message': 'Veuillez compléter votre profil (niveau et filière)',
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # ✅ RÉCUPÉRER LES QUIZ DE LA FILIÈRE ACTUELLE UNIQUEMENT
            quizzes = Quiz.objects.filter(
                is_active=True,
                subject__levels=student_profile.level,
                subject__majors=student_profile.major
            ).distinct().select_related('subject')
            
            # Sérialiser avec le contexte (pour afficher les tentatives filtrées)
            serializer = QuizListSerializer(
                quizzes, 
                many=True, 
                context={'request': request}
            )
            
            return Response({
                'success': True,
                'student_info': {
                    'level': student_profile.level.name,
                    'major': student_profile.major.name,
                },
                'quizzes': serializer.data,
                'total_quizzes': quizzes.count(),
                'message': 'Quiz disponibles pour votre filière actuelle'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur my_quizzes pour {user.username}: {str(e)}")
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ✅ FIN DE QuizViewSet - Ne rien ajouter après cette ligne dans la classe


# ========================================
# QUIZ ATTEMPT VIEWSET (classe séparée)
# ========================================

class QuizAttemptViewSet(viewsets.ReadOnlyModelViewSet):
    """
    ViewSet pour gérer les tentatives de quiz
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = QuizAttemptSerializer
    
    def get_queryset(self):
        """Seules les tentatives de l'utilisateur"""
        return QuizAttempt.objects.filter(user=self.request.user)
    
    @action(detail=True, methods=['post'])
    def abandon(self, request, pk=None):
        """
        Abandonner une tentative en cours
        POST /api/attempts/{id}/abandon/
        """
        attempt = self.get_object()
        
        if attempt.status != 'IN_PROGRESS':
            return Response(
                {'error': 'Cette tentative n\'est plus en cours'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        attempt.status = 'ABANDONED'
        attempt.completed_at = timezone.now()
        attempt.save()
        
        return Response({
            'message': 'Tentative abandonnée'
        })



    @action(detail=False, methods=['get'])
    def my_quizzes(self, request):
        """Récupérer tous les quiz de l'étudiant avec son statut"""
        user = request.user
        
        print(f"🔍 DEBUG my_quizzes - User: {user.username}")
        
        if not user.is_student():
            return Response({
                'error': 'Cette ressource est réservée aux étudiants'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            student_profile = user.student_profile
            print(f"🔍 DEBUG - Level: {student_profile.level}, Major: {student_profile.major}")
            
            if not student_profile.level or not student_profile.major:
                return Response({
                    'error': 'Profil incomplet',
                    'message': 'Veuillez compléter votre profil (niveau et filière)',
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Récupérer les quiz
            quizzes = Quiz.objects.filter(
                is_active=True,
                subject__levels=student_profile.level,
                subject__majors=student_profile.major
            ).distinct().select_related('subject')
            
            print(f"🔍 DEBUG - Quizzes found: {quizzes.count()}")
            
            # Sérialiser
            serializer = QuizListSerializer(
                quizzes, 
                many=True, 
                context={'request': request}
            )
            
            print(f"🔍 DEBUG - Serialization OK")
            
            return Response({
                'success': True,
                'student_info': {
                    'level': student_profile.level.name,
                    'major': student_profile.major.name,
                },
                'quizzes': serializer.data,
                'total_quizzes': quizzes.count(),
            })
            
        except Exception as e:
            print(f"❌ ERROR in my_quizzes: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# ========================================
# VIEWSETS POUR LA GESTION DE PROJETS ÉTUDIANTS
# ========================================


class StudentProjectViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour gérer les projets étudiants
    
    Liste: GET /api/courses/projects/
    Détail: GET /api/courses/projects/{id}/
    Créer: POST /api/courses/projects/
    Modifier: PUT/PATCH /api/courses/projects/{id}/
    Supprimer: DELETE /api/courses/projects/{id}/
    
    Actions custom:
    - POST /api/courses/projects/{id}/toggle_favorite/
    - POST /api/courses/projects/{id}/archive/
    - GET /api/courses/projects/statistics/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        """Uniquement les projets de l'utilisateur connecté"""
        return StudentProject.objects.filter(
            user=self.request.user
        ).select_related('subject').prefetch_related('tasks').order_by(
            '-is_favorite', 'order', '-created_at'
        )
    
    def get_serializer_class(self):
        """Serializer différent pour liste vs détail"""
        if self.action == 'list':
            return StudentProjectListSerializer
        return StudentProjectDetailSerializer
    
    def perform_create(self, serializer):
        """Associer automatiquement l'utilisateur connecté"""
        serializer.save(user=self.request.user)
        logger.info(f"✅ Projet créé: {serializer.instance.title} par {self.request.user.username}")
    
    def perform_update(self, serializer):
        """Log lors de la modification"""
        serializer.save()
        logger.info(f"✏️ Projet modifié: {serializer.instance.title}")
    
    def perform_destroy(self, instance):
        """Log lors de la suppression"""
        title = instance.title
        instance.delete()
        logger.info(f"🗑️ Projet supprimé: {title}")
    
    @action(detail=True, methods=['post'])
    def toggle_favorite(self, request, pk=None):
        """
        Toggle le statut favori d'un projet
        POST /api/courses/projects/{id}/toggle_favorite/
        """
        project = self.get_object()
        project.is_favorite = not project.is_favorite
        project.save(update_fields=['is_favorite'])
        
        logger.info(f"⭐ Projet {'ajouté aux' if project.is_favorite else 'retiré des'} favoris: {project.title}")
        
        return Response({
            'success': True,
            'is_favorite': project.is_favorite,
            'message': f"Projet {'ajouté aux' if project.is_favorite else 'retiré des'} favoris"
        })
    
    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """
        Archiver un projet
        POST /api/courses/projects/{id}/archive/
        """
        project = self.get_object()
        project.status = 'ARCHIVED'
        project.save(update_fields=['status'])
        
        logger.info(f"📦 Projet archivé: {project.title}")
        
        return Response({
            'success': True,
            'message': 'Projet archivé avec succès'
        })
    
    @action(detail=True, methods=['post'])
    def unarchive(self, request, pk=None):
        """
        Désarchiver un projet
        POST /api/courses/projects/{id}/unarchive/
        """
        project = self.get_object()
        
        # Remettre en "En cours" si progression > 0, sinon "Non démarré"
        if project.progress_percentage > 0:
            project.status = 'IN_PROGRESS'
        else:
            project.status = 'NOT_STARTED'
        
        project.save(update_fields=['status'])
        
        logger.info(f"📂 Projet désarchivé: {project.title}")
        
        return Response({
            'success': True,
            'message': 'Projet restauré avec succès',
            'new_status': project.status
        })
    
    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """
        Statistiques globales des projets de l'étudiant
        GET /api/courses/projects/statistics/
        """
        projects = self.get_queryset()
        
        # Calculs
        total_projects = projects.count()
        active_projects = projects.filter(status='IN_PROGRESS').count()
        completed_projects = projects.filter(status='COMPLETED').count()
        archived_projects = projects.filter(status='ARCHIVED').count()
        
        overdue_projects = projects.filter(
            due_date__lt=timezone.now().date(),
            status__in=['NOT_STARTED', 'IN_PROGRESS']
        ).count()
        
        # Stats sur les tâches
        total_tasks = ProjectTask.objects.filter(project__user=request.user).count()
        completed_tasks = ProjectTask.objects.filter(
            project__user=request.user,
            status='DONE'
        ).count()
        
        completion_rate = 0
        if total_tasks > 0:
            completion_rate = round((completed_tasks / total_tasks) * 100, 1)
        
        stats_data = {
            'total_projects': total_projects,
            'active_projects': active_projects,
            'completed_projects': completed_projects,
            'archived_projects': archived_projects,
            'overdue_projects': overdue_projects,
            'total_tasks': total_tasks,
            'completed_tasks': completed_tasks,
            'completion_rate': completion_rate,
        }
        
        serializer = ProjectStatisticsSerializer(stats_data)
        
        return Response({
            'success': True,
            'statistics': serializer.data
        })


class ProjectTaskViewSet(viewsets.ModelViewSet):
    """
    ViewSet pour gérer les tâches de projet
    
    Liste: GET /api/courses/tasks/
    Détail: GET /api/courses/tasks/{id}/
    Créer: POST /api/courses/tasks/
    Modifier: PUT/PATCH /api/courses/tasks/{id}/
    Supprimer: DELETE /api/courses/tasks/{id}/
    
    Actions custom:
    - POST /api/courses/tasks/{id}/move_to_column/
    - POST /api/courses/tasks/{id}/toggle_important/
    """
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProjectTaskSerializer
    
    def get_queryset(self):
        """Uniquement les tâches des projets de l'utilisateur"""
        queryset = ProjectTask.objects.filter(
            project__user=self.request.user
        ).select_related('project').order_by('order', '-is_important', 'created_at')
        
        # Filtrer par projet si paramètre fourni
        project_id = self.request.query_params.get('project', None)
        if project_id:
            queryset = queryset.filter(project_id=project_id)
        
        # Filtrer par statut si paramètre fourni
        status = self.request.query_params.get('status', None)
        if status:
            queryset = queryset.filter(status=status)
        
        return queryset
    
    def get_serializer_class(self):
        """Serializer différent pour création/modification"""
        if self.action in ['create', 'update', 'partial_update']:
            return ProjectTaskCreateUpdateSerializer
        return ProjectTaskSerializer
    
    def perform_create(self, serializer):
        """Log lors de la création"""
        task = serializer.save()
        logger.info(f"✅ Tâche créée: {task.title} dans projet {task.project.title}")
    
    def perform_update(self, serializer):
        """Log lors de la modification"""
        task = serializer.save()
        logger.info(f"✏️ Tâche modifiée: {task.title}")
    
    def perform_destroy(self, instance):
        """Log lors de la suppression"""
        title = instance.title
        instance.delete()
        logger.info(f"🗑️ Tâche supprimée: {title}")
    
    @action(detail=True, methods=['post'])
    def move_to_column(self, request, pk=None):
        """
        Déplacer une tâche vers une colonne Kanban (drag & drop)
        POST /api/courses/tasks/{id}/move_to_column/
        
        Body: {
            "status": "TODO" | "IN_PROGRESS" | "DONE",
            "order": 0  (optionnel)
        }
        """
        task = self.get_object()
        
        serializer = ProjectTaskMoveSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(
                serializer.errors,
                status=status.HTTP_400_BAD_REQUEST
            )
        
        new_status = serializer.validated_data['status']
        new_order = serializer.validated_data.get('order', 0)
        
        # Mettre à jour
        task.status = new_status
        task.order = new_order
        task.save()
        
        logger.info(f"🔄 Tâche déplacée: {task.title} → {new_status}")
        
        # Retourner la tâche mise à jour
        response_serializer = ProjectTaskSerializer(task)
        
        return Response({
            'success': True,
            'message': 'Tâche déplacée avec succès',
            'task': response_serializer.data
        })
    
    @action(detail=True, methods=['post'])
    def toggle_important(self, request, pk=None):
        """
        Toggle le statut important d'une tâche
        POST /api/courses/tasks/{id}/toggle_important/
        """
        task = self.get_object()
        task.is_important = not task.is_important
        task.save(update_fields=['is_important'])
        
        logger.info(f"⚠️ Tâche marquée comme {'importante' if task.is_important else 'normale'}: {task.title}")
        
        return Response({
            'success': True,
            'is_important': task.is_important,
            'message': f"Tâche marquée comme {'importante' if task.is_important else 'normale'}"
        })

# ========================================
# VUE DÉTAIL MATIÈRE PAR ID
# ========================================

class SubjectDetailAPIView(APIView):
    """
    Récupérer les détails d'une matière par son ID
    GET /api/courses/subjects/{id}/
    """
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request, subject_id):
        user = request.user
        logger.info(f"📖 Détail matière {subject_id} par: {user.username}")
        
        try:
            # Récupérer la matière
            subject = Subject.objects.get(id=subject_id, is_active=True)
            
            # Vérifier l'accès selon le rôle
            if user.role == 'STUDENT':
                try:
                    student_profile = user.student_profile
                    
                    # Vérifier que l'étudiant a accès à cette matière
                    if not (
                        subject.levels.filter(id=student_profile.level.id).exists() and
                        subject.majors.filter(id=student_profile.major.id).exists()
                    ):
                        return Response({
                            'success': False,
                            'error': 'Vous n\'avez pas accès à cette matière'
                        }, status=status.HTTP_403_FORBIDDEN)
                
                except AttributeError:
                    return Response({
                        'success': False,
                        'error': 'Profil étudiant non trouvé'
                    }, status=status.HTTP_404_NOT_FOUND)
            
            elif user.role == 'TEACHER':
                # Vérifier que le professeur a accès à cette matière
                if not has_subject_access(user, subject):
                    return Response({
                        'success': False,
                        'error': 'Vous n\'avez pas accès à cette matière'
                    }, status=status.HTTP_403_FORBIDDEN)
            
            # Annoter avec le nombre de documents
            subject = Subject.objects.filter(id=subject_id).annotate(
                document_count=Count('documents', filter=Q(documents__is_active=True))
            ).first()
            
            # Sérialiser avec SubjectDetailSerializer
            from .serializers import SubjectDetailSerializer
            serializer = SubjectDetailSerializer(subject, context={'request': request})
            
            return Response({
                'success': True,
                'subject': serializer.data
            })
            
        except Subject.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Matière non trouvée'
            }, status=status.HTTP_404_NOT_FOUND)
        
        except Exception as e:
            logger.error(f"❌ Erreur détail matière {subject_id}: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)