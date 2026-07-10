import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/usecases/admin/get_sync_logs.dart';
import 'package:aricie/domain/usecases/admin/force_sync.dart';
import 'package:aricie/domain/usecases/admin/reset_device.dart';
import 'package:aricie/domain/usecases/admin/assign_device.dart';
import 'package:aricie/domain/usecases/admin/override_ownership.dart';
import 'admin_mocks.dart';

void main() {
  // ─── GetSyncLogs ───────────────────────────────────────────────────────────
  group('GetSyncLogs', () {
    test('retourne les logs de synchronisation', () async {
      final uc = GetSyncLogs(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc =
          GetSyncLogs(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call();
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── ForceSync ────────────────────────────────────────────────────────────
  group('ForceSync', () {
    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc =
          ForceSync(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call(kBox.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── ResetDevice ──────────────────────────────────────────────────────────
  group('ResetDevice', () {
    test('réinitialise un boîtier avec succès', () async {
      final uc = ResetDevice(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kBox.id);
      expect(result.isRight(), true);
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc =
          ResetDevice(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call(kBox.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });

    test('retourne Failure si l\'opération échoue', () async {
      final uc = ResetDevice(
        MockAdminRepo(operationFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(kBox.id);
      expect(result.isLeft(), true);
    });
  });

  // ─── AssignDevice ─────────────────────────────────────────────────────────
  group('AssignDevice', () {
    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc =
          AssignDevice(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call(kBox.id, kRegularUser.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── OverrideOwnership ────────────────────────────────────────────────────
  group('OverrideOwnership', () {
    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc =
          OverrideOwnership(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call(kBox.id, kVipUser.id, 'reassignment');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });
}
