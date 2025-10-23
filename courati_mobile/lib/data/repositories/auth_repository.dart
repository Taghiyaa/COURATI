import '../models/user_model.dart';
import '../models/auth_response.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../core/utils/app_exception.dart';

class AuthRepository {
  // Login
  Future<AuthResponse> login(String username, String password) async {
    try {
      return await ApiService.login(username, password);
    } catch (e) {
      throw AuthException('Échec de la connexion: ${e.toString()}');
    }
  }

  // Register
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
    String? firstName,
    String? lastName,
    String? level,
    String? major,
  }) async {
    try {
      return await ApiService.register(
        username: username,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        firstName: firstName,
        lastName: lastName,
        level: level,
        major: major,
      );
    } catch (e) {
      throw AuthException('Échec de l\'inscription: ${e.toString()}');
    }
  }

  // Verify OTP
  Future<AuthResponse> verifyOtp(String phoneNumber, String otp) async {
    try {
      return await ApiService.verifyOtp(phoneNumber, otp);
    } catch (e) {
      throw AuthException('Vérification OTP échouée: ${e.toString()}');
    }
  }

  // Get Profile
  Future<UserModel> getProfile() async {
    try {
      final token = StorageService.getAccessToken();
      if (token == null) {
        throw AuthException('Token d\'accès manquant');
      }
      return await ApiService.getProfile(token);
    } catch (e) {
      throw AuthException('Échec de récupération du profil: ${e.toString()}');
    }
  }

  // Refresh Token
  Future<String> refreshToken() async {
    try {
      final refreshToken = StorageService.getRefreshToken();
      if (refreshToken == null) {
        throw AuthException('Token de rafraîchissement manquant');
      }
      return await ApiService.refreshToken(refreshToken);
    } catch (e) {
      throw AuthException('Échec du rafraîchissement du token: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    await StorageService.logout();
  }

  // Check if logged in
  bool isLoggedIn() {
    return StorageService.isLoggedIn();
  }

  // Get current user
  UserModel? getCurrentUser() {
    return StorageService.getUser();
  }
}
