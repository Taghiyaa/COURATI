import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import '../../../data/models/consultation_item_model.dart';
import '../document/native_document_viewer_screen.dart';
import '../../../data/models/document_model.dart';

class ConsultationHistoryScreen extends StatefulWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  State<ConsultationHistoryScreen> createState() => _ConsultationHistoryScreenState();
}

class _ConsultationHistoryScreenState extends State<ConsultationHistoryScreen> {
  List<ConsultationItemModel> _consultations = [];
  List<ConsultationItemModel> _filteredConsultations = [];
  List<ConsultationItemModel> _recentConsultations = [];
  ConsultationStats? _stats;
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConsultationHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ MODIFIÉ : Appel direct à l'API
  Future<void> _loadConsultationHistory() async {
    setState(() => _isLoading = true);
    
    try {
      // ✅ APPELER DIRECTEMENT getConsultationHistory
      final response = await ApiService.getConsultationHistory('', days: 30, limit: 100);
      
      if (response['success'] == true) {
        final historyResponse = ConsultationHistoryResponse.fromJson(response);
        
        final viewOnlyConsultations = historyResponse.consultations
            .where((item) => item.action == 'view')
            .toList();
        
        final Map<int, ConsultationItemModel> uniqueConsultations = {};
        for (var consultation in viewOnlyConsultations) {
          final docId = consultation.document.id;
          if (!uniqueConsultations.containsKey(docId) || 
              consultation.consultedAt.isAfter(uniqueConsultations[docId]!.consultedAt)) {
            uniqueConsultations[docId] = consultation;
          }
        }
        
        final uniqueList = uniqueConsultations.values.toList()
            ..sort((a, b) => b.consultedAt.compareTo(a.consultedAt));
        
        if (mounted) {
          setState(() {
            _consultations = uniqueList;
            _filteredConsultations = uniqueList;
            _stats = ConsultationStats(
              totalConsultations: uniqueList.length,
              totalViews: uniqueList.length,
              totalDownloads: 0,
              uniqueDocuments: uniqueList.length,
            );
            _recentConsultations = uniqueList.take(5).toList();
          });
        }
      }
    } catch (e) {
      print('Erreur chargement historique consultations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterConsultations(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredConsultations = _consultations;
      } else {
        final queryLower = query.toLowerCase();
        _filteredConsultations = _consultations.where((item) {
          return item.document.title.toLowerCase().contains(queryLower) ||
                 (item.subject?.name.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Historique de consultation',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade600,
                  size: 20,
                ),
              ),
              onPressed: _showClearHistoryDialog,
              tooltip: 'Effacer l\'historique',
            ),
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Chargement de l\'historique...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadConsultationHistory,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildModernSearchBar(),
          ),
          
          if (_recentConsultations.isNotEmpty && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: _buildRecentDocumentsSection(),
            ),
          ],
          
          if (_stats != null && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(
              child: _buildStatsSection(),
            ),
          ],
          
          if (_filteredConsultations.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            _buildConsultationsList(),
            
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterConsultations,
          decoration: InputDecoration(
            hintText: 'Rechercher un document ou matière...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade400),
                    onPressed: () {
                      _searchController.clear();
                      _filterConsultations('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildRecentDocumentsSection() {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Derniers documents consultés',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recentConsultations.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildRecentDocumentCard(_recentConsultations[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDocumentCard(ConsultationItemModel consultation) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _reopenDocument(consultation),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getDocumentTypeIcon(consultation.document.documentType),
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const Spacer(),
                    if (consultation.document.isFavorite)
                      const Icon(
                        Icons.favorite,
                        color: Colors.red,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  consultation.document.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  consultation.subject?.name ?? 'Matière inconnue',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatDateTime(consultation.consultedAt),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Documents consultés',
              '${_stats!.totalConsultations}',
              Icons.visibility,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Cette semaine',
              '${_getWeeklyCount()}',
              Icons.calendar_today,
              Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  int _getWeeklyCount() {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    return _consultations.where((item) => item.consultedAt.isAfter(weekAgo)).length;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationsList() {
    final Map<String, List<ConsultationItemModel>> groupedItems = {};
    for (var item in _filteredConsultations) {
      final date = _formatDate(item.consultedAt);
      groupedItems[date] ??= [];
      groupedItems[date]!.add(item);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final date = groupedItems.keys.elementAt(index);
          final items = groupedItems[date]!;
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ...items.map((item) => _buildConsultationItem(item)).toList(),
              ],
            ),
          );
        },
        childCount: groupedItems.length,
      ),
    );
  }

  Widget _buildConsultationItem(ConsultationItemModel consultation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getDocumentTypeIcon(consultation.document.documentType),
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                consultation.document.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (consultation.document.isFavorite)
              const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 16,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              consultation.subject?.name ?? 'Matière inconnue',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Dernière consultation: ${_formatTime(consultation.consultedAt)}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () => _reopenDocument(consultation),
          tooltip: 'Ré-ouvrir le document',
        ),
        onTap: () => _reopenDocument(consultation),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.visibility_outlined,
              size: 50,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _searchQuery.isNotEmpty ? 'Aucun résultat' : 'Aucune consultation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty 
                ? 'Aucun document trouvé pour "$_searchQuery"'
                : 'Vos documents consultés apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: Colors.red.shade600, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Effacer l\'historique'),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir effacer tout votre historique de consultation ? Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearHistory();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }

  /// ✅ MODIFIÉ : Appel direct à l'API
  Future<void> _clearHistory() async {
    try {
      final response = await ApiService.clearConsultationHistory('');
      
      if (response['success'] == true) {
        if (mounted) {
          setState(() {
            _consultations.clear();
            _filteredConsultations.clear();
            _recentConsultations.clear();
            _stats = ConsultationStats(
              totalConsultations: 0,
              totalViews: 0,
              totalDownloads: 0,
              uniqueDocuments: 0,
            );
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Historique effacé'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'effacement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// ✅ MODIFIÉ : Pour le viewer, on garde getAccessToken
  Future<void> _reopenDocument(ConsultationItemModel consultation) async {
    try {
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) return;
      
      final documentModel = DocumentModel(
        id: consultation.document.id,
        title: consultation.document.title,
        description: 'Document consulté depuis l\'historique',
        documentType: consultation.document.documentType,
        fileUrl: '',
        fileSizeMb: consultation.document.fileSizeMb ?? 0.0,
        isActive: true,
        isPremium: false,
        downloadCount: 0,
        isFavorite: consultation.document.isFavorite,
        isViewed: true,  // ✅ AJOUTER CETTE LIGNE (déjà consulté dans l'historique)
        order: 0,
        uploadedAt: consultation.consultedAt,
      );
      
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NativeDocumentViewerScreen(
              document: documentModel,
              accessToken: accessToken,
            ),
          ),
        );
        
        await ApiService.markDocumentAsViewed('', consultation.document.id);
        _loadConsultationHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  IconData _getDocumentTypeIcon(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'cours':
        return Icons.menu_book;
      case 'td':
        return Icons.assignment;
      case 'tp':
        return Icons.science;
      case 'archive':
        return Icons.archive;
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return 'Aujourd\'hui';
    } else if (dateToCheck == yesterday) {
      return 'Hier';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}