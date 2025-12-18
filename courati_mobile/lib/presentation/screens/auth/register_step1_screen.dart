// 📁 lib/presentation/screens/auth/register_step1_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_colors.dart';
import 'register_step2_screen.dart';
import 'login_screen.dart';

class RegisterStep1Screen extends StatefulWidget {
  const RegisterStep1Screen({super.key});

  @override
  State<RegisterStep1Screen> createState() => _RegisterStep1ScreenState();
}

class _RegisterStep1ScreenState extends State<RegisterStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _autoValidate = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    setState(() {
      _autoValidate = true;
    });

    if (!_formKey.currentState!.validate()) return;

    // Formater le numéro pour stockage (toujours avec +222)
    String phoneInput = _phoneController.text.trim();
    String formattedPhone;
    
    if (phoneInput.startsWith('+222') && phoneInput.length == 12) {
      formattedPhone = phoneInput;
    } else if (phoneInput.startsWith('222') && phoneInput.length == 11) {
      formattedPhone = '+$phoneInput';
    } else if (phoneInput.length == 8 && RegExp(r'^[2-9]').hasMatch(phoneInput)) {
      formattedPhone = '+222$phoneInput';
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Format de numéro de téléphone invalide'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Créer un objet avec les données de l'étape 1
    final step1Data = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'username': _usernameController.text.trim(),
      'email': _emailController.text.trim().toLowerCase(),
      'phone_number': formattedPhone,
      'password': _passwordController.text,
    };

    print('Données étape 1 collectées: ${step1Data.keys}');
    print('Email principal: ${step1Data['email']}');
    print('Numéro formaté: $formattedPhone');

    // Navigation vers l'étape 2 avec les données
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterStep2Screen(step1Data: step1Data),
      ),
    );
  }

  void _goToLogin() {
    Navigator.of(context).pop();
  }

  void _onFieldChanged(String value) {
    if (_autoValidate) {
      _formKey.currentState?.validate();
    }
  }

  // Validation email renforcée
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'email est requis';
    }
    
    final email = value.trim().toLowerCase();
    
    // Validation format basique
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Format d\'email invalide';
    }
    
    // Vérifications supplémentaires
    if (email.length > 254) {
      return 'L\'email est trop long';
    }
    
    if (email.contains('..') || email.startsWith('.') || email.endsWith('.')) {
      return 'Format d\'email invalide (points consécutifs)';
    }
    
    return null;
  }

  // Validation téléphone mauritanien
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est requis';
    }
    
    // Nettoyer le numéro
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    // Vérifier formats acceptés
    if (cleanPhone.startsWith('+222') && cleanPhone.length == 12) {
      return null; // Format: +22249594002
    } else if (cleanPhone.startsWith('222') && cleanPhone.length == 11) {
      return null; // Format: 22249594002
    } else if (cleanPhone.length == 8 && RegExp(r'^[2-9]').hasMatch(cleanPhone)) {
      return null; // Format: ********
    } else {
      return 'Format invalide. Ex: 49594002, 22249594002, ou +22249594002';
    }
  }

  // Validation mot de passe
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une lettre et un chiffre';
    }
    
    return null;
  }

  // Validation confirmation mot de passe
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }
    
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    
    return null;
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Étape 1 - Active
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
              Icons.person,
              color: Colors.white,
              size: 18,
            ),
          ),
          
          // Ligne de connexion 1-2
          Container(
            width: 40,
            height: 2,
            color: AppColors.primary.withOpacity(0.3),
          ),
          
          // Étape 2 - Inactive
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.school,
              color: AppColors.primary.withOpacity(0.5),
              size: 18,
            ),
          ),
          
          // Ligne de connexion 2-3
          Container(
            width: 40,
            height: 2,
            color: AppColors.primary.withOpacity(0.3),
          ),
          
          // Étape 3 - Inactive
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.verified,
              color: AppColors.primary.withOpacity(0.5),
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
        title: const Text('Inscription'),
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
              
              // Titre et sous-titre
              const Text(
                'Créer votre compte',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Étape 1 sur 3 : Vos informations personnelles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              
              // Formulaire dans une carte moderne
              Card(
                elevation: 8,
                shadowColor: Colors.black12,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidate 
                        ? AutovalidateMode.onUserInteraction 
                        : AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        // Row pour Prénom et Nom
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameController,
                                onChanged: _onFieldChanged,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Prénom *',
                                  hintText: 'Votre prénom',
                                  prefixIcon: const Icon(Icons.person_outline),
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
                                    return 'Requis';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Min 2 caractères';
                                  }
                                  if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(value.trim())) {
                                    return 'Lettres uniquement';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastNameController,
                                onChanged: _onFieldChanged,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Nom *',
                                  hintText: 'Votre nom',
                                  prefixIcon: const Icon(Icons.person_outline),
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
                                    return 'Requis';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Min 2 caractères';
                                  }
                                  if (!RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(value.trim())) {
                                    return 'Lettres uniquement';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Nom d'utilisateur
                        TextFormField(
                          controller: _usernameController,
                          onChanged: _onFieldChanged,
                          decoration: InputDecoration(
                            labelText: 'Nom d\'utilisateur *',
                            hintText: 'Choisissez un nom unique',
                            prefixIcon: const Icon(Icons.alternate_email),
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
                              return 'Le nom d\'utilisateur est requis';
                            }
                            if (value.trim().length < 3) {
                              return 'Au moins 3 caractères';
                            }
                            if (value.trim().length > 20) {
                              return 'Maximum 20 caractères';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                              return 'Lettres, chiffres et _ uniquement';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // Email
                        TextFormField(
                          controller: _emailController,
                          onChanged: _onFieldChanged,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email *',
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
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 20),
                        
                        // Téléphone
                        TextFormField(
                          controller: _phoneController,
                          onChanged: _onFieldChanged,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
                            LengthLimitingTextInputFormatter(12),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Téléphone *',
                            hintText: '49594002',
                            prefixIcon: const Icon(Icons.phone_outlined),
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
                          validator: _validatePhone,
                        ),
                        const SizedBox(height: 20),
                        
                        // Mot de passe
                        TextFormField(
                          controller: _passwordController,
                          onChanged: _onFieldChanged,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe *',
                            hintText: 'Créez un mot de passe sécurisé',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
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
                              borderSide: const BorderSide(color: AppColors.error),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 20),
                        
                        // Confirmation mot de passe
                        TextFormField(
                          controller: _confirmPasswordController,
                          onChanged: _onFieldChanged,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirmer le mot de passe *',
                            hintText: 'Répétez votre mot de passe',
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
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: 20),
                  
                        
                        // Bouton Suivant
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _goToNextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Suivant : Informations académiques',
                                  style: TextStyle(
                                    fontSize: 16, 
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Lien vers connexion
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Vous avez déjà un compte ? ',
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
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}