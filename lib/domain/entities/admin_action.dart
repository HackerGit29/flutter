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

  static AdminActionType _actionFromDb(String value) {
    switch (value) {
      case 'suspend_user': return AdminActionType.suspendUser;
      case 'activate_user': return AdminActionType.activateUser;
      case 'assign_role': return AdminActionType.assignRole;
      case 'reset_device': return AdminActionType.resetDevice;
      case 'force_sync': return AdminActionType.forceSync;
      case 'override_ownership': return AdminActionType.overrideOwnership;
      case 'block_device': return AdminActionType.blockDevice;
      case 'activate_license': return AdminActionType.activateLicense;
      case 'revoke_license': return AdminActionType.revokeLicense;
      default: return AdminActionType.values.firstWhere((a) => a.name == value);
    }
  }

  static String _actionToDb(AdminActionType action) => switch (action) {
    AdminActionType.suspendUser => 'suspend_user',
    AdminActionType.activateUser => 'activate_user',
    AdminActionType.assignRole => 'assign_role',
    AdminActionType.resetDevice => 'reset_device',
    AdminActionType.forceSync => 'force_sync',
    AdminActionType.overrideOwnership => 'override_ownership',
    AdminActionType.blockDevice => 'block_device',
    AdminActionType.activateLicense => 'activate_license',
    AdminActionType.revokeLicense => 'revoke_license',
  };

  factory AdminAction.fromJson(Map<String, dynamic> json) => AdminAction(
    id: json['id'] as String,
    adminId: json['admin_id'] as String,
    action: _actionFromDb(json['action'] as String),
    targetType: TargetType.values.firstWhere((t) => t.name == json['target_type']),
    targetId: json['target_id'] as String,
    details: json['details'] as Map<String, dynamic>?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'admin_id': adminId,
    'action': _actionToDb(action),
    'target_type': targetType.name,
    'target_id': targetId,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };
}
