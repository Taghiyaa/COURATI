import 'question_model.dart';

// Fonction helper pour parser les doubles
double _parseToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class QuizCorrectionModel {
  final int id;
  final int quiz;
  final double score;
  final List<QuestionModel> questions;

  QuizCorrectionModel({
    required this.id,
    required this.quiz,
    required this.score,
    required this.questions,
  });

  factory QuizCorrectionModel.fromJson(Map<String, dynamic> json) {
    return QuizCorrectionModel(
      id: json['id'] as int,
      quiz: json['quiz'] as int,
      score: _parseToDouble(json['score']),  // ← MODIFIÉ
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz': quiz,
      'score': score,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  int get correctCount =>
      questions.where((q) => q.isCorrect == true).length;

  int get incorrectCount =>
      questions.where((q) => q.isCorrect == false).length;

  double get successRate => questions.isNotEmpty
      ? (correctCount / questions.length) * 100
      : 0;
}