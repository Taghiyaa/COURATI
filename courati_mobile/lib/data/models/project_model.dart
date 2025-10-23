// 📁 lib/data/models/project_model.dart

class ProjectModel {
  final int id;
  final String title;
  final String? description;
  final int? subjectId;
  final String? subjectName;
  final String? subjectCode;
  final String? subjectColor;
  final String status;
  final String statusDisplay;
  final String priority;
  final String priorityDisplay;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double progressPercentage;
  final String? color;
  final bool isFavorite;
  final int order;
  final bool isOverdue;
  final int? daysUntilDue;
  final int totalTasks;
  final int completedTasksCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectModel({
    required this.id,
    required this.title,
    this.description,
    this.subjectId,
    this.subjectName,
    this.subjectCode,
    this.subjectColor,
    required this.status,
    required this.statusDisplay,
    required this.priority,
    required this.priorityDisplay,
    this.startDate,
    this.dueDate,
    this.completedAt,
    required this.progressPercentage,
    this.color,
    required this.isFavorite,
    required this.order,
    required this.isOverdue,
    this.daysUntilDue,
    required this.totalTasks,
    required this.completedTasksCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      subjectId: json['subject'],
      subjectName: json['subject_name'],
      subjectCode: json['subject_code'],
      subjectColor: json['subject_color'] ?? json['color'],
      status: json['status'] ?? 'NOT_STARTED',
      statusDisplay: json['status_display'] ?? '',
      priority: json['priority'] ?? 'MEDIUM',
      priorityDisplay: json['priority_display'] ?? '',
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date']) 
          : null,
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      progressPercentage: (json['progress_percentage'] ?? 0).toDouble(),
      color: json['color'] ?? '#4A90E2',
      isFavorite: json['is_favorite'] ?? false,
      order: json['order'] ?? 0,
      isOverdue: json['is_overdue'] ?? false,
      daysUntilDue: json['days_until_due'],
      totalTasks: json['total_tasks'] ?? 0,
      completedTasksCount: json['completed_tasks_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'subject': subjectId,
      'status': status,
      'priority': priority,
      'start_date': startDate?.toIso8601String().split('T')[0],
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'color': color,
      'is_favorite': isFavorite,
      'order': order,
    };
  }
}