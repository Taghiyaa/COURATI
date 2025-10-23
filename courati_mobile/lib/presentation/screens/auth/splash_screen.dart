// 📁 lib/presentation/screens/auth/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';  // ✅ AJOUT
import 'dart:convert';
import 'dart:math';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/student_profile_model.dart';
import '../../../presentation/providers/auth_provider.dart';  // ✅ AJOUT
import '../main/main_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<IconData> icons = [
    Icons.school,
    Icons.book,
    Icons.computer,
    Icons.edit,
    Icons.science,
    Icons.calculate,
    Icons.menu_book,
    Icons.lightbulb,
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      // ✅ AJOUT : Initialiser AuthProvider (initialise Firebase si connecté)
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();

      await Future.delayed(const Duration(seconds: 3));

      final isLoggedIn = await StorageService.isLoggedIn();

      if (isLoggedIn) {
        final userDataString = await StorageService.getUserData();
        if (userDataString != null) {
          try {
            final userData = jsonDecode(userDataString);
            final user = UserModel.fromJson(userData['user']);
            final studentProfile = userData['student_profile'] != null
                ? StudentProfileModel.fromJson(userData['student_profile'])
                : null;

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => MainScreen(
                    user: user,
                    studentProfile: studentProfile,
                  ),
                ),
              );
            }
            return;
          } catch (e) {
            print('❌ Erreur parsing user data: $e');
            await StorageService.logout();
          }
        }
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      print('❌ Erreur splash screen: $e');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildBackgroundIcons(Size size) {
    final random = Random();
    return List.generate(15, (index) {
      final icon = icons[random.nextInt(icons.length)];
      final top = random.nextDouble() * size.height;
      final left = random.nextDouble() * size.width;
      final iconSize = 30 + random.nextInt(40);

      return Positioned(
        top: top,
        left: left,
        child: Icon(
          icon,
          color: AppColors.primary.withOpacity(0.06),
          size: iconSize.toDouble(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          ..._buildBackgroundIcons(size),
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/images/logo.png",
                      width: 300,
                      height: 300,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}