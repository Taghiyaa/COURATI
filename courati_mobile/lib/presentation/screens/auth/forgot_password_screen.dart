// 📁 lib/presentation/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';
import 'login_screen.dart';
import 'register_step1_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Étape 1: Demande email
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isRequestLoading = false;
  bool _autoValidateEmail = false;
  
  // Étape 2: Vérification OTP + Nouveau mot de passe
  final _resetFormKey = GlobalKey<FormState>();
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isResetLoading = false;
  bool _autoValidateReset = false;
  
  // Timer pour renvoi OTP
  bool _canResendOtp = false;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  String? _userEmail;

  @override
  void dispose() {
    _emailController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ÉTAPE 1: Demander l'email
  Future<void> _handleEmailRequest() async {
    setState(() {
      _autoValidateEmail = true;
    });

    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _isRequestLoading = true;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      print('Demande de réinitialisation pour: $email');

      final response = await ApiService.requestPasswordReset(email: email);

      if (response['success'] == true) {
        _userEmail = email;
        _startResendTimer();
        
        setState(() {
          _currentStep = 1;
        });
        
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );

        _showMessage(
          response['message'] ?? 'Code de réinitialisation envoyé par email',
          isError: false,
        );

        // Focus automatique sur le premier champ OTP après navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_focusNodes.isNotEmpty) {
            _focusNodes[0].requestFocus();
          }
        });
      } else {
        _showMessage('Erreur lors de la demande de réinitialisation', isError: true);
      }

    } catch (e) {
      print('Erreur demande réinitialisation: $e');
      _showMessage(
        'Erreur: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    }

    setState(() {
      _isRequestLoading = false;
    });
  }

  // ÉTAPE 2: Vérifier OTP et définir nouveau mot de passe
  Future<void> _handlePasswordReset() async {
    setState(() {
      _autoValidateReset = true;
    });

    if (!_resetFormKey.currentState!.validate()) return;
    
    final otpCode = _getOtpCode();
    if (otpCode.length != 6) {
      _showMessage('Veuillez saisir le code complet', isError: true);
      return;
    }

    setState(() {
      _isResetLoading = true;
    });

    try {
      print('Confirmation réinitialisation pour: $_userEmail');

      final response = await ApiService.confirmPasswordReset(
        email: _userEmail!,
        otp: otpCode,
        newPassword: _newPasswordController.text,
      );

      if (response['success'] == true) {
        print('Réinitialisation réussie');
        
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (Route<dynamic> route) => false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Mot de passe réinitialisé avec succès !'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        _showMessage('Erreur lors de la réinitialisation', isError: true);
      }

    } catch (e) {
      print('Erreur réinitialisation: $e');
      
      String errorMessage;
      if (e.toString().contains('Code de réinitialisation invalide') ||
          e.toString().contains('400')) {
        errorMessage = 'Code de réinitialisation invalide ou expiré';
        _clearOtpFields();
      } else {
        errorMessage = 'Erreur: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      _showMessage(errorMessage, isError: true);
    }

    setState(() {
      _isResetLoading = false;
    });
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _canResendOtp = false;
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() {
            _resendCountdown--;
          });
        } else {
          setState(() {
            _canResendOtp = true;
          });
          timer.cancel();
        }
      }
    });
  }

  Future<void> _resendResetOtp() async {
    if (!_canResendOtp || _userEmail == null) return;

    try {
      await ApiService.requestPasswordReset(email: _userEmail!);
      _showMessage('Nouveau code envoyé par email', isError: false);
      _startResendTimer();
      _clearOtpFields();
    } catch (e) {
      _showMessage('Erreur lors du renvoi du code', isError: true);
    }
  }

  String _getOtpCode() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_getOtpCode().length == 6) {
          _handlePasswordReset();
        }
      }
    }
  }

  void _onFieldChanged(String value) {
    if (_autoValidateEmail || _autoValidateReset) {
      _emailFormKey.currentState?.validate();
      _resetFormKey.currentState?.validate();
    }
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  void _goToLogin() {
    Navigator.of(context).pop();
  }

  void _goToRegister() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const RegisterStep1Screen(),
      ),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: Duration(seconds: isError ? 4 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_currentStep == 0 ? 'Mot de passe oublié' : 'Nouveau mot de passe'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToLogin,
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildEmailRequestStep(),
            _buildPasswordResetStep(),
          ],
        ),
      ),
    );
  }

  // ÉTAPE 1: Demande d'email
  Widget _buildEmailRequestStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // Carte principale
          Card(
            elevation: 8,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _emailFormKey,
                autovalidateMode: _autoValidateEmail 
                    ? AutovalidateMode.onUserInteraction 
                    : AutovalidateMode.disabled,
                child: Column(
                  children: [
                    // Icône
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_reset,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Mot de passe oublié ?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    const Text(
                      'Pas de problème ! Entrez votre email pour recevoir un code de réinitialisation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    TextFormField(
                      controller: _emailController,
                      onChanged: _onFieldChanged,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Adresse email',
                        hintText: 'votre.email@exemple.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: AppColors.surfaceSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'L\'email est requis';
                        }
                        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        if (!emailRegex.hasMatch(value.trim())) {
                          return 'Format d\'email invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isRequestLoading ? null : _handleEmailRequest,
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
                        child: _isRequestLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Envoyer le code de réinitialisation',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vous vous souvenez ? ',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: _goToLogin,
                child: const Text(
                  'Se connecter',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ÉTAPE 2: Vérification OTP + Nouveau mot de passe
  Widget _buildPasswordResetStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _resetFormKey,
        autovalidateMode: _autoValidateReset 
            ? AutovalidateMode.onUserInteraction 
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Carte OTP
            Card(
              elevation: 8,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mail_outline,
                        size: 30,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Code de vérification',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      'Code envoyé à $_userEmail',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Champs OTP avec style amélioré
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) {
                        return Container(
                          width: 45,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            enabled: !_isResetLoading,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: const EdgeInsets.all(0),
                              filled: true,
                              fillColor: AppColors.surfaceSoft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.error,
                                  width: 1,
                                ),
                              ),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) => _onOtpChanged(index, value),
                            onTap: () {
                              _otpControllers[index].selection = TextSelection(
                                baseOffset: 0,
                                extentOffset: _otpControllers[index].text.length,
                              );
                            },
                          ),
                        );
                      }),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Renvoi OTP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Code non reçu ? ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        TextButton(
                          onPressed: _canResendOtp && !_isResetLoading ? _resendResetOtp : null,
                          child: Text(
                            _canResendOtp ? 'Renvoyer' : 'Renvoyer dans ${_resendCountdown}s',
                            style: TextStyle(
                              color: _canResendOtp ? AppColors.primary : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Carte nouveau mot de passe
            Card(
              elevation: 4,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nouveau mot de passe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _newPasswordController,
                      onChanged: _onFieldChanged,
                      obscureText: _obscureNewPassword,
                      decoration: InputDecoration(
                        labelText: 'Nouveau mot de passe *',
                        hintText: 'Entrez votre nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNewPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureNewPassword = !_obscureNewPassword;
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
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Le nouveau mot de passe est requis';
                        }
                        if (value.length < 8) {
                          return 'Au moins 8 caractères';
                        }
                        if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
                          return 'Lettres et chiffres requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _confirmPasswordController,
                      onChanged: _onFieldChanged,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe *',
                        hintText: 'Répétez votre nouveau mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
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
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirmation requise';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isResetLoading ? null : _handlePasswordReset,
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
                        child: _isResetLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Réinitialiser le mot de passe',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}