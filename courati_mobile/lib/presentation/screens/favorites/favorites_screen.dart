// 📁 lib/presentation/screens/favorites/favorites_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/document_model.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import '../document/native_document_viewer_screen.dart';

class FavoritesScreen extends StatefulWidget {
  final String accessToken;

  const FavoritesScreen({
    super.key,
    required this.accessToken,
  });

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  
  List<DocumentModel> _allDocuments = [];
  List<DocumentModel> _filteredDocuments = [];
  
  // Filtres
  String _searchQuery = '';
  String _selectedType = 'Tous';
  String _selectedSubject = 'Toutes';
  
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _availableTypes = ['Tous'];
  List<String> _availableSubjects = ['Toutes'];

  @override
  void initState() {
    super.initState();
    _loadFavoriteDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ MODIFIÉ : Suppression de la vérification préalable du token
  Future<void> _loadFavoriteDocuments() async {
    setState(() => _isLoading = true);
    
    try {
      // ✅ APPELER DIRECTEMENT getFavorites
      // L'API service va gérer la validation du token et la redirection
      final response = await ApiService.getFavorites('');
      
      print('Debug - Structure de la réponse: $response');
      
      if (response['success'] == true && response.containsKey('favorites')) {
        final favoritesJson = response['favorites'] as List? ?? [];
        
        final documentsJson = favoritesJson
            .where((fav) => fav['favorite_type'] == 'DOCUMENT')
            .map((fav) => fav['document_info'])
            .where((docInfo) => docInfo != null)
            .toList();
        
        print('Debug - Documents trouvés: ${documentsJson.length}');
        print('Debug - Premier document: ${documentsJson.isNotEmpty ? documentsJson.first : "Aucun"}');
        
        setState(() {
          _allDocuments = documentsJson
              .map((json) => _createDocumentFromApiData(json))
              .toList();
          
          _extractFilters();
          _applyFilters();
        });
        
        print('Debug - Documents chargés: ${_allDocuments.length}');
      } else {
        print('Debug - Réponse API sans succès ou sans favoris');
      }
    } catch (e) {
      print('Erreur lors du chargement des favoris: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Méthode pour convertir les données API en DocumentModel
  DocumentModel _createDocumentFromApiData(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['subject_name'] ?? '',
      documentType: json['type'] ?? '',
      fileUrl: json['file'] ?? '',
      fileSizeMb: (json['file_size_mb'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
      isPremium: json['is_premium'] ?? false,
      downloadCount: json['download_count'] ?? 0,
      isFavorite: true,
      order: json['order'] ?? 0,
      uploadedAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  void _extractFilters() {
    final types = _allDocuments
        .map((doc) => doc.typeDisplayName)
        .toSet()
        .toList();
    types.sort();
    _availableTypes = ['Tous', ...types];
    _availableSubjects = ['Toutes'];
  }

  void _applyFilters() {
    setState(() {
      _filteredDocuments = _allDocuments.where((doc) {
        final matchesSearch = _searchQuery.isEmpty ||
            doc.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            doc.description.toLowerCase().contains(_searchQuery.toLowerCase());

        final matchesType = _selectedType == 'Tous' ||
            doc.typeDisplayName == _selectedType;

        final matchesSubject = _selectedSubject == 'Toutes';

        return matchesSearch && matchesType && matchesSubject;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDocumentsList(),
          ),
        ],
      ),
      
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_filteredDocuments.length} document${_filteredDocuments.length > 1 ? 's' : ''} favori${_filteredDocuments.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
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
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un document...',
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
                          _applyFilters();
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
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Filtrer par type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTypes.map((type) => _buildFilterChip(type)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type) {
    final isSelected = _selectedType == type;
    
    Color chipColor;
    IconData chipIcon;
    
    switch (type.toLowerCase()) {
      case 'cours':
        chipColor = Colors.blue;
        chipIcon = Icons.school;
        break;
      case 'td':
        chipColor = Colors.green;
        chipIcon = Icons.assignment;
        break;
      case 'tp':
        chipColor = Colors.orange;
        chipIcon = Icons.science;
        break;
      case 'archive':
        chipColor = Colors.purple;
        chipIcon = Icons.archive;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.description;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedType = type;
            });
            _applyFilters();
          },
          borderRadius: BorderRadius.circular(25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        chipColor.withOpacity(0.8),
                        chipColor,
                      ],
                    )
                  : null,
              color: isSelected ? null : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isSelected ? Colors.transparent : chipColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: chipColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                else
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  chipIcon,
                  size: 18,
                  color: isSelected ? Colors.white : chipColor,
                ),
                const SizedBox(width: 8),
                Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : chipColor,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
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

  Widget _buildDocumentsList() {
    if (_filteredDocuments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadFavoriteDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _filteredDocuments.length,
        itemBuilder: (context, index) {
          final document = _filteredDocuments[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: _buildDocumentCard(document, index),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
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
                    Colors.orange.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                _searchQuery.isNotEmpty || _selectedType != 'Tous' || _selectedSubject != 'Toutes'
                    ? Icons.search_off
                    : Icons.description_outlined,
                size: 60,
                color: Colors.orange.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty || _selectedType != 'Tous'
                  ? 'Aucun résultat'
                  : 'Aucun document favori',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty || _selectedType != 'Tous'
                  ? 'Essayez de modifier vos critères de recherche.'
                  : 'Ajoutez des documents à vos favoris pour les retrouver rapidement ici.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            if (_searchQuery.isNotEmpty || _selectedType != 'Tous') ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedType = 'Tous';
                  });
                  _applyFilters();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Effacer les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(DocumentModel document, int index) {
    final cardColors = [
      Colors.orange,
      Colors.teal,
      Colors.purple,
      Colors.indigo,
      Colors.blue,
      Colors.green,
    ];
    final cardColor = cardColors[index % cardColors.length];

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
          onTap: () => _openDocument(document),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
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
                  child: Icon(
                    _getDocumentIcon(document.documentType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document.description,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              document.typeDisplayName,
                              style: TextStyle(
                                color: cardColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              document.fileSizeFormatted,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.favorite,
                      color: Colors.red,
                      size: 20,
                    ),
                    onPressed: () => _removeFavoriteDocument(document, index),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ MODIFIÉ : Appel direct à l'API
  Future<void> _removeFavoriteDocument(DocumentModel document, int index) async {
    try {
      final response = await ApiService.toggleDocumentFavorite('', document.id);
      
      if (response['success'] == true) {
        setState(() {
          _allDocuments.removeWhere((doc) => doc.id == document.id);
          _extractFilters();
          _applyFilters();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${document.title} supprimé des favoris'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ MODIFIÉ : Pour le viewer, on garde le token du StorageService
  void _openDocument(DocumentModel document) async {
    final accessToken = await StorageService.getAccessToken();
    if (accessToken == null) return;
    
    await ApiService.markDocumentAsViewed('', document.id);
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NativeDocumentViewerScreen(
            document: document,
            accessToken: accessToken,
          ),
        ),
      );
    }
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'img':
      case 'jpg':
      case 'png':
        return Icons.image;
      case 'video':
      case 'mp4':
        return Icons.video_library;
      default:
        return Icons.insert_drive_file;
    }
  }

  
}