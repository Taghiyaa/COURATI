import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_service.dart';
import '../../../data/models/subject_model.dart';
import '../../../data/models/document_model.dart';
import '../../../services/api_service.dart';
import '../document/document_preview_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  final SubjectModel subject;
  final String accessToken;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    required this.accessToken,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  List<DocumentModel> _documents = [];
  List<DocumentModel> _allDocuments = [];
  List<DocumentModel> _favoriteDocuments = [];
  bool _isLoading = true;
  String? _selectedType;
  bool _isDownloading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _documentTypes = [
    {'key': 'COURS', 'label': 'Cours', 'icon': Icons.menu_book, 'color': Colors.blue},
    {'key': 'TD', 'label': 'TD', 'icon': Icons.assignment, 'color': Colors.green},
    {'key': 'TP', 'label': 'TP', 'icon': Icons.science, 'color': Colors.orange},
    {'key': 'ARCHIVE', 'label': 'Archive', 'icon': Icons.archive, 'color': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadFavoriteDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService.getSubjectDocuments(
        '',
        widget.subject.id,
        type: null,
      );
      
      if (response != null && response['success'] == true && mounted) {
        final List<dynamic> documentsJson = response['documents'] ?? [];
        setState(() {
          _allDocuments = documentsJson
              .map((json) => DocumentModel.fromJson(json as Map<String, dynamic>))
              .toList();
          _filterDocuments();
        });
        
        _loadFavoriteDocuments();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur de chargement: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDocumentPreview(DocumentModel document) async {
    final accessToken = await StorageService.getAccessToken();
    if (accessToken == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentPreviewScreen(
          document: document,
          accessToken: accessToken,
        ),
      ),
    );
  }

  Future<void> _loadFavoriteDocuments() async {
    try {
      final response = await ApiService.getFavorites('');
      
      if (response != null && response['success'] == true && mounted) {
        final List<dynamic> allFavorites = response['favorites'] ?? [];
        
        final favoriteDocumentIds = <int>[];
        for (var favorite in allFavorites) {
          if (favorite['favorite_type'] == 'DOCUMENT' && 
              favorite['document_info'] != null) {
            favoriteDocumentIds.add(favorite['document_info']['id'] as int);
          }
        }
        
        setState(() {
          _favoriteDocuments = _allDocuments
              .where((doc) => favoriteDocumentIds.contains(doc.id))
              .toList();
        });
      }
    } catch (e) {
      print('Erreur chargement favoris: $e');
    }
  }

  void _filterDocuments() {
    List<DocumentModel> filtered;
    
    if (_selectedType == null) {
      filtered = List.from(_allDocuments);
    } else {
      filtered = _allDocuments
          .where((doc) => doc.documentType == _selectedType)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((doc) {
        final title = doc.title.toLowerCase();
        final description = doc.description.toLowerCase();
        return title.contains(query) || description.contains(query);
      }).toList();
    }

    setState(() {
      _documents = filtered;
    });
  }

  Future<void> _toggleFavorite(DocumentModel document) async {
    try {
      final response = await ApiService.toggleDocumentFavorite(
        '',
        document.id,
      );
      
      if (response != null && response['success'] == true && mounted) {
        final newFavoriteState = response['is_favorite'] ?? !document.isFavorite;
        
        setState(() {
          final index = _allDocuments.indexWhere((d) => d.id == document.id);
          if (index != -1) {
            _allDocuments[index] = document.copyWith(isFavorite: newFavoriteState);
          }
          _filterDocuments();
        });
        
        await _loadFavoriteDocuments();
        
        _showSnackBar(
          response['message'] ?? 
              (newFavoriteState ? 'Ajouté aux favoris' : 'Retiré des favoris'),
          icon: newFavoriteState ? Icons.favorite : Icons.favorite_border,
          color: newFavoriteState ? Colors.pink : Colors.grey,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur favoris: $e', isError: true);
      }
    }
  }

  void _showFavoriteDocuments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFavoritesBottomSheet(),
    );
  }

  Widget _buildFavoritesBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documents favoris',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.subject.name,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_favoriteDocuments.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _favoriteDocuments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun document favori',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajoutez des documents de cette matière\naux favoris pour les retrouver ici',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _favoriteDocuments.length,
                    itemBuilder: (context, index) {
                      final document = _favoriteDocuments[index];
                      return _buildFavoriteDocumentCard(document);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteDocumentCard(DocumentModel document) {
    final typeColor = _getDocumentTypeColor(document.documentType);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            _navigateToDocumentPreview(document);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: typeColor.withOpacity(0.3)),
                  ),
                  child: Icon(
                    _getDocumentTypeIcon(document.documentType),
                    color: typeColor,
                    size: 24,
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: typeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              document.typeDisplayName,
                              style: TextStyle(
                                color: typeColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${document.fileSizeMb.toStringAsFixed(1)} MB',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (document.downloadCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.download_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${document.downloadCount} téléchargements',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 22,
                      ),
                      onPressed: () async {
                        await _toggleFavorite(document);
                        if (_favoriteDocuments.length <= 1) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.visibility,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _navigateToDocumentPreview(document);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {IconData? icon, Color? color, bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.check_circle),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError 
            ? Colors.red.shade400 
            : (color ?? Colors.green.shade400),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _buildModernAppBar(innerBoxIsScrolled),
          ];
        },
        body: RefreshIndicator(
          onRefresh: () async {
            await _loadDocuments();
            await _loadFavoriteDocuments();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildSearchAndFilters(),
              ),
              _buildDocumentsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar(bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  const Icon(
                    Icons.favorite_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (_favoriteDocuments.isNotEmpty)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_favoriteDocuments.length}',
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
              ),
            ),
            onPressed: _showFavoriteDocuments,
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: AnimatedOpacity(
          opacity: innerBoxIsScrolled ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.subject.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ),
        background: _buildHeaderBackground(),
      ),
    );
  }

  Widget _buildHeaderBackground() {
    return Container(
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
          ..._buildFloatingIcons(),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        const Icon(
                          Icons.code,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.subject.code,
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
                  
                  Text(
                    widget.subject.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Statistiques directement sous le nom
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _buildHeaderBadge(Icons.description, '${_allDocuments.length} documents'),
                      _buildHeaderBadge(Icons.favorite, '${_favoriteDocuments.length} favoris'),
                      _buildHeaderBadge(Icons.star, '${widget.subject.credits} crédits'),
                      if (widget.subject.isFeatured)
                        _buildHeaderBadge(Icons.verified, 'Recommandée'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nouveau widget pour les badges dans le header
  Widget _buildHeaderBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingIcons() {
    final icons = [
      {'icon': Icons.book, 'top': 40.0, 'right': 30.0, 'size': 40.0, 'opacity': 0.1},
      {'icon': Icons.description, 'top': 120.0, 'right': 60.0, 'size': 30.0, 'opacity': 0.08},
      {'icon': Icons.school, 'bottom': 100.0, 'left': 40.0, 'size': 35.0, 'opacity': 0.09},
      {'icon': Icons.menu_book, 'bottom': 60.0, 'right': 80.0, 'size': 25.0, 'opacity': 0.07},
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
          angle: (topValue ?? bottomValue ?? 0.0) / 30,
          child: Icon(
            iconData,
            size: sizeValue,
            color: Colors.white.withOpacity(opacityValue),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildQuickStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                  _filterDocuments();
                });
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un document...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: AppColors.primary,
                  size: 22,
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
                            _filterDocuments();
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _documentTypes.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildFilterChip('Tous', null, Icons.all_inclusive, AppColors.primary);
                }
                final type = _documentTypes[index - 1];
                return _buildFilterChip(
                  type['label'] as String,
                  type['key'] as String,
                  type['icon'] as IconData,
                  type['color'] as Color,
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type, IconData icon, Color color) {
    final isSelected = _selectedType == type;
    final count = type == null
        ? _allDocuments.length
        : _allDocuments.where((doc) => doc.documentType == type).length;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedType = isSelected ? null : type;
              _filterDocuments();
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : color,
                ),
                const SizedBox(width: 6),
                Text(
                  '$label ($count)',
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.8),
                      AppColors.primary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.description,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Chargement des documents...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_documents.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
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
                    Icons.description_outlined,
                    size: 50,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Aucun résultat'
                      : (_selectedType == null
                          ? 'Aucun document disponible'
                          : 'Aucun document de ce type'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Essayez avec d\'autres mots-clés'
                      : 'Les documents apparaîtront ici',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _loadDocuments();
                    await _loadFavoriteDocuments();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildModernDocumentCard(_documents[index]);
          },
          childCount: _documents.length,
        ),
      ),
    );
  }

  Widget _buildModernDocumentCard(DocumentModel document) {
    final typeColor = _getDocumentTypeColor(document.documentType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDocumentPreview(document),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            typeColor.withOpacity(0.8),
                            typeColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _getDocumentTypeIcon(document.documentType),
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  document.typeDisplayName,
                                  style: TextStyle(
                                    color: typeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.insert_drive_file,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${document.fileSizeMb.toStringAsFixed(1)} MB',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: document.isFavorite
                                ? Colors.red.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              document.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: document.isFavorite
                                  ? Colors.red
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            onPressed: () => _toggleFavorite(document),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.visibility,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            onPressed: () => _navigateToDocumentPreview(document),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (document.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      document.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                if (document.downloadCount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${document.downloadCount} téléchargements',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getDocumentTypeColor(String type) {
    switch (type) {
      case 'COURS':
        return Colors.blue;
      case 'TD':
        return Colors.green;
      case 'TP':
        return Colors.orange;
      case 'ARCHIVE':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  IconData _getDocumentTypeIcon(String type) {
    switch (type) {
      case 'COURS':
        return Icons.menu_book;
      case 'TD':
        return Icons.assignment;
      case 'TP':
        return Icons.science;
      case 'ARCHIVE':
        return Icons.archive;
      default:
        return Icons.description;
    }
  }
}