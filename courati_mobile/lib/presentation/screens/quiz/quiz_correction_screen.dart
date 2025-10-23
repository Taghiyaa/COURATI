// lib/presentation/screens/quiz/quiz_correction_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/quiz_correction_model.dart';
import '../../../data/models/quiz_result_model.dart';
import '../../../data/models/question_model.dart';

class QuizCorrectionScreen extends StatelessWidget {
  final QuizCorrectionModel correction;
  final QuizResultModel result;

  const QuizCorrectionScreen({
    super.key,
    required this.correction,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Correction détaillée',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Résumé en haut
          SliverToBoxAdapter(
            child: _buildSummaryCard(),
          ),

          // Liste des questions avec correction
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildQuestionCard(
                      correction.questions[index],
                      index + 1,
                    ),
                  );
                },
                childCount: correction.questions.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
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
                  Icons.assessment,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Récapitulatif',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  Icons.check_circle,
                  'Réponses correctes',
                  '${correction.correctCount}',
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryItem(
                  Icons.cancel,
                  'Réponses incorrectes',
                  '${correction.incorrectCount}',
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: result.isPassed
                  ? Colors.green[50]
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: result.isPassed
                    ? Colors.green[200]!
                    : Colors.orange[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result.isPassed ? Icons.check_circle : Icons.info,
                  color: result.isPassed ? Colors.green[700] : Colors.orange[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Score final',
                        style: TextStyle(
                          fontSize: 12,
                          color: result.isPassed
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                      Text(
                        '${result.score.toStringAsFixed(1)}/20',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: result.isPassed
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  result.isPassed ? 'Réussi ✓' : 'Non réussi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: result.isPassed
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(QuestionModel question, int questionNumber) {
    final isCorrect = question.isCorrect ?? false;
    final hasAnswer = question.studentSelected != null &&
        question.studentSelected!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect
              ? Colors.green[200]!
              : hasAnswer
                  ? Colors.red[200]!
                  : Colors.grey[300]!,
          width: 2,
        ),
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCorrect
                  ? Colors.green[50]
                  : hasAnswer
                      ? Colors.red[50]
                      : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green
                        : hasAnswer
                            ? Colors.red
                            : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$questionNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.displayType,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCorrect
                              ? Colors.green[700]
                              : hasAnswer
                                  ? Colors.red[700]
                                  : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isCorrect
                                ? Icons.check_circle
                                : hasAnswer
                                    ? Icons.cancel
                                    : Icons.help_outline,
                            color: isCorrect
                                ? Colors.green[700]
                                : hasAnswer
                                    ? Colors.red[700]
                                    : Colors.grey[700],
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCorrect
                                ? 'Correct'
                                : hasAnswer
                                    ? 'Incorrect'
                                    : 'Non répondu',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isCorrect
                                  ? Colors.green[700]
                                  : hasAnswer
                                      ? Colors.red[700]
                                      : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${question.pointsEarned?.toInt() ?? 0}/${question.points.toInt()} pts',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Question
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              question.text,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),

          // Choix de réponses
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: question.choices.map<Widget>((choice) {
                final isStudentChoice =
                    question.studentSelected?.contains(choice.id) ?? false;
                final isCorrectChoice = choice.isCorrect ?? false;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildChoiceItem(
                    choice.text,
                    isStudentChoice,
                    isCorrectChoice,
                  ),
                );
              }).toList(),
            ),
          ),

          // Explication
          if (question.explanation != null &&
              question.explanation!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explication',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          question.explanation!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[900],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildChoiceItem(
    String text,
    bool isStudentChoice,
    bool isCorrectChoice,
  ) {
    Color borderColor;
    Color backgroundColor;
    IconData? icon;
    Color? iconColor;

    if (isCorrectChoice) {
      // Bonne réponse
      borderColor = Colors.green[300]!;
      backgroundColor = Colors.green[50]!;
      icon = Icons.check_circle;
      iconColor = Colors.green[700];
    } else if (isStudentChoice) {
      // Mauvaise réponse de l'étudiant
      borderColor = Colors.red[300]!;
      backgroundColor = Colors.red[50]!;
      icon = Icons.cancel;
      iconColor = Colors.red[700];
    } else {
      // Neutre
      borderColor = Colors.grey[300]!;
      backgroundColor = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isCorrectChoice || isStudentChoice ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (icon != null)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: iconColor!.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: iconColor),
            )
          else
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey[400]!),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isCorrectChoice || isStudentChoice
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight:
                    isCorrectChoice || isStudentChoice ? FontWeight.w600 : FontWeight.normal,
                height: 1.4,
              ),
            ),
          ),
          if (isCorrectChoice && !isStudentChoice)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Bonne réponse',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}