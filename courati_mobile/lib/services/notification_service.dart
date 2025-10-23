// 📁 lib/services/notification_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_endpoints.dart';
import 'storage_service.dart';

// ========================================
// HANDLER POUR NOTIFICATIONS EN ARRIÈRE-PLAN
// ========================================
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  if (kDebugMode) {
    print('📩 Background notification: ${message.notification?.title}');
  }
}

// ========================================
// NOTIFICATION SERVICE
// ========================================
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // Callback pour notifier quand une notification arrive
  static Function()? onNotificationReceived;

  // ========================================
  // INITIALISATION
  // ========================================
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialiser Firebase
      await Firebase.initializeApp();

      // 2. Demander les permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✅ Permission notifications accordée');
        }

        // 3. Configurer les notifications locales
        await _setupLocalNotifications();

        // 4. Récupérer et enregistrer le token FCM
        await _registerFCMToken();

        // 5. Écouter les notifications
        _setupMessageListeners();

        // 6. Handler pour notifications en arrière-plan
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        _isInitialized = true;
      } else {
        if (kDebugMode) {
          print('❌ Permission notifications refusée');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation notifications: $e');
      }
    }
  }

  // ========================================
  // CONFIGURATION NOTIFICATIONS LOCALES
  // ========================================
  static Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // ========================================
// ENREGISTRER TOKEN FCM AU BACKEND
// ========================================
static Future<void> _registerFCMToken() async {
  try {
    String? token = await _messaging.getToken();

    if (token != null && token.isNotEmpty) {
      if (kDebugMode) {
        print('📱 Token FCM: $token');
      }

      final accessToken = await StorageService.getValidAccessToken();
      
      if (accessToken != null && accessToken.isNotEmpty) {
        // ✅ AJOUT : Log du payload
        final payload = {
          'token': token,
          'device_type': defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'ios',
        };
        
        if (kDebugMode) {
          print('📤 Envoi payload FCM: $payload');
        }

        final response = await http.post(
          Uri.parse(ApiEndpoints.fcmToken),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        if (kDebugMode) {
          print('📥 Réponse FCM: ${response.statusCode}');
          print('📥 Body: ${response.body}');
        }

        if (response.statusCode == 201) {
          if (kDebugMode) {
            print('✅ Token FCM enregistré au backend');
          }
        } else {
          if (kDebugMode) {
            print('❌ Erreur enregistrement token: ${response.statusCode}');
            print('   Body: ${response.body}');
          }
        }
      } else {
        if (kDebugMode) {
          print('⏭️ JWT invalide ou expiré');
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Erreur _registerFCMToken: $e');
    }
  }
}

  // ========================================
  // ÉCOUTER LES NOTIFICATIONS
  // ========================================
  static void _setupMessageListeners() {
    // Notification reçue quand l'app est en FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📩 Notification foreground: ${message.notification?.title}');
      }
      _showLocalNotification(message);
      
      //  Notifier le provider
      onNotificationReceived?.call();
    });

    // Notification cliquée quand l'app est en BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 Notification cliquée (background): ${message.notification?.title}');
      }
      _handleNotificationClick(message);
      
      // Notifier le provider
      onNotificationReceived?.call();
    });

    // Notification cliquée quand l'app est TERMINATED
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('🔔 Notification cliquée (terminated): ${message.notification?.title}');
        }
        _handleNotificationClick(message);
        
        //  Notifier le provider
        onNotificationReceived?.call();
      }
    });
  }

  // ========================================
  // AFFICHER NOTIFICATION LOCALE (FOREGROUND)
  // ========================================
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'courati_notifications',
      'Courati Notifications',
      channelDescription: 'Notifications pour les cours, quiz et projets',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Courati',
      message.notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // ========================================
  // GÉRER LE CLIC SUR UNE NOTIFICATION
  // ========================================
  static void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    if (kDebugMode) {
      print('🎯 Type de notification: $type');
      print('📦 Data: $data');
    }

    // TODO: Navigation vers la bonne page selon le type
    // Exemples :
    // - new_document → Aller vers la page du document
    // - new_quiz → Aller vers la page du quiz
    // - project_reminder → Aller vers la page du projet

    // Pour l'instant, on log juste les infos
    // Vous pourrez implémenter la navigation plus tard
  }

  // ========================================
  // NOTIFICATION CLIQUÉE (depuis local notifications)
  // ========================================
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!);
      if (kDebugMode) {
        print('🎯 Notification locale cliquée: $data');
      }
      // TODO: Navigation
      //  Notifier le provider
      onNotificationReceived?.call();
    }
  }

  // ========================================
  // SUPPRIMER LE TOKEN (DÉCONNEXION)
  // ========================================
  static Future<void> deleteToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        final accessToken = StorageService.getAccessToken();
        if (accessToken != null) {
          await http.delete(
            Uri.parse(ApiEndpoints.deleteFcmToken(token)),
            headers: {
              'Authorization': 'Bearer $accessToken',
            },
          );
          if (kDebugMode) {
            print('🗑️ Token FCM supprimé du backend');
          }
        }
      }
      await _messaging.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression token: $e');
      }
    }
  }
}