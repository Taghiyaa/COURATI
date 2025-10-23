// 📁 lib/services/auth_interceptor.dart
import 'package:flutter/material.dart';
import 'storage_service.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../core/constants/app_colors.dart';

class AuthInterceptor {
  // ✅ Clé globale pour accéder au contexte partout
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // ✅ Flag pour éviter les redirections multiples
  static bool _isRedirecting = false;
  
  // ✅ AJOUT : Flag pour éviter les multiples déconnexions
  static bool _isLoggingOut = false;
  
  /// Gérer une erreur 401 - Redirection automatique vers login
  static Future<void> handle401Error() async {
    // ✅ Vérifier si déjà en cours de déconnexion
    if (_isLoggingOut) {
      print('⏸️ Déconnexion déjà en cours, ignorée');
      return;
    }
    
    // ✅ Vérifier si déjà en redirection
    if (_isRedirecting) {
      print('⏸️ Redirection déjà en cours, ignorée');
      return;
    }
    
    _isRedirecting = true;
    _isLoggingOut = true;
    
    try {
      print('🚪 Session expirée, déconnexion...');
      
      // Nettoyer le stockage
      await StorageService.logout();
      
      // Récupérer le contexte
      final context = navigatorKey.currentContext;
      
      if (context != null && context.mounted) {
        // Rediriger vers login
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        
        // Message d'information
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Session expirée, veuillez vous reconnecter'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      // ✅ Réinitialiser les flags après un délai
      Future.delayed(const Duration(seconds: 2), () {
        _isRedirecting = false;
        _isLoggingOut = false;
      });
    }
  }
  
  /// ✅ Vérifier le token ET rediriger si invalide
  static Future<String?> getValidTokenOrRedirect() async {
    print('🔍 Vérification token avec redirection...');
    
    final token = await StorageService.getValidAccessToken();
    
    if (token == null || token.isEmpty) {
      print('❌ Token invalide, déclenchement redirection');
      await handle401Error();
      return null;
    }
    
    print('✅ Token valide');
    return token;
  }
}