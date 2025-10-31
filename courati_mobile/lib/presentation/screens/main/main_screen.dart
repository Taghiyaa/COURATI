// 📁 lib/presentation/screens/main/main_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/student_profile_model.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/models/document_model.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../courses/subject_detail_screen.dart';
import '../history/history_screen.dart';
import '../consultation_history/consultation_history_screen.dart';
import '../favorites/favorites_screen.dart'; // Nouvelle page favoris
import '../quiz/quiz_list_screen.dart';
import '../projects/projects_list_screen.dart';
import '../../../core/painters/educational_background_painter.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';
import '../notifications/notification_list_screen.dart';
import '../../../services/notification_service.dart';
import '../notifications/notification_preferences_screen.dart';




class MainScreen extends StatefulWidget {
  final UserModel user;
  final StudentProfileModel? studentProfile;

  const MainScreen({
    super.key,
    required this.user,
    this.studentProfile,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  // Data pour les courses
  List<SubjectModel> _subjects = [];
  List<SubjectModel> _recommendedSubjects = [];
  Map<String, dynamic> _homeData = {};
  bool _isLoading = true;
  String? _accessToken;

  // Recherche
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _titles = [
    'Accueil',
    'Mes Cours',
    'Historique',
    'Favoris',
    'Quiz',
    'Projets',
  ];
  
  IconData _getRandomAcademicIcon() {
    final icons = [
      Icons.school,
      Icons.menu_book,
      Icons.calculate,
      Icons.science,
      Icons.biotech,
      Icons.psychology,
      Icons.language,
      Icons.architecture,
      Icons.engineering,
      Icons.computer,
    ];
    final random = DateTime.now().microsecond % icons.length;
    return icons[random];
  }

  

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeApp();
    _setupNotificationCallback();  
  }

  /// ✨ Initialisation avec gestion automatique du refresh token
  Future<void> _initializeApp() async {
    print('🔄 Initialisation MainScreen...');
    
    // ✅ Utiliser getValidAccessToken - vérifie et rafraîchit automatiquement
    _accessToken = await StorageService.getValidAccessToken();
    
    print('📊 Token récupéré: ${_accessToken != null ? "${_accessToken!.substring(0, 20)}..." : "null"}');
    
    // ✅ Vérifier que le token existe et est valide
    if (_accessToken == null || _accessToken!.isEmpty) {
      print('❌ Token manquant, invalide ou refresh impossible');
      await _handleSessionExpired();
      return;
    }
    
    print('✅ Token valide, chargement des données...');
    
    // Charger les données
    await _loadPersonalizedHome();
    await _loadSubjects();

    // ✅ AJOUT : Charger les notifications au démarrage
    if (mounted) {
      await Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications();
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
    
    print('✅ Initialisation MainScreen terminée');
  }

  /// ✅ NOUVEAU : Configurer le callback pour rafraîchir les notifications
  void _setupNotificationCallback() {
    NotificationService.onNotificationReceived = () {
      if (mounted) {
        print('🔄 Rafraîchissement automatique des notifications...');
        Provider.of<NotificationProvider>(context, listen: false)
            .fetchNotifications();
      }
    };
  }

  /// ✨ NOUVELLE MÉTHODE : Récupérer un token valide et le mettre à jour en mémoire
  Future<String?> _getValidToken() async {
    print('🔍 Récupération token valide...');
    
    final token = await StorageService.getValidAccessToken();
    
    if (token == null) {
      print('❌ Impossible d\'obtenir un token valide');
      await _handleSessionExpired();
      return null;
    }
    
    // ✅ Mettre à jour le token en mémoire
    if (mounted) {
      setState(() {
        _accessToken = token;
      });
    }
    
    print('✅ Token valide obtenu et mis à jour');
    return token;
  }

  /// ✨ AMÉLIORÉ : Charger la page d'accueil personnalisée
  Future<void> _loadPersonalizedHome() async {
    try {
      print('📥 Chargement page d\'accueil personnalisée...');
      
      // ✅ Récupérer un token valide avant la requête
      final token = await _getValidToken();
      if (token == null) return;
      
      final homeData = await ApiService.getPersonalizedHome(token);
      
      if (homeData['success'] && homeData['data'] != null) {
        if (mounted) {
          setState(() {
            _homeData = homeData['data'];
            final List<dynamic> subjectsJson = homeData['data']['recommended_subjects'] ?? [];
            _recommendedSubjects = subjectsJson
                .map((json) => SubjectModel.fromJson(json))
                .toList();
          });
        }
        print('✅ Page d\'accueil chargée: ${_recommendedSubjects.length} matières recommandées');
      } else {
        print('⚠️ Réponse home sans succès ou sans data');
      }
    } catch (e) {
      print('❌ Erreur chargement home: $e');
      
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        print('❌ Token invalide (401), redirection vers login...');
        await _handleSessionExpired();
      }
    }
  }

  /// ✨ AMÉLIORÉ : Charger les matières
  Future<void> _loadSubjects() async {
    try {
      print('📥 Chargement des matières...');
      
      // ✅ Récupérer un token valide avant la requête
      final token = await _getValidToken();
      if (token == null) return;
      
      final response = await ApiService.getMySubjects(token);
      
      if (response['success']) {
        final List<dynamic> subjectsJson = response['subjects'];
        if (mounted) {
          setState(() {
            _subjects = subjectsJson
                .map((json) => SubjectModel.fromJson(json))
                .toList();
          });
        }
        print('✅ Matières chargées: ${_subjects.length} matières');
      } else {
        print('⚠️ Réponse subjects sans succès');
      }
    } catch (e) {
      print('❌ Erreur chargement subjects: $e');
      
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        print('❌ Token invalide (401), redirection vers login...');
        await _handleSessionExpired();
      }
    }
  }

