// 📁 lib/presentation/screens/projects/project_detail_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import 'project_edit_screen.dart';
import 'task_create_screen.dart';
import 'task_edit_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;
  final String accessToken;

  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.accessToken,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late ProjectModel _project;
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      // ✅ APPEL DIRECT
      final tasksJson = await ApiService.getProjectTasks('', _project.id);
      
      // ✅ Vérifier si liste vide (redirection déjà gérée)
      if (tasksJson.isEmpty && mounted) {
        setState(() {
          _tasks = [];
          _isLoading = false;
        });
        return;
      }
      
      if (mounted) {
        setState(() {
          _tasks = tasksJson
              .map((json) => TaskModel.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Erreur chargement tâches: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<TaskModel> _getTasksByStatus(String status) {
    return _tasks.where((task) => task.status == status).toList();
  }

  bool get _isArchived => _project.status == 'ARCHIVED';

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(_project.color);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_project.title),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _project.isFavorite ? Icons.star : Icons.star_outline,
              color: _project.isFavorite ? Colors.orange : null,
            ),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editProject();
                  break;
                case 'archive':
                  _toggleArchive();
                  break;
                case 'delete':
                  _deleteProject();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: Colors.blue),
                    SizedBox(width: 12),
                    Text('Modifier'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Row(
                  children: [
                    Icon(
                      _isArchived ? Icons.unarchive : Icons.archive,
                      size: 20,
                      color: _isArchived ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Text(_isArchived ? 'Désarchiver' : 'Archiver'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: CustomScrollView(
                slivers: [
                  _buildProjectHeader(color),
                  _buildKanbanBoard(),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),
      floatingActionButton: _buildFloatingActionButton(color),
    );
  }

  Widget _buildProjectHeader(Color color) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
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
                        _project.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_project.subjectName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _project.subjectName!,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            if (_project.description != null && _project.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _project.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_project.progressPercentage.toInt()}% complété',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${_project.completedTasksCount}/${_project.totalTasks} tâches',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _project.progressPercentage / 100,
                    backgroundColor: color.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBadge(
                  _project.priorityDisplay,
                  _getPriorityColor(_project.priority),
                ),
                if (_project.isOverdue)
                  _buildBadge('En retard', Colors.red),
                if (_project.dueDate != null)
                  _buildBadge(
                    'Échéance: ${_formatDate(_project.dueDate!)}',
                    Colors.blue,
                  ),
                if (_isArchived)
                  _buildBadge(' Archivé', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ KANBAN BOARD avec Drag & Drop
  Widget _buildKanbanBoard() {
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 10),
        
        // Colonne "À faire"
        _buildDraggableKanbanSection(
          'À faire',
          'TODO',
          const Color(0xFF6366F1),
          _getTasksByStatus('TODO'),
        ),
        
        const SizedBox(height: 16),
        
        // Colonne "En cours"
        _buildDraggableKanbanSection(
          'En cours',
          'IN_PROGRESS',
          const Color(0xFFF59E0B),
          _getTasksByStatus('IN_PROGRESS'),
        ),
        
        const SizedBox(height: 16),
        
        // Colonne "Terminé"
        _buildDraggableKanbanSection(
          'Terminé',
          'DONE',
          const Color(0xFF10B981),
          _getTasksByStatus('DONE'),
        ),
        
        const SizedBox(height: 100),
      ]),
    );
  }

  // ✅ Section Kanban avec Drag Target
  Widget _buildDraggableKanbanSection(
    String title,
    String status,
    Color color,
    List<TaskModel> tasks,
  ) {
    return DragTarget<TaskModel>(
      onAccept: (task) {
        if (task.status != status) {
          _moveTask(task, status);
        }
      },
      onWillAccept: (task) => task?.status != status,
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovering ? color : Colors.grey[200]!,
              width: isHovering ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isHovering 
                    ? color.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: isHovering ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Header SANS icône - épuré
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(isHovering ? 0.2 : 0.1),
                      color.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: color,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // ✅ Liste horizontale avec scroll
              Container(
                height: 200,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isHovering 
                                  ? Icons.add_circle_outline 
                                  : Icons.inbox_outlined,
                              size: 45,
                              color: isHovering ? color : Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isHovering 
                                  ? 'Déposer ici' 
                                  : 'Aucune tâche',
                              style: TextStyle(
                                color: isHovering ? color : Colors.grey[400],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          return _buildDraggableTaskCard(
                            tasks[index],
                            color,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Carte de tâche DRAGGABLE
  Widget _buildDraggableTaskCard(TaskModel task, Color color) {
    return LongPressDraggable<TaskModel>(
      data: task,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _buildTaskContent(task, color, isDragging: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildStaticTaskCard(task, color),
      ),
      child: _buildStaticTaskCard(task, color),
    );
  }

  // ✅ Carte statique (affichage normal)
  Widget _buildStaticTaskCard(TaskModel task, Color color) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTaskOptions(task),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildTaskContent(task, color),
          ),
        ),
      ),
    );
  }

  // ✅ Contenu de la tâche (partagé)
  Widget _buildTaskContent(TaskModel task, Color color, {bool isDragging = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Titre
        Text(
          task.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: AppColors.textPrimary,
            height: 1.3,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 12),
        
        // Badges en bas
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // ✅ Badge "IMPORTANT" au lieu de l'icône
            if (task.isImportant)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.priority_high_rounded,
                      color: Colors.red,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'IMPORTANT',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Date d'échéance
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: task.isOverdue
                      ? Colors.red.withOpacity(0.1)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: task.isOverdue ? Colors.red : color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatDate(task.dueDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: task.isOverdue ? Colors.red : color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(Color color) {
    if (_isArchived) return null;
    
    return FloatingActionButton.extended(
      onPressed: _createTask,
      backgroundColor: color,
      icon: const Icon(Icons.add),
      label: const Text('Nouvelle tâche'),
    );
  }

  // ✅ MODAL AMÉLIORÉ avec description
  void _showTaskOptions(TaskModel task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barre de drag
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Titre de la tâche
              Text(
                task.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // ✅ DESCRIPTION (si existe)
              if (task.description != null && task.description!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        task.description!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Infos supplémentaires
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (task.isImportant)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.priority_high_rounded,
                            color: Colors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'IMPORTANT',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (task.dueDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: task.isOverdue
                            ? Colors.red.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: task.isOverdue ? Colors.red : Colors.blue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDate(task.dueDate!),
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isOverdue ? Colors.red : Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // ✅ Section Déplacer vers
              if (task.status != 'TODO' || 
                  task.status != 'IN_PROGRESS' || 
                  task.status != 'DONE') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Déplacer vers',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      if (task.status != 'TODO')
                        _buildQuickMoveButton(
                          'À faire',
                          const Color(0xFF6366F1),
                          () {
                            Navigator.pop(context);
                            _moveTask(task, 'TODO');
                          },
                        ),
                      
                      if (task.status != 'TODO' && task.status != 'IN_PROGRESS')
                        const SizedBox(height: 8),
                      
                      if (task.status != 'IN_PROGRESS')
                        _buildQuickMoveButton(
                          'En cours',
                          const Color(0xFFF59E0B),
                          () {
                            Navigator.pop(context);
                            _moveTask(task, 'IN_PROGRESS');
                          },
                        ),
                      
                      if (task.status != 'IN_PROGRESS' && task.status != 'DONE')
                        const SizedBox(height: 8),
                      
                      if (task.status != 'DONE')
                        _buildQuickMoveButton(
                          'Terminé',
                          const Color(0xFF10B981),
                          () {
                            Navigator.pop(context);
                            _moveTask(task, 'DONE');
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Actions
              _buildActionButton(
                Icons.edit_rounded,
                'Modifier',
                Colors.blue,
                () {
                  Navigator.pop(context);
                  _editTask(task);
                },
              ),
              const SizedBox(height: 12),
              _buildActionButton(
                Icons.delete_rounded,
                'Supprimer',
                Colors.red,
                () {
                  Navigator.pop(context);
                  _deleteTask(task);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMoveButton(
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MÉTHODES D'ACTION
  
  Future<void> _toggleFavorite() async {
    try {
      // ✅ APPEL DIRECT
      final response = await ApiService.toggleProjectFavorite('', _project.id);
      
      // ✅ Vérifier succès
      if (response['success'] == false) return;
      
      setState(() {
        _project = ProjectModel(
          id: _project.id,
          title: _project.title,
          description: _project.description,
          subjectId: _project.subjectId,
          subjectName: _project.subjectName,
          subjectCode: _project.subjectCode,
          subjectColor: _project.subjectColor,
          status: _project.status,
          statusDisplay: _project.statusDisplay,
          priority: _project.priority,
          priorityDisplay: _project.priorityDisplay,
          startDate: _project.startDate,
          dueDate: _project.dueDate,
          completedAt: _project.completedAt,
          progressPercentage: _project.progressPercentage,
          color: _project.color,
          isFavorite: !_project.isFavorite,
          order: _project.order,
          isOverdue: _project.isOverdue,
          daysUntilDue: _project.daysUntilDue,
          totalTasks: _project.totalTasks,
          completedTasksCount: _project.completedTasksCount,
          createdAt: _project.createdAt,
          updatedAt: _project.updatedAt,
        );
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _project.isFavorite 
                  ? '⭐ Ajouté aux favoris' 
                  : 'Retiré des favoris',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur toggle favorite: $e');
    }
  }

  Future<void> _moveTask(TaskModel task, String newStatus) async {
    try {
      // ✅ APPEL DIRECT
      final response = await ApiService.moveTask('', task.id, newStatus);
      
      // ✅ Vérifier succès
      if (response['success'] == false) return;
      
      await _loadTasks();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tâche déplacée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Erreur déplacement tâche: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createTask() async {
    // ✅ Utiliser getAccessToken pour la navigation
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskCreateScreen(
          projectId: _project.id,
          accessToken: token,
        ),
      ),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  void _editTask(TaskModel task) async {
    // ✅ Utiliser getAccessToken pour la navigation
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          task: task,
          accessToken: token,
        ),
      ),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  Future<void> _deleteTask(TaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Supprimer la tâche'),
        content: Text('Voulez-vous supprimer "${task.title}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ✅ APPEL DIRECT
        await ApiService.deleteTask('', task.id);
        await _loadTasks();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Tâche supprimée'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression tâche: $e');
      }
    }
  }

  void _editProject() async {
    // ✅ Utiliser getAccessToken pour la navigation
    final token = await StorageService.getAccessToken();
    if (token == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectEditScreen(
          project: _project,
          accessToken: token,
        ),
      ),
    );

    if (result == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _toggleArchive() async {
    final action = _isArchived ? 'désarchiver' : 'archiver';
    final actionCap = _isArchived ? 'Désarchiver' : 'Archiver';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('$actionCap le projet'),
        content: Text(
          _isArchived
              ? 'Ce projet sera réactivé et apparaîtra dans vos projets actifs.'
              : 'Ce projet sera archivé et n\'apparaîtra plus dans vos projets actifs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isArchived ? Colors.green : Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(actionCap),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ✅ APPEL DIRECT
        if (_isArchived) {
          await ApiService.unarchiveProject('', _project.id);
        } else {
          await ApiService.archiveProject('', _project.id);
        }
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isArchived 
                    ? '✅ Projet désarchivé' 
                    : '✅ Projet archivé',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur $action: $e');
      }
    }
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Supprimer le projet'),
        content: const Text(
          'Cette action est irréversible. Le projet et toutes ses tâches seront supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // ✅ APPEL DIRECT
        await ApiService.deleteProject('', _project.id);
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Projet supprimé'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur suppression: $e');
      }
    }
  }

  Color _parseColor(String? colorString) {
    if (colorString == null) return AppColors.primary;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColors.primary;
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}