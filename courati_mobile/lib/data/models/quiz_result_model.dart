// Fonction helper pour parser les doubles
double _parseToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class QuizResultModel {
  final int id;
  final String quizTitle;
  final double score;  // Score normalisé sur 20
  final double passingScore;  // Passing score normalisé sur 20
  final bool isPassed;
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime completedAt;
  final double? timeSpent;
  final int totalQuestions;
  final int correctAnswers;
  final int wrongAnswers;

  QuizResultModel({
    required this.id,
    required this.quizTitle,
    required this.score,
    required this.passingScore,
    required this.isPassed,
    required this.attemptNumber,
    required this.startedAt,
    required this.completedAt,
    this.timeSpent,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.wrongAnswers,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
  return QuizResultModel(
    id: json['id'] as int,
    quizTitle: json['quiz_title'] ?? '',
    score: _parseToDouble(json['score_normalized']),  // ← CHANGÉ : utiliser score_normalized
    passingScore: _parseToDouble(json['passing_score']),
    isPassed: json['is_passed'] ?? false,
    attemptNumber: json['attempt_number'] ?? 1,
    startedAt: DateTime.parse(json['started_at'] as String),
    completedAt: DateTime.parse(json['completed_at'] as String),
    timeSpent: json['time_spent'] != null 
        ? _parseToDouble(json['time_spent'])
        : null,
    totalQuestions: json['total_questions'] ?? 0,
    correctAnswers: json['correct_answers'] ?? 0,
    wrongAnswers: json['wrong_answers'] ?? 0,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz_title': quizTitle,
      'score': score,
      'passing_score': passingScore,
      'is_passed': isPassed,
      'attempt_number': attemptNumber,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt.toIso8601String(),
      if (timeSpent != null) 'time_spent': timeSpent,
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'wrong_answers': wrongAnswers,
    };
  }

  // ✅ CORRECTION: Calculer le pourcentage à partir du score normalisé sur 20
  double get percentage => (score / 20) * 100;
  
  // Alias pour compatibilité
  double get scorePercentage => percentage;

  Map<String, dynamic> get statusInfo {
    if (isPassed) {
      return {
        'text': 'Réussi',
        'color': '#4CAF50',
        'icon': '✓',
      };
    } else {
      return {
        'text': 'Échoué',
        'color': '#F44336',
        'icon': '✗',
      };
    }
  }

  String get formattedTimeSpent {
    if (timeSpent == null) return 'N/A';
    final minutes = timeSpent!.floor();
    final seconds = ((timeSpent! - minutes) * 60).floor();
    return '${minutes}min ${seconds}s';
  }
}