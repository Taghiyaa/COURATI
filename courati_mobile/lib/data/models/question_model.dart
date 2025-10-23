import 'choice_model.dart';

// Fonction helper pour parser les doubles
double _parseToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class QuestionModel {
  final int id;
  final String text;
  final String questionType;
  final double points;
  final int order;
  final String? explanation;
  final List<ChoiceModel> choices;
  final List<int>? studentSelected;
  final bool? isCorrect;
  final double? pointsEarned;

  QuestionModel({
    required this.id,
    required this.text,
    required this.questionType,
    required this.points,
    required this.order,
    this.explanation,
    required this.choices,
    this.studentSelected,
    this.isCorrect,
    this.pointsEarned,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as int,
      text: json['text'] ?? '',
      questionType: json['question_type'] ?? 'QCM',
      points: _parseToDouble(json['points']),  // ← MODIFIÉ
      order: json['order'] ?? 0,
      explanation: json['explanation'],
      choices: (json['choices'] as List? ?? [])
          .map((c) => ChoiceModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      studentSelected: json['student_selected'] != null
          ? List<int>.from(json['student_selected'] as List)
          : null,
      isCorrect: json['is_correct'],
      pointsEarned: json['points_earned'] != null
          ? _parseToDouble(json['points_earned'])  // ← MODIFIÉ
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'question_type': questionType,
      'points': points,
      'order': order,
      if (explanation != null) 'explanation': explanation,
      'choices': choices.map((c) => c.toJson()).toList(),
      if (studentSelected != null) 'student_selected': studentSelected,
      if (isCorrect != null) 'is_correct': isCorrect,
      if (pointsEarned != null) 'points_earned': pointsEarned,
    };
  }

  bool get allowsMultipleAnswers => questionType == 'MULTIPLE';

  String get displayType {
    switch (questionType) {
      case 'QCM':
        return 'Choix unique';
      case 'TRUE_FALSE':
        return 'Vrai/Faux';
      case 'MULTIPLE':
        return 'Choix multiples';
      default:
        return questionType;
    }
  }

  QuestionModel copyWith({
    List<int>? studentSelected,
    bool? isCorrect,
    double? pointsEarned,
  }) {
    return QuestionModel(
      id: id,
      text: text,
      questionType: questionType,
      points: points,
      order: order,
      explanation: explanation,
      choices: choices,
      studentSelected: studentSelected ?? this.studentSelected,
      isCorrect: isCorrect ?? this.isCorrect,
      pointsEarned: pointsEarned ?? this.pointsEarned,
    );
  }
}