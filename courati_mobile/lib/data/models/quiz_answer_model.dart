class QuizAnswerModel {
  final int questionId;
  final List<int> selectedChoices;

  QuizAnswerModel({
    required this.questionId,
    required this.selectedChoices,
  });

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      'selected_choices': selectedChoices,
    };
  }

  factory QuizAnswerModel.fromJson(Map<String, dynamic> json) {
    return QuizAnswerModel(
      questionId: json['question_id'] as int,
      selectedChoices: List<int>.from(json['selected_choices'] as List),
    );
  }
}