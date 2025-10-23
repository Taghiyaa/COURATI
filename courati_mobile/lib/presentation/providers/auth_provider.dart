// 📁 lib/presentation/providers/auth_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/user_model.dart';
import '../../data/models/auth_response_model.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _error;

  // Getters
  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  // Initialize the auth provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _isLoggedIn = await StorageService.isLoggedIn();

      if (_isLoggedIn) {
        await _loadUserProfile();
        
        try {
          await NotificationService.initialize();
          if (kDebugMode) {
            print('✅ Firebase initialisé (utilisateur déjà connecté)');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Erreur init Firebase: $e');
          }
        }
      }

      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('AuthProvider initialization error: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final userData = await StorageService.getUserData();
      if (userData != null) {
        final parsedData = jsonDecode(userData);
        _user = UserModel.fromJson(parsedData['user']);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load user profile: $e');
      }
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await ApiService.login(
        username: username,
        password: password,
      );

      await StorageService.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
      );

      final userData = {
        'user': response.user.toJson(),
        'student_profile': response.studentProfile?.toJson(),
      };
      await StorageService.saveUserData(jsonEncode(userData));

      _user = response.user;
      _isLoggedIn = true;

      try {
        await NotificationService.initialize();
        if (kDebugMode) {
          print('✅ Token FCM enregistré après login');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur enregistrement token FCM: $e');
        }
      }

      if (kDebugMode) {
        print('User logged in successfully');
      }

      return true;
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      if (kDebugMode) {
        print('Login failed: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? firstName,
    String? lastName,
    required int levelId,     // ✅ CORRIGÉ : int au lieu de String
    required int majorId,     // ✅ CORRIGÉ : int au lieu de String
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await ApiService.register(
        username: username,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        levelId: levelId,       // ✅ CORRIGÉ
        majorId: majorId,       // ✅ CORRIGÉ
      );

      if (kDebugMode) {
        print('User registered successfully');
      }

      return true;
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
      if (kDebugMode) {
        print('Registration failed: $e');
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await NotificationService.deleteToken();
      await StorageService.logout();
      
      _user = null;
      _isLoggedIn = false;
      
      if (kDebugMode) {
        print('User logged out successfully');
      }
      
    } catch (e) {
      _error = 'Logout failed: ${e.toString()}';
      if (kDebugMode) {
        print('Logout failed: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile() async {
    final token = await StorageService.getAccessToken();
    if (token != null) {
      try {
        // Code pour mettre à jour le profil
      } catch (e) {
        await logout();
      }
    }
  }
}