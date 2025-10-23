class QuizAttemptModel {
  final int id;
  final int quiz;
  final String quizTitle;
  final String status; // 'IN_PROGRESS', 'COMPLETED', 'ABANDONED'
  final int attemptNumber;
  final DateTime startedAt;
  final int durationMinutes;
  final DateTime? completedAt;

  QuizAttemptModel({
    required this.id,
    required this.quiz,
    required this.quizTitle,
    required this.status,
    required this.attemptNumber,
    required this.startedAt,
    required this.durationMinutes,
    this.completedAt,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    return QuizAttemptModel(
      id: json['id'] as int,
      quiz: json['quiz'] as int,
      quizTitle: json['quiz_title'] ?? '',
      status: json['status'] ?? 'IN_PROGRESS',
      attemptNumber: json['attempt_number'] ?? 1,
      startedAt: DateTime.parse(json['started_at'] as String),
      durationMinutes: json['duration_minutes'] ?? 0,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quiz': quiz,
      'quiz_title': quizTitle,
      'status': status,
      'attempt_number': attemptNumber,
      'started_at': startedAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  // Calculer le temps restant
  Duration get timeRemaining {
    final endTime = startedAt.add(Duration(minutes: durationMinutes));
    final remaining = endTime.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // Le temps est-il écoulé ?
  bool get isTimeUp => timeRemaining.inSeconds <= 0;

  // Formater le temps restant
  String get formattedTimeRemaining {
    final minutes = timeRemaining.inMinutes;
    final seconds = timeRemaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Temps écoulé
  Duration get elapsedTime {
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  // Est en cours ?
  bool get isInProgress => status == 'IN_PROGRESS';
}