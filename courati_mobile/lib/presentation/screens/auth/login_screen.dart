import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/student_profile_model.dart';
import '../home/home_screen.dart';
import 'register_step1_screen.dart';
import 'forgot_password_screen.dart';
import '../main/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _autoValidate = false; // Pour contrôler la validation automatique

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    // Activer la validation automatique après le premier essai
    setState(() {
      _autoValidate = true;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('Tentative de connexion...');

      final response = await ApiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
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

      print('Connexion réussie');

      if (mounted) {
        // ✅ CORRECTION : Supprimer toute la pile de navigation
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MainScreen(
              user: response.user,
              studentProfile: response.studentProfile,
            ),
          ),
          (route) => false, // Supprimer toutes les routes précédentes
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connexion réussie !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      print('Erreur connexion: $e');

      String errorMessage;
      if (e.toString().contains('Identifiants invalides') || 
          e.toString().contains('401')) {
        errorMessage = 'Nom d\'utilisateur/email ou mot de passe incorrect';
      } else if (e.toString().contains('Veuillez vérifier votre email')) {
        errorMessage = 'Veuillez d\'abord vérifier votre email avant de vous connecter';
      } else if (e.toString().contains('désactivé')) {
        errorMessage = 'Votre compte est désactivé. Contactez l\'administration.';
      } else {
        errorMessage = 'Erreur de connexion: ${e.toString().replaceAll('Exception: ', '')}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RegisterStep1Screen(),
      ),
    );
  }

  void _onUsernameChanged(String value) {
    // Valider automatiquement si la validation auto est activée
    if (_autoValidate) {
      _formKey.currentState?.validate();
    }
  }

  void _onPasswordChanged(String value) {
    // Valider automatiquement si la validation auto est activée
    if (_autoValidate) {
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 5),

              Center(
                child: Image.asset(
                  "assets/images/logo.png", 
                  width: 200,
                  height: 180,
                ),
              ),
              const SizedBox(height: 0),

              const Text(
                "Bienvenue",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Connectez-vous pour continuer",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Formulaire dans une carte moderne
              Card(
                elevation: 6,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidate 
                        ? AutovalidateMode.onUserInteraction 
                        : AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          onChanged: _onUsernameChanged,
                          decoration: InputDecoration(
                            labelText: AppStrings.username,
                            hintText: 'Email, nom d\'utilisateur ou téléphone',
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: AppColors.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error, width: 1),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Le nom d\'utilisateur est requis';
                            }
                            if (value.trim().length < 2) {
                              return 'Au moins 2 caractères requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          onChanged: _onPasswordChanged,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: AppStrings.password,
                            hintText: 'Votre mot de passe',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceSoft,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error, width: 1),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.error, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le mot de passe est requis';
                            }
                            if (value.length < 3) {
                              return 'Au moins 3 caractères requis';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Bouton de connexion
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              disabledBackgroundColor: AppColors.primary.withOpacity(0.6),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    "Se connecter",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lien mot de passe oublié
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Lien inscription
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Pas encore de compte ? ",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  TextButton(
                    onPressed: _goToRegister,
                    child: const Text(
                      AppStrings.register,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}