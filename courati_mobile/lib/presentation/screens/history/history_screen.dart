// 📁 lib/presentation/screens/history/history_screen.dart
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      _accessToken = await StorageService.getAccessToken();
      if (_accessToken != null) {
        final response = await ApiService.getHistory(_accessToken!);
        
        if (response != null && response['success'] == true) {
          setState(() {
            _historyItems = List<Map<String, dynamic>>.from(response['history'] ?? []);
          });
        }
      }
    } catch (e) {
      print('Erreur chargement historique: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Activités récentes',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildContent() {
    if (_historyItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _historyItems.length,
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          return _buildHistoryItem(item);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                  Colors.grey.withOpacity(0.1),
                  Colors.grey.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.history_outlined,
              size: 60,
              color: Colors.grey.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucune activité récente',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Consultez des documents pour voir votre activité ici',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final action = item['action']?.toString().toLowerCase() ?? '';
    final actionColor = _getActionColor(action);
    final actionIcon = _getActionIcon(action);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: actionColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(actionIcon, color: actionColor, size: 24),
        ),
        title: Text(
          item['document_name']?.toString() ?? 'Document',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (item['subject_name'] != null)
              Text(
                item['subject_name'].toString(),
                style: TextStyle(color: AppColors.primary, fontSize: 14),
              ),
          ],
        ),
        trailing: item['created_at'] != null
            ? Text(
                _formatTime(DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now()),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              )
            : null,
      ),
    );
  }

  Color _getActionColor(String action) {
    if (action.contains('download') || action.contains('téléchargement')) return Colors.blue;
    if (action.contains('view') || action.contains('consulté') || action.contains('consultation')) return Colors.green;
    if (action.contains('favorite') || action.contains('favori')) return Colors.red;
    return AppColors.primary;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('download') || action.contains('téléchargement')) return Icons.download;
    if (action.contains('view') || action.contains('consulté') || action.contains('consultation')) return Icons.visibility;
    if (action.contains('favorite') || action.contains('favori')) return Icons.favorite;
    return Icons.circle;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes}min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${time.day}/${time.month}';
    }
  }
}