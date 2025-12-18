# courses/views.py

import logging
from django.db.models import Q, Count, Avg, Max, Sum, F
from django.utils import timezone
from django.shortcuts import get_object_or_404
from datetime import datetime, timedelta

from rest_framework import status, permissions, viewsets
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.decorators import api_view, permission_classes, action

from accounts.models import StudentProfile, Level, Major
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
    
    # Serializers Quiz étudiants
    QuizListSerializer, QuizDetailSerializer, QuizAttemptCreateSerializer,
    QuizAttemptSerializer, QuizSubmitSerializer, QuizResultSerializer,
    QuizCorrectionSerializer, QuizStatisticsSerializer,

    # Serializers Projets
    ProjectTaskSerializer,
    ProjectTaskCreateUpdateSerializer,
    ProjectTaskMoveSerializer,
    StudentProjectListSerializer,
    StudentProjectDetailSerializer,
    ProjectStatisticsSerializer,
    
    # Serializers Admin Matières (Phase 2)
    SubjectCreateUpdateSerializer,
    SubjectAdminDetailSerializer,
    SubjectAdminListSerializer,
    SubjectStatisticsSerializer,
    
    # Serializers Quiz Admin/Professeur 
    ChoiceCreateUpdateSerializer,
    QuestionCreateUpdateSerializer,
    QuestionWithAnswerSerializer,  
    QuizCreateUpdateSerializer,
    QuizAdminListSerializer,
    QuizAdminDetailSerializer,

    #  Serializers Professeur 
    TeacherDashboardStatsSerializer,
    TeacherSubjectPerformanceSerializer,
    TeacherRecentActivitySerializer,
    TeacherQuizAttemptListSerializer,
    TeacherStudentProgressSerializer,
    DocumentUpdateSerializer,
    SubjectUpdateByTeacherSerializer
)

