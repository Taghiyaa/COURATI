// 📁 lib/presentation/providers/notification_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/api_endpoints.dart';
import '../../data/models/notification_model.dart';
import '../../data/models/notification_preference_model.dart';
import '../../services/storage_service.dart';

class NotificationProvider with ChangeNotifier {
  NotificationPreferenceModel? _preferences;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  NotificationPreferenceModel? get preferences => _preferences;
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.read).length;

  // ========================================
  // RÉCUPÉRER LES PRÉFÉRENCES
  // ========================================
  Future<void> fetchPreferences() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = StorageService.getAccessToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiEndpoints.notificationPreferences),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _preferences = NotificationPreferenceModel.fromJson(data['preferences']);
      } else {
        _error = 'Erreur lors du chargement des préférences';
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Erreur fetchPreferences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========================================
  // METTRE À JOUR LES PRÉFÉRENCES
  // ========================================
  Future<bool> updatePreferences(NotificationPreferenceModel newPreferences) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final token = StorageService.getAccessToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse(ApiEndpoints.notificationPreferences),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newPreferences.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _preferences = NotificationPreferenceModel.fromJson(data['preferences']);
        notifyListeners();
        return true;
      } else {
        _error = 'Erreur lors de la mise à jour';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Erreur updatePreferences: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========================================
  // RÉCUPÉRER L'HISTORIQUE DES NOTIFICATIONS
  // ========================================
  Future<void> fetchNotifications() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // ✅ DOIT ÊTRE await
      final token = await StorageService.getValidAccessToken();
      
      if (token == null) {
        print('❌ Pas de token JWT pour récupérer les notifications');
        return;
      }

      print('📤 Récupération historique avec token: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse(ApiEndpoints.notificationHistory),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📥 Réponse history: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> notifList = data['notifications'];
        _notifications = notifList
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        print('✅ ${_notifications.length} notifications chargées');
      } else {
        _error = 'Erreur ${response.statusCode}: ${response.body}';
        print('❌ Erreur: $_error');
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Erreur fetchNotifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========================================
  // MARQUER UNE NOTIFICATION COMME LUE
  // ========================================
  Future<void> markAsRead(int notificationId) async {
    try {
      final token = StorageService.getAccessToken();
      if (token == null) return;

      final response = await http.patch(
        Uri.parse(ApiEndpoints.markNotificationAsRead(notificationId)),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Mettre à jour localement
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            notificationType: _notifications[index].notificationType,
            notificationTypeDisplay: _notifications[index].notificationTypeDisplay,
            title: _notifications[index].title,
            message: _notifications[index].message,
            data: _notifications[index].data,
            sentAt: _notifications[index].sentAt,
            read: true,
            clicked: _notifications[index].clicked,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Erreur markAsRead: $e');
    }
  }

  // ========================================
  // MARQUER TOUTES LES NOTIFICATIONS COMME LUES
  // ========================================
  Future<void> markAllAsRead() async {
    try {
      final token = StorageService.getAccessToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse(ApiEndpoints.markAllNotificationsAsRead),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Mettre à jour localement
        _notifications = _notifications.map((n) => NotificationModel(
          id: n.id,
          notificationType: n.notificationType,
          notificationTypeDisplay: n.notificationTypeDisplay,
          title: n.title,
          message: n.message,
          data: n.data,
          sentAt: n.sentAt,
          read: true,
          clicked: n.clicked,
        )).toList();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Erreur markAllAsRead: $e');
    }
  }

  // ========================================
  // TOGGLE PRÉFÉRENCE (helper)
  // ========================================
  Future<bool> toggleNotifications(bool value) async {
    if (_preferences == null) return false;
    return updatePreferences(_preferences!.copyWith(notificationsEnabled: value));
  }

  Future<bool> toggleNewContent(bool value) async {
    if (_preferences == null) return false;
    return updatePreferences(_preferences!.copyWith(newContentEnabled: value));
  }

  Future<bool> toggleQuiz(bool value) async {
    if (_preferences == null) return false;
    return updatePreferences(_preferences!.copyWith(quizEnabled: value));
  }

  Future<bool> toggleDeadlineReminders(bool value) async {
    if (_preferences == null) return false;
    return updatePreferences(_preferences!.copyWith(deadlineRemindersEnabled: value));
  }
}