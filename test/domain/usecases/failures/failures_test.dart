import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/errors/failures.dart';

void main() {
  group('Failures — messages par défaut', () {
    test('ServerFailure a le bon message par défaut', () {
      const f = ServerFailure();
      expect(f.message, 'Erreur serveur');
    });

    test('NetworkFailure a le bon message par défaut', () {
      const f = NetworkFailure();
      expect(f.message, 'Erreur réseau');
    });

    test('CacheFailure a le bon message par défaut', () {
      const f = CacheFailure();
      expect(f.message, 'Erreur cache local');
    });

    test('AuthFailure a le bon message par défaut', () {
      const f = AuthFailure();
      expect(f.message, 'Erreur d\'authentification');
    });

    test('InvalidCredentialsFailure a le bon message par défaut', () {
      const f = InvalidCredentialsFailure();
      expect(f.message, 'Email ou mot de passe incorrect');
    });

    test('SessionExpiredFailure a le bon message par défaut', () {
      const f = SessionExpiredFailure();
      expect(f.message, 'Session expirée, reconnectez-vous');
    });

    test('AccountSuspendedFailure a le bon message par défaut', () {
      const f = AccountSuspendedFailure();
      expect(f.message, contains('suspendu'));
    });

    test('DeviceOwnershipFailure a le bon message par défaut', () {
      const f = DeviceOwnershipFailure();
      expect(f.message, contains('propriétaire'));
    });

    test('DeviceNotFoundFailure a le bon message par défaut', () {
      const f = DeviceNotFoundFailure();
      expect(f.message, contains('introuvable'));
    });

    test('DeviceAlreadyAssignedFailure a le bon message par défaut', () {
      const f = DeviceAlreadyAssignedFailure();
      expect(f.message, contains('déjà assigné'));
    });

    test('DeviceNotIdentifiedFailure a le bon message par défaut', () {
      const f = DeviceNotIdentifiedFailure();
      expect(f.message, contains('identifier'));
    });

    test('DeviceCryptoMismatchFailure a le bon message par défaut', () {
      const f = DeviceCryptoMismatchFailure();
      expect(f.message, contains('invalide'));
    });

    test('DeviceBlockedFailure a le bon message par défaut', () {
      const f = DeviceBlockedFailure();
      expect(f.message, contains('bloqué'));
    });

    test('LicenseExpiredFailure a le bon message par défaut', () {
      const f = LicenseExpiredFailure();
      expect(f.message, contains('expiré'));
    });

    test('NoActiveSubscriptionFailure a le bon message par défaut', () {
      const f = NoActiveSubscriptionFailure();
      expect(f.message, contains('abonnement'));
    });

    test('AlreadyHasActiveSubscriptionFailure a le bon message par défaut', () {
      const f = AlreadyHasActiveSubscriptionFailure();
      expect(f.message, contains('abonnement actif'));
    });

    test('FeatureNotAllowedFailure a le bon message par défaut', () {
      const f = FeatureNotAllowedFailure();
      expect(f.message, contains('VIP'));
    });

    test('AdminPermissionFailure a le bon message par défaut', () {
      const f = AdminPermissionFailure();
      expect(f.message, contains('administrateur'));
    });

    test('CannotModifySelfFailure a le bon message par défaut', () {
      const f = CannotModifySelfFailure();
      expect(f.message, contains('propre compte'));
    });

    test('CannotModifyAdminFailure a le bon message par défaut', () {
      const f = CannotModifyAdminFailure();
      expect(f.message, contains('administrateur'));
    });

    test('SyncUnauthorizedFailure a le bon message par défaut', () {
      const f = SyncUnauthorizedFailure();
      expect(f.message, contains('autorisée'));
    });

    test('SyncRateLimitFailure a le bon message par défaut', () {
      const f = SyncRateLimitFailure();
      expect(f.message, contains('tentatives'));
    });

    test('SyncInProgressFailure a le bon message par défaut', () {
      const f = SyncInProgressFailure();
      expect(f.message, contains('cours'));
    });
  });

  group('Failures — message personnalisé', () {
    test('ServerFailure accepte un message personnalisé', () {
      const f = ServerFailure('Erreur personnalisée');
      expect(f.message, 'Erreur personnalisée');
    });

    test('NetworkFailure accepte un message personnalisé', () {
      const f = NetworkFailure('Pas de réseau');
      expect(f.message, 'Pas de réseau');
    });

    test('AdminPermissionFailure accepte un message personnalisé', () {
      const f = AdminPermissionFailure('Accès refusé');
      expect(f.message, 'Accès refusé');
    });
  });

  group('Failures — équality (Equatable)', () {
    test('deux ServerFailure avec le même message sont égales', () {
      const f1 = ServerFailure('err');
      const f2 = ServerFailure('err');
      expect(f1, equals(f2));
    });

    test('deux ServerFailure avec des messages différents ne sont pas égales', () {
      const f1 = ServerFailure('err1');
      const f2 = ServerFailure('err2');
      expect(f1, isNot(equals(f2)));
    });

    test('deux types différents de failures ne sont pas égaux', () {
      const f1 = ServerFailure();
      const f2 = NetworkFailure();
      expect(f1, isNot(equals(f2)));
    });

    test('props contient le message', () {
      const f = ServerFailure('test');
      expect(f.props, contains('test'));
    });
  });

  group('Failures — hiérarchie de types', () {
    test('InvalidCredentialsFailure est un AuthFailure', () {
      const f = InvalidCredentialsFailure();
      expect(f, isA<AuthFailure>());
      expect(f, isA<Failure>());
    });

    test('SessionExpiredFailure est un AuthFailure', () {
      const f = SessionExpiredFailure();
      expect(f, isA<AuthFailure>());
    });

    test('AccountSuspendedFailure est un AuthFailure', () {
      const f = AccountSuspendedFailure();
      expect(f, isA<AuthFailure>());
    });

    test('AdminPermissionFailure est un Failure', () {
      const f = AdminPermissionFailure();
      expect(f, isA<Failure>());
    });
  });
}