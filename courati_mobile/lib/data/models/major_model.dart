// data/models/major_model.dart
class MajorModel {
  final int id;
  final String code;
  final String name;
  final String? department;

  MajorModel({
    required this.id,
    required this.code,
    required this.name,
    this.department,
  });

  factory MajorModel.fromJson(Map<String, dynamic> json) {
    return MajorModel(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      department: json['department'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'department': department,
    };
  }

  @override
  String toString() => name;
}