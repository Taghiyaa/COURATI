class ApiEndpoints {
  static const bool isEmulator = true; // Changez selon votre cible
  static const String baseUrl = isEmulator 
    ? 'http://10.0.2.2:8000'  // Émulateur
    : 'http://127.0.0.1:8000'; // Windows/Web
  
  static const String authBase = '$baseUrl/api/auth';
  static const String login = '$authBase/login/';
  static const String register = '$authBase/register/';
  static const String verifyOtp = '$authBase/verify-otp/';
  static const String profile = '$authBase/profile/';
  static const String tokenRefresh = '$authBase/token/refresh/';
  
  // Nouveaux endpoints pour réinitialisation de mot de passe par email
  static const String passwordResetRequest = '$authBase/password-reset-request/';
  static const String passwordResetConfirm = '$authBase/password-reset-confirm/';
  
  // Endpoints optionnels pour fonctionnalités avancées
  static const String updateProfile = '$authBase/update-profile/';
  static const String logout = '$authBase/logout/';
  static const String changePassword = '$authBase/change-password/';
  
  // NOUVEAUX ENDPOINTS POUR LES CHOIX DYNAMIQUES - CORRIGÉS
  static const String getLevels = '$authBase/choices/levels/';
  static const String getMajors = '$authBase/choices/majors/';
  static const String getRegistrationChoices = '$authBase/choices/registration/'; // CORRIGÉ
  
  // NOUVEAUX ENDPOINTS POUR LES COURS
  static const String coursesBase = '$baseUrl/api/courses';
  static const String mySubjects = '$coursesBase/my-subjects/';
  static const String personalizedHome = '$coursesBase/home/';
  static const String favorites = '$coursesBase/favorites/';
  static const String documentTypes = '$coursesBase/choices/document-types/';
  
  // Endpoints dynamiques (avec paramètres)
  static String subjectDocuments(int subjectId) => '$coursesBase/subjects/$subjectId/documents/';
  static String downloadDocument(int documentId) => '$coursesBase/documents/$documentId/download/';

   
  // NOUVEAUX ENDPOINTS pour la visualisation
  static String documentView(int documentId) => '$coursesBase/documents/$documentId/view/';

  // NOUVEAU ENDPOINT pour l'historique de consultation
  static const String consultationHistory = '$coursesBase/consultation-history/';

    // Quiz endpoints
  static String get myQuizzes => '$coursesBase/quizzes/my_quizzes/';
  static String quizDetail(int id) => '$coursesBase/quizzes/$id/';
  static String startQuiz(int id) => '$coursesBase/quizzes/$id/start/';
  static String submitQuiz(int id) => '$coursesBase/quizzes/$id/submit/';
  static String quizResults(int id) => '$coursesBase/quizzes/$id/results/';
  static String quizCorrection(int quizId, int attemptId) => 
      '$coursesBase/quizzes/$quizId/correction/$attemptId/';
  static String abandonAttempt(int id) => '$coursesBase/attempts/$id/abandon/';
  static String get myAttempts => '$coursesBase/attempts/';
  // ========================================
  // PROJECTS ENDPOINTS
  // ========================================
  
  // Liste et création de projets
  static String get myProjects => '$coursesBase/projects/';
  
  // Détail, modification, suppression d'un projet
  static String projectDetail(int id) => '$coursesBase/projects/$id/';
  
  // Actions sur les projets
  static String toggleProjectFavorite(int id) => '$coursesBase/projects/$id/toggle_favorite/';
  static String archiveProject(int id) => '$coursesBase/projects/$id/archive/';
  static String unarchiveProject(int id) => '$coursesBase/projects/$id/unarchive/';
  static String get projectStatistics => '$coursesBase/projects/statistics/';
  
  // Gestion des tâches
  static String get myTasks => '$coursesBase/tasks/';
  static String taskDetail(int id) => '$coursesBase/tasks/$id/';
  static String tasksByProject(int projectId) => '$coursesBase/tasks/?project=$projectId';
  static String moveTask(int id) => '$coursesBase/tasks/$id/move_to_column/';
  static String toggleTaskImportant(int id) => '$coursesBase/tasks/$id/toggle_important/';

  // ========================================
// NOTIFICATIONS ENDPOINTS
// ========================================
static const String notificationsBase = '$baseUrl/api/notifications';
static const String fcmToken = '$notificationsBase/fcm-token/';
static String deleteFcmToken(String token) => '$notificationsBase/fcm-token/$token/';
static const String notificationPreferences = '$notificationsBase/preferences/';
static const String subjectPreferences = '$notificationsBase/subject-preferences/';
static String updateSubjectPreference(int id) => '$notificationsBase/subject-preferences/$id/';
static const String notificationHistory = '$notificationsBase/history/';
static String markNotificationAsRead(int id) => '$notificationsBase/history/$id/read/';
static const String markAllNotificationsAsRead = '$notificationsBase/history/mark-all-read/';
}
