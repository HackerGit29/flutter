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

  static SyncStatus _statusFromDb(String value) {
    switch (value) {
      case 'crypto_mismatch': return SyncStatus.cryptoMismatch;
      case 'device_blocked': return SyncStatus.deviceBlocked;
      default: return SyncStatus.values.firstWhere((s) => s.name == value);
    }
  }

  static String _statusToDb(SyncStatus status) {
    switch (status) {
      case SyncStatus.cryptoMismatch: return 'crypto_mismatch';
      case SyncStatus.deviceBlocked: return 'device_blocked';
      default: return status.name;
    }
  }

  factory SyncLog.fromJson(Map<String, dynamic> json) => SyncLog(
    id: json['id'] as String,
    deviceId: json['device_id'] as String,
    userId: json['user_id'] as String,
    status: _statusFromDb(json['status'] as String),
    data: json['data'] as Map<String, dynamic>?,
    errorMessage: json['error_message'] as String?,
    ipAddress: json['ip_address'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_id': deviceId,
    'user_id': userId,
    'status': _statusToDb(status),
    'data': data,
    'error_message': errorMessage,
    'ip_address': ipAddress,
    'timestamp': timestamp.toIso8601String(),
  };
}
