// 📁 lib/data/models/notifications/notification_preference_model.dart
class NotificationPreferenceModel {
  final int id;
  final bool notificationsEnabled;
  final bool newContentEnabled;
  final bool quizEnabled;
  final bool deadlineRemindersEnabled;
  final bool quietHoursEnabled;
  final String? quietHoursStart;
  final String? quietHoursEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreferenceModel({
    required this.id,
    required this.notificationsEnabled,
    required this.newContentEnabled,
    required this.quizEnabled,
    required this.deadlineRemindersEnabled,
    required this.quietHoursEnabled,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationPreferenceModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferenceModel(
      id: json['id'],
      notificationsEnabled: json['notifications_enabled'],
      newContentEnabled: json['new_content_enabled'],
      quizEnabled: json['quiz_enabled'],
      deadlineRemindersEnabled: json['deadline_reminders_enabled'],
      quietHoursEnabled: json['quiet_hours_enabled'],
      quietHoursStart: json['quiet_hours_start'],
      quietHoursEnd: json['quiet_hours_end'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications_enabled': notificationsEnabled,
      'new_content_enabled': newContentEnabled,
      'quiz_enabled': quizEnabled,
      'deadline_reminders_enabled': deadlineRemindersEnabled,
      'quiet_hours_enabled': quietHoursEnabled,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
    };
  }

  NotificationPreferenceModel copyWith({
    bool? notificationsEnabled,
    bool? newContentEnabled,
    bool? quizEnabled,
    bool? deadlineRemindersEnabled,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
  }) {
    return NotificationPreferenceModel(
      id: id,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      newContentEnabled: newContentEnabled ?? this.newContentEnabled,
      quizEnabled: quizEnabled ?? this.quizEnabled,
      deadlineRemindersEnabled: deadlineRemindersEnabled ?? this.deadlineRemindersEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}