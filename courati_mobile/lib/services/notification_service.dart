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
  static String? _currentToken;

  // Callback pour notifier quand une notification arrive
  static Function()? onNotificationReceived;

  // ========================================
  // INITIALISATION (une seule fois)
  // ========================================
  static Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('ℹ️  Service déjà initialisé');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔄 Initialisation du service de notifications...');
      }

      // 1. Initialiser Firebase
      await Firebase.initializeApp();

      // 2. Demander les permissions
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('❌ Permission notifications refusée');
        }
        return;
      }

      if (kDebugMode) {
        print('✅ Permission notifications accordée');
      }

      // 3. Configurer les notifications locales
      await _setupLocalNotifications();

      // 4. Écouter les notifications
      _setupMessageListeners();

      // 5. Handler pour notifications en arrière-plan
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 6. Récupérer le token FCM
      _currentToken = await _messaging.getToken();
      
      if (kDebugMode) {
        print('✅ Service de notifications initialisé');
        print('📱 Token FCM: ${_currentToken ?? "Non disponible"}');
      }

      _isInitialized = true;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur initialisation notifications: $e');
      }
    }
  }

  // ========================================
  // ENREGISTRER LE TOKEN AU BACKEND (peut être appelé plusieurs fois)
  // ========================================
  static Future<bool> ensureTokenRegistered() async {
    try {
      // S'assurer que le service est initialisé
      if (!_isInitialized) {
        await initialize();
      }

      // Récupérer le token
      String? token = _currentToken ?? await _messaging.getToken();
      
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Aucun token FCM disponible');
        }
        return false;
      }

      // Attendre que le token JWT soit disponible
      String? accessToken = await _waitForAccessToken();
      
      if (accessToken == null) {
        if (kDebugMode) {
          print('⚠️ Token JWT non disponible, enregistrement FCM impossible');
        }
        return false;
      }

      // Enregistrer le token au backend
      return await _sendTokenToBackend(token, accessToken);
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur ensureTokenRegistered: $e');
      }
      return false;
    }
  }

  // ========================================
  // FORCER LE RAFRAÎCHISSEMENT DU TOKEN
  // ========================================
  static Future<bool> refreshToken() async {
    try {
      if (kDebugMode) {
        print('🔄 Rafraîchissement du token FCM...');
      }

      // Supprimer l'ancien token Firebase (optionnel)
      await _messaging.deleteToken();
      
      // Récupérer un nouveau token
      _currentToken = await _messaging.getToken();
      
      if (kDebugMode) {
        print('📱 Nouveau token: ${_currentToken ?? "Non disponible"}');
      }

      // Enregistrer le nouveau token
      return await ensureTokenRegistered();
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur refreshToken: $e');
      }
      return false;
    }
  }

  // ========================================
  // ATTENDRE QUE LE TOKEN JWT SOIT DISPONIBLE
  // ========================================
  static Future<String?> _waitForAccessToken() async {
    String? accessToken;
    int retries = 0;
    const maxRetries = 10;
    
    while (accessToken == null && retries < maxRetries) {
      accessToken = await StorageService.getValidAccessToken();
      
      if (accessToken == null) {
        if (kDebugMode && retries == 0) {
          print('⏳ Attente du token JWT...');
        }
        await Future.delayed(const Duration(milliseconds: 500));
        retries++;
      }
    }
    
    if (accessToken == null && kDebugMode) {
      print('❌ Token JWT toujours indisponible après ${maxRetries} tentatives');
    }
    
    return accessToken;
  }

  // ========================================
  // ENVOYER LE TOKEN AU BACKEND
  // ========================================
  static Future<bool> _sendTokenToBackend(String token, String accessToken) async {
    try {
      final payload = {
        'token': token,
        'device_type': defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'ios',
      };
      
      if (kDebugMode) {
        print('📤 Envoi token FCM au backend...');
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
        print('📥 Réponse: ${response.statusCode}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (kDebugMode) {
          final body = jsonDecode(response.body);
          print('✅ ${body['message'] ?? 'Token FCM enregistré'}');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ Erreur: ${response.statusCode}');
          print('   ${response.body}');
        }
        return false;
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur envoi token: $e');
      }
      return false;
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
  // ÉCOUTER LES NOTIFICATIONS
  // ========================================
  static void _setupMessageListeners() {
    // Notification reçue quand l'app est en FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📩 Notification foreground: ${message.notification?.title}');
      }
      _showLocalNotification(message);
      onNotificationReceived?.call();
    });

    // Notification cliquée quand l'app est en BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('🔔 Notification cliquée (background): ${message.notification?.title}');
      }
      _handleNotificationClick(message);
      onNotificationReceived?.call();
    });

    // Notification cliquée quand l'app est TERMINATED
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        if (kDebugMode) {
          print('🔔 Notification cliquée (terminated): ${message.notification?.title}');
        }
        _handleNotificationClick(message);
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
      print('🎯 Type: $type');
      print('📦 Data: $data');
    }

    // TODO: Navigation selon le type
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
      onNotificationReceived?.call();
    }
  }

  // ========================================
  // SUPPRIMER LE TOKEN (DÉCONNEXION)
  // ========================================
  static Future<void> deleteToken() async {
    try {
      String? token = _currentToken ?? await _messaging.getToken();
      
      if (token != null) {
        final accessToken = await StorageService.getAccessToken();
        
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
      _currentToken = null;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erreur suppression token: $e');
      }
    }
  }

  // ========================================
  // RÉINITIALISER (pour tests uniquement)
  // ========================================
  static void reset() {
    _isInitialized = false;
    _currentToken = null;
    onNotificationReceived = null;
  }
}