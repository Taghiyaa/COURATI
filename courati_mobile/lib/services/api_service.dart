import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_endpoints.dart';
import '../data/models/auth_response_model.dart';
import '../data/models/level_model.dart';
import '../data/models/major_model.dart';
import 'auth_interceptor.dart';
import '../data/models/registration_choices_model.dart';

class ApiService {
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> _authHeaders(String token) {
    return {
      ..._headers,
      'Authorization': 'Bearer $token',
    };
  }

  // ✅ NOUVELLE MÉTHODE : Wrapper pour gérer les 401 automatiquement
  static Future<http.Response> _makeAuthenticatedRequest({
    required Future<http.Response> Function() request,
  }) async {
    try {
      final response = await request();
      
      // ✅ Détecter les 401 Unauthorized
      if (response.statusCode == 401) {
        print('❌ 401 Unauthorized détecté - Session expirée');
        await AuthInterceptor.handle401Error();
        
        // Retourner une réponse vide pour éviter le crash
        return http.Response(
          jsonEncode({'error': 'Session expirée', 'success': false}), 
          401
        );
      }
      
      return response;
    } catch (e) {
      print('❌ Erreur requête authentifiée: $e');
      rethrow;
    }
  }

  // ========================================
  // NOUVELLES MÉTHODES POUR LES CHOIX DYNAMIQUES
  // ========================================

