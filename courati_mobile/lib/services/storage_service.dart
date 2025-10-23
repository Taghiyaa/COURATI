// 📁 lib/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'api_service.dart';

class StorageService {
  static late SharedPreferences _prefs;
  
  // ✨ NOUVEAU : Variables pour éviter les race conditions
  static bool _isRefreshing = false;
  static DateTime? _lastRefreshTime;

  // Clés de stockage
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';

  /// Initialiser le service de stockage (à appeler au démarrage de l'app)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    print('✅ StorageService initialisé');
  }

  /// Sauvegarder les tokens JWT
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _prefs.setString(_accessTokenKey, accessToken);
    await _prefs.setString(_refreshTokenKey, refreshToken);
    print('✅ Tokens sauvegardés');
    print('   Access: ${accessToken.substring(0, 20)}...');
  }

  /// Récupérer le token d'accès (sans vérification)
  static Future<String?> getAccessToken() async {
    final token = _prefs.getString(_accessTokenKey);
    if (token != null) {
      print('📊 Token récupéré: ${token.substring(0, 20)}...');
    } else {
      print('⚠️  Aucun token trouvé');
    }
    return token;
  }

  /// ✨ AMÉLIORÉ : Récupérer un token d'accès VALIDE (avec refresh automatique + protection race conditions)
  static Future<String?> getValidAccessToken() async {
    String? accessToken = await getAccessToken();
    
    if (accessToken == null || accessToken.isEmpty) {
      print('❌ Aucun access token disponible');
      return null;
    }
    
    // ✅ Vérifier si le token est expiré
    if (_isTokenExpired(accessToken)) {
      print('⏰ Token expiré, tentative de refresh...');
      
      // ✅ AMÉLIORATION 1 : Vérifier si un refresh est déjà en cours
      if (_isRefreshing) {
        print('⏳ Refresh déjà en cours, attente...');
        
        // Attendre un peu et réessayer (max 5 secondes)
        for (int i = 0; i < 10; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (!_isRefreshing) {
            // Le refresh est terminé, récupérer le nouveau token
            final newToken = await getAccessToken();
            if (newToken != null && !_isTokenExpired(newToken)) {
              print('✅ Token rafraîchi par un autre processus');
              return newToken;
            }
          }
        }
        
        print('⚠️  Timeout en attendant le refresh');
        return null;
      }
      
      // ✅ AMÉLIORATION 2 : Vérifier si on a déjà rafraîchi récemment (< 30 secondes)
      if (_lastRefreshTime != null) {
        final timeSinceRefresh = DateTime.now().difference(_lastRefreshTime!);
        if (timeSinceRefresh.inSeconds < 30) {
          print('⚠️  Refresh déjà effectué il y a ${timeSinceRefresh.inSeconds}s');
          // Récupérer le token actuel au cas où
          final currentToken = await getAccessToken();
          if (currentToken != null && !_isTokenExpired(currentToken)) {
            return currentToken;
          }
        }
      }
      
      // Marquer qu'un refresh est en cours
      _isRefreshing = true;
      
      try {
        final refreshToken = await getRefreshToken();
        
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final response = await ApiService.refreshToken(refreshToken);
          
          if (response['access'] != null) {
            final newAccessToken = response['access'] as String;
            
            // ✅ AMÉLIORATION 3 : Sauvegarder aussi le nouveau refresh token si fourni
            if (response['refresh'] != null) {
              await saveTokens(
                accessToken: newAccessToken,
                refreshToken: response['refresh'] as String,
              );
              print('✅ Token et refresh token mis à jour');
            } else {
              await updateAccessToken(newAccessToken);
              print('✅ Token mis à jour (refresh token inchangé)');
            }
            
            _lastRefreshTime = DateTime.now();
            print('✅ Token rafraîchi avec succès');
            
            return newAccessToken;
          } else {
            print('❌ Réponse refresh sans access token');
            await logout();
            return null;
          }
        } else {
          print('❌ Pas de refresh token disponible');
          await logout();
          return null;
        }
      } catch (e) {
        print('❌ Erreur refresh token: $e');
        // Token refresh expiré ou invalide
        await logout();
        return null;
      } finally {
        // ✅ AMÉLIORATION 4 : Toujours libérer le lock
        _isRefreshing = false;
      }
    }
    
    print('✅ Token encore valide');
    return accessToken;
  }

  /// ✨ AMÉLIORÉ : Vérifier si un token JWT est expiré ou expire bientôt
  static bool _isTokenExpired(String token) {
    try {
      // Décoder le payload du JWT (format: header.payload.signature)
      final parts = token.split('.');
      if (parts.length != 3) {
        print('⚠️  Format token invalide');
        return true;
      }
      
      // Décoder la partie payload (base64)
      final payload = parts[1];
      
      // Normaliser le base64 (ajouter padding si nécessaire)
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      
      final decoded = utf8.decode(base64.decode(normalized));
      final payloadMap = json.decode(decoded) as Map<String, dynamic>;
      
      if (payloadMap['exp'] == null) {
        print('⚠️  Token sans date d\'expiration');
        return false;
      }
      
      // Convertir le timestamp Unix en DateTime
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (payloadMap['exp'] as int) * 1000,
      );
      
      final now = DateTime.now();
      final difference = expiry.difference(now);
      
      print('⏱️  Token expire dans: ${difference.inMinutes} minutes');
      
      // ✅ AMÉLIORATION 5 : Augmenter la marge de sécurité à 10 minutes
      return difference.inMinutes < 10;
    } catch (e) {
      print('❌ Erreur décodage token: $e');
      return true;
    }
  }

  /// Récupérer le token de rafraîchissement
  static Future<String?> getRefreshToken() async {
    return _prefs.getString(_refreshTokenKey);
  }

  /// Sauvegarder les données utilisateur (JSON string)
  static Future<void> saveUserData(String userData) async {
    await _prefs.setString(_userDataKey, userData);
    print('✅ Données utilisateur sauvegardées');
    print('   Data: ${userData.substring(0, 50)}...');
  }

  /// Récupérer les données utilisateur
  static Future<String?> getUserData() async {
    final userData = _prefs.getString(_userDataKey);
    if (userData != null) {
      print('📊 UserData récupéré: ${userData.substring(0, 50)}...');
    } else {
      print('⚠️  Aucune donnée utilisateur trouvée');
    }
    return userData;
  }

  /// Vérifier si l'utilisateur est connecté
  static Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    final userData = await getUserData();
    
    final isValid = accessToken != null && 
                    accessToken.isNotEmpty && 
                    userData != null && 
                    userData.isNotEmpty;
    
    print('📊 isLoggedIn: $isValid');
    print('   - Token présent: ${accessToken != null && accessToken.isNotEmpty}');
    print('   - UserData présent: ${userData != null && userData.isNotEmpty}');
    
    return isValid;
  }

  /// ✨ AMÉLIORÉ : Déconnexion - Nettoyer tout le stockage + réinitialiser les variables
  static Future<void> logout() async {
    try {
      // Récupérer les tokens AVANT de les supprimer
      final accessToken = await getAccessToken();
      final refreshToken = await getRefreshToken();

      // Appeler l'API de logout si les deux tokens sont disponibles
      if (accessToken != null && accessToken.isNotEmpty &&
          refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final result = await ApiService.logout(accessToken, refreshToken);
          
          if (result['success'] == true) {
            print('✅ ${result['message']}');
            if (result['warning'] != null) {
              print('⚠️ ${result['warning']}');
            }
          }
        } catch (e) {
          print('⚠️ Erreur appel logout API (non bloquant): $e');
          // On continue quand même pour nettoyer local
        }
      } else {
        print('⚠️ Tokens manquants, nettoyage local uniquement');
      }

      // ✅ NETTOYER TOUT LE STOCKAGE dans tous les cas
      await _prefs.remove(_accessTokenKey);
      await _prefs.remove(_refreshTokenKey);
      await _prefs.remove(_userDataKey);
      
      // ✅ Réinitialiser les variables de refresh
      _isRefreshing = false;
      _lastRefreshTime = null;
      
      print('✅ Logout complet effectué - Tout le stockage nettoyé');
      
      // Vérifier que tout est bien supprimé
      final checkToken = await getAccessToken();
      final checkData = await getUserData();
      print('🔍 Vérification post-logout:');
      print('   - Token: ${checkToken ?? "null"}');
      print('   - UserData: ${checkData ?? "null"}');
      
    } catch (e) {
      print('❌ Erreur logout: $e');
      // En cas d'erreur, forcer le nettoyage complet
      await _prefs.clear();
      _isRefreshing = false;
      _lastRefreshTime = null;
      print('✅ Nettoyage forcé effectué');
    }
  }

  /// Afficher les informations de stockage (debug)
  static Future<void> printStorageInfo() async {
    print('📊 === STORAGE INFO ===');
    final token = await getAccessToken();
    final refreshToken = await getRefreshToken();
    final userData = await getUserData();
    final isLogged = await isLoggedIn();
    
    print('   Access Token: ${token != null ? "${token.substring(0, 20)}..." : "null"}');
    print('   Refresh Token: ${refreshToken != null ? "${refreshToken.substring(0, 20)}..." : "null"}');
    print('   User Data: ${userData != null ? "${userData.substring(0, 50)}..." : "null"}');
    print('   Is Logged In: $isLogged');
    print('   Is Refreshing: $_isRefreshing');
    print('   Last Refresh: ${_lastRefreshTime?.toString() ?? "jamais"}');
    print('📊 ==================');
  }

  /// Mettre à jour le token d'accès (après refresh)
  static Future<void> updateAccessToken(String newAccessToken) async {
    await _prefs.setString(_accessTokenKey, newAccessToken);
    print('✅ Token d\'accès mis à jour');
  }

  /// ✨ AMÉLIORÉ : Nettoyer complètement le stockage (mode debug)
  static Future<void> clearAll() async {
    await _prefs.clear();
    _isRefreshing = false;
    _lastRefreshTime = null;
    print('🧹 Stockage complètement nettoyé');
  }
  
  /// ✨ BONUS : Forcer le refresh du token (utile pour les tests)
  static Future<String?> forceRefreshToken() async {
    print('🔄 Force refresh du token...');
    
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      print('❌ Pas de refresh token disponible');
      return null;
    }
    
    _isRefreshing = true;
    
    try {
      final response = await ApiService.refreshToken(refreshToken);
      
      if (response['access'] != null) {
        final newAccessToken = response['access'] as String;
        
        if (response['refresh'] != null) {
          await saveTokens(
            accessToken: newAccessToken,
            refreshToken: response['refresh'] as String,
          );
        } else {
          await updateAccessToken(newAccessToken);
        }
        
        _lastRefreshTime = DateTime.now();
        print('✅ Force refresh réussi');
        
        return newAccessToken;
      }
      
      return null;
    } catch (e) {
      print('❌ Erreur force refresh: $e');
      return null;
    } finally {
      _isRefreshing = false;
    }
  }
  
  /// ✨ BONUS : Obtenir le temps restant avant expiration du token
  static Future<Duration?> getTokenTimeRemaining() async {
    final token = await getAccessToken();
    if (token == null) return null;
    
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      
      final payload = parts[1];
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      
      final decoded = utf8.decode(base64.decode(normalized));
      final payloadMap = json.decode(decoded) as Map<String, dynamic>;
      
      if (payloadMap['exp'] == null) return null;
      
      final expiry = DateTime.fromMillisecondsSinceEpoch(
        (payloadMap['exp'] as int) * 1000,
      );
      
      return expiry.difference(DateTime.now());
    } catch (e) {
      print('❌ Erreur calcul temps restant: $e');
      return null;
    }
  }
}