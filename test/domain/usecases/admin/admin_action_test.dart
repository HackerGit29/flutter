import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/domain/entities/admin_action.dart';

void main() {
  final kTimestamp = DateTime(2026, 6, 26, 12, 0, 0);

  group('AdminAction — fromJson', () {
    test('parse suspend_user correctement', () {
      final json = {
        'id': 'a1', 'admin_id': 'admin-1', 'action': 'suspend_user',
        'target_type': 'user', 'target_id': 'user-1',
        'details': {'reason': 'violation'},
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.id, 'a1');
      expect(action.action, AdminActionType.suspendUser);
      expect(action.targetType, TargetType.user);
      expect(action.details, {'reason': 'violation'});
    });

    test('parse activate_user correctement', () {
      final json = {
        'id': 'a2', 'admin_id': 'admin-1', 'action': 'activate_user',
        'target_type': 'user', 'target_id': 'user-2', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.activateUser);
      expect(action.details, null);
    });

    test('parse assign_role correctement', () {
      final json = {
        'id': 'a3', 'admin_id': 'admin-1', 'action': 'assign_role',
        'target_type': 'user', 'target_id': 'user-3',
        'details': {'role': 'vip'}, 'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.assignRole);
    });

    test('parse reset_device correctement', () {
      final json = {
        'id': 'a4', 'admin_id': 'admin-1', 'action': 'reset_device',
        'target_type': 'box', 'target_id': 'box-1', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.resetDevice);
      expect(action.targetType, TargetType.box);
    });

    test('parse force_sync correctement', () {
      final json = {
        'id': 'a5', 'admin_id': 'admin-1', 'action': 'force_sync',
        'target_type': 'box', 'target_id': 'box-1', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.forceSync);
    });

    test('parse override_ownership correctement', () {
      final json = {
        'id': 'a6', 'admin_id': 'admin-1', 'action': 'override_ownership',
        'target_type': 'box', 'target_id': 'box-1',
        'details': {'new_user_id': 'user-2'},
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.overrideOwnership);
    });

    test('parse block_device correctement', () {
      final json = {
        'id': 'a7', 'admin_id': 'admin-1', 'action': 'block_device',
        'target_type': 'device', 'target_id': 'box-1', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.blockDevice);
      expect(action.targetType, TargetType.device);
    });

    test('parse activate_license correctement', () {
      final json = {
        'id': 'a8', 'admin_id': 'admin-1', 'action': 'activate_license',
        'target_type': 'subscription', 'target_id': 'sub-1', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.activateLicense);
      expect(action.targetType, TargetType.subscription);
    });

    test('parse revoke_license correctement', () {
      final json = {
        'id': 'a9', 'admin_id': 'admin-1', 'action': 'revoke_license',
        'target_type': 'license', 'target_id': 'sub-1', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.revokeLicense);
      expect(action.targetType, TargetType.license);
    });

    test('parse reset_box correctement', () {
      final json = {
        'id': 'a10', 'admin_id': 'admin-1', 'action': 'reset_box',
        'target_type': 'box', 'target_id': 'box-1', 'details': null,
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.resetBox);
    });

    test('parse assign_box correctement', () {
      final json = {
        'id': 'a11', 'admin_id': 'admin-1', 'action': 'assign_box',
        'target_type': 'box', 'target_id': 'box-1',
        'details': {'user_id': 'user-2'},
        'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(json);
      expect(action.action, AdminActionType.assignBox);
    });

    test('parse tous les TargetType', () {
      final types = ['user', 'device', 'license', 'subscription', 'box', 'appliance'];
      for (final type in types) {
        final json = {
          'id': 'ax', 'admin_id': 'admin-1', 'action': 'suspend_user',
          'target_type': type, 'target_id': 'target-1', 'details': null,
          'timestamp': '2026-06-26T12:00:00.000',
        };
        final action = AdminAction.fromJson(json);
        expect(action.targetType.name, type);
      }
    });
  });

  group('AdminAction — toJson', () {
    final kAction = AdminAction(
      id: 'a1', adminId: 'admin-1',
      action: AdminActionType.suspendUser,
      targetType: TargetType.user,
      targetId: 'user-1',
      details: {'reason': 'test'},
      timestamp: kTimestamp,
    );

    test('toJson produit les clés correctes', () {
      final json = kAction.toJson();
      expect(json['id'], 'a1');
      expect(json['admin_id'], 'admin-1');
      expect(json['action'], 'suspend_user');
      expect(json['target_type'], 'user');
      expect(json['target_id'], 'user-1');
      expect(json['details'], {'reason': 'test'});
    });

    test('toJson convertit les actions vers le format DB', () {
      final cases = {
        AdminActionType.suspendUser: 'suspend_user',
        AdminActionType.activateUser: 'activate_user',
        AdminActionType.assignRole: 'assign_role',
        AdminActionType.resetDevice: 'reset_device',
        AdminActionType.forceSync: 'force_sync',
        AdminActionType.overrideOwnership: 'override_ownership',
        AdminActionType.blockDevice: 'block_device',
        AdminActionType.activateLicense: 'activate_license',
        AdminActionType.revokeLicense: 'revoke_license',
        AdminActionType.resetBox: 'reset_box',
        AdminActionType.assignBox: 'assign_box',
      };
      for (final entry in cases.entries) {
        final action = AdminAction(
          id: 'x', adminId: 'a', action: entry.key,
          targetType: TargetType.user, targetId: 't',
          timestamp: kTimestamp,
        );
        expect(action.toJson()['action'], entry.value);
      }
    });

    test('roundtrip fromJson → toJson préserve les données', () {
      final original = {
        'id': 'rt', 'admin_id': 'admin-rt', 'action': 'assign_role',
        'target_type': 'user', 'target_id': 'user-rt',
        'details': {'role': 'vip'}, 'timestamp': '2026-06-26T12:00:00.000',
      };
      final action = AdminAction.fromJson(original);
      final json = action.toJson();
      expect(json['id'], original['id']);
      expect(json['action'], original['action']);
      expect(json['details'], original['details']);
    });
  });
}