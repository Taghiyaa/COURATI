// 📁 lib/presentation/screens/auth/email_otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';
import 'login_screen.dart';
import 'register_step1_screen.dart';

class EmailOtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? userName;

  const EmailOtpVerificationScreen({
    super.key,
    required this.email,
    this.userName,
  });

  @override
  State<EmailOtpVerificationScreen> createState() => _EmailOtpVerificationScreenState();
}

class _EmailOtpVerificationScreenState extends State<EmailOtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  
  bool _isLoading = false;
  bool _canResend = false;
  int _resendCountdown = 60;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _canResend = false;
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() {
            _resendCountdown--;
          });
        } else {
          setState(() {
            _canResend = true;
          });
          timer.cancel();
        }
      }
    });
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
          _handleOtpVerification();
        }
      }
    }
  }

  Future<void> _handleOtpVerification() async {
    final otpCode = _getOtpCode();
    
    if (otpCode.length != 6) {
      _showMessage('Veuillez saisir le code complet', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Vérification Email OTP pour: ${widget.email}');
      
      final response = await ApiService.verifyRegistrationOtp(
        email: widget.email,
        otp: otpCode,
      );

      print('Vérification OTP réussie');

      if (mounted) {
        // Redirection vers login après succès (pas de tokens à cette étape)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (Route<dynamic> route) => false,
        );

        _showMessage(
          response['message'] ?? 'Compte créé avec succès ! Vous pouvez maintenant vous connecter.',
          isError: false
        );
      }
      
    } catch (e) {
      print('Erreur vérification Email OTP: $e');
      
      String errorMessage;
      if (e.toString().contains('400') || e.toString().contains('Code OTP invalide')) {
        errorMessage = 'Code de vérification invalide ou expiré';
        _clearOtpFields();
      } else if (e.toString().contains('Session expirée') || 
                 e.toString().contains('Session d\'inscription expirée')) {
        errorMessage = 'Session d\'inscription expirée. Veuillez recommencer l\'inscription.';
        _goToRegistration();
        return;
      } else if (e.toString().contains('429')) {
        errorMessage = 'Trop de tentatives. Veuillez attendre.';
      } else {
        errorMessage = 'Erreur de vérification: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      if (mounted) {
        _showMessage(errorMessage, isError: true);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Note: Vous devrez peut-être ajouter un endpoint de renvoi d'OTP d'inscription
      // Pour l'instant, on simule le renvoi
      await Future.delayed(const Duration(seconds: 2));
      
      print('OTP de vérification renvoyé à: ${widget.email}');
      
      if (mounted) {
        _showMessage('Nouveau code de vérification envoyé par email !', isError: false);
        _startResendTimer();
        _clearOtpFields();
      }
      
    } catch (e) {
      print('Erreur renvoi OTP: $e');
      
      if (mounted) {
        _showMessage('Erreur lors du renvoi du code', isError: true);
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _goToRegistration() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterStep1Screen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: Duration(seconds: isError ? 5 : 3),
        action: isError && message.contains('Session expirée') 
          ? SnackBarAction(
              label: 'Recommencer',
              textColor: Colors.white,
              onPressed: _goToRegistration,
            ) 
          : null,
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Étape 1 - Terminée
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 18,
            ),
          ),
          
          // Ligne de connexion 1-2
          Container(
            width: 40,
            height: 2,
            color: AppColors.success,
          ),
          
          // Étape 2 - Terminée
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 18,
            ),
          ),
          
          // Ligne de connexion 2-3
          Container(
            width: 40,
            height: 2,
            color: AppColors.primary,
          ),
          
          // Étape 3 - Active
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.verified,
              color: Colors.white,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vérification'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goToLogin,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicateur d'étapes moderne
              _buildStepIndicator(),
              
              const SizedBox(height: 20),
              
              // Icône et titre dans une carte
              Card(
                elevation: 8,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      // Icône centrale
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mail_outline,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text(
                        'Vérifiez votre email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Text(
                        'Code envoyé à\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      
                      // Message personnalisé si nom fourni
                      if (widget.userName != null && widget.userName!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Bonjour ${widget.userName} !',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 32),
                      
                    // Champs OTP dans une row avec style moderne
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
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: const TextStyle(
                              fontSize: 20,
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
                            onChanged: (value) {
                              _onOtpChanged(index, value);
                            },
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
                      
                      const SizedBox(height: 32),
                      
                      // Bouton de vérification
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleOtpVerification,
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
                                  'Vérifier le code',
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Bouton de renvoi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Code non reçu ? ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: _canResend && !_isLoading ? _resendOtp : null,
                            child: Text(
                              _canResend
                                  ? 'Renvoyer'
                                  : 'Renvoyer dans ${_resendCountdown}s',
                              style: TextStyle(
                                color: _canResend ? AppColors.primary : AppColors.textSecondary,
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
              
              // Information sur la boîte email
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vérifiez votre boîte de réception et vos spams. Le code expire dans 10 minutes.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Liens de navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: _goToLogin,
                    child: const Text(
                      'Retour à la connexion',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _goToRegistration,
                    child: const Text(
                      'Recommencer',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}