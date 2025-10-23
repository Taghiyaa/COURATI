import 'level_model.dart';
import 'major_model.dart';

class StudentProfileModel {
  final int id;
  final int userId;
  final String phoneNumber;
  final LevelModel? level;     // CHANGÉ: maintenant un objet LevelModel
  final MajorModel? major;     // CHANGÉ: maintenant un objet MajorModel
  final bool isVerified;
  final String? otp;
  final DateTime? otpExpiry;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentProfileModel({
    required this.id,
    required this.userId,
    required this.phoneNumber,
    this.level,                // CHANGÉ: peut être null
    this.major,                // CHANGÉ: peut être null
    required this.isVerified,
    this.otp,
    this.otpExpiry,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentProfileModel(
      id: json['id'],
      userId: json['user'],
      phoneNumber: json['phone_number'],
      // CHANGÉ: Parser les objets level et major depuis le JSON
      level: json['level'] != null ? LevelModel.fromJson(json['level']) : null,
      major: json['major'] != null ? MajorModel.fromJson(json['major']) : null,
      isVerified: json['is_verified'] ?? false,
      otp: json['otp'],
      otpExpiry: json['otp_expiry'] != null 
          ? DateTime.parse(json['otp_expiry']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': userId,
      'phone_number': phoneNumber,
      // CHANGÉ: Sérialiser les objets level et major
      'level': level?.toJson(),
      'major': major?.toJson(),
      'is_verified': isVerified,
      'otp': otp,
      'otp_expiry': otpExpiry?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // CHANGÉ: Nouvelles getters pour l'affichage
  String get levelDisplay {
    return level?.name ?? 'Non défini';
  }

  String get majorDisplay {
    return major?.name ?? 'Non défini';
  }

  String get levelCode {
    return level?.code ?? '';
  }

  String get majorCode {
    return major?.code ?? '';
  }

  String get majorDepartment {
    return major?.department ?? '';
  }

  StudentProfileModel copyWith({
    int? id,
    int? userId,
    String? phoneNumber,
    LevelModel? level,        // CHANGÉ: type LevelModel
    MajorModel? major,        // CHANGÉ: type MajorModel
    bool? isVerified,
    String? otp,
    DateTime? otpExpiry,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentProfileModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      level: level ?? this.level,
      major: major ?? this.major,
      isVerified: isVerified ?? this.isVerified,
      otp: otp ?? this.otp,
      otpExpiry: otpExpiry ?? this.otpExpiry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}