// 📁 lib/data/models/notifications/notification_model.dart
class NotificationModel {
  final int id;
  final String notificationType;
  final String notificationTypeDisplay;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime sentAt;
  final bool read;
  final bool clicked;

  NotificationModel({
    required this.id,
    required this.notificationType,
    required this.notificationTypeDisplay,
    required this.title,
    required this.message,
    this.data,
    required this.sentAt,
    required this.read,
    required this.clicked,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      notificationType: json['notification_type'],
      notificationTypeDisplay: json['notification_type_display'],
      title: json['title'],
      message: json['message'],
      data: json['data'],
      sentAt: DateTime.parse(json['sent_at']),
      read: json['read'],
      clicked: json['clicked'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'notification_type': notificationType,
      'notification_type_display': notificationTypeDisplay,
      'title': title,
      'message': message,
      'data': data,
      'sent_at': sentAt.toIso8601String(),
      'read': read,
      'clicked': clicked,
    };
  }
}