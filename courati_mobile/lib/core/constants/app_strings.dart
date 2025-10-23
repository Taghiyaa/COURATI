class AppStrings {
  // App
  static const String appName = 'Courati';
  static const String appTagline = 'Gestion des cours et projets étudiants';
  
  // Auth
  static const String login = 'Se connecter';
  static const String register = 'S\'inscrire';
  static const String logout = 'Se déconnecter';
  static const String forgotPassword = 'Mot de passe oublié ?';
  static const String verifyOtp = 'Vérifier le code OTP';
  
  // Fields
  static const String username = 'Nom d\'utilisateur';
  static const String email = 'Email';
  static const String password = 'Mot de passe';
  static const String confirmPassword = 'Confirmer le mot de passe';
  static const String phoneNumber = 'Numéro de téléphone';
  static const String firstName = 'Prénom';
  static const String lastName = 'Nom';
  static const String level = 'Niveau';
  static const String major = 'Filière';
  
  // Levels
  static const Map<String, String> levels = {
    'L1': 'Licence 1',
    'L2': 'Licence 2', 
    'L3': 'Licence 3',
    'M1': 'Master 1',
    'M2': 'Master 2',
  };
  
  // Majors
  static const Map<String, String> majors = {
    'INFO': 'Informatique',
    'MATH': 'Mathématiques',
    'PHYS': 'Physique', 
    'CHIM': 'Chimie',
    'BIO': 'Biologie',
  };
  
  // Messages
  static const String welcomeBack = 'Bon retour !';
  static const String createAccount = 'Créer un compte';
  static const String otpSent = 'Code envoyé par SMS';
  static const String accountCreated = 'Compte créé avec succès';
  static const String loginSuccess = 'Connexion réussie';
  static const String loginFailed = 'Échec de la connexion';
  
  // Errors
  static const String errorGeneral = 'Une erreur est survenue';
  static const String errorNetwork = 'Erreur de connexion';
  static const String errorInvalidCredentials = 'Identifiants invalides';
  static const String errorAccountNotVerified = 'Compte non vérifié';
  
  // Navigation
  static const String home = 'Accueil';
  static const String subjects = 'Matières';
  static const String courses = 'Cours';
  static const String projects = 'Projets';
  static const String profile = 'Profil';
  static const String history = 'Historique';
  static const String favorites = 'Favoris';
  static const String quiz = 'Quiz';
}
