enum AdminActionType {
  suspendUser, activateUser, assignRole,
  resetDevice, forceSync, overrideOwnership, blockDevice,
  activateLicense, revokeLicense,
}
enum TargetType { user, device, license, subscription }

class AdminAction {
  final String id;
  final String adminId;
  final AdminActionType action;
  final TargetType targetType;
  final String targetId;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  const AdminAction({
    required this.id, required this.adminId, required this.action,
    required this.targetType, required this.targetId, this.details, required this.timestamp,
  });

  factory AdminAction.fromJson(Map<String, dynamic> json) => AdminAction(
    id: json['id'] as String,
    adminId: json['admin_id'] as String,
    action: AdminActionType.values.firstWhere((a) => a.name == json['action']),
    targetType: TargetType.values.firstWhere((t) => t.name == json['target_type']),
    targetId: json['target_id'] as String,
    details: json['details'] as Map<String, dynamic>?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
