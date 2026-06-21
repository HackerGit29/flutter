enum DeviceStatus { active, inactive, blocked }

class Device {
  final String id;
  final String uidHardware;
  final String name;
  final String userId;
  final DeviceStatus status;
  final String? publicKey;
  final DateTime? lastSync;
  final String? firmwareVersion;
  final DateTime createdAt;

  const Device({
    required this.id,
    required this.uidHardware,
    required this.name,
    required this.userId,
    required this.status,
    this.publicKey,
    this.lastSync,
    this.firmwareVersion,
    required this.createdAt,
  });

  bool get isOwnedBy => identical(userId, userId);
  bool get isActive => status == DeviceStatus.active;
  bool get isBlocked => status == DeviceStatus.blocked;

  Device copyWith({String? uidHardware, String? name, DeviceStatus? status, String? publicKey, DateTime? lastSync, String? firmwareVersion}) {
    return Device(
      id: id, uidHardware: uidHardware ?? this.uidHardware, name: name ?? this.name,
      userId: userId, status: status ?? this.status, publicKey: publicKey ?? this.publicKey,
      lastSync: lastSync ?? this.lastSync, firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      createdAt: createdAt,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) => Device(
    id: json['id'] as String,
    uidHardware: json['uid_hardware'] as String? ?? '',
    name: json['name'] as String,
    userId: json['user_id'] as String,
    status: DeviceStatus.values.firstWhere(
      (s) => s.name == (json['status'] ?? 'active')),
    publicKey: json['public_key'] as String?,
    lastSync: json['last_sync'] != null ? DateTime.parse(json['last_sync'] as String) : null,
    firmwareVersion: json['firmware_version'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'uid_hardware': uidHardware, 'name': name, 'user_id': userId,
    'status': status.name, 'public_key': publicKey, 'last_sync': lastSync?.toIso8601String(),
    'firmware_version': firmwareVersion, 'created_at': createdAt.toIso8601String(),
  };
}