  /// ✨ NOUVELLE MÉTHODE : Refresh des données (pull-to-refresh)
  Future<void> _refreshData() async {
    print('🔄 Refresh des données...');
    
    // Récupérer un token valide (et le rafraîchir si nécessaire)
    final token = await _getValidToken();
    if (token == null) return;
    
    // Recharger les données
    await Future.wait([
      _loadPersonalizedHome(),
      _loadSubjects(),
    ]);
    
    print('✅ Refresh terminé');
  }

  /// Gérer l'expiration de session
  Future<void> _handleSessionExpired() async {
    print('🚪 Session expirée, déconnexion...');
    
    await StorageService.logout();
    
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Votre session a expiré. Veuillez vous reconnecter.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    NotificationService.onNotificationReceived = null;  
    super.dispose();
  }

  void _onNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // ✨ NOUVEAU : Rafraîchir automatiquement si on retourne sur l'accueil
    if (index == 0) {
      print('🔄 Retour sur l\'accueil - Rafraîchissement...');
      _refreshData();
    }
  }

  List<SubjectModel> get _filteredSubjects {
    if (_searchQuery.isEmpty) return _subjects;
    
    final query = _searchQuery.toLowerCase();
    
    return _subjects.where((subject) {
      final name = subject.name?.toLowerCase() ?? '';
      final code = subject.code?.toLowerCase() ?? '';
      
      return name.contains(query) || code.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: _buildModernAppBar(),
      drawer: _buildModernDrawer(),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _getScreens(),
      ),
      bottomNavigationBar: _buildModernBottomNavBar(),
      floatingActionButton: _currentIndex == 0 ? _buildSimpleFloatingActionButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      // ✨ NOUVEAU : Icône drawer plus large SANS background
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(
            Icons.menu,
            size: 32, // ← Plus large (défaut = 24)
          ),
          color: AppColors.textPrimary, // ← Couleur directe sans background
          onPressed: () => Scaffold.of(context).openDrawer(),
          padding: EdgeInsets.zero,
          iconSize: 32,
        ),
      ),
      
      title: Text(
        _titles[_currentIndex],
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: AppColors.textPrimary,
        ),
      ),
      
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.white,
      
        actions: [
        // ✅ Badge avec notifications
        Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    size: 28,
                  ),
                  color: AppColors.textPrimary,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationListScreen(),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  iconSize: 28,
                ),
                
                // Badge avec nombre
                if (provider.unreadCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        provider.unreadCount > 99 ? '99+' : '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  Widget _buildSimpleFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        _onNavTap(1); // Aller vers Mes Cours
      },
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 8,
      label: const Text('Mes Cours'),
      icon: const Icon(Icons.school),
    );
  }

  List<Widget> _getScreens() {
    return [
      _buildPersonalizedHomeContent(),   // Accueil personnalisé
      _buildCoursesContent(),            // Mes Cours
      _buildModernHistoryContent(),      // Historique
      FavoritesScreen(accessToken: _accessToken ?? ''), // Page Favoris séparée
      _buildModernQuizContent(),         // Quiz
      _buildModernProjectsContent(),     // Projets
    ];
  }

  // PAGE D'ACCUEIL PERSONNALISÉE
  Widget _buildPersonalizedHomeContent() {
  if (_isLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  return RefreshIndicator(
    onRefresh: _refreshData,  // ✅ Utiliser la nouvelle méthode
    child: Stack(
      children: [
        // ✨ NOUVEAU : Fond avec motifs éducatifs
        _buildEducationalBackground(),
        
        // Contenu principal
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 32),
                    _buildPersonalizedStats(),
                    const SizedBox(height: 32),
                    _buildRecommendedSubjects(),
                    const SizedBox(height: 32),
                    const Text(
                      'Accès rapide',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildModernActionGrid(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  // ✨ NOUVEAU : Fond éducatif avec motifs
Widget _buildEducationalBackground() {
  return Positioned.fill(
    child: CustomPaint(
      painter: EducationalBackgroundPainter(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[50]!,
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildWelcomeCard() {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary,
          AppColors.primary.withOpacity(0.85),
          AppColors.primary.withOpacity(0.7),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.4),
          blurRadius: 30,
          offset: const Offset(0, 15),
          spreadRadius: -5,
        ),
      ],
    ),
    child: Stack(
      children: [
        // ✨ Icônes académiques flottantes
        ..._buildFloatingAcademicIcons(),
        
        // Contenu principal
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge animé
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getTimeIcon(),
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getTimeOfDay(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Nom de l'utilisateur
                        Text(
                          widget.user.firstName?.isNotEmpty == true
                              ? widget.user.firstName!
                              : widget.user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Message de bienvenue
                        Text(
                          'Prêt à apprendre aujourd\'hui ?',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Avatar avec icône académique
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getRandomAcademicIcon(),
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ],
              ),
              
              if (widget.studentProfile != null) ...[
                const SizedBox(height: 20),
                
                // Informations académiques
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Niveau
                      Expanded(
                        child: _buildInfoPill(
                          Icons.school,
                          widget.studentProfile!.levelDisplay,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Séparateur
                      Container(
                        width: 1,
                        height: 30,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 12),
                      
                      // Filière
                      Expanded(
                        child: _buildInfoPill(
                          Icons.menu_book,
                          widget.studentProfile!.majorDisplay,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

 // ✨ NOUVEAU : Icônes académiques flottantes
List<Widget> _buildFloatingAcademicIcons() {
  final icons = [
    {'icon': Icons.calculate, 'top': 20.0, 'right': 80.0, 'size': 30.0, 'opacity': 0.15},
    {'icon': Icons.science, 'top': 60.0, 'right': 30.0, 'size': 25.0, 'opacity': 0.12},
    {'icon': Icons.menu_book, 'bottom': 80.0, 'left': 30.0, 'size': 28.0, 'opacity': 0.13},
    {'icon': Icons.psychology, 'bottom': 30.0, 'left': 80.0, 'size': 22.0, 'opacity': 0.1},
    {'icon': Icons.biotech, 'top': 100.0, 'left': 50.0, 'size': 24.0, 'opacity': 0.11},
  ];

  return icons.map((data) {
    // ✅ CORRECTION : Cast correct des types
    final topValue = data['top'] as double?;
    final bottomValue = data['bottom'] as double?;
    final leftValue = data['left'] as double?;
    final rightValue = data['right'] as double?;
    final iconData = data['icon'] as IconData;
    final sizeValue = data['size'] as double;
    final opacityValue = data['opacity'] as double;

    return Positioned(
      top: topValue,
      bottom: bottomValue,
      left: leftValue,
      right: rightValue,
      child: Transform.rotate(
        angle: (topValue ?? 0.0) / 50,  // ✅ CORRECTION : ajout de .0
        child: Icon(
          iconData,
          size: sizeValue,
          color: Colors.white.withOpacity(opacityValue),
        ),
      ),
    );
  }).toList();
}

// ✨ NOUVEAU : Icônes éducatives flottantes pour le drawer
List<Widget> _buildDrawerFloatingIcons() {
  final icons = [
    {'icon': Icons.school, 'top': 15.0, 'right': 25.0, 'size': 40.0, 'opacity': 0.15},
    {'icon': Icons.menu_book, 'top': 85.0, 'right': 70.0, 'size': 30.0, 'opacity': 0.12},
    {'icon': Icons.calculate, 'top': 130.0, 'left': 25.0, 'size': 32.0, 'opacity': 0.13},
    {'icon': Icons.science, 'top': 50.0, 'left': 110.0, 'size': 28.0, 'opacity': 0.11},
    {'icon': Icons.psychology, 'bottom': 25.0, 'right': 35.0, 'size': 26.0, 'opacity': 0.10},
    {'icon': Icons.biotech, 'top': 100.0, 'left': 50.0, 'size': 24.0, 'opacity': 0.11},
    {'icon': Icons.language, 'top': 25.0, 'left': 180.0, 'size': 22.0, 'opacity': 0.09},
  ];

  return icons.map((data) {
    final topValue = data['top'] as double?;
    final bottomValue = data['bottom'] as double?;
    final leftValue = data['left'] as double?;
    final rightValue = data['right'] as double?;
    final iconData = data['icon'] as IconData;
    final sizeValue = data['size'] as double;
    final opacityValue = data['opacity'] as double;

    return Positioned(
      top: topValue,
      bottom: bottomValue,
      left: leftValue,
      right: rightValue,
      child: Transform.rotate(
        angle: (topValue ?? bottomValue ?? 0.0) / 50,
        child: Icon(
          iconData,
          size: sizeValue,
          color: Colors.white.withOpacity(opacityValue),
        ),
      ),
    );
  }).toList();
}

// ✨ NOUVEAU : Pill d'information
Widget _buildInfoPill(IconData icon, String text) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        icon,
        color: Colors.white,
        size: 18,
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    ],
  );
}

// ============================================
// 📊 SECTION STATISTIQUES - VERSION FINALE
// ============================================

/// Statistiques réelles depuis l'API
Widget _buildPersonalizedStats() {
  // Récupération des vraies statistiques
  final totalSubjects = _subjects.length;
  final totalFavorites = _homeData['stats']?['total_favorites'] ?? 0;
  final completionRate = _homeData['stats']?['completion_rate'] ?? 0;
  
  // Données pour la progression détaillée
  final viewedDocs = _homeData['stats']?['viewed_documents'] ?? 0;
  final totalDocs = _homeData['stats']?['total_documents'] ?? 1;
  
  return SizedBox(
    height: 95,
    child: Row(
      children: [
        // Carte Matières
        Expanded(
          child: _buildStatCard(
            'Matières', 
            '$totalSubjects', 
            Icons.school, 
            Colors.blue
          )
        ),
        const SizedBox(width: 8),
        
        // Carte Favoris
        Expanded(
          child: _buildStatCard(
            'Favoris', 
            '$totalFavorites', 
            Icons.favorite, 
            Colors.red
          )
        ),
        const SizedBox(width: 8),
        
        // ✅ Carte Progression CLIQUABLE (sans IconButton)
        Expanded(
          child: _buildProgressStatCard(
            'Progression', 
            '$completionRate%', 
            '$viewedDocs/$totalDocs',
            Icons.trending_up, 
            Colors.green
          )
        ),
        // ❌ IconButton supprimé
      ],
    ),
  );
}

/// Dialog d'explication de la progression
void _showProgressExplanation() {
  final viewedDocs = _homeData['stats']?['viewed_documents'] ?? 0;
  final totalDocs = _homeData['stats']?['total_documents'] ?? 1;
  final completionRate = _homeData['stats']?['completion_rate'] ?? 0;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.trending_up,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Progression Globale',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Votre progression représente le pourcentage de documents que vous avez consultés sur l\'ensemble de vos matières.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            
            // Situation actuelle
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre situation actuelle :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Documents consultés : $viewedDocs',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    '• Total documents : $totalDocs',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Progression : $completionRate%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Formule de calcul
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Formule de calcul :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Documents consultés ÷ Total documents × 100',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Astuce
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Consultez plus de documents pour augmenter votre progression !',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Compris !',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

/// ✅ Carte de progression CLIQUABLE - SANS OVERFLOW
Widget _buildProgressStatCard(
  String title, 
  String value, 
  String subtitle,
  IconData icon, 
  Color color
) {
  return Container(
    height: 100,
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
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showProgressExplanation,
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.2),      // ← Effet au clic
        highlightColor: color.withOpacity(0.1),   // ← Effet au survol
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),  // ← Padding réduit
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,  // ← center au lieu de spaceEvenly
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icône
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 12),
              ),
              
              const SizedBox(height: 3),  // ← Espacement réduit
              
              // Valeur principale (ex: "64.0%")
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              
              const SizedBox(height: 1),  // ← Espacement minimal
              
              // Sous-titre (ex: "32/50")
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 7,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                  height: 1.0,
                  letterSpacing: -0.2,  // ← Compacter le texte
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              
              const SizedBox(height: 1),  // ← Espacement minimal
              
              // Titre (ex: "Progression")
              Text(
                title,
                style: const TextStyle(
                  fontSize: 8,
                  color: AppColors.textSecondary,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
              ),
              
              const SizedBox(height: 2),  // ← Espacement minimal
              
              // Indicateur de cliquabilité
              Icon(
                Icons.info_outline,
                size: 9,
                color: color.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Carte de statistique standard (inchangée)
Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    height: 100,
    padding: const EdgeInsets.all(12),
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
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Icône
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        
        // Valeur
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        
        // Titre
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildRecommendedSubjects() {
  if (_recommendedSubjects.isEmpty) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Matières recommandées',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Aucune matière disponible pour votre profil.\nContactez l\'administration.',
            style: TextStyle(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Matières recommandées',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: () => _onNavTap(1),
            child: const Text('Voir tout'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      
      // Changement ici : hauteur adaptative au lieu de fixe
      SizedBox(
        height: 220, // Augmenté de 200 à 220 pour éviter l'overflow
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _recommendedSubjects.take(5).length,
          itemBuilder: (context, index) {
            final subject = _recommendedSubjects[index];
            return Container(
              width: 300,
              margin: const EdgeInsets.only(right: 16),
              child: _buildCompactSubjectCard(subject, index), // Nouvelle fonction pour cartes compactes
            );
          },
        ),
      ),
    ],
  );
}


// Nouvelle fonction pour les cartes horizontales plus compactes
Widget _buildCompactSubjectCard(SubjectModel subject, int index) {
  final cardColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
  ];
  final cardColor = cardColors[(cardColors.length - 1 - index) % cardColors.length];

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToSubjectDetail(subject),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, // ← CHANGÉ
            children: [
              // Header compact
              Row(
                crossAxisAlignment: CrossAxisAlignment.start, // ← AJOUTÉ
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cardColor.withOpacity(0.8),
                          cardColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // ← AJOUTÉ
                      children: [
                        Text(
                          subject.name ?? 'Nom non disponible',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15, // ← RÉDUIT de 16 à 15
                            color: AppColors.textPrimary,
                            height: 1.2, // ← AJOUTÉ pour contrôler l'espacement
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cardColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            subject.code ?? 'Code non disponible',
                            style: TextStyle(
                              color: cardColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12), // ← RÉDUIT de 16 à 12
              
              // Statistiques compactes
              Row(
                children: [
                  Expanded(
                    child: _buildCompactStatContainer(
                      Icons.description_outlined,
                      '${subject.documentCount ?? 0}',
                      'Docs',
                      cardColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactStatContainer(
                      Icons.star_outline,
                      '${subject.credits ?? 0}',
                      'Crédits',
                      cardColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Bouton compact
              Container(
                width: double.infinity,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      cardColor.withOpacity(0.8),
                      cardColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _navigateToSubjectDetail(subject),
                    borderRadius: BorderRadius.circular(10),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Accéder',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Fonction pour les stats compactes (inchangée)
Widget _buildCompactStatContainer(IconData icon, String value, String label, Color color) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: color.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildModernActionGrid() {
    final actions = [
      {'title': 'Mes Cours', 'icon': Icons.school, 'color': Colors.blue, 'index': 1},
      {'title': 'Quiz', 'icon': Icons.quiz, 'color': Colors.green, 'index': 4},
      {'title': 'Projets', 'icon': Icons.work, 'color': Colors.orange, 'index': 5},
      {'title': 'Favoris', 'icon': Icons.favorite, 'color': Colors.red, 'index': 3},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return _buildModernActionCard(
          action['title'] as String,
          action['icon'] as IconData,
          action['color'] as Color,
          () => _onNavTap(action['index'] as int),
        );
      },
    );
  }

  Widget _buildModernActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

 

  // PAGE MES COURS avec recherche automatique
  Widget _buildCoursesContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadSubjects,
      child: CustomScrollView(
        slivers: [
          // Barre de recherche moderne
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildCoursesHeader(),
                  const SizedBox(height: 20),
                  _buildModernSearchBar(),
                ],
              ),
            ),
          ),
          
          // Contenu principal des cours
          if (_subjects.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyCoursesState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _buildModernSubjectCard(_filteredSubjects[index], index),
                    );
                  },
                  childCount: _filteredSubjects.length,
                ),
              ),
            ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  // Nouvelle barre de recherche moderne et automatique
  Widget _buildModernSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Rechercher une matière...',
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.7),
            fontSize: 16,
          ),
          prefixIcon: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCoursesHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              Text(
                '${_subjects.length} matière${_subjects.length > 1 ? 's' : ''} disponible${_subjects.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        // Bouton de recherche supprimé, remplacé par la barre automatique
      ],
    );
  }

  // Carte de matière modernisée (même modèle partout)
  Widget _buildModernSubjectCard(SubjectModel subject, int index, {bool isHorizontal = false}) {
    // Couleurs alternées pour plus de variété
    final cardColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    final cardColor = cardColors[(cardColors.length - 1 - index) % cardColors.length];

    return Container(
      height: isHorizontal ? 180 : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToSubjectDetail(subject),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Header de la carte
                Row(
                  children: [
                    // Icône avec gradient
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            cardColor.withOpacity(0.8),
                            cardColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cardColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.book,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Informations principales
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.name ?? 'Nom non disponible',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              subject.code ?? 'Code non disponible',
                              style: TextStyle(
                                color: cardColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Statistiques et badges
                Row(
                  children: [
                    Expanded(
                      child: _buildStatContainer(
                        Icons.description_outlined,
                        '${subject.documentCount ?? 0}', // Nombre réel de documents
                        'Documents',
                        cardColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatContainer(
                        Icons.star_outline,
                        '${subject.credits ?? 0}',
                        'Crédits',
                        cardColor,
                      ),
                    ),
                    if (subject.isFeatured == true) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withOpacity(0.8),
                              Colors.orange,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Recommandée',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                
                if (!isHorizontal) ...[
                  const SizedBox(height: 16),
                  
                  // Bouton d'action principal
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          cardColor.withOpacity(0.8),
                          cardColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _navigateToSubjectDetail(subject),
                        borderRadius: BorderRadius.circular(12),
                        child: const Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Accéder au cours',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatContainer(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCoursesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration vide modernisée
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.school_outlined,
              size: 60,
              color: AppColors.primary.withOpacity(0.6),
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Aucune matière disponible',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          const Text(
            'Contactez l\'administration pour ajouter\ndes matières à votre profil académique.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Bouton d'action
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact administration - Fonctionnalité à venir')),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.contact_support,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Contacter l\'administration',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Contenu moderne pour les autres onglets
  Widget _buildModernHistoryContent() {
    return const ConsultationHistoryScreen();
  }

  Widget _buildModernQuizContent() {
  return QuizListScreen(accessToken: _accessToken ?? '');
  }
  Widget _buildModernProjectsContent() {
  return ProjectsListScreen(accessToken: _accessToken ?? '');
  }

  Widget _buildComingSoonContent(String title, IconData icon, Color color, String description) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.8),
                    color,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(icon, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: const Text(
                'Bientôt disponible',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildModernBottomNavBar() {
  return Container(
    height: 90, // Plus haute
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Espacement des bords
    decoration: BoxDecoration(
      color: Colors.white, // Background blanc opaque
      borderRadius: BorderRadius.circular(30), // Coins arrondis complets
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.15),
          spreadRadius: 0,
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          spreadRadius: 0,
          blurRadius: 15,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildModernNavItem(Icons.home_outlined, Icons.home, 'Accueil', 0),
        _buildModernNavItem(Icons.school_outlined, Icons.school, 'Cours', 1),
        _buildModernNavItem(Icons.history_outlined, Icons.history, 'Historique', 2),
        _buildModernNavItem(Icons.favorite_outline, Icons.favorite, 'Favoris', 3),
        _buildModernNavItem(Icons.quiz_outlined, Icons.quiz, 'Quiz', 4),
        _buildModernNavItem(Icons.work_outline, Icons.work, 'Projets', 5),
      ],
    ),
  );
}

Widget _buildModernNavItem(IconData inactiveIcon, IconData activeIcon, String label, int index) {
  final isActive = _currentIndex == index;
  
  return GestureDetector(
    onTap: () => _onNavTap(index),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Container pour l'icône avec background primary seulement si actif
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: isActive ? 44 : 36,
            height: isActive ? 44 : 36,
            decoration: isActive ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ) : null, // Pas de décoration pour les inactifs
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : inactiveIcon,
                  key: ValueKey('${index}_$isActive'),
                  color: isActive 
                    ? Colors.white 
                    : AppColors.textSecondary,
                  size: isActive ? 22 : 20,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Label avec animation
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              color: isActive 
                ? AppColors.primary 
                : AppColors.textSecondary,
              fontSize: isActive ? 11 : 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}

// Version alternative avec effet de bulle plus prononcé
Widget _buildModernBottomNavBarBubble() {
  return Container(
    height: 85,
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withOpacity(0.9),
          AppColors.primary,
          AppColors.primary.withOpacity(0.8),
        ],
      ),
      borderRadius: BorderRadius.circular(50),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.4),
          spreadRadius: 0,
          blurRadius: 25,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBubbleNavItem(Icons.home_outlined, Icons.home, 'Accueil', 0),
        _buildBubbleNavItem(Icons.school_outlined, Icons.school, 'Cours', 1),
        _buildBubbleNavItem(Icons.history_outlined, Icons.history, 'Historique', 2),
        _buildBubbleNavItem(Icons.favorite_outline, Icons.favorite, 'Favoris', 3),
        _buildBubbleNavItem(Icons.quiz_outlined, Icons.quiz, 'Quiz', 4),
        _buildBubbleNavItem(Icons.work_outline, Icons.work, 'Projets', 5),
      ],
    ),
  );
}

Widget _buildBubbleNavItem(IconData inactiveIcon, IconData activeIcon, String label, int index) {
  final isActive = _currentIndex == index;
  
  return GestureDetector(
    onTap: () => _onNavTap(index),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      padding: EdgeInsets.symmetric(
        vertical: 10,
        horizontal: isActive ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: isActive 
          ? Colors.white.withOpacity(0.25)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(70),
        border: isActive 
          ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
          : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isActive ? 40 : 32,
            height: isActive ? 40 : 32,
            decoration: BoxDecoration(
              color: isActive 
                ? Colors.white 
                : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: isActive ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.4),
                  spreadRadius: 0,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive 
                ? AppColors.primary 
                : Colors.white.withOpacity(0.8),
              size: isActive ? 20 : 18,
            ),
          ),
          
          if (isActive) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildModernDrawer() {
    return Drawer(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? const Color(0xFF121212) 
          : Colors.white,
      child: Column(
        children: [
          // ✨ Header utilisateur avec icônes éducatives flottantes
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withOpacity(0.85),
                  AppColors.primary.withOpacity(0.7),
                ],
              ),
            ),
            child: Stack(
              children: [
                // ✨ Icônes éducatives flottantes
                ..._buildDrawerFloatingIcons(),
                
                // Contenu principal
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar à gauche
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person,
                            size: 30,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Informations à droite
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nom d'utilisateur
                              Text(
                                widget.user.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              // Niveau et filière (si disponibles)
                              if (widget.studentProfile != null) ...[
                                const SizedBox(height: 8),
                                
                                // Badge niveau
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.school,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          widget.studentProfile!.levelDisplay,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.95),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 6),
                                
                                // Filière
                                Text(
                                  widget.studentProfile!.majorDisplay,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildModernDrawerItem(
                  icon: Icons.person_outline,
                  title: 'Mon Profil',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          user: widget.user,
                          studentProfile: widget.studentProfile,
                        ),
                      ),
                    );
                  },
                ),
                _buildModernDrawerItem(
                  icon: Icons.track_changes,
                  title: 'Mes activités',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      ),
                    );
                  },
                ),

                _buildModernDrawerItem(
                icon: Icons.notifications_outlined,
                title: 'Paramètres de notifications',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationPreferencesScreen(),
                    ),
                  );
                },
              ),
               
                _buildModernDrawerItem(
                  icon: Icons.info_outline,
                  title: 'À propos',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Divider(),
                ),
                _buildModernDrawerItem(
                  icon: Icons.logout,
                  title: 'Se déconnecter',
                  onTap: _handleLogout,
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDestructive 
                ? AppColors.error.withOpacity(0.1)
                : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? AppColors.error : AppColors.primary,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('À propos de Courati'),
        content: const Text(
          'Courati est une plateforme éducative moderne dédiée aux étudiants.\n\nVersion 1.0.0\nDéveloppé avec Flutter',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context); // Fermer le drawer
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // ✅ AMÉLIORATION : Afficher un loader pendant le logout
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Déconnexion (appel API + nettoyage local)
        await StorageService.logout();
        
        if (mounted) {
          // Fermer le loader
          Navigator.pop(context);
          
          // Rediriger vers login
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          
          // Message de confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Déconnexion réussie'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Erreur logout: $e');
        
        if (mounted) {
          // Fermer le loader
          Navigator.pop(context);
          
          // ✅ MÊME EN CAS D'ERREUR, on déconnecte localement
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          
          // Afficher un avertissement (mais pas bloquer)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Déconnexion locale effectuée\n(Erreur serveur: $e)'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  // ✨ AMÉLIORÉ : Navigation vers détail matière avec token valide
  Future<void> _navigateToSubjectDetail(SubjectModel subject) async {
    // Récupérer un token valide avant navigation
    final token = await _getValidToken();
    if (token == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubjectDetailScreen(
          subject: subject,
          accessToken: token,
        ),
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  IconData _getTimeIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny;
    if (hour < 18) return Icons.wb_sunny_outlined;
    return Icons.nightlight_round;
  }
}