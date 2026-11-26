// lib/features/auth/models/user_model.dart

class UserModel {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final bool isActive;
  final DateTime? createdAt;

  const UserModel({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    this.email,
    this.phone,
    this.role = 'owner',
    this.isActive = true,
    this.createdAt,
  });

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
  }

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        username: map['username'] as String,
        passwordHash: map['password_hash'] as String,
        fullName: map['full_name'] as String,
        email: map['email'] as String?,
        phone: map['phone'] as String?,
        role: map['role'] as String? ?? 'owner',
        isActive: (map['is_active'] as int?) == 1,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        'password_hash': passwordHash,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'role': role,
        'is_active': isActive ? 1 : 0,
      };

  UserModel copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? fullName,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
    );
  }
}