  /// Récupérer tous les choix d'inscription (niveaux + filières)
  static Future<RegistrationChoicesModel> getRegistrationChoices() async {
    print('Récupération des choix d\'inscription');
    
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getRegistrationChoices),
        headers: _headers,
      );

      print('Réponse registration choices: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RegistrationChoicesModel.fromJson(data);
      } else {
        throw Exception('Erreur récupération choix: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception registration choices: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer uniquement les niveaux
  static Future<List<LevelModel>> getLevels() async {
    print('Récupération des niveaux');
    
    try {
      final response = await http.get(
        Uri.parse(ApiEndpoints.getLevels),
        headers: _headers,
      );

      print('Réponse levels: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['levels'] as List)
            .map((level) => LevelModel.fromJson(level))
            .toList();
      } else {
        throw Exception('Erreur récupération niveaux: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception levels: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer uniquement les filières (avec filtre département optionnel)
  static Future<List<MajorModel>> getMajors({String? department}) async {
    print('Récupération des filières${department != null ? ' pour $department' : ''}');
    
    try {
      String url = ApiEndpoints.getMajors;
      if (department != null && department.isNotEmpty) {
        url += '?department=$department';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      print('Réponse majors: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['majors'] as List)
            .map((major) => MajorModel.fromJson(major))
            .toList();
      } else {
        throw Exception('Erreur récupération filières: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception majors: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  // ========================================
  // MÉTHODES EXISTANTES MODIFIÉES
  // ========================================

  /// Connexion utilisateur (supporte username, email ou téléphone)
  static Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    print('Tentative de connexion pour: $username');
    
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.login),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      print('Réponse login: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuthResponseModel.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur de connexion: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception login: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Inscription utilisateur - MODIFIÉ pour utiliser les IDs des niveaux/filières
  static Future<Map<String, dynamic>> register({
  required String username,
  required String email,
  required String password,
  required String phoneNumber,
  required int levelId,      // CHANGÉ: maintenant un ID
  required int majorId,      // CHANGÉ: maintenant un ID
  String? firstName,
  String? lastName,
  }) async {
    print('Inscription pour: $username');
    
    try {
      final body = {
        'username': username,
        'email': email,
        'password': password,
        'phone_number': phoneNumber,
        'level': levelId,        // CHANGÉ: envoyer l'ID
        'major': majorId,        // CHANGÉ: envoyer l'ID
      };

      if (firstName != null && firstName.isNotEmpty) {
        body['first_name'] = firstName;
      }
      if (lastName != null && lastName.isNotEmpty) {
        body['last_name'] = lastName;
      }

      final response = await http.post(
        Uri.parse(ApiEndpoints.register),
        headers: _headers,
        body: jsonEncode(body),
      );

      print('Réponse register: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur inscription: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception register: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Vérification de l'OTP envoyé par email lors de l'inscription
  static Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    print('Vérification OTP d\'inscription pour: $email');
    
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.verifyOtp),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'otp': otp,
        }),
      );

      print('Réponse verify OTP: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Code OTP invalide');
      }
    } catch (e) {
      print('Exception verify OTP: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Demande de réinitialisation de mot de passe - envoie un OTP par email
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    print('Demande de réinitialisation pour: $email');
    
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.passwordResetRequest),
        headers: _headers,
        body: jsonEncode({
          'email': email,
        }),
      );

      print('Réponse password reset request: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur demande réinitialisation: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception password reset request: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Confirmation de réinitialisation avec OTP email
  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    print('Confirmation réinitialisation pour: $email');
    
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.passwordResetConfirm),
        headers: _headers,
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'new_password': newPassword,
          'confirm_password': newPassword,
        }),
      );

      print('Réponse password reset confirm: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur confirmation réinitialisation: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception password reset confirm: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupération du profil utilisateur
static Future<Map<String, dynamic>> getUserProfile(String token) async {
  print('📊 Récupération du profil utilisateur');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'user': null};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse(ApiEndpoints.profile),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse user profile: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'user': null};
    } else {
      throw Exception('Erreur récupération profil: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception user profile: $e');
    throw Exception('Erreur réseau: $e');
  }
}

  /// Mise à jour du profil utilisateur
static Future<Map<String, dynamic>> updateUserProfile({
  required String token,
  Map<String, dynamic>? updates,
}) async {
  print('✏️ Mise à jour du profil utilisateur');
  print('📄 Données à envoyer: $updates');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.put(
        Uri.parse(ApiEndpoints.profile),
        headers: _authHeaders(validToken),
        body: jsonEncode(updates ?? {}),
      ),
    );

    print('📱 Réponse update profile: ${response.statusCode}');
    print('📄 Réponse body: ${response.body}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      print('❌ Erreur HTTP: ${response.statusCode}');
      print('📄 Body erreur: ${response.body}');
      
      try {
        final errorData = jsonDecode(response.body);
        String errorMessage = '';
        
        if (errorData.containsKey('details') && errorData['details'] is Map) {
          final details = errorData['details'] as Map<String, dynamic>;
          details.forEach((field, errors) {
            if (errors is List) {
              errorMessage += '$field: ${errors.join(', ')}\n';
            }
          });
        } else {
          errorMessage = errorData['error'] ?? 
                        errorData['detail'] ?? 
                        'Erreur mise à jour profil: ${response.statusCode}';
        }
        
        throw Exception(errorMessage.trim());
      } catch (jsonError) {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    }
  } catch (e) {
    print('❌ Exception update profile: $e');
    if (e.toString().contains('FormatException')) {
      throw Exception('Erreur de communication avec le serveur');
    }
    throw Exception('Erreur réseau: $e');
  }
}
  /// Changement de mot de passe (utilisateur connecté)
static Future<Map<String, dynamic>> changePassword({
  required String token,
  required String currentPassword,
  required String newPassword,
}) async {
  print('🔒 Changement de mot de passe');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.changePassword),
        headers: _authHeaders(validToken),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': newPassword,
        }),
      ),
    );

    print('📱 Réponse change password: ${response.statusCode}');
    print('📄 Réponse body: ${response.body}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      print('❌ Erreur HTTP: ${response.statusCode}');
      print('📄 Body erreur: ${response.body}');
      
      try {
        final errorData = jsonDecode(response.body);
        String errorMessage = '';
        
        if (errorData.containsKey('error')) {
          errorMessage = errorData['error'];
        } else if (errorData.containsKey('current_password')) {
          errorMessage = 'Mot de passe actuel incorrect';
        } else if (errorData.containsKey('new_password')) {
          errorMessage = errorData['new_password'].join(', ');
        } else {
          errorMessage = 'Erreur lors du changement de mot de passe';
        }
        
        throw Exception(errorMessage);
      } catch (jsonError) {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    }
  } catch (e) {
    print('❌ Exception change password: $e');
    if (e.toString().contains('FormatException')) {
      throw Exception('Erreur de communication avec le serveur');
    }
    throw Exception('Erreur réseau: $e');
  }
}

  /// Rafraîchissement du token JWT
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    print('Rafraîchissement du token');
    
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.tokenRefresh),
        headers: _headers,
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      print('Réponse token refresh: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur rafraîchissement token: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception token refresh: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Déconnexion avec blacklist du refresh token
  static Future<Map<String, dynamic>> logout(String accessToken, String refreshToken) async {
    print('🚪 Déconnexion utilisateur');
    
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.logout),
        headers: _authHeaders(accessToken),
        body: jsonEncode({
          'refresh': refreshToken,  // ✅ AJOUTÉ : Envoyer le refresh token
        }),
      );

      print('📱 Réponse logout: ${response.statusCode}');
      print('📄 Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Logout API réussi');
        return {
          'success': true,
          'message': data['message'] ?? 'Déconnexion réussie',
        };
      } else {
        print('⚠️ Logout API échoué: ${response.statusCode}');
        // Retourner succès quand même car on va nettoyer localement
        return {
          'success': true,
          'message': 'Déconnexion locale effectuée',
          'warning': 'Erreur serveur: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Exception logout: $e');
      // Retourner succès pour permettre le nettoyage local
      return {
        'success': true,
        'message': 'Déconnexion locale effectuée',
        'warning': 'Erreur réseau: $e',
      };
    }
  }

  // ========================================
  // MÉTHODES COURSES
  // ========================================

  /// Récupérer les matières de l'étudiant connecté
  static Future<Map<String, dynamic>> getMySubjects(String token, {bool? featuredOnly}) async {
    print('Récupération des matières étudiantes');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'subjects': []};
      }
      
      String url = ApiEndpoints.mySubjects;
      if (featuredOnly != null) {
        url += '?featured=${featuredOnly.toString()}';
      }

      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.get(
          Uri.parse(url),
          headers: _authHeaders(validToken),
        ),
      );

      print('Réponse my subjects: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return {'success': false, 'subjects': []};
      } else {
        throw Exception('Erreur récupération matières: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception my subjects: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Récupérer les documents d'une matière
static Future<Map<String, dynamic>> getSubjectDocuments(String token, int subjectId, {String? type}) async {
  print('📄 Récupération documents matière $subjectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'documents': []};
    }
    
    String url = ApiEndpoints.subjectDocuments(subjectId);
    if (type != null) {
      url += '?type=$type';
    }

    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse(url),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse subject documents: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'documents': []};
    } else {
      throw Exception('Erreur récupération documents: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception subject documents: $e');
    throw Exception('Erreur réseau: $e');
  }
}

  /// Page d'accueil personnalisée
  static Future<Map<String, dynamic>> getPersonalizedHome(String token) async {
    print('Récupération page d\'accueil personnalisée');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'data': null};
      }
      
      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.get(
          Uri.parse(ApiEndpoints.personalizedHome),
          headers: _authHeaders(validToken),
        ),
      );

      print('Réponse personalized home: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        return {'success': false, 'data': null};
      } else {
        throw Exception('Erreur récupération accueil: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception personalized home: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Télécharger un document
static Future<Map<String, dynamic>?> downloadDocument(
  String accessToken, 
  int documentId
) async {
  try {
    print('📥 Téléchargement document: $documentId');
    
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/api/courses/documents/$documentId/download/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse download: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      return {
        'success': false,
        'message': 'Erreur ${response.statusCode}',
      };
    }
  } catch (e) {
    print('❌ Exception download: $e');
    return {
      'success': false,
      'message': e.toString(),
    };
  }
}

 /// Méthode pour obtenir l'URL de visualisation
static Future<Map<String, dynamic>?> getDocumentViewUrl(
  String accessToken, 
  int documentId
) async {
  try {
    print('🔗 Récupération URL document: $documentId');
    
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/api/courses/documents/$documentId/view/'),
        headers: {
          'Authorization': 'Bearer $validToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    print('📱 Réponse get view URL: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ URL récupérée: ${data['view_url']}');
      return data;
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      print('❌ Erreur get view URL: ${response.statusCode} - ${response.body}');
      return {
        'success': false,
        'message': 'Erreur ${response.statusCode}',
      };
    }
  } catch (e) {
    print('❌ Exception get view URL: $e');
    return {
      'success': false,
      'message': e.toString(),
    };
  }
}

  // ========================================
  // MÉTHODES FAVORIS
  // ========================================

  /// Toggle favori général (méthode principale)
  static Future<Map<String, dynamic>> toggleFavorite(String token, String type, int id) async {
    print('🔄 Toggle favori $type $id');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'message': 'Token invalide'};
      }
      
      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.post(
          Uri.parse(ApiEndpoints.favorites),
          headers: _authHeaders(validToken),
          body: jsonEncode({
            'type': type, // 'SUBJECT' ou 'DOCUMENT'
            'id': id,
          }),
        ),
      );

      print('📱 Réponse toggle favorite: ${response.statusCode}');
      print('📄 Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Token invalide'};
      } else {
        String errorMessage = 'Erreur gestion favori: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (e) {
          // Si le JSON de l'erreur ne peut pas être parsé, garder le message par défaut
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Exception toggle favorite: $e');
      
      if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Problème de connexion réseau. Vérifiez votre connexion internet.');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Erreur de format de réponse du serveur.');
      } else {
        throw Exception('Erreur réseau: $e');
      }
    }
  }

  /// Récupérer tous les favoris
  static Future<Map<String, dynamic>> getFavorites(String token) async {
    print('📥 Récupération favoris');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'favorites': [], 'total_favorites': 0};
      }
      
      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.get(
          Uri.parse(ApiEndpoints.favorites),
          headers: _authHeaders(validToken),
        ),
      );

      print('📱 Réponse get favorites: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Favoris récupérés: ${data['total_favorites'] ?? 0} favoris');
        return data;
      } else if (response.statusCode == 401) {
        return {'success': false, 'favorites': [], 'total_favorites': 0};
      } else {
        String errorMessage = 'Erreur récupération favoris: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['error'] ?? errorMessage;
        } catch (e) {
          // Garder le message par défaut
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Exception get favorites: $e');
      
      if (e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        throw Exception('Problème de connexion réseau. Vérifiez votre connexion internet.');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('Erreur de format de réponse du serveur.');
      } else {
        throw Exception('Erreur réseau: $e');
      }
    }
  }

  /// Toggle favori pour un document spécifique
  static Future<Map<String, dynamic>> toggleDocumentFavorite(String token, int documentId) async {
    print('📄 Toggle favori document $documentId');
    return await toggleFavorite(token, 'DOCUMENT', documentId);
  }



  // ========================================
  // MÉTHODES POUR L'HISTORIQUE
  // ========================================

  /// Récupère l'historique des activités de l'utilisateur
