// Fonction helper AVANT la classe QuizModel
double _parseToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class QuizModel {
  final int id;
  final String title;
  final String description;
  final String subjectName;
  final String subjectCode;
  final int durationMinutes;
  final double passingPercentage;  // ← CHANGÉ
  final double passingScoreNormalized;
  final int maxAttempts;
  final int questionCount;
  final double totalPoints;
  final bool isActive;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  
  final double? userBestScore;
  final int userAttemptsCount;
  final DateTime? userLastAttempt;
  final bool isAvailable;
  final bool canAttempt;

  QuizModel({
    required this.id,
    required this.title,
    required this.description,
    required this.subjectName,
    required this.subjectCode,
    required this.durationMinutes,
    required this.passingPercentage,  // ← CHANGÉ
    required this.passingScoreNormalized,
    required this.maxAttempts,
    required this.questionCount,
    required this.totalPoints,
    required this.isActive,
    this.availableFrom,
    this.availableUntil,
    this.userBestScore,
    required this.userAttemptsCount,
    this.userLastAttempt,
    required this.isAvailable,
    required this.canAttempt,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] as int,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      subjectName: json['subject_name'] ?? '',
      subjectCode: json['subject_code'] ?? '',
      durationMinutes: json['duration_minutes'] ?? 0,
      passingPercentage: _parseToDouble(json['passing_percentage']),  // ← CHANGÉ
      passingScoreNormalized: _parseToDouble(json['passing_score_normalized']),
      maxAttempts: json['max_attempts'] ?? 3,
      questionCount: json['question_count'] ?? 0,
      totalPoints: _parseToDouble(json['total_points']),
      isActive: json['is_active'] ?? false,
      availableFrom: json['available_from'] != null 
          ? DateTime.parse(json['available_from']) 
          : null,
      availableUntil: json['available_until'] != null 
          ? DateTime.parse(json['available_until']) 
          : null,
      userBestScore: json['user_best_score'] != null 
          ? _parseToDouble(json['user_best_score'])
          : null,
      userAttemptsCount: json['user_attempts_count'] ?? 0,
      userLastAttempt: json['user_last_attempt'] != null 
          ? DateTime.parse(json['user_last_attempt']) 
          : null,
      isAvailable: json['is_available'] ?? false,
      canAttempt: json['can_attempt'] ?? false,
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
      'passing_percentage': passingPercentage,  // ← CHANGÉ
      'passing_score_normalized': passingScoreNormalized,
      'max_attempts': maxAttempts,
      'question_count': questionCount,
      'total_points': totalPoints,
      'is_active': isActive,
      'available_from': availableFrom?.toIso8601String(),
      'available_until': availableUntil?.toIso8601String(),
      'user_best_score': userBestScore,
      'user_attempts_count': userAttemptsCount,
      'user_last_attempt': userLastAttempt?.toIso8601String(),
      'is_available': isAvailable,
      'can_attempt': canAttempt,
    };
  }

  String get statusText {
    if (!isAvailable) return 'Non disponible';
    if (!canAttempt) {
      if (userAttemptsCount >= maxAttempts) return 'Tentatives épuisées';
      return 'Non disponible';
    }
    if (userBestScore != null && userBestScore! >= passingScoreNormalized) {
      return 'Réussi';
    }
    return 'En cours';
  }

  String get statusColor {
    if (!canAttempt) return '#9E9E9E';
    if (userAttemptsCount == 0) return '#2196F3';
    if (userBestScore != null && userBestScore! >= passingScoreNormalized) {
      return '#4CAF50';
    }
    return '#FF9800';
  }

  int get remainingAttempts => maxAttempts - userAttemptsCount;

  double get bestScorePercentage {
    if (userBestScore != null) {
      return (userBestScore! / 20) * 100;
    }
    return 0.0;
  }
  
  String get displayBestScore {
    if (userBestScore != null) {
      return '${userBestScore!.toStringAsFixed(1)}/20';
    }
    return '--/20';
  }
  
  String get displayPassingScore {
    return '${passingScoreNormalized.toStringAsFixed(1)}/20';
  }
}