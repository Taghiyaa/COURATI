// 📁 lib/presentation/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/student_profile_model.dart';
import '../../../services/storage_service.dart';
import '../auth/login_screen.dart';
import '../main/main_screen.dart';
import 'edit_profile_screen.dart';
import '../../../data/models/level_model.dart';
import '../../../data/models/major_model.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;
  final StudentProfileModel? studentProfile;

  const ProfileScreen({
    super.key,
    required this.user,
    this.studentProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _handleEditProfile(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header du profil amélioré
            _buildProfileHeader(context),
            
            const SizedBox(height: 32),
            
            // Informations personnelles (incluant téléphone et statut)
            _buildProfileInfoSection(),
            
            const SizedBox(height: 24),
            
            // Informations académiques (si étudiant)
            if (studentProfile != null) _buildAcademicInfoSection(),
            
            const SizedBox(height: 24),
            
            // Actions du profil (sans sécurité)
            _buildProfileActions(context),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Avatar compact
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.person,
              size: 45,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Nom compact
          Text(
            user.fullName.isNotEmpty ? user.fullName : user.username,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Rôle compact
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              user.isStudent ? 'Étudiant' : 'Administrateur',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations personnelles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          
          _buildModernInfoRow(
            Icons.person_outline,
            'Nom d\'utilisateur',
            user.username,
          ),
          _buildModernInfoRow(
            Icons.email_outlined,
            'Email',
            user.email,
          ),
          if (user.firstName != null && user.firstName!.isNotEmpty)
            _buildModernInfoRow(
              Icons.badge_outlined,
              'Prénom',
              user.firstName!,
            ),
          if (user.lastName != null && user.lastName!.isNotEmpty)
            _buildModernInfoRow(
              Icons.badge_outlined,
              'Nom de famille',
              user.lastName!,
            ),
          // Téléphone et statut déplacés ici
          if (studentProfile != null) ...[
            _buildModernInfoRow(
              Icons.phone_outlined,
              'Téléphone',
              studentProfile!.phoneNumber,
            ),
            _buildModernInfoRow(
              Icons.verified_outlined,
              'Statut du compte',
              studentProfile!.isVerified ? 'Vérifié' : 'En attente de vérification',
              valueColor: studentProfile!.isVerified ? Colors.green : Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcademicInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.school,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informations académiques',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
         _buildModernInfoRow(
            Icons.school_outlined,
            'Niveau d\'étude',
            studentProfile!.level?.name ?? 'Non défini',
          ),
          _buildModernInfoRow(
            Icons.bookmark_outline,
            'Filière',
            studentProfile!.major?.name ?? 'Non défini',
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildActionButton(
            icon: Icons.edit_outlined,
            title: 'Modifier le profil',
            subtitle: 'Mettre à jour vos informations',
            onTap: () => _handleEditProfile(context),
          ),
          
          const SizedBox(height: 12),
          
          _buildActionButton(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Gérer vos préférences',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications - Fonctionnalité à venir')),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          const Divider(),
          
          const SizedBox(height: 12),
          
          // Bouton de déconnexion directe
          _buildActionButton(
            icon: Icons.logout,
            title: 'Se déconnecter',
            subtitle: 'Fermer votre session',
            onTap: () => _handleDirectLogout(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.primary;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ MÉTHODE CENTRALISÉE POUR LA GESTION DE L'ÉDITION DU PROFIL
  Future<void> _handleEditProfile(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          user: user,
          studentProfile: studentProfile,
        ),
      ),
    );
    
    // Si des modifications ont été faites, remplacer l'écran profil par MainScreen
    if (result != null && result['updated'] == true) {
      final newUserData = result['user_data'];
      
      // Créer les nouveaux modèles avec les données mises à jour
      final updatedUser = UserModel(
        id: user.id,
        username: newUserData['username'] ?? user.username,
        email: newUserData['email'] ?? user.email,
        firstName: newUserData['first_name'],
        lastName: newUserData['last_name'],
        role: user.role,
        isStaff: user.isStaff,
        isActive: user.isActive,
        dateJoined: user.dateJoined,
      );
      
      // ✅ CORRECTION APPLIQUÉE : Créer les objets LevelModel et MajorModel
      StudentProfileModel? updatedStudentProfile;
      if (newUserData['user_type'] == 'student' && studentProfile != null) {
        // Créer les objets Level et Major à partir des données JSON
        LevelModel? newLevel;
        MajorModel? newMajor;

        if (newUserData['level'] != null) {
          newLevel = LevelModel.fromJson(newUserData['level']);
        }
        if (newUserData['major'] != null) {
          newMajor = MajorModel.fromJson(newUserData['major']);
        }

        updatedStudentProfile = studentProfile!.copyWith(
          phoneNumber: newUserData['phone_number'],
          level: newLevel,     // ✅ Objet LevelModel
          major: newMajor,     // ✅ Objet MajorModel
          isVerified: newUserData['is_verified'],
          updatedAt: DateTime.now(),
        );
      }
      
      // Naviguer vers MainScreen en remplaçant toute la pile de navigation
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MainScreen(
              user: updatedUser,
              studentProfile: updatedStudentProfile,
            ),
          ),
          (route) => false, // Remplacer toute la navigation
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleDirectLogout(BuildContext context) async {
    try {
      await StorageService.logout();
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Déconnexion réussie'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de déconnexion: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}