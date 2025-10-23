import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/document_model.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import 'package:share_plus/share_plus.dart';

class NativeDocumentViewerScreen extends StatefulWidget {
  final DocumentModel document;
  final String accessToken;

  const NativeDocumentViewerScreen({
    super.key,
    required this.document,
    required this.accessToken,
  });

  @override
  State<NativeDocumentViewerScreen> createState() => _NativeDocumentViewerScreenState();
}

class _NativeDocumentViewerScreenState extends State<NativeDocumentViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _localFilePath;
  int _currentPage = 0;
  int _totalPages = 0;
  double _downloadProgress = 0.0;
  bool _isFullScreen = false;
  bool _isDownloadingToPhone = false;
  
  PDFViewController? _pdfViewController;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _downloadProgress = 0.0;
      });

      // ✅ Récupérer token valide
      final accessToken = await StorageService.getValidAccessToken();
      if (accessToken == null) {
        _setError('Session expirée. Veuillez vous reconnecter.');
        return;
      }

      final response = await ApiService.getDocumentViewUrl(
        accessToken,
        widget.document.id,
      );

      if (response != null && response['success'] == true) {
        final viewUrl = response['view_url'] as String?;
        if (viewUrl != null) {
          await _downloadFileForViewing(viewUrl);
        } else {
          _setError('URL de visualisation non disponible');
        }
      } else {
        _setError('Impossible d\'obtenir le document: ${response?['message'] ?? 'Erreur inconnue'}');
      }
    } catch (e) {
      _setError('Erreur de chargement: $e');
    }
  }

  Future<void> _downloadFileForViewing(String url) async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // ✅ NOUVEAU : S'assurer que le fichier a l'extension correcte
      String fileName = widget.document.title;
      
      // Nettoyer le nom (enlever caractères spéciaux)
      fileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      
      // ✅ CRITIQUE : S'assurer qu'il y a une extension .pdf
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        // Si pas d'extension, ajouter .pdf
        if (!fileName.contains('.')) {
          fileName = '$fileName.pdf';
        } else {
          // Si autre extension, remplacer par .pdf
          final lastDot = fileName.lastIndexOf('.');
          fileName = '${fileName.substring(0, lastDot)}.pdf';
        }
      }
      
      final filePath = '${tempDir.path}/$fileName';

      print('📥 Téléchargement vers cache: $filePath');
      print('📄 Nom du fichier: $fileName');

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _downloadProgress = received / total;
            });
            print('📊 Progression: ${(_downloadProgress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      if (mounted) {
        setState(() {
          _localFilePath = filePath;
          _isLoading = false;
          _hasError = false;
        });
        print('✅ Fichier en cache: $filePath');
      }
    } catch (e) {
      _setError('Erreur de téléchargement: $e');
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _isFullScreen ? null : _buildModernAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadDocument,
        color: AppColors.primary,
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      flexibleSpace: Container(
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
      ),
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.document.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (!_isLoading && !_hasError)
            Row(
              children: [
                Icon(
                  _getFileIcon(),
                  size: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 4),
                Text(
                  _getFileTypeLabel(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (_totalPages > 0) ...[
                  Text(
                    ' • ',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    '$_totalPages pages',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
      actions: [
        // ✅ NOUVEAU : Bouton Partager
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 20),
          ),
          onPressed: _shareFile,
          tooltip: 'Partager',
        ),
        
        // Bouton Menu à 3 points
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
          ),
          onPressed: _showOptionsBottomSheet,
          tooltip: 'Options',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildModernLoadingState();
    }

    if (_hasError) {
      return _buildModernErrorState();
    }

    if (_localFilePath == null) {
      return _buildModernErrorState();
    }

    // Détection du type de fichier
    final fileName = widget.document.title.toLowerCase();
    final documentType = widget.document.documentType?.toLowerCase();
    
    print('📄 Analyse du fichier: $fileName');
    print('📄 Type de document: $documentType');
    
    if (fileName.endsWith('.pdf') || documentType == 'pdf' || _isPdfFile()) {
      print('🔍 Type détecté: PDF');
      return _buildModernPDFViewer();
    } else if (_isImageFile(fileName)) {
      print('🔍 Type détecté: Image');
      return _buildModernImageViewer();
    } else if (_isOfficeFile(fileName)) {
      print('🔍 Type détecté: Office');
      return _buildModernOfficeDocumentViewer();
    } else {
      print('🔍 Type incertain, tentative PDF...');
      return _buildModernPDFViewer();
    }
  }

  // ========== VIEWERS MODERNES ==========

  Widget _buildModernPDFViewer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isFullScreen = !_isFullScreen;
        });
      },
      child: Container(
        color: Colors.grey[100],
        child: PDFView(
          filePath: _localFilePath!,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: 0,
          fitPolicy: FitPolicy.WIDTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            print('📖 PDF rendu avec $pages pages');
            if (mounted) {
              setState(() {
                _totalPages = pages ?? 0;
                _currentPage = 1;
              });
            }
          },
          onError: (error) {
            print('❌ Erreur PDF: $error');
            _setError('Erreur lors de la lecture du PDF');
          },
          onPageError: (page, error) {
            print('❌ Erreur page $page: $error');
          },
          onPageChanged: (int? page, int? total) {
            if (mounted && page != null) {
              setState(() {
                _currentPage = page + 1;
              });
            }
          },
          onViewCreated: (PDFViewController pdfViewController) {
            _pdfViewController = pdfViewController;
            print('📖 PDF Controller créé');
          },
        ),
      ),
    );
  }

  Widget _buildModernImageViewer() {
    return Container(
      color: Colors.grey[100],
      child: PhotoView(
        imageProvider: FileImage(File(_localFilePath!)),
        backgroundDecoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        minScale: PhotoViewComputedScale.contained * 0.5,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        initialScale: PhotoViewComputedScale.contained,
        heroAttributes: PhotoViewHeroAttributes(tag: widget.document.id),
        loadingBuilder: (context, event) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                event == null 
                    ? 'Chargement de l\'image...'
                    : 'Chargement: ${(event.cumulativeBytesLoaded / event.expectedTotalBytes! * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        errorBuilder: (context, error, stackTrace) => _buildModernErrorState(),
      ),
    );
  }

  Widget _buildModernOfficeDocumentViewer() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône du type de document
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withOpacity(0.8),
                    Colors.orange,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.description,
                size: 70,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Titre
            const Text(
              'Document Office',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Carte d'information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _getFileIcon(),
                    size: 48,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.document.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoChip(
                        Icons.insert_drive_file,
                        _getFileTypeLabel(),
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        Icons.data_usage,
                        widget.document.fileSizeFormatted ?? 'N/A',
                        Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Message informatif
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ce document a été téléchargé avec succès.\nUtilisez le menu ⋮ pour le télécharger sur votre téléphone.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange.shade900,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône animée
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.8),
                    AppColors.primary,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.description,
                color: Colors.white,
                size: 60,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Indicateur de progression
            SizedBox(
              width: 200,
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Préparation du document...',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.document.title,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône d'erreur
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.red.shade200,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            
            const SizedBox(height: 32),
            
            const Text(
              'Oups !',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              'Impossible de charger le document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.red.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 32),
            
            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Réessayer',
                    Icons.refresh,
                    AppColors.primary,
                    _loadDocument,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'Retour',
                    Icons.arrow_back,
                    Colors.grey,
                    () => Navigator.pop(context),
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========== CONTRÔLES ET WIDGETS ==========

  Widget? _buildBottomControls() {
    if (_isLoading || _hasError || _isFullScreen) return null;
    
    if (_isPdfFile() && _totalPages > 0) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Bouton page précédente
                _buildNavButton(
                  Icons.chevron_left,
                  _currentPage > 1,
                  () async {
                    if (_currentPage > 1) {
                      await _pdfViewController?.setPage(_currentPage - 2);
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
                
                // Indicateur de page
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.1),
                        AppColors.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_currentPage',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        ' / ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$_totalPages',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bouton page suivante
                _buildNavButton(
                  Icons.chevron_right,
                  _currentPage < _totalPages,
                  () async {
                    if (_currentPage < _totalPages) {
                      await _pdfViewController?.setPage(_currentPage);
                      HapticFeedback.lightImpact();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return null;
  }

  Widget _buildNavButton(IconData icon, bool enabled, VoidCallback onPressed) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: enabled
            ? LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.8),
                  AppColors.primary,
                ],
              )
            : null,
        color: enabled ? null : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.grey[500],
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: isOutlined
            ? null
            : LinearGradient(
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
              ),
        borderRadius: BorderRadius.circular(12),
        border: isOutlined
            ? Border.all(color: color, width: 2)
            : null,
        boxShadow: isOutlined
            ? null
            : [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isOutlined ? color : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isOutlined ? color : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ========== BOTTOM SHEETS & DIALOGS ==========

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // ✅ Télécharger dans Downloads
              _buildBottomSheetItem(
                Icons.download,
                'Télécharger dans Downloads',
                Colors.green,
                () {
                  Navigator.pop(context);
                  _downloadToPhone();
                },
              ),
              
              
              // ✅ Informations
              _buildBottomSheetItem(
                Icons.info_outline,
                'Informations',
                AppColors.primary,
                () {
                  Navigator.pop(context);
                  _showDocumentInfo();
                },
              ),
              
              // ✅ Recharger
              _buildBottomSheetItem(
                Icons.refresh,
                'Recharger',
                Colors.orange,
                () {
                  Navigator.pop(context);
                  _loadDocument();
                },
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showDocumentInfo() {
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
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Informations'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Nom', widget.document.title),
            const SizedBox(height: 12),
            _buildInfoRow('Type', _getFileTypeLabel()),
            const SizedBox(height: 12),
            _buildInfoRow('Taille', widget.document.fileSizeFormatted ?? 'N/A'),
            if (_totalPages > 0) ...[
              const SizedBox(height: 12),
              _buildInfoRow('Pages', '$_totalPages'),
            ],
          ],
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label :',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  // ========== TÉLÉCHARGEMENT DANS DOWNLOADS ==========

  Future<void> _downloadToPhone() async {
    if (_isDownloadingToPhone) return;
    
    setState(() => _isDownloadingToPhone = true);
    
    try {
      // ✅ Récupérer token et URL de téléchargement
      final accessToken = await StorageService.getValidAccessToken();
      if (accessToken == null) {
        setState(() => _isDownloadingToPhone = false);
        return;
      }
      
      final response = await ApiService.downloadDocument(
        accessToken,
        widget.document.id,
      );
      
      if (response != null && response['success'] == true) {
        final downloadUrl = response['download_url'] as String?;
        
        if (downloadUrl != null) {
          // ✅ Télécharger dans Downloads
          final directory = await _getDownloadsDirectory();
          final fileName = _sanitizeFileName(widget.document.title);
          final filePath = '${directory.path}/$fileName';
          
          final dio = Dio();
          await dio.download(
            downloadUrl,
            filePath,
            onReceiveProgress: (received, total) {
              if (total != -1 && mounted) {
                final progress = (received / total * 100).toStringAsFixed(0);
                print('📥 Téléchargement Downloads: $progress%');
              }
            },
          );
          
          if (mounted) {
            _showDownloadSuccess(fileName);
          }
          
          print('✅ Fichier téléchargé dans Downloads: $filePath');
        }
      }
    } catch (e) {
      if (mounted) {
        _showDownloadError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingToPhone = false);
      }
    }
  }

  // ✅ Obtenir le dossier Downloads
  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Android: Dossier Downloads public
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (!await publicDownloads.exists()) {
        await publicDownloads.create(recursive: true);
      }
      return publicDownloads;
    } else if (Platform.isIOS) {
      // iOS: Documents directory
      return await getApplicationDocumentsDirectory();
    } else {
      // Desktop: Downloads du système
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  }

  // ✅ Nettoyer le nom de fichier
  String _sanitizeFileName(String fileName) {
    String sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    if (!sanitized.contains('.')) {
      final extension = _getFileExtension();
      sanitized += extension;
    }
    
    return sanitized;
  }

  String _getFileExtension() {
    switch (widget.document.documentType?.toUpperCase()) {
      case 'COURS':
      case 'TD':
      case 'TP':
        return '.pdf';
      default:
        return '.pdf';
    }
  }

  void _showDownloadSuccess(String fileName) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_done, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Téléchargé: $fileName'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getDownloadLocationMessage(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _getDownloadLocationMessage() {
    if (Platform.isAndroid) {
      return 'Sauvegardé dans Downloads';
    } else if (Platform.isIOS) {
      return 'Sauvegardé dans Fichiers > Courati';
    } else {
      return 'Sauvegardé dans Téléchargements';
    }
  }

  void _showDownloadError(String error) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Erreur téléchargement: $error'),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ========== MÉTHODES UTILITAIRES ==========

  bool _isPdfFile() {
    final fileName = widget.document.title.toLowerCase();
    final documentType = widget.document.documentType?.toLowerCase();
    return fileName.endsWith('.pdf') || 
           documentType == 'pdf' || 
           documentType == 'cours' || 
           documentType == 'td' || 
           documentType == 'tp';
  }

  bool _isImageFile(String fileName) {
    return fileName.endsWith('.jpg') || 
           fileName.endsWith('.jpeg') || 
           fileName.endsWith('.png') || 
           fileName.endsWith('.gif') || 
           fileName.endsWith('.bmp') ||
           fileName.endsWith('.webp');
  }

  bool _isOfficeFile(String fileName) {
    return fileName.endsWith('.pptx') || 
           fileName.endsWith('.ppt') || 
           fileName.endsWith('.docx') || 
           fileName.endsWith('.doc') || 
           fileName.endsWith('.xlsx') || 
           fileName.endsWith('.xls');
  }

  IconData _getFileIcon() {
    final fileName = widget.document.title.toLowerCase();
    
    if (_isPdfFile()) return Icons.picture_as_pdf;
    if (_isImageFile(fileName)) return Icons.image;
    if (fileName.endsWith('.pptx') || fileName.endsWith('.ppt')) return Icons.slideshow;
    if (fileName.endsWith('.docx') || fileName.endsWith('.doc')) return Icons.description;
    if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) return Icons.table_chart;
    
    return Icons.insert_drive_file;
  }

  String _getFileTypeLabel() {
    final fileName = widget.document.title.toLowerCase();
    
    if (_isPdfFile()) return 'PDF';
    if (_isImageFile(fileName)) {
      if (fileName.endsWith('.jpg') || fileName.endsWith('.jpeg')) return 'JPEG';
      if (fileName.endsWith('.png')) return 'PNG';
      if (fileName.endsWith('.gif')) return 'GIF';
      return 'Image';
    }
    if (fileName.endsWith('.pptx') || fileName.endsWith('.ppt')) return 'PowerPoint';
    if (fileName.endsWith('.docx') || fileName.endsWith('.doc')) return 'Word';
    if (fileName.endsWith('.xlsx') || fileName.endsWith('.xls')) return 'Excel';
    
    return 'Document';
  }

  Future<void> _shareFile() async {
    HapticFeedback.lightImpact();
    
    try {
      // Vérifier si le fichier existe en cache
      if (_localFilePath == null || !File(_localFilePath!).existsSync()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Préparation du fichier pour le partage...'),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (_localFilePath == null || !File(_localFilePath!).existsSync()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('Impossible de partager : fichier non disponible'),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
          return;
        }
      }
      
      print('📤 Partage du fichier: $_localFilePath');
      
      // Vérifier la taille et l'extension
      final file = File(_localFilePath!);
      final fileSize = await file.length();
      final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
      final fileName = _localFilePath!.split('/').last;
      
      print('📊 Taille du fichier: $fileSizeMB MB');
      print('📄 Nom du fichier: $fileName');
      print('📎 Extension: ${fileName.split('.').last}');
      
      // ✅ Partager directement (pas de copie nécessaire)
      await Share.shareXFiles(
        [XFile(_localFilePath!)],
        text: 'Document: ${widget.document.title}',
        subject: widget.document.title,
      );
      
      print('📤 Partage lancé avec succès');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.share, color: Colors.white),
                SizedBox(width: 12),
                Text('Partage du document...'),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e, stackTrace) {
      print('❌ Erreur lors du partage: $e');
      print('📋 StackTrace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Erreur lors du partage: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _dio.close();
    
    // ✅ NOUVEAU : Garder le fichier pendant 5 minutes
    // (temps pour Gmail/WhatsApp de l'envoyer)
    if (_localFilePath != null) {
      final filePath = _localFilePath!;
      Future.delayed(const Duration(minutes: 5), () {
        try {
          final file = File(filePath);
          if (file.existsSync()) {
            file.delete();
            print('🗑️ Fichier cache supprimé: $filePath');
          }
        } catch (e) {
          print('⚠️ Erreur suppression: $e');
        }
      });
    }
    
    super.dispose();
  }
}