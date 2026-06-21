enum SyncStatus { success, failed, unauthorized, cryptoMismatch, deviceBlocked }

class SyncLog {
  final String id;
  final String deviceId;
  final String userId;
  final SyncStatus status;
  final Map<String, dynamic>? data;
  final String? errorMessage;
  final String? ipAddress;
  final DateTime timestamp;

  const SyncLog({
    required this.id, required this.deviceId, required this.userId,
    required this.status, this.data, this.errorMessage, this.ipAddress, required this.timestamp,
  });

  factory SyncLog.fromJson(Map<String, dynamic> json) => SyncLog(
    id: json['id'] as String,
    deviceId: json['device_id'] as String,
    userId: json['user_id'] as String,
    status: SyncStatus.values.firstWhere((s) => s.name == json['status']),
    data: json['data'] as Map<String, dynamic>?,
    errorMessage: json['error_message'] as String?,
    ipAddress: json['ip_address'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
