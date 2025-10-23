// data/models/registration_choices_model.dart
import 'level_model.dart';
import 'major_model.dart';

class RegistrationChoicesModel {
  final List<LevelModel> levels;
  final List<MajorModel> majors;
  final int levelCount;
  final int majorCount;

  RegistrationChoicesModel({
    required this.levels,
    required this.majors,
    required this.levelCount,
    required this.majorCount,
  });

  factory RegistrationChoicesModel.fromJson(Map<String, dynamic> json) {
    return RegistrationChoicesModel(
      levels: (json['choices']['levels'] as List)
          .map((level) => LevelModel.fromJson(level))
          .toList(),
      majors: (json['choices']['majors'] as List)
          .map((major) => MajorModel.fromJson(major))
          .toList(),
      levelCount: json['counts']['levels'],
      majorCount: json['counts']['majors'],
    );
  }
}