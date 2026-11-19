import 'access.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String username;
  final String fullName;
  final Role role;

  AppUser copyWith({Role? role}) {
    return AppUser(
      id: id,
      username: username,
      fullName: fullName,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'role': role.name,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      username: '${json['username'] ?? ''}',
      fullName: '${json['fullName'] ?? ''}',
      role: Role.parse('${json['role']}') ?? Role.buyer,
    );
  }
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionExpiresAt,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime sessionExpiresAt;
  final AppUser user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return AuthResult(
      accessToken: '${json['accessToken']}',
      refreshToken: '${json['refreshToken']}',
      sessionExpiresAt:
          DateTime.tryParse('${json['sessionExpiresAt']}')?.toLocal() ??
              DateTime.now().add(const Duration(hours: 8)),
      user: user is Map<String, dynamic>
          ? AppUser.fromJson(user)
          : user is Map
              ? AppUser.fromJson(Map<String, dynamic>.from(user))
              : const AppUser(
                  id: 0, username: '', fullName: '', role: Role.buyer),
    );
  }
}
