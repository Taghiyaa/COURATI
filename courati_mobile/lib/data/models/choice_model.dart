class ChoiceModel {
  final int id;
  final String text;
  final int order;
  final bool? isCorrect;

  ChoiceModel({
    required this.id,
    required this.text,
    required this.order,
    this.isCorrect,
  });

  factory ChoiceModel.fromJson(Map<String, dynamic> json) {
    return ChoiceModel(
      id: json['id'] as int,
      text: json['text'] ?? '',
      order: json['order'] ?? 0,
      isCorrect: json['is_correct'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'order': order,
      if (isCorrect != null) 'is_correct': isCorrect,
    };
  }

  ChoiceModel copyWith({
    int? id,
    String? text,
    int? order,
    bool? isCorrect,
  }) {
    return ChoiceModel(
      id: id ?? this.id,
      text: text ?? this.text,
      order: order ?? this.order,
      isCorrect: isCorrect ?? this.isCorrect,
    );
  }
}