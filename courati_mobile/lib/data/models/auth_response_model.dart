// 📁 lib/data/models/auth_response_model.dart
import 'user_model.dart';
import 'student_profile_model.dart';

class AuthResponseModel {
  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final StudentProfileModel? studentProfile;

  AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.studentProfile,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access'] ?? '',
      refreshToken: json['refresh'] ?? '',
      user: UserModel.fromJson(json['user']),
      studentProfile: json['student_profile'] != null
          ? StudentProfileModel.fromJson(json['student_profile'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access': accessToken,
      'refresh': refreshToken,
      'user': user.toJson(),
      'student_profile': studentProfile?.toJson(),
    };
  }

  @override
  String toString() {
    return 'AuthResponseModel(accessToken: ${accessToken.substring(0, 10)}..., '
           'user: ${user.username}, studentProfile: ${studentProfile != null})';
  }
}