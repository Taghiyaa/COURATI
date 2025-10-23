// lib/presentation/screens/quiz/quiz_list_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/storage_service.dart';
import '../../../data/models/quiz_model.dart';
import '../../../services/api_service.dart';
import 'quiz_detail_screen.dart';

class QuizListScreen extends StatefulWidget {
  final String accessToken;

  const QuizListScreen({
    super.key,
    required this.accessToken,
  });

  @override
  State<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends State<QuizListScreen> {
  List<QuizModel> _quizzes = [];
  Map<String, List<QuizModel>> _quizzesBySubject = {};
  bool _isLoading = true;
  String _error = '';
  String? _selectedSubject;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  /// ✅ MODIFIÉ : Suppression de la vérification préalable du token
  Future<void> _loadQuizzes() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // ✅ APPELER DIRECTEMENT getMyQuizzes
      // L'API service va gérer la validation du token et la redirection
      final response = await ApiService.getMyQuizzes('');
      
      if (response['success'] == true) {
        final List<dynamic> quizzesJson = response['quizzes'] ?? [];
        
        if (mounted) {
          setState(() {
            _quizzes = quizzesJson
                .map((json) => QuizModel.fromJson(json))
                .toList();
            _groupQuizzesBySubject();
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Erreur de chargement');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _groupQuizzesBySubject() {
    _quizzesBySubject.clear();
    for (var quiz in _quizzes) {
      final subject = '${quiz.subjectCode} - ${quiz.subjectName}';
      if (!_quizzesBySubject.containsKey(subject)) {
        _quizzesBySubject[subject] = [];
      }
      _quizzesBySubject[subject]!.add(quiz);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_quizzes.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadQuizzes,
      child: CustomScrollView(
        slivers: [
          _buildHeader(),
          
          if (_selectedSubject == null)
            _buildSubjectGrid()
          else
            _buildQuizList(),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedSubject != null)
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedSubject = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Retour aux matières',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildStatsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final availableCount = _selectedSubject == null
        ? _quizzes.where((q) => q.canAttempt).length
        : _quizzesBySubject[_selectedSubject]!.where((q) => q.canAttempt).length;
    
    final completedCount = _selectedSubject == null
        ? _quizzes.where((q) => q.userBestScore != null && q.userBestScore! >= q.passingScoreNormalized).length
        : _quizzesBySubject[_selectedSubject]!.where((q) => q.userBestScore != null && q.userBestScore! >= q.passingScoreNormalized).length;

    return Row(
      children: [
        _buildStatCard(availableCount, 'Disponibles', Icons.play_circle_outline, Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard(completedCount, 'Réussis', Icons.check_circle_outline, Colors.green),
        const SizedBox(width: 12),
        _buildStatCard(
          _selectedSubject == null ? _quizzesBySubject.length : _quizzesBySubject[_selectedSubject]!.length,
          _selectedSubject == null ? 'Matières' : 'Quiz',
          _selectedSubject == null ? Icons.folder_outlined : Icons.quiz_outlined,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(int count, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectGrid() {
    final subjects = _quizzesBySubject.keys.toList();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final subject = subjects[index];
            final quizzes = _quizzesBySubject[subject]!;
            final gradients = [
              [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              [Color(0xFF10B981), Color(0xFF059669)],
              [Color(0xFFF59E0B), Color(0xFFEF4444)],
              [Color(0xFFEC4899), Color(0xFF8B5CF6)],
              [Color(0xFF06B6D4), Color(0xFF3B82F6)],
              [Color(0xFF84CC16), Color(0xFF22C55E)],
            ];
            final gradient = gradients[index % gradients.length];

            return _buildSubjectCard(subject, quizzes, gradient);
          },
          childCount: subjects.length,
        ),
      ),
    );
  }

  Widget _buildSubjectCard(String subject, List<QuizModel> quizzes, List<Color> gradient) {
    final completedCount = quizzes
        .where((q) => q.userBestScore != null && q.userBestScore! >= q.passingScoreNormalized)
        .length;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedSubject = subject;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.folder_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${quizzes.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.split(' - ').first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$completedCount/${quizzes.length} réussis',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizList() {
    final quizzes = _quizzesBySubject[_selectedSubject] ?? [];

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildQuizCard(quizzes[index], index),
            );
          },
          childCount: quizzes.length,
        ),
      ),
    );
  }

  Widget _buildQuizCard(QuizModel quiz, int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal];
    final color = colors[index % colors.length];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToQuizDetail(quiz),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.quiz, color: color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (quiz.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              quiz.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildStatusBadge(quiz),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildStatChip(Icons.quiz_outlined, '${quiz.questionCount} Q', color),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.timer_outlined, '${quiz.durationMinutes} min', color),
                    const SizedBox(width: 8),
                    _buildStatChip(Icons.star_outline, '${quiz.passingScoreNormalized.toInt()}/20', color),
                  ],
                ),
                if (quiz.userAttemptsCount > 0) ...[
                  const SizedBox(height: 16),
                  _buildProgressSection(quiz, color),
                ],
                const SizedBox(height: 16),
                _buildActionButton(quiz, color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(QuizModel quiz) {
    Color bgColor;
    Color textColor;
    String text;

    if (!quiz.canAttempt) {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
      text = 'Terminé';
    } else if (quiz.userAttemptsCount == 0) {
      bgColor = Colors.blue[50]!;
      textColor = Colors.blue[700]!;
      text = 'Nouveau';
    } else if (quiz.userBestScore != null && quiz.userBestScore! >= quiz.passingScoreNormalized) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      text = 'Réussi';
    } else {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      text = 'En cours';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(QuizModel quiz, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tentative ${quiz.userAttemptsCount}/${quiz.maxAttempts}',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
              if (quiz.userBestScore != null)
                Text(
                  '${quiz.userBestScore!.toStringAsFixed(1)}/20',
                  style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          if (quiz.userBestScore != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: quiz.bestScorePercentage / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(QuizModel quiz, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: quiz.canAttempt ? () => _navigateToQuizDetail(quiz) : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: quiz.canAttempt ? color : Colors.grey[300],
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(quiz.canAttempt ? Icons.play_arrow : Icons.lock_outline, size: 20),
            const SizedBox(width: 8),
            Text(
              quiz.canAttempt
                  ? (quiz.userAttemptsCount == 0 ? 'Commencer' : 'Reprendre')
                  : 'Non disponible',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucun quiz disponible', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadQuizzes,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// ✅ MODIFIÉ : Pour la navigation, on garde getAccessToken sans validation
  void _navigateToQuizDetail(QuizModel quiz) async {
    final accessToken = await StorageService.getAccessToken();
    if (accessToken == null) return;
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizDetailScreen(
            quiz: quiz,
            accessToken: accessToken,
          ),
        ),
      ).then((_) => _loadQuizzes());
    }
  }
}