# Permissions personnalisées
from accounts.permissions import (
    IsTeacherUser, IsAdminOrTeacher, HasSubjectAccess,
    TeacherSubjectPermission, has_subject_access,
    can_upload_document, get_teacher_subjects,
    can_manage_students, can_delete_document,
    IsAdminPermission  
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
            
            # ========================================
            # ✅ STATISTIQUES GLOBALES CORRIGÉES
            # ========================================
            
            total_subjects = Subject.objects.filter(
                levels=student_profile.level,
                majors=student_profile.major,
                is_active=True
            ).count()

            # ✅ Total de documents disponibles (actifs uniquement)
            total_documents = Document.objects.filter(
                subject__levels=student_profile.level,
                subject__majors=student_profile.major,
                subject__is_active=True,
                is_active=True  # ✅ Documents actifs uniquement
            ).count()

            # ✅ Documents consultés (exclure les documents supprimés)
            viewed_documents = UserProgress.objects.filter(
                user=user,
                document__is_active=True,  # ✅ CORRECTION : Exclure documents supprimés
                status__in=['IN_PROGRESS', 'COMPLETED']
            ).values('document').distinct().count()

            # ✅ SÉCURITÉ : Limiter viewed_documents au maximum de total_documents
            viewed_documents = min(viewed_documents, total_documents)

            # ✅ Calcul de la progression réelle (limitée à 100%)
            if total_documents > 0:
                completion_rate = round((viewed_documents / total_documents) * 100, 1)
                completion_rate = min(completion_rate, 100.0)  # ✅ Limiter à 100%
            else:
                completion_rate = 0.0

            # ========================================
            # ✅ PROGRESSION PAR MATIÈRE CORRIGÉE
            # ========================================
            
            subject_progress = {}
            completed_subjects = 0

            for subject in Subject.objects.filter(
                levels=student_profile.level,
                majors=student_profile.major,
                is_active=True
            ):
                # ✅ Compter uniquement les documents actifs
                subject_docs = Document.objects.filter(
                    subject=subject,
                    is_active=True
                ).count()
                
                if subject_docs > 0:
                    # ✅ CORRECTION CRITIQUE : Exclure les documents supprimés
                    viewed_in_subject = UserProgress.objects.filter(
                        user=user,
                        subject=subject,
                        document__is_active=True,  # ✅ AJOUT : Exclure documents supprimés
                        status__in=['IN_PROGRESS', 'COMPLETED']
                    ).values('document').distinct().count()
                    
                    # ✅ SÉCURITÉ : Limiter à subject_docs (évite 3/2 = 150%)
                    viewed_in_subject = min(viewed_in_subject, subject_docs)
                    
                    # ✅ Calculer le taux de progression pour cette matière
                    subject_rate = round((viewed_in_subject / subject_docs) * 100, 1)
                    
                    # ✅ SÉCURITÉ : Assurer que le taux ne dépasse jamais 100%
                    subject_rate = min(subject_rate, 100.0)
                    
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

            # ========================================
            # FAVORIS
            # ========================================
            
            total_favorites = UserFavorite.objects.filter(user=user).count()

            # ========================================
            # SERIALIZATION ET RÉPONSE
            # ========================================
            
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
                # ✅ Progression détaillée par matière
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
            
            # Construction manuelle avec toutes les stats
            subjects_data = []
            
            for subject in subjects:
                # Documents
                total_documents = Document.objects.filter(subject=subject).count()
                
                # Quiz
                total_quizzes = Quiz.objects.filter(subject=subject).count()
                
                # Étudiants
                from accounts.models import StudentProfile
                student_profiles = StudentProfile.objects.filter(
                    level__in=subject.levels.all(),
                    major__in=subject.majors.all()
                ).distinct()
                total_students = student_profiles.count()
                
                # Vues et téléchargements
                total_views = UserActivity.objects.filter(
                    subject=subject,
                    action='view'
                ).count()
                
                total_downloads = UserActivity.objects.filter(
                    subject=subject,
                    action='download'
                ).count()
                
                # LOG DEBUG
                logger.info(f"📊 {subject.name}: docs={total_documents}, quiz={total_quizzes}, students={total_students}")
                
                # ✅ CORRECTION : Import uniquement ce qui existe
                from accounts.permissions import can_edit_subject_content
                
                # ✅ Permissions simplifiées
                # Un professeur peut toujours uploader des documents sur ses matières
                can_upload = True  # Par défaut, le professeur peut uploader
                
                # Construire l'objet matière
                subject_data = {
                    'subject': {
                        'id': subject.id,
                        'name': subject.name,
                        'code': subject.code,
                        'description': subject.description,
                        'is_active': subject.is_active,
                        'is_featured': subject.is_featured,
                        'levels': [{'id': l.id, 'name': l.name} for l in subject.levels.all()],
                        'majors': [{'id': m.id, 'name': m.name} for m in subject.majors.all()],
                        'created_at': subject.created_at,
                        'updated_at': subject.updated_at
                    },
                    'statistics': {
                        'total_documents': total_documents,
                        'total_quizzes': total_quizzes,
                        'total_students': total_students,
                        'total_views': total_views,
                        'total_downloads': total_downloads
                    },
                    'permissions': {
                        'can_edit_content': can_edit_subject_content(user, subject),
                        'can_upload_documents': can_upload  # ✅ Simplifié
                    }
                }
                
                subjects_data.append(subject_data)
            
            return Response({
                'success': True,
                'teacher_info': {
                    'name': user.get_full_name(),
                    'email': user.email,
                },
                'total_subjects': len(subjects_data),
                'subjects': subjects_data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur matières professeur {user.username}: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
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
    """
    Statistiques détaillées d'une matière pour un professeur
    GET /api/courses/teacher/subjects/{subject_id}/statistics/
    """
    permission_classes = [IsTeacherUser]
    
    def get(self, request, subject_id):
        """Récupérer les statistiques d'une matière"""
        logger.info(f"📊 Statistiques matière {subject_id} par prof: {request.user.username}")
        
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            # Vérifier l'accès
            if not has_subject_access(request.user, subject):
                return Response({
                    'success': False,
                    'error': 'Accès refusé à cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Dates
            now = timezone.now()
            week_ago = now - timedelta(days=7)
            
            # ✅ STATISTIQUES GÉNÉRALES
            total_documents = Document.objects.filter(subject=subject).count()
            total_quizzes = Quiz.objects.filter(subject=subject).count()
            
            # Étudiants
            from accounts.models import StudentProfile
            student_profiles = StudentProfile.objects.filter(
                level__in=subject.levels.all(),
                major__in=subject.majors.all()
            ).distinct()
            total_students = student_profiles.count()
            
            # Vues et téléchargements
            total_views = UserActivity.objects.filter(
                subject=subject,
                action='view'
            ).count()
            
            total_downloads = UserActivity.objects.filter(
                subject=subject,
                action='download'
            ).count()
            
            # ✅ ACTIVITÉ RÉCENTE (7 derniers jours)
            recent_views = UserActivity.objects.filter(
                subject=subject,
                action='view',
                created_at__gte=week_ago
            ).count()
            
            recent_downloads = UserActivity.objects.filter(
                subject=subject,
                action='download',
                created_at__gte=week_ago
            ).count()
            
            recent_quiz_attempts = QuizAttempt.objects.filter(
                quiz__subject=subject,
                started_at__gte=week_ago
            ).count()
            
            # ✅ DOCUMENTS PAR TYPE
            documents_by_type = {}
            for doc_type, _ in Document.DOCUMENT_TYPES:
                count = Document.objects.filter(
                    subject=subject,
                    document_type=doc_type
                ).count()
                if count > 0:
                    documents_by_type[doc_type] = count
            
            # ✅ TOP DOCUMENTS
            top_documents = []
            docs = Document.objects.filter(subject=subject).order_by('-view_count')[:5]
            for doc in docs:
                top_documents.append({
                    'id': doc.id,
                    'title': doc.title,
                    'views': doc.view_count,
                    'downloads': doc.download_count
                })
            
            # ✅ PERFORMANCE DES QUIZ
            quiz_performance = []
            quizzes = Quiz.objects.filter(subject=subject)
            
            for quiz in quizzes:
                attempts = QuizAttempt.objects.filter(quiz=quiz)
                completed = attempts.filter(status='COMPLETED')
                
                if completed.exists():
                    # Score moyen normalisé sur 20
                    scores = []
                    for attempt in completed:
                        if quiz.total_points and quiz.total_points > 0:
                            normalized = (float(attempt.score) / float(quiz.total_points)) * 20
                            scores.append(normalized)
                    
                    avg_score = round(sum(scores) / len(scores), 2) if scores else 0
                    
                    # Taux de réussite
                    passed = 0
                    for attempt in completed:
                        if quiz.total_points and quiz.total_points > 0:
                            percentage = (float(attempt.score) / float(quiz.total_points)) * 100
                            if percentage >= float(quiz.passing_percentage):
                                passed += 1
                    
                    pass_rate = round((passed / completed.count()) * 100, 1) if completed.count() > 0 else 0
                    
                    quiz_performance.append({
                        'quiz_id': quiz.id,
                        'quiz_title': quiz.title,
                        'total_attempts': attempts.count(),
                        'average_score': avg_score,
                        'pass_rate': pass_rate
                    })
            
            # ✅ LOG POUR DEBUG
            logger.info(f"📊 Stats calculées pour {subject.name}:")
            logger.info(f"  - Documents: {total_documents}")
            logger.info(f"  - Quiz: {total_quizzes}")
            logger.info(f"  - Étudiants: {total_students}")
            logger.info(f"  - Vues totales: {total_views}")
            logger.info(f"  - Vues récentes (7j): {recent_views}")
            logger.info(f"  - Téléchargements récents (7j): {recent_downloads}")
            logger.info(f"  - Tentatives quiz récentes (7j): {recent_quiz_attempts}")
            
            statistics = {
                'total_documents': total_documents,
                'total_quizzes': total_quizzes,
                'total_students': total_students,
                'total_views': total_views,
                'total_downloads': total_downloads,
                'recent_views': recent_views,
                'recent_downloads': recent_downloads,
                'recent_quiz_attempts': recent_quiz_attempts,
                'documents_by_type': documents_by_type,
                'top_documents': top_documents,
                'quiz_performance': quiz_performance
            }
            
            return Response({
                'success': True,
                'statistics': statistics
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur statistiques matière: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
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
            passed = completed.filter(score__gte=quiz.passing_percentage).count()
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
        GET /api/quizzes/my_quizzes/
        """
        user = request.user
        
        if not hasattr(user, 'is_student') or not user.is_student():
            return Response({
                'error': 'Cette ressource est réservée aux étudiants'
            }, status=status.HTTP_403_FORBIDDEN)
        
        try:
            if not hasattr(user, 'student_profile'):
                return Response({
                    'error': 'Profil étudiant non trouvé'
                }, status=status.HTTP_404_NOT_FOUND)
            
            student_profile = user.student_profile
            
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
            
            # Récupérer les tentatives en une requête
            from django.db.models import Max, Count as CountAgg
            
            user_attempts = QuizAttempt.objects.filter(
                user=user,
                quiz__in=quizzes
            ).values('quiz_id').annotate(
                attempts_count=CountAgg('id'),
                best_score=Max('score'),
                last_attempt_date=Max('started_at')
            )
            
            attempts_dict = {a['quiz_id']: a for a in user_attempts}
            
            # Construire la réponse
            quizzes_data = []
            
            for quiz in quizzes:
                user_data = attempts_dict.get(quiz.id, {})
                attempts_count = user_data.get('attempts_count', 0)
                best_score = user_data.get('best_score', None)
                last_attempt = user_data.get('last_attempt_date', None)
                
                # Calculer les points totaux
                total_points = quiz.total_points or 0
                question_count = quiz.question_count or 0
                
                # Score normalisé
                best_score_normalized = None
                best_score_percentage = 0
                
                if best_score is not None and total_points > 0:
                    best_score_normalized = round((float(best_score) / float(total_points)) * 20, 2)
                    best_score_percentage = round((float(best_score) / float(total_points)) * 100, 1)
                
                remaining_attempts = max(0, quiz.max_attempts - attempts_count)
                
                # Disponibilité
                now = timezone.now()
                is_available = quiz.is_active
                if quiz.available_from and now < quiz.available_from:
                    is_available = False
                if quiz.available_until and now > quiz.available_until:
                    is_available = False
                
                can_attempt = is_available and (attempts_count < quiz.max_attempts)
                
                quizzes_data.append({
                    'id': quiz.id,
                    'title': quiz.title,
                    'description': quiz.description,
                    'subject_name': quiz.subject.name,
                    'subject_code': quiz.subject.code,
                    'duration_minutes': quiz.duration_minutes,
                    'passing_percentage': float(quiz.passing_percentage),
                    'max_attempts': quiz.max_attempts,
                    'question_count': question_count,
                    'total_points': float(total_points),
                    'is_active': quiz.is_active,
                    'available_from': quiz.available_from,
                    'available_until': quiz.available_until,
                    'user_best_score': best_score_normalized,
                    'user_attempts_count': attempts_count,
                    'user_last_attempt': last_attempt,
                    'best_score_percentage': best_score_percentage,
                    'remaining_attempts': remaining_attempts,
                    'is_available': is_available,
                    'can_attempt': can_attempt
                })
            
            return Response({
                'success': True,
                'student_info': {
                    'level': student_profile.level.name,
                    'major': student_profile.major.name,
                },
                'quizzes': quizzes_data,
                'total_quizzes': len(quizzes_data),
                'message': 'Quiz disponibles pour votre filière actuelle'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur my_quizzes pour {user.username}: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())
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


# ========================================
# GESTION DES MATIÈRES (ADMIN)
# ========================================

class AdminSubjectListCreateView(APIView):
    """
    Liste et création des matières (Admin uniquement)
    GET /api/courses/admin/subjects/
    POST /api/courses/admin/subjects/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request):
        """Liste de toutes les matières avec filtres"""
        logger.info(f"📚 Liste matières par admin: {request.user.username}")
        
        try:
            # Base queryset
            queryset = Subject.objects.all().prefetch_related('levels', 'majors')
            
            # Filtres
            is_active = request.GET.get('is_active', None)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
            is_featured = request.GET.get('is_featured', None)
            if is_featured is not None:
                queryset = queryset.filter(is_featured=is_featured.lower() == 'true')
            
            search = request.GET.get('search', None)
            if search:
                queryset = queryset.filter(
                    Q(name__icontains=search) | Q(code__icontains=search)
                )
            
            level_id = request.GET.get('level', None)
            if level_id:
                queryset = queryset.filter(levels__id=level_id)
            
            major_id = request.GET.get('major', None)
            if major_id:
                queryset = queryset.filter(majors__id=major_id)
            
            # ✅ PAS D'ANNOTATION - utiliser les propriétés du modèle
            queryset = queryset.order_by('order', 'name')
            
            # Sérialiser
            serializer = SubjectAdminListSerializer(queryset, many=True)
            
            return Response({
                'success': True,
                'total_subjects': queryset.count(),
                'subjects': serializer.data,
                'filters_applied': {
                    'is_active': is_active,
                    'is_featured': is_featured,
                    'search': search,
                    'level': level_id,
                    'major': major_id
                }
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur liste matières: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """Créer une nouvelle matière"""
        logger.info(f"➕ Création matière par admin: {request.user.username}")
        
        serializer = SubjectCreateUpdateSerializer(data=request.data)
        
        if serializer.is_valid():
            try:
                subject = serializer.save()
                
                # Retourner la matière créée avec détails
                response_serializer = SubjectAdminDetailSerializer(subject)
                
                logger.info(f"✅ Matière créée: {subject.code} - {subject.name}")
                
                return Response({
                    'success': True,
                    'message': f'Matière "{subject.name}" créée avec succès',
                    'subject': response_serializer.data
                }, status=status.HTTP_201_CREATED)
                
            except Exception as e:
                logger.error(f"❌ Erreur création matière: {str(e)}")
                return Response({
                    'success': False,
                    'error': 'Erreur lors de la création',
                    'details': str(e)
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class AdminSubjectDetailView(APIView):
    """
    Détail, modification et suppression d'une matière (Admin uniquement)
    GET /api/courses/admin/subjects/{id}/
    PUT/PATCH /api/courses/admin/subjects/{id}/
    DELETE /api/courses/admin/subjects/{id}/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, subject_id):
        """Détail d'une matière"""
        logger.info(f"📖 Détail matière {subject_id} par admin: {request.user.username}")
        
        try:
            # ✅ PAS D'ANNOTATION
            subject = Subject.objects.prefetch_related('levels', 'majors').get(id=subject_id)
            
            serializer = SubjectAdminDetailSerializer(subject)
            
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
            logger.error(f"❌ Erreur détail matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    # Garde les méthodes put, patch, delete comme elles sont
    def put(self, request, subject_id):
        return self.update_subject(request, subject_id, partial=False)
    
    def patch(self, request, subject_id):
        return self.update_subject(request, subject_id, partial=True)
    
    def update_subject(self, request, subject_id, partial=False):
        """Logique de mise à jour"""
        logger.info(f"✏️ Modification matière {subject_id} par admin: {request.user.username}")
        
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            serializer = SubjectCreateUpdateSerializer(
                subject,
                data=request.data,
                partial=partial
            )
            
            if serializer.is_valid():
                serializer.save()
                
                # Retourner la matière mise à jour
                response_serializer = SubjectAdminDetailSerializer(subject)
                
                logger.info(f"✅ Matière modifiée: {subject.code} - {subject.name}")
                
                return Response({
                    'success': True,
                    'message': 'Matière mise à jour avec succès',
                    'subject': response_serializer.data
                })
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"❌ Erreur modification matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, subject_id):
        """Supprimer une matière"""
        logger.info(f"🗑️ Suppression matière {subject_id} par admin: {request.user.username}")
        
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            # Vérifier s'il y a des documents
            document_count = Document.objects.filter(subject=subject).count()
            if document_count > 0:
                return Response({
                    'success': False,
                    'error': f'Impossible de supprimer cette matière. Elle contient {document_count} document(s).',
                    'suggestion': 'Supprimez d\'abord tous les documents ou désactivez la matière'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Vérifier s'il y a des quiz
            quiz_count = Quiz.objects.filter(subject=subject).count()
            if quiz_count > 0:
                return Response({
                    'success': False,
                    'error': f'Impossible de supprimer cette matière. Elle contient {quiz_count} quiz.',
                    'suggestion': 'Supprimez d\'abord tous les quiz ou désactivez la matière'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Vérifier s'il y a des assignations
            from accounts.models import TeacherAssignment
            assignment_count = TeacherAssignment.objects.filter(subject=subject).count()
            if assignment_count > 0:
                return Response({
                    'success': False,
                    'error': f'Impossible de supprimer cette matière. Elle a {assignment_count} assignation(s) professeur.',
                    'suggestion': 'Supprimez d\'abord les assignations ou désactivez la matière'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            subject_name = subject.name
            subject_code = subject.code
            subject.delete()
            
            logger.info(f"✅ Matière supprimée: {subject_code} - {subject_name}")
            
            return Response({
                'success': True,
                'message': f'Matière "{subject_name}" supprimée avec succès'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminSubjectStatisticsView(APIView):
    """
    Statistiques détaillées d'une matière (Admin uniquement)
    GET /api/courses/admin/subjects/{id}/statistics/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, subject_id):
        """Statistiques complètes d'une matière"""
        logger.info(f"📊 Stats matière {subject_id} par admin: {request.user.username}")
        
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            # Documents
            documents = Document.objects.filter(subject=subject)
            total_documents = documents.count()
            
            documents_by_type = {}
            for doc_type, doc_label in Document.DOCUMENT_TYPES:
                count = documents.filter(document_type=doc_type).count()
                documents_by_type[doc_label] = count
            
            # Top 5 documents les plus consultés
            most_viewed = documents.filter(is_active=True).order_by('-view_count')[:5]
            most_viewed_documents = [{
                'id': doc.id,
                'title': doc.title,
                'type': doc.get_document_type_display(),
                'views': doc.view_count,
                'downloads': doc.download_count
            } for doc in most_viewed]
            
            # Quiz
            quizzes = Quiz.objects.filter(subject=subject)
            total_quizzes = quizzes.count()
            active_quizzes = quizzes.filter(is_active=True).count()
            
            # Score moyen des quiz
            completed_attempts = QuizAttempt.objects.filter(
                quiz__subject=subject,
                status='COMPLETED'
            )
            avg_score = completed_attempts.aggregate(avg=Avg('score'))['avg'] or 0
            
            # Étudiants
            from accounts.models import StudentProfile
            total_students = StudentProfile.objects.filter(
                level__in=subject.levels.all(),
                major__in=subject.majors.all()
            ).distinct().count()
            
            # Étudiants actifs (ayant consulté au moins 1 doc)
            active_students = UserActivity.objects.filter(
                subject=subject,
                action__in=['view', 'download']
            ).values('user').distinct().count()
            
            # Professeurs
            from accounts.models import TeacherAssignment
            total_teachers = TeacherAssignment.objects.filter(
                subject=subject,
                is_active=True
            ).count()
            
            # Activité
            total_views = UserActivity.objects.filter(
                subject=subject,
                action='view'
            ).count()
            
            total_downloads = UserActivity.objects.filter(
                subject=subject,
                action='download'
            ).count()
            
            # Activité des 30 derniers jours
            from datetime import timedelta
            thirty_days_ago = timezone.now() - timedelta(days=30)
            views_last_30_days = UserActivity.objects.filter(
                subject=subject,
                action='view',
                created_at__gte=thirty_days_ago
            ).count()
            
            # Construire les stats
            stats_data = {
                'subject_id': subject.id,
                'subject_name': subject.name,
                'subject_code': subject.code,
                'total_documents': total_documents,
                'documents_by_type': documents_by_type,
                'most_viewed_documents': most_viewed_documents,
                'total_quizzes': total_quizzes,
                'active_quizzes': active_quizzes,
                'average_quiz_score': round(float(avg_score), 2),
                'total_students': total_students,
                'active_students': active_students,
                'total_teachers': total_teachers,
                'total_views': total_views,
                'total_downloads': total_downloads,
                'views_last_30_days': views_last_30_days
            }
            
            serializer = SubjectStatisticsSerializer(stats_data)
            
            return Response({
                'success': True,
                'statistics': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur stats matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminSubjectToggleActiveView(APIView):
    """
    Activer/désactiver rapidement une matière
    POST /api/courses/admin/subjects/{id}/toggle-active/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request, subject_id):
        """Toggle is_active"""
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            subject.is_active = not subject.is_active
            subject.save(update_fields=['is_active'])
            
            status_text = 'activée' if subject.is_active else 'désactivée'
            logger.info(f"🔄 Matière {status_text}: {subject.code}")
            
            return Response({
                'success': True,
                'message': f'Matière "{subject.name}" {status_text}',
                'is_active': subject.is_active
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur toggle matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminSubjectToggleFeaturedView(APIView):
    """
    Mettre en avant/retirer une matière
    POST /api/courses/admin/subjects/{id}/toggle-featured/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request, subject_id):
        """Toggle is_featured"""
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            subject.is_featured = not subject.is_featured
            subject.save(update_fields=['is_featured'])
            
            status_text = 'mise en avant' if subject.is_featured else 'retirée de la mise en avant'
            logger.info(f"⭐ Matière {status_text}: {subject.code}")
            
            return Response({
                'success': True,
                'message': f'Matière "{subject.name}" {status_text}',
                'is_featured': subject.is_featured
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur toggle featured: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# ========================================
# GESTION DES QUIZ (ADMIN)
# ========================================

class AdminQuizListCreateView(APIView):
    """
    Liste et création des quiz (Admin uniquement)
    GET /api/courses/admin/quizzes/
    POST /api/courses/admin/quizzes/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request):
        """Liste de tous les quiz avec filtres"""
        logger.info(f"📝 Liste quiz par admin: {request.user.username}")
        
        try:
            from django.db.models import Count, Q
            
            # Récupérer tous les quiz avec optimisation
            queryset = Quiz.objects.select_related(
                'subject', 'created_by'
            ).prefetch_related('questions', 'attempts')
            
            # Filtres
            is_active = request.GET.get('is_active', None)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
            subject_id = request.GET.get('subject', None)
            if subject_id:
                queryset = queryset.filter(subject_id=subject_id)
            
            search = request.GET.get('search', None)
            if search:
                queryset = queryset.filter(title__icontains=search)
            
            queryset = queryset.order_by('-created_at')
            
            # ✅ Construction manuelle des données avec calcul du taux de réussite
            quiz_list = []
            for quiz in queryset:
                # ✅ Calculer le taux de réussite
                pass_rate = None
                completed_attempts = quiz.attempts.filter(status='COMPLETED')
                total_completed = completed_attempts.count()
                
                if total_completed > 0:
                    # Calculer le score de passage en points (pas en pourcentage)
                    total_points = quiz.total_points
                    if total_points > 0:
                        # Score minimum pour réussir
                        passing_score = (float(total_points) * float(quiz.passing_percentage)) / 100.0
                        
                        # Compter les tentatives qui ont réussi
                        passed_attempts = completed_attempts.filter(
                            score__gte=passing_score
                        ).count()
                        
                        # Calculer le pourcentage de réussite
                        pass_rate = round((passed_attempts / total_completed) * 100, 1)
                        
                        logger.debug(f"📊 Quiz {quiz.id} '{quiz.title}': {passed_attempts}/{total_completed} réussis (score min: {passing_score}/{total_points}) = {pass_rate}%")
                
                quiz_data = {
                    'id': quiz.id,
                    'title': quiz.title,
                    'subject': quiz.subject.id,
                    'subject_name': quiz.subject.name,
                    'subject_code': quiz.subject.code,
                    'duration_minutes': quiz.duration_minutes,
                    'passing_percentage': float(quiz.passing_percentage),
                    'max_attempts': quiz.max_attempts,
                    'is_active': quiz.is_active,
                    'question_count': quiz.questions.count(),
                    'total_attempts': quiz.attempts.count(),
                    'pass_rate': pass_rate,  # ✅ AJOUTÉ
                    'created_by_name': quiz.created_by.get_full_name() if quiz.created_by else 'Inconnu',
                    'created_at': quiz.created_at.isoformat() if quiz.created_at else None,
                    'available_from': quiz.available_from.isoformat() if quiz.available_from else None,
                    'available_until': quiz.available_until.isoformat() if quiz.available_until else None,
                }
                quiz_list.append(quiz_data)
            
            return Response({
                'success': True,
                'total_quizzes': len(quiz_list),
                'quizzes': quiz_list,
                'filters_applied': {
                    'is_active': is_active,
                    'subject': subject_id,
                    'search': search
                }
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur liste quiz: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """Créer un nouveau quiz"""
        logger.info(f"➕ Création quiz par admin: {request.user.username}")
        
        serializer = QuizCreateUpdateSerializer(
            data=request.data,
            context={'request': request}
        )
        
        if serializer.is_valid():
            try:
                quiz = serializer.save()
                
                # Retourner le quiz créé avec détails
                response_serializer = QuizAdminDetailSerializer(quiz)
                
                logger.info(f"✅ Quiz créé: {quiz.title}")
                
                return Response({
                    'success': True,
                    'message': f'Quiz "{quiz.title}" créé avec succès',
                    'quiz': response_serializer.data
                }, status=status.HTTP_201_CREATED)
                
            except Exception as e:
                logger.error(f"❌ Erreur création quiz: {str(e)}")
                return Response({
                    'success': False,
                    'error': 'Erreur lors de la création',
                    'details': str(e)
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        return Response({
            'success': False,
            'errors': serializer.errors
        }, status=status.HTTP_400_BAD_REQUEST)


class AdminQuizDetailView(APIView):
    """
    Détail, modification et suppression d'un quiz (Admin uniquement)
    GET /api/courses/admin/quizzes/{id}/
    PUT/PATCH /api/courses/admin/quizzes/{id}/
    DELETE /api/courses/admin/quizzes/{id}/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, quiz_id):
        try:
            quiz = Quiz.objects.select_related('subject', 'created_by').prefetch_related('questions', 'questions__choices').get(id=quiz_id)
            
            serializer = QuizAdminDetailSerializer(quiz)
            
            return Response({
                'success': True,
                'quiz': serializer.data
            })
            
        except Quiz.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Quiz non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur détail quiz: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def put(self, request, quiz_id):
        """Mise à jour complète"""
        return self.update_quiz(request, quiz_id, partial=False)
    
    def patch(self, request, quiz_id):
        """Mise à jour partielle"""
        return self.update_quiz(request, quiz_id, partial=True)
    
    def update_quiz(self, request, quiz_id, partial=False):
        """Logique de mise à jour"""
        logger.info(f"✏️ Modification quiz {quiz_id} par admin: {request.user.username}")
        
        try:
            quiz = get_object_or_404(Quiz, id=quiz_id)
            
            serializer = QuizCreateUpdateSerializer(
                quiz,
                data=request.data,
                partial=partial,
                context={'request': request}
            )
            
            if serializer.is_valid():
                serializer.save()
                
                # Retourner le quiz mis à jour
                response_serializer = QuizAdminDetailSerializer(quiz)
                
                logger.info(f"✅ Quiz modifié: {quiz.title}")
                
                return Response({
                    'success': True,
                    'message': 'Quiz mis à jour avec succès',
                    'quiz': response_serializer.data
                })
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"❌ Erreur modification quiz: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, quiz_id):
        """Supprimer un quiz"""
        logger.info(f"🗑️ Suppression quiz {quiz_id} par admin: {request.user.username}")
        
        try:
            quiz = get_object_or_404(Quiz, id=quiz_id)
            
            # Vérifier s'il y a des tentatives
            attempt_count = QuizAttempt.objects.filter(quiz=quiz).count()
            if attempt_count > 0:
                return Response({
                    'success': False,
                    'error': f'Impossible de supprimer ce quiz. Il a {attempt_count} tentative(s).',
                    'suggestion': 'Désactivez le quiz au lieu de le supprimer pour conserver l\'historique'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            quiz_title = quiz.title
            quiz.delete()
            
            logger.info(f"✅ Quiz supprimé: {quiz_title}")
            
            return Response({
                'success': True,
                'message': f'Quiz "{quiz_title}" supprimé avec succès'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression quiz: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminQuizToggleActiveView(APIView):
    """
    Activer/désactiver un quiz
    POST /api/courses/admin/quizzes/{id}/toggle-active/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request, quiz_id):
        """Toggle is_active"""
        try:
            quiz = get_object_or_404(Quiz, id=quiz_id)
            
            quiz.is_active = not quiz.is_active
            quiz.save(update_fields=['is_active'])
            
            status_text = 'activé' if quiz.is_active else 'désactivé'
            logger.info(f"🔄 Quiz {status_text}: {quiz.title}")
            
            return Response({
                'success': True,
                'message': f'Quiz "{quiz.title}" {status_text}',
                'is_active': quiz.is_active
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur toggle quiz: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# GESTION DES QUIZ (PROFESSEUR)
# ========================================

class TeacherQuizListCreateView(APIView):
    """
    Liste et création des quiz pour un professeur
    GET /api/courses/teacher/quizzes/
    POST /api/courses/teacher/quizzes/
    """
    permission_classes = [IsTeacherUser]
    
    def get(self, request):
        """Liste des quiz du professeur"""
        logger.info(f"📝 Liste quiz professeur: {request.user.username}")
        
        try:
            # Récupérer les matières du professeur
            teacher_subjects = get_teacher_subjects(request.user)
            
            # Récupérer les quiz de ces matières
            queryset = Quiz.objects.filter(
                subject__in=teacher_subjects
            ).select_related('subject', 'created_by').prefetch_related('questions').order_by('-created_at')
            # ✅ Ajout de prefetch_related('questions') pour optimiser
            
            # Filtres
            is_active = request.GET.get('is_active', None)
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
            subject_id = request.GET.get('subject', None)
            if subject_id:
                queryset = queryset.filter(subject_id=subject_id)
            
            search = request.GET.get('search', None)
            if search:
                queryset = queryset.filter(title__icontains=search)
            
            serializer = QuizAdminListSerializer(queryset, many=True)
            
            return Response({
                'success': True,
                'total_quizzes': queryset.count(),
                'quizzes': serializer.data,
                'my_subjects': [{
                    'id': s.id,
                    'name': s.name,
                    'code': s.code
                } for s in teacher_subjects]
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur liste quiz professeur: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def post(self, request):
        """Créer un quiz pour une de ses matières"""
        logger.info(f"➕ Création quiz par professeur: {request.user.username}")
        
        # Vérifier que la matière appartient au professeur
        subject_id = request.data.get('subject')
        if not subject_id:
            return Response({
                'success': False,
                'error': 'La matière est requise'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            subject = Subject.objects.get(id=subject_id)
            
            # Vérifier l'accès
            from accounts.permissions import can_create_quiz
            if not can_create_quiz(request.user, subject):
                return Response({
                    'success': False,
                    'error': 'Vous n\'avez pas la permission de créer un quiz pour cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Créer le quiz
            serializer = QuizCreateUpdateSerializer(
                data=request.data,
                context={'request': request}
            )
            
            if serializer.is_valid():
                quiz = serializer.save()
                
                response_serializer = QuizAdminDetailSerializer(quiz)
                
                logger.info(f"✅ Quiz créé par professeur: {quiz.title}")
                
                return Response({
                    'success': True,
                    'message': f'Quiz "{quiz.title}" créé avec succès',
                    'quiz': response_serializer.data
                }, status=status.HTTP_201_CREATED)
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Subject.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Matière non trouvée'
            }, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"❌ Erreur création quiz professeur: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class TeacherQuizDetailView(APIView):
    """
    Détail, modification et suppression d'un quiz par un professeur
    GET /api/courses/teacher/quizzes/{id}/
    PUT/PATCH /api/courses/teacher/quizzes/{id}/
    DELETE /api/courses/teacher/quizzes/{id}/
    """
    permission_classes = [IsTeacherUser]
    
    def get(self, request, quiz_id):
        """Détail d'un quiz"""
        try:
            quiz = Quiz.objects.select_related('subject', 'created_by').prefetch_related('questions', 'questions__choices').get(id=quiz_id)
            
            # Vérifier l'accès
            if not has_subject_access(request.user, quiz.subject):
                return Response({
                    'success': False,
                    'error': 'Accès refusé'
                }, status=status.HTTP_403_FORBIDDEN)
            
            serializer = QuizAdminDetailSerializer(quiz)
            
            return Response({
                'success': True,
                'quiz': serializer.data
            })
            
        except Quiz.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Quiz non trouvé'
            }, status=status.HTTP_404_NOT_FOUND)
    
    def put(self, request, quiz_id):
        """Mise à jour complète"""
        return self.update_quiz(request, quiz_id, partial=False)
    
    def patch(self, request, quiz_id):
        """Mise à jour partielle"""
        return self.update_quiz(request, quiz_id, partial=True)
    
    def update_quiz(self, request, quiz_id, partial=False):
        """Mise à jour par professeur"""
        try:
            quiz = get_object_or_404(Quiz, id=quiz_id)
            
            # Vérifier la permission
            from accounts.permissions import can_edit_quiz
            if not can_edit_quiz(request.user, quiz):
                return Response({
                    'success': False,
                    'error': 'Vous n\'avez pas la permission de modifier ce quiz'
                }, status=status.HTTP_403_FORBIDDEN)
            
            serializer = QuizCreateUpdateSerializer(
                quiz,
                data=request.data,
                partial=partial,
                context={'request': request}
            )
            
            if serializer.is_valid():
                serializer.save()
                
                response_serializer = QuizAdminDetailSerializer(quiz)
                
                logger.info(f"✅ Quiz modifié par professeur: {quiz.title}")
                
                return Response({
                    'success': True,
                    'message': 'Quiz mis à jour avec succès',
                    'quiz': response_serializer.data
                })
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"❌ Erreur modification quiz: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, quiz_id):
        """Suppression par professeur"""
        try:
            quiz = get_object_or_404(Quiz, id=quiz_id)
            
            # Vérifier la permission
            from accounts.permissions import can_delete_quiz
            if not can_delete_quiz(request.user, quiz):
                return Response({
                    'success': False,
                    'error': 'Vous n\'avez pas la permission de supprimer ce quiz'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Vérifier les tentatives
            attempt_count = QuizAttempt.objects.filter(quiz=quiz).count()
            if attempt_count > 0:
                return Response({
                    'success': False,
                    'error': f'Impossible de supprimer ce quiz. Il a {attempt_count} tentative(s).',
                    'suggestion': 'Désactivez le quiz au lieu de le supprimer'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            quiz_title = quiz.title
            quiz.delete()
            
            logger.info(f"✅ Quiz supprimé par professeur: {quiz_title}")
            
            return Response({
                'success': True,
                'message': f'Quiz "{quiz_title}" supprimé avec succès'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression quiz: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# DASHBOARD PROFESSEUR
# ========================================

class TeacherDashboardView(APIView):
    """
    Dashboard personnalisé pour le professeur
    GET /api/courses/teacher/dashboard/
    """
    permission_classes = [IsTeacherUser]
    
    def get(self, request):
        """Récupérer les statistiques du professeur"""
        logger.info(f"📊 Dashboard professeur: {request.user.username}")
        
        try:
            # Dates
            now = timezone.now()
            week_ago = now - timedelta(days=7)
            month_ago = now - timedelta(days=30)
            
            # Récupérer les matières du professeur
            teacher_subjects = get_teacher_subjects(request.user)
            subject_ids = [s.id for s in teacher_subjects]
            
            # =====================================
            # 1. STATISTIQUES GÉNÉRALES
            # =====================================
            
            total_subjects = teacher_subjects.count()
            active_subjects = teacher_subjects.filter(is_active=True).count()
            
            # Documents
            total_documents = Document.objects.filter(
                subject__in=teacher_subjects
            ).count()
            
            my_documents = Document.objects.filter(
                subject__in=teacher_subjects,
                created_by=request.user
            ).count()
            
            documents_this_month = Document.objects.filter(
                subject__in=teacher_subjects,
                created_at__gte=month_ago
            ).count()
            
            # Quiz
            total_quizzes = Quiz.objects.filter(
                subject__in=teacher_subjects
            ).count()
            
            active_quizzes = Quiz.objects.filter(
                subject__in=teacher_subjects,
                is_active=True
            ).count()
            
            quizzes_this_month = Quiz.objects.filter(
                subject__in=teacher_subjects,
                created_at__gte=month_ago
            ).count()
            
            # Étudiants
            from accounts.models import StudentProfile
            student_profiles = StudentProfile.objects.filter(
                level__in=Level.objects.filter(subject__in=teacher_subjects).distinct(),
                major__in=Major.objects.filter(subject__in=teacher_subjects).distinct()
            ).distinct()

            total_students = student_profiles.count()
            
            # Étudiants actifs (avec au moins 1 activité cette semaine)
            active_students = UserActivity.objects.filter(
                subject__in=teacher_subjects,
                created_at__gte=week_ago
            ).values('user').distinct().count()
            
            # Activité de la semaine
            views_this_week = UserActivity.objects.filter(
                subject__in=teacher_subjects,
                action='view',
                created_at__gte=week_ago
            ).count()
            
            downloads_this_week = UserActivity.objects.filter(
                subject__in=teacher_subjects,
                action='download',
                created_at__gte=week_ago
            ).count()
            
            quiz_attempts_this_week = QuizAttempt.objects.filter(
                quiz__subject__in=teacher_subjects,
                started_at__gte=week_ago
            ).count()

            # =====================================
            # ACTIVITÉ HEBDOMADAIRE (jour par jour)
            # =====================================

            weekly_activity = []

            for i in range(6, -1, -1):  # 7 derniers jours (du plus ancien au plus récent)
                day_start = now - timedelta(days=i)
                day_start = day_start.replace(hour=0, minute=0, second=0, microsecond=0)
                day_end = day_start + timedelta(days=1)
                
                # ✅ Vues du jour (étudiants uniquement)
                day_views = UserActivity.objects.filter(
                    subject__in=teacher_subjects,
                    action='view',
                    user__role='STUDENT',  # ✅ CORRECT : user__role
                    created_at__gte=day_start,
                    created_at__lt=day_end
                ).count()
                
                # ✅ Téléchargements du jour (étudiants uniquement)
                day_downloads = UserActivity.objects.filter(
                    subject__in=teacher_subjects,
                    action='download',
                    user__role='STUDENT',  # ✅ CORRECT : user__role
                    created_at__gte=day_start,
                    created_at__lt=day_end
                ).count()
                
                # Tentatives de quiz du jour
                day_quiz_attempts = QuizAttempt.objects.filter(
                    quiz__subject__in=teacher_subjects,
                    started_at__gte=day_start,
                    started_at__lt=day_end
                ).count()
                
                weekly_activity.append({
                    'date': day_start.isoformat(),
                    'views': day_views,
                    'downloads': day_downloads,
                    'quiz_attempts': day_quiz_attempts
                })

            logger.info(f"📊 Activité hebdomadaire: {weekly_activity}")

            stats_data = {
                'total_subjects': total_subjects,
                'active_subjects': active_subjects,
                'total_documents': total_documents,
                'my_documents': my_documents,
                'documents_this_month': documents_this_month,
                'total_quizzes': total_quizzes,
                'active_quizzes': active_quizzes,
                'quizzes_this_month': quizzes_this_month,
                'total_students': total_students,
                'active_students': active_students,
                'views_this_week': views_this_week,
                'downloads_this_week': downloads_this_week,
                'quiz_attempts_this_week': quiz_attempts_this_week,
                'weekly_activity': weekly_activity,  # ✅ AJOUTÉ
            }
            
            
            # =====================================
            # 2. PERFORMANCE PAR MATIÈRE
            # =====================================

            subject_performance = []

            for subject in teacher_subjects:
                # Documents et quiz
                doc_count = Document.objects.filter(subject=subject).count()
                quiz_count = Quiz.objects.filter(subject=subject).count()
                
                # Étudiants
                students = StudentProfile.objects.filter(
                    level__in=subject.levels.all(),
                    major__in=subject.majors.all()
                ).distinct()
                
                student_count = students.count()
                
                # Étudiants actifs sur cette matière
                active_on_subject = UserActivity.objects.filter(
                    subject=subject,
                    created_at__gte=week_ago
                ).values('user').distinct().count()
                
                # Activité
                total_views = UserActivity.objects.filter(
                    subject=subject,
                    action='view'
                ).count()
                
                total_downloads = UserActivity.objects.filter(
                    subject=subject,
                    action='download'
                ).count()
                
                quiz_attempts = QuizAttempt.objects.filter(
                    quiz__subject=subject
                ).count()
                
                # ✅ PERFORMANCE QUIZ CORRIGÉE
                completed = QuizAttempt.objects.filter(
                    quiz__subject=subject,
                    status='COMPLETED'
                ).select_related('quiz')
                
                avg_score = 0
                pass_rate = 0
                
                if completed.exists():
                    # Score moyen normalisé sur 20
                    scores = []
                    passed = 0
                    total = 0
                    
                    for attempt in completed:
                        quiz = attempt.quiz
                        
                        # Vérifier que le quiz a un total_points valide
                        if quiz.total_points and quiz.total_points > 0:
                            # ✅ Score normalisé sur 20
                            normalized_score = (float(attempt.score) / float(quiz.total_points)) * 20
                            scores.append(normalized_score)
                            
                            # ✅ Calculer le pourcentage pour vérifier la réussite
                            percentage = (float(attempt.score) / float(quiz.total_points)) * 100
                            
                            # ✅ Comparer le POURCENTAGE au passing_percentage
                            if percentage >= float(quiz.passing_percentage):
                                passed += 1
                            
                            total += 1
                    
                    # Score moyen
                    if scores:
                        avg_score = round(sum(scores) / len(scores), 2)
                    
                    # Taux de réussite
                    if total > 0:
                        pass_rate = round((passed / total) * 100, 1)
                    
                    # ✅ LOG POUR DEBUG
                    logger.info(f"📊 {subject.name}: {passed}/{total} réussis ({pass_rate}%) - Score moyen: {avg_score}/20")
                
                subject_performance.append({
                    'subject_id': subject.id,
                    'subject_name': subject.name,
                    'subject_code': subject.code,
                    'document_count': doc_count,
                    'quiz_count': quiz_count,
                    'student_count': student_count,
                    'active_students': active_on_subject,
                    'total_views': total_views,
                    'total_downloads': total_downloads,
                    'quiz_attempts': quiz_attempts,
                    'average_quiz_score': avg_score,
                    'quiz_pass_rate': pass_rate
                })
            
            # =====================================
            # 3. ACTIVITÉS RÉCENTES
            # =====================================
            
            recent_activities = []
            
            # Nouveaux documents du professeur
            my_recent_docs = Document.objects.filter(
                created_by=request.user,
                subject__in=teacher_subjects
            ).select_related('subject').order_by('-created_at')[:5]
            
            for doc in my_recent_docs:
                recent_activities.append({
                    'activity_type': 'document_created',
                    'title': 'Document ajouté',
                    'description': doc.title,
                    'subject_name': doc.subject.name,
                    'created_at': doc.created_at,
                    'icon': 'description',
                    'color': 'green'
                })
            
            # Nouveaux quiz du professeur
            my_recent_quizzes = Quiz.objects.filter(
                created_by=request.user,
                subject__in=teacher_subjects
            ).select_related('subject').order_by('-created_at')[:5]
            
            for quiz in my_recent_quizzes:
                recent_activities.append({
                    'activity_type': 'quiz_created',
                    'title': 'Quiz créé',
                    'description': quiz.title,
                    'subject_name': quiz.subject.name,
                    'created_at': quiz.created_at,
                    'icon': 'quiz',
                    'color': 'purple'
                })
            
            # Tentatives récentes de quiz
            recent_attempts = QuizAttempt.objects.filter(
                quiz__subject__in=teacher_subjects,
                status='COMPLETED'
            ).select_related('user', 'quiz', 'quiz__subject').order_by('-completed_at')[:5]
            
            for attempt in recent_attempts:
                is_passed = attempt.score >= attempt.quiz.passing_percentage
                recent_activities.append({
                    'activity_type': 'quiz_attempt',
                    'title': 'Quiz complété',
                    'description': f'{attempt.user.get_full_name()} - {attempt.quiz.title}',
                    'subject_name': attempt.quiz.subject.name,
                    'student_name': attempt.user.get_full_name(),
                    'created_at': attempt.completed_at,
                    'icon': 'check_circle' if is_passed else 'cancel',
                    'color': 'green' if is_passed else 'red'
                })
            
            # Trier par date
            recent_activities = sorted(
                recent_activities,
                key=lambda x: x['created_at'],
                reverse=True
            )[:15]
            
            # =====================================
            # ASSEMBLAGE
            # =====================================
            
            dashboard_data = {
                'stats': stats_data,
                'subject_performance': subject_performance,
                'recent_activities': recent_activities
            }
            
            return Response({
                'success': True,
                'dashboard': dashboard_data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur dashboard professeur: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# GESTION DES TENTATIVES DE QUIZ (PROFESSEUR)
# ========================================

class TeacherQuizAttemptsView(APIView):
    """
    Liste des tentatives de quiz pour un professeur
    GET /api/courses/teacher/quizzes/{quiz_id}/attempts/
    """
    permission_classes = [IsTeacherUser]
    
    def get(self, request, quiz_id):
        """Liste des tentatives d'un quiz"""
        logger.info(f"📝 Tentatives quiz {quiz_id} par prof: {request.user.username}")
        
        try:
            quiz = get_object_or_404(Quiz, id=quiz_id)
            
            # Vérifier l'accès
            if not has_subject_access(request.user, quiz.subject):
                return Response({
                    'success': False,
                    'error': 'Accès refusé à cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Récupérer les tentatives
            attempts = QuizAttempt.objects.filter(
                quiz=quiz
            ).select_related('user', 'quiz').order_by('-started_at')
            
            # Filtres
            status_filter = request.GET.get('status', None)
            if status_filter:
                attempts = attempts.filter(status=status_filter)
            
            student_id = request.GET.get('student', None)
            if student_id:
                attempts = attempts.filter(user_id=student_id)
            
            serializer = TeacherQuizAttemptListSerializer(attempts, many=True)
            
            # Statistiques
            total_attempts = attempts.count()
            completed = attempts.filter(status='COMPLETED')
            completed_count = completed.count()
            
            # ✅ Récupérer total_points et vérifier qu'il n'est pas None
            total_points = quiz.total_points if quiz.total_points is not None else 0
            
            avg_score = 0
            if completed_count > 0 and total_points > 0:
                scores = []
                for attempt in completed:
                    normalized = (float(attempt.score) / float(total_points)) * 20
                    scores.append(normalized)
                
                if scores:
                    avg_score = round(sum(scores) / len(scores), 2)
            
            # ✅ Calcul du taux de réussite corrigé
            passed = 0
            if completed_count > 0 and total_points > 0:
                for attempt in completed:
                    percentage = (float(attempt.score) / float(total_points)) * 100
                    if percentage >= float(quiz.passing_percentage):
                        passed += 1
            
            pass_rate = round((passed / completed_count) * 100, 1) if completed_count > 0 else 0
            
            return Response({
                'success': True,
                'quiz': {
                    'id': quiz.id,
                    'title': quiz.title,
                    'total_points': float(total_points),  # ✅ Utiliser la variable vérifiée
                    'passing_percentage': float(quiz.passing_percentage)
                },
                'statistics': {
                    'total_attempts': total_attempts,
                    'completed_attempts': completed_count,
                    'average_score': avg_score,
                    'pass_rate': pass_rate
                },
                'attempts': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur tentatives quiz: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# ========================================
# LISTE DES DOCUMENTS D'UNE MATIÈRE (PROFESSEUR)
# ========================================

class TeacherSubjectDocumentsView(APIView):
    """
    Liste des documents d'une matière pour un professeur
    GET /api/courses/teacher/subjects/{subject_id}/documents/
    """
    permission_classes = [IsTeacherUser]
    
    def get(self, request, subject_id):
        """Récupérer les documents d'une matière"""
        logger.info(f"📄 Documents matière {subject_id} par prof: {request.user.username}")
        
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            # Vérifier l'accès
            if not has_subject_access(request.user, subject):
                return Response({
                    'success': False,
                    'error': 'Accès refusé à cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Récupérer tous les documents de la matière
            documents = Document.objects.filter(
                subject=subject
            ).select_related('created_by', 'subject').order_by('-created_at')
            
            # Filtres optionnels
            document_type = request.GET.get('type', None)
            if document_type:
                documents = documents.filter(document_type=document_type)
            
            search = request.GET.get('search', None)
            if search:
                from django.db.models import Q
                documents = documents.filter(
                    Q(title__icontains=search) | Q(description__icontains=search)
                )
            
            # ✅ CORRECTION : Utiliser DocumentSerializer au lieu de DocumentListSerializer
            serializer = DocumentSerializer(documents, many=True, context={'request': request})
            
            # Ajouter les permissions pour chaque document
            documents_with_permissions = []
            for doc_data in serializer.data:
                doc = Document.objects.get(id=doc_data['id'])
                doc_data['can_edit'] = doc.created_by == request.user
                doc_data['can_delete'] = doc.created_by == request.user
                documents_with_permissions.append(doc_data)
            
            return Response({
                'success': True,
                'documents': documents_with_permissions,
                'count': len(documents_with_permissions)
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur documents matière: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# MODIFICATION DE DOCUMENTS (PROFESSEUR)
# ========================================

class TeacherUpdateDocumentView(APIView):
    """
    Modifier un document créé par le professeur
    PATCH /api/courses/teacher/documents/{document_id}/
    """
    permission_classes = [IsTeacherUser]
    
    def patch(self, request, document_id):
        """Modifier son propre document"""
        logger.info(f"✏️ Modification document {document_id} par prof: {request.user.username}")
        
        try:
            document = get_object_or_404(Document, id=document_id)
            
            # Vérifier que c'est son document
            if document.created_by != request.user:
                return Response({
                    'success': False,
                    'error': 'Vous ne pouvez modifier que vos propres documents'
                }, status=status.HTTP_403_FORBIDDEN)
            
            # Vérifier qu'il a toujours accès à la matière
            if not has_subject_access(request.user, document.subject):
                return Response({
                    'success': False,
                    'error': 'Vous n\'avez plus accès à cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            serializer = DocumentUpdateSerializer(
                document,
                data=request.data,
                partial=True,
                context={'request': request}
            )
            
            if serializer.is_valid():
                serializer.save()
                
                logger.info(f"✅ Document modifié: {document.title}")
                
                # Retourner le document complet
                response_serializer = DocumentSerializer(document)
                
                return Response({
                    'success': True,
                    'message': 'Document modifié avec succès',
                    'document': response_serializer.data
                })
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"❌ Erreur modification document: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# ========================================
# MODIFICATION DE MATIÈRE (PROFESSEUR)
# ========================================

class TeacherUpdateSubjectView(APIView):
    """
    Modifier une matière (si permission can_edit_content)
    PATCH /api/courses/teacher/subjects/{subject_id}/
    """
    permission_classes = [IsTeacherUser]
    
    def patch(self, request, subject_id):
        """Modifier une matière"""
        logger.info(f"✏️ Modification matière {subject_id} par prof: {request.user.username}")
        
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            # Vérifier la permission
            from accounts.permissions import can_edit_subject_content
            if not can_edit_subject_content(request.user, subject):
                return Response({
                    'success': False,
                    'error': 'Vous n\'avez pas la permission de modifier cette matière'
                }, status=status.HTTP_403_FORBIDDEN)
            
            serializer = SubjectUpdateByTeacherSerializer(
                subject,
                data=request.data,
                partial=True,
                context={'request': request}
            )
            
            if serializer.is_valid():
                serializer.save()
                
                logger.info(f"✅ Matière modifiée par prof: {subject.name}")
                
                return Response({
                    'success': True,
                    'message': 'Matière modifiée avec succès',
                    'subject': {
                        'id': subject.id,
                        'name': subject.name,
                        'code': subject.code,
                        'description': subject.description,
                        'is_featured': subject.is_featured
                    }
                })
            
            return Response({
                'success': False,
                'errors': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            logger.error(f"❌ Erreur modification matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
            


# ========================================
# ADMIN - GESTION DES DOCUMENTS
# ========================================

class AdminDocumentListView(APIView):
    """
    Liste de TOUS les documents avec filtres
    GET /api/courses/admin/documents/
    Filtres disponibles: ?subject=1&teacher=2&type=PDF&is_active=true&search=math&page=1&page_size=20
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request):
        """Liste globale de tous les documents"""
        logger.info(f"📋 Liste admin documents par: {request.user.username}")
        
        try:
            # Récupérer tous les documents avec relations
            queryset = Document.objects.select_related(
                'subject', 'created_by'
            ).prefetch_related(
                'subject__levels', 'subject__majors'
            ).order_by('-created_at')
            
            # ===== FILTRES =====
            
            # Filtre par matière
            subject_id = request.GET.get('subject')
            if subject_id:
                queryset = queryset.filter(subject_id=subject_id)
            
            # Filtre par professeur
            teacher_id = request.GET.get('teacher')
            if teacher_id:
                queryset = queryset.filter(created_by_id=teacher_id)
            
            # Filtre par type de document
            doc_type = request.GET.get('type')
            if doc_type:
                queryset = queryset.filter(document_type=doc_type)
            
            # Filtre par statut actif
            is_active = request.GET.get('is_active')
            if is_active is not None:
                queryset = queryset.filter(is_active=is_active.lower() == 'true')
            
            # Recherche par titre ou description
            search = request.GET.get('search')
            if search:
                from django.db.models import Q
                queryset = queryset.filter(
                    Q(title__icontains=search) | 
                    Q(description__icontains=search)
                )
            
            # ===== PAGINATION =====
            page = int(request.GET.get('page', 1))
            page_size = int(request.GET.get('page_size', 20))
            start = (page - 1) * page_size
            end = start + page_size
            
            total = queryset.count()
            documents = queryset[start:end]
            
            # ===== SERIALIZATION =====
            serializer = DocumentSerializer(
                documents, 
                many=True,
                context={'request': request}
            )
            
            return Response({
                'success': True,
                'total': total,
                'page': page,
                'page_size': page_size,
                'total_pages': (total + page_size - 1) // page_size,
                'documents': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur liste documents admin: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur',
                'details': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminDocumentDetailView(APIView):
    """
    Détail, modification, suppression d'un document (ADMIN)
    GET /api/courses/admin/documents/<id>/     - Voir détails
    PATCH /api/courses/admin/documents/<id>/   - Modifier
    DELETE /api/courses/admin/documents/<id>/  - Supprimer
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, document_id):
        """Récupérer les détails d'un document"""
        try:
            document = get_object_or_404(
                Document.objects.select_related('subject', 'created_by'),
                id=document_id
            )
            
            serializer = DocumentSerializer(document, context={'request': request})
            
            return Response({
                'success': True,
                'document': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur détail document: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def patch(self, request, document_id):
        """Modifier un document"""
        try:
            document = get_object_or_404(Document, id=document_id)
            
            # Mettre à jour les champs fournis
            if 'title' in request.data:
                document.title = request.data['title']
            
            if 'description' in request.data:
                document.description = request.data['description']
            
            if 'document_type' in request.data:
                document.document_type = request.data['document_type']
            
            if 'is_active' in request.data:
                document.is_active = request.data['is_active']
            
            if 'is_premium' in request.data:
                document.is_premium = request.data['is_premium']
            
            document.save()
            
            serializer = DocumentSerializer(document, context={'request': request})
            
            logger.info(f"✅ Document modifié par admin: {document.title}")
            
            return Response({
                'success': True,
                'message': 'Document modifié avec succès',
                'document': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur modification document: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    def delete(self, request, document_id):
        """Supprimer un document définitivement"""
        try:
            document = get_object_or_404(Document, id=document_id)
            
            title = document.title
            
            # Supprimer le fichier physique du serveur
            if document.file:
                try:
                    document.file.delete(save=False)
                except Exception as e:
                    logger.warning(f"⚠️ Erreur suppression fichier physique: {str(e)}")
            
            # Supprimer l'entrée de la base de données
            document.delete()
            
            logger.info(f"✅ Document supprimé par admin: {title}")
            
            return Response({
                'success': True,
                'message': f'Document "{title}" supprimé avec succès'
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur suppression document: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminDocumentToggleActiveView(APIView):
    """
    Activer/Désactiver rapidement un document
    POST /api/courses/admin/documents/<id>/toggle-active/
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request, document_id):
        """Basculer le statut actif/inactif d'un document"""
        try:
            document = get_object_or_404(Document, id=document_id)
            
            # Inverser le statut
            document.is_active = not document.is_active
            document.save()
            
            status_text = "activé" if document.is_active else "désactivé"
            
            logger.info(f"✅ Document {status_text} par admin: {document.title}")
            
            return Response({
                'success': True,
                'message': f'Document {status_text} avec succès',
                'is_active': document.is_active
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur toggle document: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminDocumentBulkActionView(APIView):
    """
    Actions en masse sur plusieurs documents
    POST /api/courses/admin/documents/bulk-action/
    
    Body JSON:
    {
        "action": "activate" | "deactivate" | "delete",
        "document_ids": [1, 2, 3, 4]
    }
    """
    permission_classes = [IsAdminPermission]
    
    def post(self, request):
        """Effectuer une action sur plusieurs documents à la fois"""
        try:
            action = request.data.get('action')
            document_ids = request.data.get('document_ids', [])
            
            # Validation
            if not action or not document_ids:
                return Response({
                    'success': False,
                    'error': 'Les champs "action" et "document_ids" sont requis'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Récupérer les documents concernés
            documents = Document.objects.filter(id__in=document_ids)
            count = documents.count()
            
            if count == 0:
                return Response({
                    'success': False,
                    'error': 'Aucun document trouvé'
                }, status=status.HTTP_404_NOT_FOUND)
            
            # Exécuter l'action
            if action == 'activate':
                documents.update(is_active=True)
                message = f'{count} document(s) activé(s)'
                
            elif action == 'deactivate':
                documents.update(is_active=False)
                message = f'{count} document(s) désactivé(s)'
                
            elif action == 'delete':
                # Supprimer les fichiers physiques
                for doc in documents:
                    if doc.file:
                        try:
                            doc.file.delete(save=False)
                        except Exception as e:
                            logger.warning(f"⚠️ Erreur suppression fichier: {str(e)}")
                
                # Supprimer les entrées de la base
                documents.delete()
                message = f'{count} document(s) supprimé(s)'
                
            else:
                return Response({
                    'success': False,
                    'error': f'Action invalide: {action}. Actions valides: activate, deactivate, delete'
                }, status=status.HTTP_400_BAD_REQUEST)
            
            logger.info(f"✅ Action en masse par admin ({request.user.username}): {message}")
            
            return Response({
                'success': True,
                'message': message,
                'count': count
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur action en masse: {str(e)}")
            import traceback
            traceback.print_exc()
            
            return Response({
                'success': False,
                'error': 'Erreur serveur'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class AdminSubjectDocumentsView(APIView):
    """
    Liste des documents d'une matière spécifique (vue admin)
    GET /api/courses/admin/subjects/<id>/documents/
    """
    permission_classes = [IsAdminPermission]
    
    def get(self, request, subject_id):
        """Récupérer tous les documents d'une matière"""
        try:
            subject = get_object_or_404(Subject, id=subject_id)
            
            # Tous les documents de cette matière
            documents = Document.objects.filter(
                subject=subject
            ).select_related('created_by').order_by('-created_at')
            
            serializer = DocumentSerializer(
                documents, 
                many=True,
                context={'request': request}
            )
            
            return Response({
                'success': True,
                'subject': {
                    'id': subject.id,
                    'name': subject.name,
                    'code': subject.code
                },
                'total': documents.count(),
                'documents': serializer.data
            })
            
        except Exception as e:
            logger.error(f"❌ Erreur documents matière: {str(e)}")
            return Response({
                'success': False,
                'error': 'Erreur serveur'
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)