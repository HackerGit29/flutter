enum BoxStatus { active, inactive, blocked }

class Box {
  final String id;
  final String uidHardware;
  final String name;
  final String? location;
  final String userId;
  final BoxStatus status;
  final String? publicKey;
  final DateTime? lastSync;
  final String? firmwareVersion;
  final DateTime createdAt;

  const Box({
    required this.id,
    required this.uidHardware,
    required this.name,
    this.location,
    required this.userId,
    required this.status,
    this.publicKey,
    this.lastSync,
    this.firmwareVersion,
    required this.createdAt,
  });

  bool get isActive => status == BoxStatus.active;
  bool get isBlocked => status == BoxStatus.blocked;

  Box copyWith({
    String? uidHardware, String? name, String? location,
    BoxStatus? status, String? publicKey,
    DateTime? lastSync, String? firmwareVersion,
  }) => Box(
    id: id, uidHardware: uidHardware ?? this.uidHardware,
    name: name ?? this.name, location: location ?? this.location,
    userId: userId, status: status ?? this.status,
    publicKey: publicKey ?? this.publicKey, lastSync: lastSync ?? this.lastSync,
    firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    createdAt: createdAt,
  );

  factory Box.fromJson(Map<String, dynamic> json) => Box(
    id: json['id'] as String,
    uidHardware: json['uid_hardware'] as String? ?? '',
    name: json['name'] as String,
    location: json['location'] as String?,
    userId: json['user_id'] as String,
    status: BoxStatus.values.firstWhere((s) => s.name == (json['status'] ?? 'inactive')),
    publicKey: json['public_key'] as String?,
    lastSync: json['last_sync'] != null ? DateTime.parse(json['last_sync'] as String) : null,
    firmwareVersion: json['firmware_version'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'uid_hardware': uidHardware, 'name': name,
    if (location != null) 'location': location,
    'user_id': userId, 'status': status.name,
    'public_key': publicKey, 'last_sync': lastSync?.toIso8601String(),
    'firmware_version': firmwareVersion, 'created_at': createdAt.toIso8601String(),
  };
}
