class UserModel {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String role; // 'ADMIN' ou 'STUDENT'
  final bool isStaff;
  final bool isActive;
  final DateTime? dateJoined;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    required this.role,
    required this.isStaff,
    required this.isActive,
    this.dateJoined,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      role: (json['role']?.toString().toUpperCase() ?? 'STUDENT'),
      isStaff: json['is_staff'] == true || json['is_staff'] == 1,
      isActive: json['is_active'] != false, // true par défaut
      dateJoined: json['date_joined'] != null && json['date_joined'].toString().isNotEmpty
          ? DateTime.tryParse(json['date_joined'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName ?? '',
      'last_name': lastName ?? '',
      'role': role,
      'is_staff': isStaff,
      'is_active': isActive,
      'date_joined': dateJoined?.toIso8601String(),
    };
  }

  String get fullName {
    if ((firstName?.isNotEmpty ?? false) || (lastName?.isNotEmpty ?? false)) {
      return '${firstName ?? ''} ${lastName ?? ''}'.trim();
    }
    return username;
  }

  bool get isAdmin => role == 'ADMIN';
  bool get isStudent => role == 'STUDENT';

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? role,
    bool? isStaff,
    bool? isActive,
    DateTime? dateJoined,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      isStaff: isStaff ?? this.isStaff,
      isActive: isActive ?? this.isActive,
      dateJoined: dateJoined ?? this.dateJoined,
    );
  }
}
