import 'question_model.dart';

// Fonction helper pour parser les doubles
double _parseToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class QuizDetailModel {
  final int id;
  final String title;
  final String description;
  final String subjectName;
  final String subjectCode;
  final int durationMinutes;
  final double passingPercentage;  // NOUVEAU
  final double passingScoreNormalized;
  final int maxAttempts;
  final bool showCorrection;
  final int questionCount;
  final double totalPoints;
  final List<QuestionModel> questions;

  QuizDetailModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectName,
    required this.subjectCode,
    required this.durationMinutes,
    required this.passingPercentage,  // NOUVEAU
    required this.passingScoreNormalized,
    required this.maxAttempts,
    required this.showCorrection,
    required this.questionCount,
    required this.totalPoints,
    required this.questions,
  });

  factory QuizDetailModel.fromJson(Map<String, dynamic> json) {
    return QuizDetailModel(
      id: json['id'] as int,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      passingPercentage: _parseToDouble(json['passing_percentage']),  // NOUVEAU
      passingScoreNormalized: _parseToDouble(json['passing_score_normalized']),
      maxAttempts: json['max_attempts'] ?? 3,
      showCorrection: json['show_correction'] ?? true,
      questionCount: json['question_count'] ?? 0,
      totalPoints: _parseToDouble(json['total_points']),
      questions: (json['questions'] as List? ?? [])
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject_name': subjectName,
      'subject_code': subjectCode,
      'duration_minutes': durationMinutes,
      'passing_percentage': passingPercentage,
      'passing_score_normalized': passingScoreNormalized,
      'max_attempts': maxAttempts,
      'show_correction': showCorrection,
      'question_count': questionCount,
      'total_points': totalPoints,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}