static Future<Map<String, dynamic>> getHistory(String token) async {
  print('📜 Récupération historique');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'history': []};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.coursesBase}/history/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse history: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'history': []};
    } else {
      throw Exception('Erreur récupération historique: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception history: $e');
    throw Exception('Erreur réseau: $e');
  }
}

 

  // Ajouter ces méthodes dans votre ApiService existant

  // ========================================
  // MÉTHODES POUR L'HISTORIQUE DE CONSULTATION
  // ========================================

  /// Récupère l'historique des consultations de documents
  static Future<Map<String, dynamic>> getConsultationHistory(String token, {
    int? days,
    int? limit,
  }) async {
    print('📖 Récupération historique consultations');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'consultations': []};
      }
      
      String url = '${ApiEndpoints.coursesBase}/consultation-history/';
      
      List<String> queryParams = [];
      if (days != null) queryParams.add('days=$days');
      if (limit != null) queryParams.add('limit=$limit');
      
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.get(
          Uri.parse(url),
          headers: _authHeaders(validToken),
        ),
      );

      print('📱 Réponse consultation history: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        return {'success': false, 'consultations': []};
      } else {
        throw Exception('Erreur récupération historique consultations: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception consultation history: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Efface l'historique des consultations
  static Future<Map<String, dynamic>> clearConsultationHistory(String token) async {
    print('🗑 Effacement historique consultations');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'message': 'Token invalide'};
      }
      
      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.delete(
          Uri.parse('${ApiEndpoints.coursesBase}/consultation-history/'),
          headers: _authHeaders(validToken),
        ),
      );

      print('📱 Réponse clear history: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Token invalide'};
      } else {
        throw Exception('Erreur effacement historique: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception clear history: $e');
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Marque un document comme consulté
  static Future<Map<String, dynamic>?> markDocumentAsViewed(String token, int documentId) async {
    print('👁 Marquage consultation document $documentId');
    
    try {
      // ✅ Vérifier le token AVANT
      final validToken = await AuthInterceptor.getValidTokenOrRedirect();
      if (validToken == null) {
        return {'success': false, 'message': 'Token invalide'};
      }
      
      // ✅ Utiliser le wrapper
      final response = await _makeAuthenticatedRequest(
        request: () => http.post(
          Uri.parse('${ApiEndpoints.coursesBase}/documents/$documentId/view/'),
          headers: _authHeaders(validToken),
          body: jsonEncode({
            'timestamp': DateTime.now().toIso8601String(),
            'action': 'view'
          }),
        ),
      );

      print('📱 Réponse mark viewed: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Document marqué comme consulté',
        };
      } else if (response.statusCode == 401) {
        return {'success': false, 'message': 'Token invalide'};
      } else {
        return {'success': false, 'message': 'Erreur de marquage'};
      }
    } catch (e) {
      print('❌ Exception mark viewed: $e');
      return {'success': false, 'message': 'Erreur réseau'};
    }
  }

