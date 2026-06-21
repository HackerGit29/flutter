enum Role { admin, user, vip }
enum UserStatus { active, suspended }

class User {
  final String id;
  final String email;
  final Role role;
  final UserStatus status;
  final DateTime createdAt;
  final String? subscriptionId;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.subscriptionId,
  });

  bool get isAdmin => role == Role.admin;
  bool get isVip => role == Role.vip;
  bool get isSuspended => status == UserStatus.suspended;

  User copyWith({Role? role, UserStatus? status, String? subscriptionId}) {
    return User(
      id: id, email: email,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt,
      subscriptionId: subscriptionId ?? this.subscriptionId,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    role: Role.values.firstWhere((r) => r.name == json['role'] ?? 'user'),
    status: UserStatus.values.firstWhere((s) => s.name == json['status'] ?? 'active'),
    createdAt: DateTime.parse(json['created_at'] as String),
    subscriptionId: json['subscription_id'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'email': email, 'role': role.name,
    'status': status.name, 'created_at': createdAt.toIso8601String(),
    if (subscriptionId != null) 'subscription_id': subscriptionId,
  };
}
