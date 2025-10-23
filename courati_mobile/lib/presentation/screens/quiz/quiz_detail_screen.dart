// lib/presentation/screens/quiz/quiz_detail_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/quiz_model.dart';
import '../../../data/models/quiz_detail_model.dart';
import '../../../data/models/quiz_attempt_model.dart';
import '../../../services/storage_service.dart';
import '../../../services/api_service.dart';
import 'quiz_taking_screen.dart';

class QuizDetailScreen extends StatefulWidget {
  final QuizModel quiz;
  final String accessToken;

  const QuizDetailScreen({
    super.key,
    required this.quiz,
    required this.accessToken,
  });

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  QuizDetailModel? _quizDetail;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadQuizDetails();
  }

  Future<void> _loadQuizDetails() async {
  setState(() {
    _isLoading = true;
    _error = '';
  });

  try {
    // ✅ APPEL DIRECT sans vérification
    final response = await ApiService.getQuizDetail('', widget.quiz.id);

    // ✅ Vérifier si la réponse indique un échec
    if (response is Map && response['success'] == false) {
      // AuthInterceptor a déjà géré la redirection
      if (mounted) {
        setState(() {
          _error = 'Session expirée';
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _quizDetail = QuizDetailModel.fromJson(response);
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Détails du Quiz',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? _buildErrorState()
              : _buildContent(),
      bottomNavigationBar: _isLoading || _error.isNotEmpty
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildContent() {
    if (_quizDetail == null) return const SizedBox();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildInfoSection()),
        SliverToBoxAdapter(child: _buildRulesSection()),
        if (widget.quiz.userAttemptsCount > 0)
          SliverToBoxAdapter(child: _buildAttemptsHistory()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.quiz.subjectCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _quizDetail!.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_quizDetail!.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _quizDetail!.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(20),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(Icons.quiz_outlined, 'Questions',
            '${_quizDetail!.questions.length} questions', Colors.blue),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.timer_outlined, 'Durée',
            '${_quizDetail!.durationMinutes} minutes', Colors.orange),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.star_outline, 'Score minimum',
            '${_quizDetail!.passingScoreNormalized.toStringAsFixed(1)}/20 (${_quizDetail!.passingPercentage.toStringAsFixed(0)}%)', 
            Colors.amber),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.repeat, 'Tentatives',
            '${widget.quiz.userAttemptsCount}/${widget.quiz.maxAttempts}', Colors.purple),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.calculate_outlined, 'Points total',
            '${_quizDetail!.totalPoints.toInt()} points', Colors.green),
      ],
    ),
  );
}

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRulesSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Règles du quiz',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRule('⏱️',
              'Vous disposez de ${_quizDetail!.durationMinutes} minutes pour compléter ce quiz'),
          _buildRule('🔢',
              'Le quiz contient ${_quizDetail!.questions.length} questions'),
          _buildRule('✓',
              'Un score minimum de ${_quizDetail!.passingScoreNormalized.toInt()}/20 est requis pour réussir'),
          _buildRule('🔄',
              'Vous avez droit à ${widget.quiz.maxAttempts} tentative${widget.quiz.maxAttempts > 1 ? 's' : ''}'),
          if (_quizDetail!.showCorrection)
            _buildRule('📖',
                'La correction sera disponible après la soumission'),
        ],
      ),
    );
  }

  Widget _buildRule(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsHistory() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vos tentatives',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tentatives effectuées',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '${widget.quiz.userAttemptsCount}/${widget.quiz.maxAttempts}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                if (widget.quiz.userBestScore != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meilleur score',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${widget.quiz.userBestScore!.toStringAsFixed(1)}/20',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: widget.quiz.userBestScore! >=
                                  widget.quiz.passingScoreNormalized
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadQuizDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
  if (_quizDetail == null) return const SizedBox();

  final hasQuestions = _quizDetail!.questions.isNotEmpty;

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, -4),
        ),
      ],
    ),
    child: SafeArea(
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: (widget.quiz.canAttempt && hasQuestions) ? _startQuiz : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: hasQuestions ? AppColors.primary : Colors.grey[300],
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                !hasQuestions 
                    ? Icons.block 
                    : widget.quiz.canAttempt 
                        ? Icons.play_arrow 
                        : Icons.lock_outline,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                !hasQuestions
                    ? 'Quiz vide'
                    : widget.quiz.canAttempt
                        ? 'Commencer le quiz'
                        : 'Quiz non disponible',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Future<void> _startQuiz() async {
  // VÉRIFICATION: Quiz vide
  if (_quizDetail!.questions.isEmpty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Text('Quiz vide'),
          ],
        ),
        content: const Text(
          'Ce quiz ne contient aucune question.\n\nContactez votre professeur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Commencer le quiz'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Êtes-vous prêt à commencer ?'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le chronomètre démarrera dès que vous appuierez sur Commencer.',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Commencer'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // ✅ APPEL DIRECT
    final response = await ApiService.startQuiz('', widget.quiz.id);

    if (!mounted) return;
    Navigator.pop(context);

    // ✅ Vérifier si la réponse indique un échec
    if (response is Map && response['success'] == false) {
      // AuthInterceptor a déjà géré la redirection
      return;
    }

    final attempt = QuizAttemptModel.fromJson(response['attempt']);
    final quizDetail = QuizDetailModel.fromJson(response['quiz']);

    // ✅ Récupérer le token pour la navigation
    final accessToken = await StorageService.getAccessToken();
    if (accessToken == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizTakingScreen(
          quiz: quizDetail,
          attempt: attempt,
          accessToken: accessToken,
        ),
      ),
    );
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}
}