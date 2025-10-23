// 📁 lib/presentation/screens/projects/projects_list_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/project_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import 'project_detail_screen.dart';
import 'project_create_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  final String accessToken;

  const ProjectsListScreen({
    super.key,
    required this.accessToken,
  });

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  List<ProjectModel> _projects = [];
  bool _isLoading = true;
  String _error = '';
  String _filterStatus = 'ALL'; // ALL, IN_PROGRESS, COMPLETED, ARCHIVED

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // ✅ APPEL DIRECT
      final projectsJson = await ApiService.getMyProjects('');
      
      // ✅ Vérifier si c'est une liste vide (redirection déjà gérée)
      if (projectsJson.isEmpty && mounted) {
        setState(() {
          _projects = [];
          _isLoading = false;
        });
        return;
      }
      
      if (mounted) {
        setState(() {
          _projects = projectsJson
              .map((json) => ProjectModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement projets: $e');
      if (mounted) {
        setState(() {
          _error = 'Erreur: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<ProjectModel> get _filteredProjects {
    if (_filterStatus == 'ALL') return _projects;
    return _projects.where((p) => p.status == _filterStatus).toList();
  }

  int get _activeProjects => _projects.where((p) => p.status == 'IN_PROGRESS').length;
  int get _completedProjects => _projects.where((p) => p.status == 'COMPLETED').length;
  int get _overdueProjects => _projects.where((p) => p.isOverdue && p.status != 'COMPLETED').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadProjects,
      child: CustomScrollView(
        slivers: [
          _buildHeader(),
          _buildStatsRow(),
          _buildFilterChips(),
          if (_filteredProjects.isEmpty)
            _buildEmptyState()
          else
            _buildProjectsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes Projets',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_projects.length} projet${_projects.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            // ✅ Bouton + en haut à droite
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _navigateToCreateProject,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Nouveau',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            _buildStatCard(
              _activeProjects,
              'En cours',
              Icons.play_circle_outline,
              Colors.blue,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              _completedProjects,
              'Terminés',
              Icons.check_circle_outline,
              Colors.green,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              _overdueProjects,
              'En retard',
              Icons.warning_amber_rounded,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(int count, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildFilterChip('Tous', 'ALL', Icons.grid_view),
            _buildFilterChip('En cours', 'IN_PROGRESS', Icons.work),
            _buildFilterChip('Terminés', 'COMPLETED', Icons.check_circle),
            _buildFilterChip('Archivés', 'ARCHIVED', Icons.archive),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String status, IconData icon) {
    final isSelected = _filterStatus == status;
    
    return Container(
        margin: const EdgeInsets.only(right: 8),
        child: FilterChip(
        selected: isSelected,
        label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
            Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.primary : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(label),
            ],
        ),
        onSelected: (selected) {
            setState(() => _filterStatus = status);
        },
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withOpacity(0.1),
        checkmarkColor: AppColors.primary,
        side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: 1.5,
        ),
        labelStyle: TextStyle(
            color: isSelected ? AppColors.primary : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        
        // ✨ LIGNE À AJOUTER
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // ← Changez ce nombre !
        ),
        ),
    );
    }

  Widget _buildProjectsList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildProjectCard(_filteredProjects[index], index),
            );
          },
          childCount: _filteredProjects.length,
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project, int index) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    final defaultColor = colors[index % colors.length];
    final color = _parseColor(project.color) ?? defaultColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToProjectDetail(project),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec titre et favoris
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (project.subjectName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              project.subjectName!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (project.isFavorite)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.orange,
                          size: 18,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Barre de progression
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${project.progressPercentage.toInt()}% complété',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${project.completedTasksCount}/${project.totalTasks} tâches',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: project.progressPercentage / 100,
                        backgroundColor: color.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Badges et infos
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(
                      project.priorityDisplay,
                      _getPriorityColor(project.priority),
                      _getPriorityIcon(project.priority),
                    ),
                    if (project.isOverdue)
                      _buildBadge(
                        'En retard',
                        Colors.red,
                        Icons.warning_amber_rounded,
                      ),
                    if (project.dueDate != null)
                      _buildBadge(
                        _formatDate(project.dueDate!),
                        Colors.blue,
                        Icons.calendar_today,
                      ),
                    _buildBadge(
                      project.statusDisplay,
                      _getStatusColor(project.status),
                      _getStatusIcon(project.status),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.work_outline,
                  size: 60,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Aucun projet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _filterStatus == 'ALL'
                    ? 'Créez votre premier projet !'
                    : 'Aucun projet dans cette catégorie',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _navigateToCreateProject,
                icon: const Icon(Icons.add),
                label: const Text('Créer un projet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadProjects,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Méthodes utilitaires
  Color? _parseColor(String? colorString) {
    if (colorString == null) return null;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return null;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'HIGH':
        return Icons.arrow_upward;
      case 'MEDIUM':
        return Icons.remove;
      case 'LOW':
        return Icons.arrow_downward;
      default:
        return Icons.remove;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'NOT_STARTED':
        return Colors.grey;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'ARCHIVED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'NOT_STARTED':
        return Icons.radio_button_unchecked;
      case 'IN_PROGRESS':
        return Icons.play_circle_outline;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'ARCHIVED':
        return Icons.archive;
      default:
        return Icons.circle;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _navigateToProjectDetail(ProjectModel project) async {
    // ✅ Utiliser getAccessToken pour la navigation
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(
          project: project,
          accessToken: token,
        ),
      ),
    ).then((_) => _loadProjects());
  }

  void _navigateToCreateProject() async {
    // ✅ Utiliser getAccessToken pour la navigation
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectCreateScreen(accessToken: token),
      ),
    ).then((_) => _loadProjects());
  }
}