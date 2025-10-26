// 📁 lib/presentation/screens/notifications/notification_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/models/subject_model.dart';
import '../../../services/storage_service.dart';
import '../../providers/notification_provider.dart';
import '../courses/subject_detail_screen.dart';
import '../quiz/quiz_list_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    await provider.fetchNotifications();
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: 'Tout marquer comme lu',
                  onPressed: () => _markAllAsRead(provider),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.notifications.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refreshNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return _NotificationItem(
                  notification: notification,
                  onTap: () => _handleNotificationTap(notification, provider),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous serez notifié des nouveaux contenus',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllAsRead(NotificationProvider provider) async {
    await provider.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Toutes les notifications marquées comme lues'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleNotificationTap(
    NotificationModel notification,
    NotificationProvider provider,
  ) async {
    if (!notification.read) {
      await provider.markAsRead(notification.id);
    }

    if (notification.data == null || !mounted) return;

    final type = notification.data!['type'];
    final accessToken = await StorageService.getAccessToken();
    
    if (accessToken == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur : Session expirée'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (type == 'new_document') {
      final subjectId = notification.data!['subject_id'];
      if (subjectId != null) {
        final subjectIdInt = int.tryParse(subjectId.toString());
        if (subjectIdInt != null && mounted) {
          final subject = SubjectModel(
            id: subjectIdInt,
            name: '',
            code: '',
            credits: 0,
            isFeatured: false,
            levelNames: const [],
            majorNames: const [],
            documentCount: 0,
            isFavorite: false,
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubjectDetailScreen(
                subject: subject,
                accessToken: accessToken,
              ),
            ),
          );
        }
      }
    } else if (type == 'new_quiz') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizListScreen(accessToken: accessToken),
        ),
      );
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getNotificationIcon(),
                  color: _getNotificationColor(),
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.read ? FontWeight.w500 : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!notification.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(notification.sentAt),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon() {
    switch (notification.notificationType) {
      case 'new_document':
        return Icons.description_outlined;
      case 'new_quiz':
        return Icons.quiz_outlined;
      case 'project_reminder':
        return Icons.notification_important_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor() {
    switch (notification.notificationType) {
        case 'new_document':
        return Colors.blue;
        case 'new_quiz':
        return Colors.orange; // ✅ CORRECTION : Colors.orange au lieu de Icons.orange
        case 'project_reminder':
        return Colors.red;
        default:
        return AppColors.primary;
    }
    }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}