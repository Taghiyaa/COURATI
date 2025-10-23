// lib/presentation/screens/quiz/quiz_taking_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/quiz_detail_model.dart';
import '../../../data/models/quiz_attempt_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/quiz_answer_model.dart';
import '../../../services/api_service.dart';
import '../../../services/storage_service.dart';
import 'quiz_result_screen.dart';

class QuizTakingScreen extends StatefulWidget {
  final QuizDetailModel quiz;
  final QuizAttemptModel attempt;
  final String accessToken;

  const QuizTakingScreen({
    super.key,
    required this.quiz,
    required this.attempt,
    required this.accessToken,
  });

  @override
  State<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends State<QuizTakingScreen> {
  late PageController _pageController;
  int _currentQuestionIndex = 0;
  
  // Réponses de l'utilisateur: Map<questionId, List<choiceIds>>
  final Map<int, List<int>> _userAnswers = {};
  
  // Timer
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _remainingTime = widget.attempt.timeRemaining;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      } else {
        _timer?.cancel();
        _autoSubmit();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onAnswerSelected(int questionId, int choiceId, bool allowMultiple) {
    setState(() {
      if (!_userAnswers.containsKey(questionId)) {
        _userAnswers[questionId] = [];
      }

      if (allowMultiple) {
        // Mode choix multiples
        if (_userAnswers[questionId]!.contains(choiceId)) {
          _userAnswers[questionId]!.remove(choiceId);
        } else {
          _userAnswers[questionId]!.add(choiceId);
        }
      } else {
        // Mode choix unique
        _userAnswers[questionId] = [choiceId];
      }
    });
  }

  Future<void> _autoSubmit() async {
    if (_isSubmitting) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⏱️ Temps écoulé ! Soumission automatique...'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );

    await Future.delayed(const Duration(seconds: 1));
    _submitQuiz();
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    // Préparer les réponses au format API
    final answers = widget.quiz.questions.map((question) {
      return {
        'question_id': question.id,
        'selected_choices': _userAnswers[question.id] ?? [],
      };
    }).toList();

    try {
      // ✅ APPEL DIRECT
      final response = await ApiService.submitQuiz(
        '',  // Token vide
        widget.quiz.id,
        widget.attempt.id,
        answers,
      );

      if (!mounted) return;

      // ✅ Vérifier si la réponse indique un échec
      if (response is Map && response['success'] == false) {
        // AuthInterceptor a déjà géré la redirection
        setState(() => _isSubmitting = false);
        return;
      }

      // ✅ Récupérer le token pour la navigation
      final accessToken = await StorageService.getAccessToken();
      if (accessToken == null) {
        setState(() => _isSubmitting = false);
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            resultData: response['results'],
            quizId: widget.quiz.id,
            accessToken: accessToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isSubmitting = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de soumission: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await _showExitConfirmation();
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildTimerBar(),
            _buildProgressIndicator(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentQuestionIndex = index);
                },
                itemCount: widget.quiz.questions.length,
                itemBuilder: (context, index) {
                  return _buildQuestionPage(widget.quiz.questions[index]);
                },
              ),
            ),
            _buildNavigationBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.quiz.title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () async {
          final shouldExit = await _showExitConfirmation();
          if (shouldExit == true && mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildTimerBar() {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;
    final isLowTime = _remainingTime.inMinutes < 5;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isLowTime ? Colors.red[50] : AppColors.primary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: isLowTime ? Colors.red[200]! : AppColors.primary.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer,
            color: isLowTime ? Colors.red : AppColors.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isLowTime ? Colors.red : AppColors.primary,
              
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'restant${isLowTime ? ' ⚠️' : ''}',
            style: TextStyle(
              fontSize: 14,
              color: isLowTime ? Colors.red : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = (_currentQuestionIndex + 1) / widget.quiz.questions.length;
    final answeredCount = _userAnswers.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentQuestionIndex + 1}/${widget.quiz.questions.length}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: answeredCount == widget.quiz.questions.length
                      ? Colors.green[100]
                      : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$answeredCount/${widget.quiz.questions.length} répondue${answeredCount > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: answeredCount == widget.quiz.questions.length
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(QuestionModel question) {
    final isAnswered = _userAnswers.containsKey(question.id) &&
        _userAnswers[question.id]!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte question
          Container(
            width: double.infinity,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        question.displayType,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${question.points.toInt()} pts',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  question.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                if (question.allowsMultipleAnswers) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Plusieurs réponses possibles',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Choix de réponses
          ...question.choices.map((choice) {
            final isSelected = _userAnswers[question.id]?.contains(choice.id) ?? false;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildChoiceCard(
                choice.text,
                isSelected,
                () => _onAnswerSelected(
                  question.id,
                  choice.id,
                  question.allowsMultipleAnswers,
                ),
                question.allowsMultipleAnswers,
              ),
            );
          }).toList(),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildChoiceCard(
    String text,
    bool isSelected,
    VoidCallback onTap,
    bool isMultiple,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: isMultiple ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: isMultiple ? BorderRadius.circular(4) : null,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey[400]!,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(
                          isMultiple ? Icons.check : Icons.circle,
                          size: isMultiple ? 16 : 12,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationBar() {
    final isFirstQuestion = _currentQuestionIndex == 0;
    final isLastQuestion = _currentQuestionIndex == widget.quiz.questions.length - 1;
    final allAnswered = _userAnswers.length == widget.quiz.questions.length;

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
        child: Row(
          children: [
            if (!isFirstQuestion)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Précédent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!isFirstQuestion) const SizedBox(width: 12),
            Expanded(
              flex: isFirstQuestion ? 1 : 1,
              child: ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (isLastQuestion) {
                          _showSubmitConfirmation();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLastQuestion && allAnswered
                      ? Colors.green
                      : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastQuestion ? 'Soumettre' : 'Suivant',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastQuestion ? Icons.check : Icons.arrow_forward,
                            size: 20,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubmitConfirmation() async {
    final unansweredCount = widget.quiz.questions.length - _userAnswers.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Soumettre le quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unansweredCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attention : $unansweredCount question${unansweredCount > 1 ? 's' : ''} non répondue${unansweredCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text('Voulez-vous vraiment soumettre vos réponses ?'),
            const SizedBox(height: 8),
            const Text(
              'Cette action est définitive et ne peut pas être annulée.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
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
              backgroundColor: unansweredCount > 0 ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _submitQuiz();
    }
  }

  Future<bool?> _showExitConfirmation() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitter le quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Êtes-vous sûr de vouloir quitter ?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Votre progression sera perdue et cette tentative sera comptabilisée.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
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
            child: const Text('Continuer le quiz'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }
}