// ========================================
// MÉTHODES QUIZ
// ========================================

/// Récupérer la liste de tous les quiz disponibles pour l'étudiant
static Future<Map<String, dynamic>> getMyQuizzes(String token) async {
  print('📝 Récupération de mes quiz');
  
  try {
    // ✅ Vérifier le token AVANT la requête
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'quizzes': []};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.coursesBase}/quizzes/my_quizzes/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse my quizzes: ${response.statusCode}');
    print('📄 Body brut: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Data décodé: $data');
      return data;
    } else if (response.statusCode == 401) {
      // Déjà géré par le wrapper
      return {'success': false, 'quizzes': []};
    } else {
      throw Exception('Erreur récupération quiz: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception my quizzes: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Récupérer les détails d'un quiz spécifique
static Future<Map<String, dynamic>> getQuizDetail(String token, int quizId) async {
  print('📝 Récupération détails quiz $quizId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'quiz': null};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.coursesBase}/quizzes/$quizId/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse quiz detail: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'quiz': null};
    } else {
      throw Exception('Erreur récupération détails quiz: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception quiz detail: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Démarrer une nouvelle tentative de quiz
static Future<Map<String, dynamic>> startQuiz(String token, int quizId) async {
  print('🚀 Démarrage quiz $quizId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse('${ApiEndpoints.coursesBase}/quizzes/$quizId/start/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse start quiz: ${response.statusCode}');
    print('📄 Body brut: ${response.body}');
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // DÉBOGAGE DÉTAILLÉ
      print('✅ Clés reçues: ${data.keys.toList()}');
      print('✅ Type attempt: ${data['attempt']?.runtimeType}');
      print('✅ Type quiz: ${data['quiz']?.runtimeType}');
      
      if (data['quiz'] != null) {
        print('📝 Quiz data: ${data['quiz']}');
        print('📝 Questions: ${data['quiz']['questions']}');
      }
      
      return data;
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Erreur démarrage quiz');
    }
  } catch (e, stackTrace) {
    print('❌ Exception start quiz: $e');
    print('❌ Stack trace: $stackTrace');
    rethrow;
  }
}

/// Soumettre les réponses d'un quiz
static Future<Map<String, dynamic>> submitQuiz(
  String token, 
  int quizId, 
  int attemptId,
  List<Map<String, dynamic>> answers
) async {
  print('✅ Soumission quiz $quizId, tentative $attemptId');
  print('📄 Réponses: ${answers.length} questions');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse('${ApiEndpoints.coursesBase}/quizzes/$quizId/submit/'),
        headers: _authHeaders(validToken),
        body: jsonEncode({
          'attempt_id': attemptId,
          'answers': answers,
        }),
      ),
    );

    print('📱 Réponse submit quiz: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Erreur soumission quiz');
    }
  } catch (e) {
    print('❌ Exception submit quiz: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Récupérer les résultats de toutes les tentatives d'un quiz
static Future<Map<String, dynamic>> getQuizResults(String token, int quizId) async {
  print('📊 Récupération résultats quiz $quizId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'results': []};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.coursesBase}/quizzes/$quizId/results/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse quiz results: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'results': []};
    } else {
      throw Exception('Erreur récupération résultats: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception quiz results: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Récupérer la correction détaillée d'une tentative
static Future<Map<String, dynamic>> getQuizCorrection(
  String token, 
  int quizId, 
  int attemptId
) async {
  print('📖 Récupération correction quiz $quizId, tentative $attemptId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'correction': null};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.coursesBase}/quizzes/$quizId/correction/$attemptId/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse quiz correction: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'correction': null};
    } else if (response.statusCode == 403) {
      throw Exception('La correction n\'est pas disponible pour ce quiz');
    } else {
      throw Exception('Erreur récupération correction: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception quiz correction: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Abandonner une tentative en cours
static Future<Map<String, dynamic>> abandonQuizAttempt(String token, int attemptId) async {
  print('🚫 Abandon tentative $attemptId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse('${ApiEndpoints.coursesBase}/attempts/$attemptId/abandon/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse abandon attempt: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Erreur abandon tentative');
    }
  } catch (e) {
    print('❌ Exception abandon attempt: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Récupérer toutes les tentatives de l'utilisateur
static Future<List<dynamic>> getMyAttempts(String token) async {
  print('📋 Récupération de mes tentatives');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return [];
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse('${ApiEndpoints.coursesBase}/attempts/'),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse my attempts: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    } else if (response.statusCode == 401) {
      return [];
    } else {
      throw Exception('Erreur récupération tentatives: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception my attempts: $e');
    throw Exception('Erreur réseau: $e');
  }
}



// ========================================
// MÉTHODES PROJETS
// ========================================

/// Récupérer tous les projets de l'étudiant
static Future<List<dynamic>> getMyProjects(String token) async {
  print('📂 Récupération de mes projets');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return [];
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse(ApiEndpoints.myProjects),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse my projects: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // ✅ Retourner la liste directement
      if (data is List) {
        return data;
      } else {
        // Si c'est un objet avec des clés, extraire la liste
        return data['results'] ?? data['data'] ?? [];
      }
    } else if (response.statusCode == 401) {
      return [];
    } else {
      throw Exception('Erreur récupération projets: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception my projects: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Créer un nouveau projet
static Future<Map<String, dynamic>> createProject(
  String token,
  Map<String, dynamic> projectData,
) async {
  print('➕ Création projet');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.myProjects),
        headers: _authHeaders(validToken),
        body: jsonEncode(projectData),
      ),
    );

    print('📱 Réponse create project: ${response.statusCode}');
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['error'] ?? 'Erreur création projet');
    }
  } catch (e) {
    print('❌ Exception create project: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Récupérer les détails d'un projet
static Future<Map<String, dynamic>> getProjectDetail(String token, int projectId) async {
  print('📄 Récupération détails projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'project': null};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse(ApiEndpoints.projectDetail(projectId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse project detail: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'project': null};
    } else {
      throw Exception('Erreur récupération détails: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception project detail: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Mettre à jour un projet
static Future<Map<String, dynamic>> updateProject(
  String token,
  int projectId,
  Map<String, dynamic> updates,
) async {
  print('✏️ Mise à jour projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.patch(
        Uri.parse(ApiEndpoints.projectDetail(projectId)),
        headers: _authHeaders(validToken),
        body: jsonEncode(updates),
      ),
    );

    print('📱 Réponse update project: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur mise à jour projet: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception update project: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Supprimer un projet
static Future<void> deleteProject(String token, int projectId) async {
  print('🗑 Suppression projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      throw Exception('Token invalide');
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.delete(
        Uri.parse(ApiEndpoints.projectDetail(projectId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse delete project: ${response.statusCode}');
    
    if (response.statusCode != 204 && response.statusCode != 200 && response.statusCode != 401) {
      throw Exception('Erreur suppression projet: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception delete project: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Toggle favori d'un projet
static Future<Map<String, dynamic>> toggleProjectFavorite(String token, int projectId) async {
  print('⭐ Toggle favori projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.toggleProjectFavorite(projectId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse toggle favorite: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur toggle favori: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception toggle favorite: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Archiver un projet
static Future<Map<String, dynamic>> archiveProject(String token, int projectId) async {
  print('📦 Archivage projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.archiveProject(projectId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse archive: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur archivage: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception archive: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Désarchiver un projet (en changeant le statut)
static Future<Map<String, dynamic>> unarchiveProject(String token, int projectId) async {
  print('🔓 Désarchivage du projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.patch(
        Uri.parse('${ApiEndpoints.baseUrl}/api/courses/projects/$projectId/'),
        headers: _authHeaders(validToken),
        body: jsonEncode({'status': 'IN_PROGRESS'}),
      ),
    );

    print('📱 Réponse unarchive: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Projet désarchivé avec succès');
      return data;
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      print('❌ Erreur désarchivage: ${response.statusCode}');
      throw Exception('Erreur désarchivage projet: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception unarchive: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Statistiques des projets
static Future<Map<String, dynamic>> getProjectStatistics(String token) async {
  print('📊 Récupération statistiques projets');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'statistics': null};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse(ApiEndpoints.projectStatistics),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse statistics: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'statistics': null};
    } else {
      throw Exception('Erreur statistiques: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception statistics: $e');
    throw Exception('Erreur réseau: $e');
  }
}



// ========================================
// MÉTHODES TÂCHES
// ========================================

/// Récupérer les tâches d'un projet
static Future<List<dynamic>> getProjectTasks(String token, int projectId) async {
  print('✅ Récupération tâches projet $projectId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return [];
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.get(
        Uri.parse(ApiEndpoints.tasksByProject(projectId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse tasks: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List;
    } else if (response.statusCode == 401) {
      return [];
    } else {
      throw Exception('Erreur récupération tâches: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception tasks: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Créer une nouvelle tâche
static Future<Map<String, dynamic>> createTask(
  String token,
  Map<String, dynamic> taskData,
) async {
  print('➕ Création tâche');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.myTasks),
        headers: _authHeaders(validToken),
        body: jsonEncode(taskData),
      ),
    );

    print('📱 Réponse create task: ${response.statusCode}');
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur création tâche: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception create task: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Déplacer une tâche (drag & drop)
static Future<Map<String, dynamic>> moveTask(
  String token,
  int taskId,
  String newStatus, {
  int? order,
}) async {
  print('🔄 Déplacement tâche $taskId vers $newStatus');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.moveTask(taskId)),
        headers: _authHeaders(validToken),
        body: jsonEncode({
          'status': newStatus,
          if (order != null) 'order': order,
        }),
      ),
    );

    print('📱 Réponse move task: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur déplacement tâche: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception move task: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Mettre à jour une tâche
static Future<Map<String, dynamic>> updateTask(
  String token,
  int taskId,
  Map<String, dynamic> updates,
) async {
  print('✏️ Mise à jour tâche $taskId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.patch(
        Uri.parse(ApiEndpoints.taskDetail(taskId)),
        headers: _authHeaders(validToken),
        body: jsonEncode(updates),
      ),
    );

    print('📱 Réponse update task: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur mise à jour tâche: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception update task: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Supprimer une tâche
static Future<void> deleteTask(String token, int taskId) async {
  print('🗑 Suppression tâche $taskId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      throw Exception('Token invalide');
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.delete(
        Uri.parse(ApiEndpoints.taskDetail(taskId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse delete task: ${response.statusCode}');
    
    if (response.statusCode != 204 && response.statusCode != 200 && response.statusCode != 401) {
      throw Exception('Erreur suppression tâche: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception delete task: $e');
    throw Exception('Erreur réseau: $e');
  }
}

/// Toggle importance d'une tâche
static Future<Map<String, dynamic>> toggleTaskImportant(String token, int taskId) async {
  print('⚠️ Toggle importance tâche $taskId');
  
  try {
    // ✅ Vérifier le token AVANT
    final validToken = await AuthInterceptor.getValidTokenOrRedirect();
    if (validToken == null) {
      return {'success': false, 'message': 'Token invalide'};
    }
    
    // ✅ Utiliser le wrapper
    final response = await _makeAuthenticatedRequest(
      request: () => http.post(
        Uri.parse(ApiEndpoints.toggleTaskImportant(taskId)),
        headers: _authHeaders(validToken),
      ),
    );

    print('📱 Réponse toggle important: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      return {'success': false, 'message': 'Token invalide'};
    } else {
      throw Exception('Erreur toggle importance: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Exception toggle important: $e');
    throw Exception('Erreur réseau: $e');
  }
}

}