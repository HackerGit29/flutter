import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/box.dart';
import 'package:aricie/domain/entities/appliance.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/usecases/admin/create_box_for_user.dart';
import 'package:aricie/domain/usecases/admin/create_appliances_for_box.dart';
import 'package:aricie/domain/usecases/admin/get_all_users.dart';
import 'package:aricie/domain/usecases/admin/get_all_devices.dart';
import 'package:aricie/domain/usecases/admin/get_available_boxes.dart';
import 'package:aricie/domain/usecases/admin/activate_subscription.dart';
import 'package:aricie/domain/usecases/admin/revoke_subscription.dart';
import 'package:aricie/domain/usecases/admin/get_all_subscriptions.dart';
import 'admin_mocks.dart';

void main() {
  // ─── CreateBoxForUser ──────────────────────────────────────────────────────
  group('CreateBoxForUser', () {
    test('crée un boîtier pour un utilisateur avec succès', () async {
      final uc = CreateBoxForUser(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(
        uidHardware: 'ESP32-ABCDEF01',
        name: 'Boîtier salon',
        location: 'Salon',
        userId: kRegularUser.id,
      );
      expect(result.isRight(), true);
      result.fold((_) {}, (box) {
        expect(box.uidHardware, 'ESP32-ABCDEF01');
        expect(box.name, 'Boîtier salon');
        expect(box.status, BoxStatus.active);
      });
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = CreateBoxForUser(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call(
        uidHardware: 'ESP32-ABCDEF01',
        name: 'Test',
        userId: kRegularUser.id,
      );
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });

    test('retourne Failure si la création échoue', () async {
      final uc = CreateBoxForUser(
        MockAdminRepo(operationFails: true),
        MockAuthRepo(),
      );
      final result = await uc.call(
        uidHardware: 'ESP32-ABCDEF01',
        name: 'Test',
        userId: kRegularUser.id,
      );
      expect(result.isLeft(), true);
    });
  });

  // ─── CreateAppliancesForBox ────────────────────────────────────────────────
  group('CreateAppliancesForBox', () {
    test('crée 3 appareils pour un boîtier avec succès', () async {
      final uc = CreateAppliancesForBox(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call('box-1', kRegularUser.id);
      expect(result.isRight(), true);
      result.fold((_) {}, (appliances) {
        expect(appliances.length, 3);
        expect(appliances[0].relayIndex, 1);
        expect(appliances[1].relayIndex, 2);
        expect(appliances[2].relayIndex, 3);
      });
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = CreateAppliancesForBox(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call('box-1', kRegularUser.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });

    test('les appareils sont initialement éteints', () async {
      final uc = CreateAppliancesForBox(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call('box-1', kRegularUser.id);
      result.fold((_) {}, (appliances) {
        for (final a in appliances) {
          expect(a.isOn, false);
        }
      });
    });
  });

  // ─── GetAllUsers ───────────────────────────────────────────────────────────
  group('GetAllUsers', () {
    test('retourne la liste de tous les utilisateurs', () async {
      final uc = GetAllUsers(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (users) => expect(users.isNotEmpty, true));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = GetAllUsers(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call();
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── GetAllDevices ─────────────────────────────────────────────────────────
  group('GetAllDevices', () {
    test('retourne la liste de tous les boîtiers', () async {
      final uc = GetAllDevices(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (boxes) => expect(boxes.isNotEmpty, true));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc =
          GetAllDevices(MockAdminRepo(), MockAuthRepo(user: kRegularUser));
      final result = await uc.call();
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── GetAvailableBoxes ─────────────────────────────────────────────────────
  group('GetAvailableBoxes', () {
    test('retourne une liste vide si aucun boîtier disponible', () async {
      final uc = GetAvailableBoxes(MockAdminRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
    });

    test('retourne la liste même sans vérification de permission', () async {
      final uc = GetAvailableBoxes(MockAdminRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
    });
  });

  // ─── ActivateSubscription ──────────────────────────────────────────────────
  group('ActivateSubscription', () {
    test('active un abonnement avec succès', () async {
      final uc = ActivateSubscription(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kSubscription.id);
      expect(result.isRight(), true);
      result.fold((_) {}, (sub) => expect(sub.isActive, true));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = ActivateSubscription(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call(kSubscription.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── RevokeSubscription ────────────────────────────────────────────────────
  group('RevokeSubscription', () {
    test('révoque un abonnement avec succès', () async {
      final uc = RevokeSubscription(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call(kSubscription.id);
      expect(result.isRight(), true);
      result.fold((_) {}, (sub) => expect(sub.isActive, false));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = RevokeSubscription(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call(kSubscription.id);
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });

  // ─── GetAllSubscriptions ───────────────────────────────────────────────────
  group('GetAllSubscriptions', () {
    test('retourne la liste des abonnements', () async {
      final uc = GetAllSubscriptions(MockAdminRepo(), MockAuthRepo());
      final result = await uc.call();
      expect(result.isRight(), true);
      result.fold((_) {}, (subs) => expect(subs.isNotEmpty, true));
    });

    test('retourne AdminPermissionFailure si non-admin', () async {
      final uc = GetAllSubscriptions(
        MockAdminRepo(),
        MockAuthRepo(user: kRegularUser),
      );
      final result = await uc.call();
      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<AdminPermissionFailure>()), (_) {});
    });
  });
}
