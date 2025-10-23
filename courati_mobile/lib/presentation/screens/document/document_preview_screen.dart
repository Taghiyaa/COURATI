// 📁 lib/presentation/screens/document/document_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/document_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import 'native_document_viewer_screen.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DocumentPreviewScreen extends StatefulWidget {
  final DocumentModel document;
  final String accessToken;

  const DocumentPreviewScreen({
    super.key,
    required this.document,
    required this.accessToken,
  });

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isDownloading = false;
  bool _hasViewed = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.document.isFavorite;
    _markAsViewed();
  }

  Future<void> _markAsViewed() async {
    if (_hasViewed) return;
    
    try {
      final accessToken = await StorageService.getValidAccessToken();
      if (accessToken == null) return;
      
      await ApiService.markDocumentAsViewed(accessToken, widget.document.id);
      _hasViewed = true;
    } catch (e) {
      print('Erreur marquage vue: $e');
    }
  }

  Future<void> _downloadDocument() async {
    if (_isDownloading) return;
    
    setState(() => _isDownloading = true);
    
    try {
      final accessToken = await StorageService.getValidAccessToken();
      if (accessToken == null) {
        setState(() => _isDownloading = false);
        return;
      }
      
      final response = await ApiService.downloadDocument(
        accessToken,
        widget.document.id,
      );
      
      if (response != null && response['success'] == true) {
        final downloadUrl = response['download_url'] as String?;
        
        if (downloadUrl != null) {
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
                print('Téléchargement: $progress%');
              }
            },
          );
          
          if (mounted) {
            _showDownloadSuccess(fileName);
          }
          
          print('Fichier téléchargé: $filePath');
        }
      }
    } catch (e) {
      if (mounted) {
        _showDownloadError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final publicDownloads = Directory('/storage/emulated/0/Download');
      if (!await publicDownloads.exists()) {
        await publicDownloads.create(recursive: true);
      }
      return publicDownloads;
    } else if (Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else {
      return await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  }

  String _sanitizeFileName(String fileName) {
    String sanitized = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    
    if (!sanitized.contains('.')) {
      final extension = _getFileExtension();
      sanitized += extension;
    }
    
    return sanitized;
  }

  String _getFileExtension() {
    switch (widget.document.documentType) {
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
              child: Text('Erreur: $error'),
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

  Future<void> _toggleFavorite() async {
    try {
      final accessToken = await StorageService.getValidAccessToken();
      if (accessToken == null) return;
      
      final response = await ApiService.toggleDocumentFavorite(
        accessToken,
        widget.document.id,
      );
      
      if (response != null && response['success'] == true && mounted) {
        final newFavoriteState = response['is_favorite'] ?? !_isFavorite;
        
        setState(() {
          _isFavorite = newFavoriteState;
        });
        
        HapticFeedback.lightImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newFavoriteState ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(newFavoriteState ? 'Ajouté aux favoris' : 'Retiré des favoris'),
              ],
            ),
            backgroundColor: newFavoriteState ? Colors.pink.shade400 : Colors.grey.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur favoris: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Aperçu du document',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        // ✅ Uniquement favori
        IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.red.shade200 : Colors.white,
          ),
          onPressed: _toggleFavorite,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDocumentHeader(),
          const SizedBox(height: 24),
          _buildDocumentInfo(),
          const SizedBox(height: 24),
          if (widget.document.description.isNotEmpty) ...[
            _buildDocumentDescription(),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentHeader() {
    final typeColor = _getDocumentTypeColor(widget.document.documentType);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            typeColor.withOpacity(0.1),
            typeColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getDocumentTypeIcon(widget.document.documentType),
              color: typeColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.document.typeDisplayName,
                    style: TextStyle(
                      color: typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informations du fichier',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.insert_drive_file, 'Type', widget.document.typeDisplayName),
          _buildInfoRow(Icons.data_usage, 'Taille', widget.document.fileSizeFormatted),
          // ✅ Téléchargements supprimé
          if (widget.document.uploadedAt != null)
            _buildInfoRow(Icons.calendar_today, 'Ajouté le', _formatDate(widget.document.uploadedAt!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.document.description,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton Consulter
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openDocumentViewer(),
                icon: const Icon(Icons.visibility),
                label: const Text('Consulter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Bouton Télécharger
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _downloadDocument,
                icon: _isDownloading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download),
                label: Text(_isDownloading ? 'Téléchargement...' : 'Télécharger'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDocumentViewer() async {
    final accessToken = await StorageService.getValidAccessToken();
    if (accessToken == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NativeDocumentViewerScreen(
          document: widget.document,
          accessToken: accessToken,
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}