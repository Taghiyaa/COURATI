// 📁 lib/data/models/task_model.dart

class TaskModel {
  final int id;
  final int projectId;
  final String title;
  final String? description;
  final String status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final int order;
  final bool isImportant;
  final int? estimatedHours;
  final bool isOverdue;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.status,
    this.dueDate,
    this.completedAt,
    required this.order,
    required this.isImportant,
    this.estimatedHours,
    required this.isOverdue,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? 0,
      projectId: json['project'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'TODO',
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      order: json['order'] ?? 0,
      isImportant: json['is_important'] ?? false,
      estimatedHours: json['estimated_hours'],
      isOverdue: json['is_overdue'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project': projectId,
      'title': title,
      'description': description,
      'status': status,
      'due_date': dueDate?.toIso8601String().split('T')[0],
      'order': order,
      'is_important': isImportant,
      'estimated_hours': estimatedHours,
    };
  }

  TaskModel copyWith({
    String? status,
    int? order,
    bool? isImportant,
  }) {
    return TaskModel(
      id: id,
      projectId: projectId,
      title: title,
      description: description,
      status: status ?? this.status,
      dueDate: dueDate,
      completedAt: completedAt,
      order: order ?? this.order,
      isImportant: isImportant ?? this.isImportant,
      estimatedHours: estimatedHours,
      isOverdue: isOverdue,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}