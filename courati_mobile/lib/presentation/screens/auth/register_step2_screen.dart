// 📁 lib/presentation/screens/auth/register_step2_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../data/models/level_model.dart';
import '../../../data/models/major_model.dart';
import '../../../data/models/registration_choices_model.dart';
import 'otp_verification_screen.dart';

class RegisterStep2Screen extends StatefulWidget {
  final Map<String, String> step1Data;

  const RegisterStep2Screen({
    super.key,
    required this.step1Data,
  });

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  
  // CHANGÉ: Utiliser les nouveaux modèles
  LevelModel? _selectedLevel;
  MajorModel? _selectedMajor;
  List<LevelModel> _availableLevels = [];
  List<MajorModel> _availableMajors = [];
  
  bool _isLoading = false;
  bool _isLoadingChoices = true;
  String? _choicesError;

  @override
  void initState() {
    super.initState();
    _loadRegistrationChoices();
  }

  // NOUVEAU: Charger les choix depuis l'API
  Future<void> _loadRegistrationChoices() async {
    try {
      setState(() {
        _isLoadingChoices = true;
        _choicesError = null;
      });

      final choices = await ApiService.getRegistrationChoices();
      
      setState(() {
        _availableLevels = choices.levels;
        _availableMajors = choices.majors;
        _isLoadingChoices = false;
      });

      print('✅ Choix chargés: ${_availableLevels.length} niveaux, ${_availableMajors.length} filières');
      
    } catch (e) {
      print('❌ Erreur chargement choix: $e');
      setState(() {
        _choicesError = 'Erreur de chargement des options d\'inscription: $e';
        _isLoadingChoices = false;
      });
    }
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('📤 Envoi des données d\'inscription complètes...');
      print('📋 Email principal: ${widget.step1Data['email']}');
      print('📋 Niveau ID: ${_selectedLevel!.id}, Filière ID: ${_selectedMajor!.id}');
      
      // MODIFIÉ: Utiliser les IDs au lieu des codes
      final response = await ApiService.register(
        // Données de l'étape 1
        username: widget.step1Data['username']!,
        email: widget.step1Data['email']!,
        password: widget.step1Data['password']!,
        phoneNumber: widget.step1Data['phone_number']!,
        firstName: widget.step1Data['first_name'],
        lastName: widget.step1Data['last_name'],
        // Données de l'étape 2 - CHANGÉ: utiliser les IDs
        levelId: _selectedLevel!.id,
        majorId: _selectedMajor!.id,
      );

      print('✅ Inscription réussie - OTP envoyé par email');

      if (mounted) {
        // Navigation vers la vérification OTP EMAIL
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailOtpVerificationScreen(
              email: widget.step1Data['email']!,
              userName: '${widget.step1Data['first_name']} ${widget.step1Data['last_name']}'.trim(),
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inscription réussie ! Code de vérification envoyé à ${widget.step1Data['email']}'
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Erreur inscription: $e');
      
      String errorMessage;
      if (e.toString().contains('Ce nom d\'utilisateur existe déjà') ||
          e.toString().contains('Cet email existe déjà') ||
          e.toString().contains('Ce numéro de téléphone existe déjà')) {
        errorMessage = 'Nom d\'utilisateur, email ou téléphone déjà utilisé. Utilisez des informations différentes.';
      } else if (e.toString().contains('400')) {
        errorMessage = 'Données d\'inscription invalides. Vérifiez vos informations.';
      } else if (e.toString().contains('422')) {
        errorMessage = 'Format de données incorrect';
      } else if (e.toString().contains('500')) {
        errorMessage = 'Erreur serveur. Veuillez réessayer plus tard';
      } else {
        errorMessage = 'Erreur d\'inscription: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: _handleRegistration,
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _goBack() {
    Navigator.of(context).pop();
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
          
          // Étape 2 - Active
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
              Icons.school,
              color: Colors.white,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // NOUVEAU: Widget pour afficher l'erreur de chargement
  Widget _buildChoicesError() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _choicesError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRegistrationChoices,
              child: const Text('Réessayer'),
            ),
          ],
        ),
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
          onPressed: _goBack,
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
                'Informations académiques',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Étape 2 sur 3 : Choisissez votre niveau et filière',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              
              // NOUVEAU: Gestion des états de chargement
              if (_isLoadingChoices)
                Card(
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        const Text(
                          'Chargement des options d\'inscription...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_choicesError != null)
                _buildChoicesError()
              else
                // Formulaire dans une carte moderne - MODIFIÉ
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
                      child: Column(
                        children: [
                          // Niveau d'études - MODIFIÉ
                          DropdownButtonFormField<LevelModel>(
                            value: _selectedLevel,
                            decoration: InputDecoration(
                              labelText: 'Niveau d\'études *',
                              hintText: 'Sélectionnez votre niveau',
                              prefixIcon: const Icon(Icons.school_outlined),
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
                            items: _availableLevels.map((level) {
                              return DropdownMenuItem<LevelModel>(
                                value: level,
                                child: Text(
                                  level.name,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _selectedLevel = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Veuillez sélectionner votre niveau d\'études';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Filière - MODIFIÉ
                          DropdownButtonFormField<MajorModel>(
                            value: _selectedMajor,
                            decoration: InputDecoration(
                              labelText: 'Filière d\'études *',
                              hintText: 'Sélectionnez votre filière',
                              prefixIcon: const Icon(Icons.book_outlined),
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
                            items: _availableMajors.map((major) {
                              return DropdownMenuItem<MajorModel>(
                                value: major,
                                child: Text(
                                  major.name,
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                            onChanged: _isLoading ? null : (value) {
                              setState(() {
                                _selectedMajor = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Veuillez sélectionner votre filière d\'études';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          
                          // Bouton de création du compte
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isLoading || _availableLevels.isEmpty) ? null : _handleRegistration,
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
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Création du compte...',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.account_circle, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Créer mon compte étudiant',
                                          style: TextStyle(
                                            fontSize: 16, 
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
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
              
              // Récapitulatif des informations - MODIFIÉ
              if (!_isLoadingChoices && _choicesError == null)
                Card(
                  elevation: 4,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.success,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Récapitulatif de vos informations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Nom complet', '${widget.step1Data['first_name']} ${widget.step1Data['last_name']}'),
                        _buildInfoRow('Nom d\'utilisateur', widget.step1Data['username']!),
                        _buildInfoRow('Email', widget.step1Data['email']!),
                        _buildInfoRow('Téléphone', widget.step1Data['phone_number']!),
                        if (_selectedLevel != null)
                          _buildInfoRow('Niveau sélectionné', _selectedLevel!.name),
                        if (_selectedMajor != null)
                          _buildInfoRow('Filière sélectionnée', _selectedMajor!.name),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Information sur la suite
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.mail_outline,
                      color: Colors.blue,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Un code de vérification sera envoyé à votre email pour finaliser l\'inscription',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}