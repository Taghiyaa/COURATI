// data/models/level_model.dart
class LevelModel {
  final int id;
  final String code;
  final String name;

  LevelModel({
    required this.id,
    required this.code,
    required this.name,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
    };
  }

  @override
  String toString() => name;
}