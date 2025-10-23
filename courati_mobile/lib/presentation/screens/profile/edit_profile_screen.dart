// 📁 lib/presentation/screens/profile/edit_profile_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/student_profile_model.dart';
import '../../../data/models/level_model.dart';
import '../../../data/models/major_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import 'change_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  final StudentProfileModel? studentProfile;

  const EditProfileScreen({
    super.key,
    required this.user,
    this.studentProfile,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // CHANGÉ: Utiliser les nouveaux modèles
  LevelModel? _selectedLevel;
  MajorModel? _selectedMajor;
  List<LevelModel> _availableLevels = [];
  List<MajorModel> _availableMajors = [];
  
  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isLoadingChoices = false;
  String? _choicesError;

  // Préfixe téléphone pour la Mauritanie
  final String _phonePrefix = '+222';

  @override
  void initState() {
    super.initState();
    _initializeFields();
    _addTextListeners();
    if (widget.studentProfile != null) {
      _loadChoices();
    }
  }

  void _initializeFields() {
    _firstNameController.text = widget.user.firstName ?? '';
    _lastNameController.text = widget.user.lastName ?? '';
    _usernameController.text = widget.user.username;
    _emailController.text = widget.user.email;
    
    if (widget.studentProfile != null) {
      // Enlever le préfixe +222 pour l'affichage
      String phoneNumber = widget.studentProfile!.phoneNumber;
      if (phoneNumber.startsWith(_phonePrefix)) {
        phoneNumber = phoneNumber.substring(_phonePrefix.length).trim();
      }
      _phoneController.text = phoneNumber;
      
      // CHANGÉ: NE PAS initialiser _selectedLevel et _selectedMajor ici
      // Attendre que les choix soient chargés depuis l'API
    }
  }

  void _addTextListeners() {
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _usernameController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  // NOUVEAU: Associer le profil aux choix chargés
  void _matchProfileToChoices() {
    if (widget.studentProfile != null && 
        _availableLevels.isNotEmpty && 
        _availableMajors.isNotEmpty) {
      
      // Trouver le niveau correspondant par ID
      if (widget.studentProfile!.level != null) {
        _selectedLevel = _availableLevels.firstWhere(
          (level) => level.id == widget.studentProfile!.level!.id,
          orElse: () => _availableLevels.first,
        );
      }
      
      // Trouver la filière correspondante par ID
      if (widget.studentProfile!.major != null) {
        _selectedMajor = _availableMajors.firstWhere(
          (major) => major.id == widget.studentProfile!.major!.id,
          orElse: () => _availableMajors.first,
        );
      }
      
      print('🔗 Profil associé: Level ${_selectedLevel?.name}, Major ${_selectedMajor?.name}');
    }
  }

  // MODIFIÉ: Charger les choix depuis l'API et associer le profil
  Future<void> _loadChoices() async {
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

      // AJOUTÉ: Associer le profil aux choix chargés
      _matchProfileToChoices();

      print('✅ Choix chargés pour édition: ${_availableLevels.length} niveaux, ${_availableMajors.length} filières');
      
    } catch (e) {
      print('❌ Erreur chargement choix: $e');
      setState(() {
        _choicesError = 'Erreur de chargement: $e';
        _isLoadingChoices = false;
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await StorageService.getAccessToken();
      if (token == null) {
        throw Exception('Token non disponible');
      }

      // Préparer les données à mettre à jour
      final updates = <String, dynamic>{};
      
      // Informations utilisateur de base
      if (_firstNameController.text.trim() != (widget.user.firstName ?? '')) {
        updates['first_name'] = _firstNameController.text.trim();
      }
      
      if (_lastNameController.text.trim() != (widget.user.lastName ?? '')) {
        updates['last_name'] = _lastNameController.text.trim();
      }
      
      if (_usernameController.text.trim() != widget.user.username) {
        updates['username'] = _usernameController.text.trim();
      }
      
      if (_emailController.text.trim() != widget.user.email) {
        updates['email'] = _emailController.text.trim();
      }

      // Informations profil étudiant
      if (widget.studentProfile != null) {
        String currentPhone = widget.studentProfile!.phoneNumber;
        String newPhone = _phoneController.text.trim();
        
        // Ajouter le préfixe +222 si nécessaire
        if (newPhone.isNotEmpty && !newPhone.startsWith('+')) {
          newPhone = '$_phonePrefix$newPhone';
        }
        
        if (newPhone != currentPhone) {
          updates['phone_number'] = newPhone;
        }
        
        // CHANGÉ: Comparer et envoyer les IDs
        if (_selectedLevel?.id != widget.studentProfile!.level?.id) {
          updates['level'] = _selectedLevel?.id;
        }
        
        if (_selectedMajor?.id != widget.studentProfile!.major?.id) {
          updates['major'] = _selectedMajor?.id;
        }
      }

      if (updates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune modification détectée'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Appel API pour mise à jour
      final response = await ApiService.updateUserProfile(
        token: token,
        updates: updates,
      );

      // Rafraîchir les données du cache après la mise à jour réussie
      final newProfileData = await ApiService.getUserProfile(token);
      
      // Sauvegarder les nouvelles données dans le cache
      final userData = {
        'user': newProfileData,
        'student_profile': newProfileData['user_type'] == 'student' ? {
          'id': null,
          'user': newProfileData['username'],
          'phone_number': newProfileData['phone_number'],
          'level': newProfileData['level'],
          'major': newProfileData['major'],
          'is_verified': newProfileData['is_verified'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        } : null,
      };
      
      await StorageService.saveUserData(jsonEncode(userData));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );

        // Retourner vers l'écran profil avec les nouvelles données
        Navigator.pop(context, {
          'updated': true,
          'user_data': newProfileData,
        });
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la mise à jour: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Modifier le profil',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primary.withOpacity(0.8),
              ],
            ),
          ),
        ),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveChanges,
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Sauvegarder',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Informations personnelles
              _buildPersonalInfoSection(),
              
              const SizedBox(height: 24),
              
              // Informations de contact
              _buildContactInfoSection(),
              
              if (widget.studentProfile != null) ...[
                const SizedBox(height: 24),
                _buildAcademicInfoSection(),
              ],
              
              const SizedBox(height: 24),
              
              // Section sécurité
              _buildSecuritySection(),
              
              const SizedBox(height: 40),
              
              // Bouton de sauvegarde principal
              _buildSaveButton(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _buildSection(
      title: 'Sécurité',
      icon: Icons.security_outlined,
      children: [
        Container(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _showChangePasswordDialog();
            },
            icon: const Icon(Icons.lock_outline),
            label: const Text('Changer le mot de passe'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Changer le mot de passe'),
        content: const Text(
          'Vous allez être redirigé vers un écran sécurisé pour changer votre mot de passe.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: 'Informations personnelles',
      icon: Icons.person_outline,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'Prénom',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 2) {
                    return 'Au moins 2 caractères';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'Nom de famille',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 2) {
                    return 'Au moins 2 caractères';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _usernameController,
          label: 'Nom d\'utilisateur',
          icon: Icons.alternate_email,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le nom d\'utilisateur est requis';
            }
            if (value.trim().length < 3) {
              return 'Au moins 3 caractères requis';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildContactInfoSection() {
    return _buildSection(
      title: 'Informations de contact',
      icon: Icons.contact_mail_outlined,
      children: [
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'L\'email est requis';
            }
            if (!value.contains('@')) {
              return 'Email invalide';
            }
            return null;
          },
        ),
        if (widget.studentProfile != null) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Le téléphone est requis';
              }
              if (value.trim().length < 8) {
                return 'Numéro invalide (min 8 chiffres)';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
              prefixText: '$_phonePrefix ',
              prefixStyle: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              helperText: 'Numéro sans le préfixe +222',
              helperStyle: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAcademicInfoSection() {
    return _buildSection(
      title: 'Informations académiques',
      icon: Icons.school_outlined,
      children: [
        // Gestion du chargement des choix
        if (_isLoadingChoices)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_choicesError != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _choicesError!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadChoices,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          )
        else ...[
          // MODIFIÉ: Dropdown pour niveau avec LevelModel
          DropdownButtonFormField<LevelModel>(
            value: _selectedLevel,
            decoration: InputDecoration(
              labelText: 'Niveau d\'étude',
              prefixIcon: Icon(Icons.school_outlined, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            items: _availableLevels.map((level) {
              return DropdownMenuItem<LevelModel>(
                value: level,
                child: Text(level.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedLevel = value;
                _hasChanges = true;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Veuillez sélectionner un niveau';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // MODIFIÉ: Dropdown pour filière avec MajorModel
          DropdownButtonFormField<MajorModel>(
            value: _selectedMajor,
            decoration: InputDecoration(
              labelText: 'Filière',
              prefixIcon: Icon(Icons.bookmark_outline, color: AppColors.primary),
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            items: _availableMajors.map((major) {
              return DropdownMenuItem<MajorModel>(
                value: major,
                child: Text(major.name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedMajor = value;
                _hasChanges = true;
              });
            },
            validator: (value) {
              if (value == null) {
                return 'Veuillez sélectionner une filière';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_hasChanges && !_isLoading) ? _saveChanges : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Sauvegarde en cours...'),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.save, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _hasChanges ? 'Sauvegarder les modifications' : 'Aucune modification',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}