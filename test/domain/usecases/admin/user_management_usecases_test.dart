import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/user.dart';
import 'package:aricie/domain/usecases/admin/suspend_user.dart';
import 'package:aricie/domain/usecases/admin/activate_user.dart';
import 'package:aricie/domain/usecases/admin/assign_role.dart';
import 'admin_mocks.dart';

void main() {
  // ─── SuspendUser ───────────────────────────────────────────────────────────
  group('SuspendUser', () {
    test('suspend un utilisateur actif avec succès', () async {
      final uc = SuspendUser(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kRegularUser.id);
      expect(result.isRight(), true);
      result.fold((_) {}, (u) => expect(u.status, UserStatus.suspended));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = SuspendUser(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call(kVipUser.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });

    test('retourne CannotModifySelfFailure si admin cible son propre compte',
        () async {
      final uc = SuspendUser(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kAdminUser.id); // même ID que l'admin connecté
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<CannotModifySelfFailure>()), (_) {});
    });

    test('retourne CannotModifyAdminFailure si la cible est admin', () async {
      final uc = SuspendUser(
        MockAdminRepo(getUserResult: kOtherAdmin),
        MockAuthRepo(),
      );
      final result = await uc.call(kOtherAdmin.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<CannotModifyAdminFailure>()), (_) {});
    });

    test('retourne ServerFailure si getUser échoue', () async {
      final uc = SuspendUser(
        MockAdminRepo(getUserFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(kRegularUser.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) {});
    });

    test('retourne ServerFailure si l\'opération échoue', () async {
      final uc = SuspendUser(
        MockAdminRepo(operationFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(kRegularUser.id);
      expect(result.isLeft(), true);
    });
  });

  // ─── ActivateUser ──────────────────────────────────────────────────────────
  group('ActivateUser', () {
    test('active un utilisateur suspendu avec succès', () async {
      final uc = ActivateUser(
        MockAdminRepo(getUserResult: kSuspendedUser),
        MockAuthRepo(),
      );
      final result = await uc.call(kSuspendedUser.id);
      expect(result.isRight(), true);
      result.fold((_) {}, (u) => expect(u.status, UserStatus.active));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = ActivateUser(
        MockAdminRepo(getUserResult: kSuspendedUser),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call(kSuspendedUser.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });

    test('retourne CannotModifySelfFailure si admin cible son propre compte',
        () async {
      final uc = ActivateUser(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kAdminUser.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<CannotModifySelfFailure>()), (_) {});
    });

    test('retourne CannotModifyAdminFailure si la cible est admin', () async {
      final uc = ActivateUser(
        MockAdminRepo(getUserResult: kOtherAdmin),
        MockAuthRepo(),
      );
      final result = await uc.call(kOtherAdmin.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<CannotModifyAdminFailure>()), (_) {});
    });

    test('retourne ServerFailure si getUser échoue', () async {
      final uc = ActivateUser(
        MockAdminRepo(getUserFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(kSuspendedUser.id);
      expect(result.isLeft(), true);
    });
  });

  // ─── AssignRole ────────────────────────────────────────────────────────────
  group('AssignRole', () {
    test('assigne le rôle vip avec succès', () async {
      final uc = AssignRole(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kRegularUser.id, 'vip');
      expect(result.isRight(), true);
      result.fold((_) {}, (u) => expect(u.role, Role.vip));
    });

    test('assigne le rôle admin avec succès', () async {
      final uc = AssignRole(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kRegularUser.id, 'admin');
      expect(result.isRight(), true);
      result.fold((_) {}, (u) => expect(u.role, Role.admin));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = AssignRole(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call(kVipUser.id, 'user');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });

    test('retourne CannotModifySelfFailure si admin cible son propre compte',
        () async {
      final uc = AssignRole(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kAdminUser.id, 'user');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<CannotModifySelfFailure>()), (_) {});
    });

    test('retourne CannotModifyAdminFailure si la cible est admin', () async {
      final uc = AssignRole(
        MockAdminRepo(getUserResult: kOtherAdmin),
        MockAuthRepo(),
      );
      final result = await uc.call(kOtherAdmin.id, 'user');
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<CannotModifyAdminFailure>()), (_) {});
    });

    test('retourne ServerFailure si getUser échoue', () async {
      final uc = AssignRole(
        MockAdminRepo(getUserFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(kRegularUser.id, 'vip');
      expect(result.isLeft(), true);
    });

    test('retourne Failure si l\'opération échoue', () async {
      final uc = AssignRole(
        MockAdminRepo(operationFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(kRegularUser.id, 'vip');
      expect(result.isLeft(), true);
    });
  });
}
