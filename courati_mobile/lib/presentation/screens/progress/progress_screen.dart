import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/models/document_model.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _homeData = {};
  List<SubjectModel> _subjects = [];
  
  // Stats globales
  int _totalDocuments = 0;
  int _viewedDocuments = 0;
  double _completionRate = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }
  
  Future<void> _loadProgressData() async {
    setState(() => _isLoading = true);
    
    try {
      final accessToken = await StorageService.getValidAccessToken();
      if (accessToken == null) return;
      
      // Charger les données depuis l'API
      final homeData = await ApiService.getPersonalizedHome(accessToken);
      final subjectsResponse = await ApiService.getMySubjects(accessToken);
      
      if (homeData['success'] && subjectsResponse['success']) {
        if (mounted) {
          setState(() {
            _homeData = homeData['data'];
            _subjects = (subjectsResponse['subjects'] as List)
                .map((json) => SubjectModel.fromJson(json))
                .toList();
            
            // Extraire les stats globales
            _totalDocuments = _homeData['stats']?['total_documents'] ?? 0;
            _viewedDocuments = _homeData['stats']?['viewed_documents'] ?? 0;
            _completionRate = (_homeData['stats']?['completion_rate'] ?? 0.0).toDouble();
          });
        }
      }
    } catch (e) {
      print('❌ Erreur chargement progression: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Ma Progression',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProgressData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Graphique circulaire global
                    _buildGlobalProgressCircle(),
                    
                    const SizedBox(height: 24),
                    
                    // 2. Stats en cartes
                    _buildStatsCards(),
                    
                    const SizedBox(height: 32),
                    
                    // 3. Progression par matière
                    const Text(
                      'Progression par matière',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    _buildSubjectsProgressList(),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }
  
  // ========================================
  // GRAPHIQUE CIRCULAIRE GLOBAL
  // ========================================
  
  Widget _buildGlobalProgressCircle() {
    final progressRate = _totalDocuments > 0 
        ? _viewedDocuments / _totalDocuments 
        : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Progression Globale',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Cercle de progression
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Cercle de fond
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 14,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey.shade200,
                    ),
                  ),
                ),
                
                // Cercle de progression animé
                SizedBox(
                  width: 180,
                  height: 180,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: progressRate),
                    builder: (context, value, child) {
                      return CircularProgressIndicator(
                        value: value,
                        strokeWidth: 14,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(value),
                        ),
                      );
                    },
                  ),
                ),
                
                // Texte au centre
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(
                        begin: 0, 
                        end: _completionRate,
                      ),
                      builder: (context, value, child) {
                        return Text(
                          '${value.toInt()}%',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: _getProgressColor(progressRate),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$_viewedDocuments/$_totalDocuments',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'documents consultés',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Message motivationnel
          _buildMotivationalMessage(progressRate),
        ],
      ),
    );
  }
  
  Widget _buildMotivationalMessage(double progress) {
    String message;
    IconData icon;
    Color color;
    
    if (progress == 1.0) {
      message = '🎉 Bravo ! Vous avez tout consulté !';
      icon = Icons.emoji_events;
      color = Colors.amber;
    } else if (progress >= 0.8) {
      message = '🔥 Excellent ! Encore un petit effort !';
      icon = Icons.local_fire_department;
      color = Colors.orange;
    } else if (progress >= 0.5) {
      message = '💪 Bon travail ! Continuez comme ça !';
      icon = Icons.thumb_up;
      color = Colors.blue;
    } else if (progress > 0) {
      message = '🚀 Vous avez démarré ! Gardez le rythme !';
      icon = Icons.rocket_launch;
      color = Colors.green;
    } else {
      message = '📚 Commencez votre parcours d\'apprentissage !';
      icon = Icons.school;
      color = Colors.grey;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color.darken(30),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // ========================================
  // STATS EN CARTES
  // ========================================
  
  Widget _buildStatsCards() {
    final totalSubjects = _homeData['stats']?['total_subjects'] ?? 0;
    final completedSubjects = _homeData['stats']?['completed_subjects'] ?? 0;
    final remaining = _totalDocuments - _viewedDocuments;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Matières',
            '$completedSubjects/$totalSubjects',
            Icons.subject,
            Colors.purple,
            'complètes',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Restants',
            '$remaining',
            Icons.pending_actions,
            Colors.orange,
            'documents',
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // ========================================
  // LISTE DES MATIÈRES - CORRIGÉ
  // ========================================
  
  Widget _buildSubjectsProgressList() {
    if (_subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(
                Icons.subject_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune matière disponible',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      children: _subjects.map((subject) {
        return _buildSubjectProgressCard(subject);
      }).toList(),
    );
  }
  
  Widget _buildSubjectProgressCard(SubjectModel subject) {
    // Récupérer la progression de cette matière
    final subjectProgress = _homeData['subject_progress']?[subject.id.toString()] ?? {};
    final viewedDocs = subjectProgress['viewed_documents'] ?? 0;
    final totalDocs = subjectProgress['total_documents'] ?? 0;
    final progressRate = (subjectProgress['completion_rate'] ?? 0.0).toDouble();
    final isCompleted = subjectProgress['is_completed'] ?? false;
    
    // Calculer le ratio pour la barre de progression (entre 0.0 et 1.0)
    final progressRatio = totalDocs > 0 ? (viewedDocs / totalDocs).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subject.code,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Icône complété
                if (isCompleted)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Nom de la matière
            Text(
              subject.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // Barre de progression - CORRIGÉ
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 8,
                      child: LinearProgressIndicator(
                        value: progressRatio, // Utilise le ratio entre 0.0 et 1.0
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isCompleted ? Colors.green : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Text(
                  '${progressRate.toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.green : AppColors.primary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Détails
            Text(
              '$viewedDocs/$totalDocs documents consultés',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // ========================================
  // HELPERS
  // ========================================
  
  Color _getProgressColor(double progress) {
    if (progress < 0.3) return Colors.red;
    if (progress < 0.6) return Colors.orange;
    if (progress < 0.9) return AppColors.primary;
    return Colors.green;
  }
}

// Extension pour assombrir les couleurs
extension ColorExtension on Color {
  Color darken([int percent = 10]) {
    assert(1 <= percent && percent <= 100);
    final f = 1 - percent / 100;
    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }
}