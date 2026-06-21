import 'package:equatable/equatable.dart';

sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);
  @override List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Erreur serveur']);
}
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Erreur réseau']);
}
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Erreur cache local']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Erreur d\'authentification']);
}
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure([super.message = 'Email ou mot de passe incorrect']);
}
class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure([super.message = 'Session expirée, reconnectez-vous']);
}
class AccountSuspendedFailure extends AuthFailure {
  const AccountSuspendedFailure([super.message = 'Compte suspendu. Contactez l\'administrateur.']);
}

class DeviceOwnershipFailure extends Failure {
  const DeviceOwnershipFailure([super.message = 'Vous n\'êtes pas le propriétaire de ce boîtier']);
}
class DeviceNotFoundFailure extends Failure {
  const DeviceNotFoundFailure([super.message = 'Boîtier introuvable']);
}
class DeviceAlreadyAssignedFailure extends Failure {
  const DeviceAlreadyAssignedFailure([super.message = 'Ce boîtier est déjà assigné à un utilisateur']);
}
class DeviceNotIdentifiedFailure extends Failure {
  const DeviceNotIdentifiedFailure([super.message = 'Impossible d\'identifier le boîtier']);
}
class DeviceCryptoMismatchFailure extends Failure {
  const DeviceCryptoMismatchFailure([super.message = 'Signature du boîtier invalide']);
}
class DeviceBlockedFailure extends Failure {
  const DeviceBlockedFailure([super.message = 'Ce boîtier est bloqué']);
}

class LicenseExpiredFailure extends Failure {
  const LicenseExpiredFailure([super.message = 'Abonnement expiré']);
}
class NoActiveSubscriptionFailure extends Failure {
  const NoActiveSubscriptionFailure([super.message = 'Aucun abonnement actif']);
}
class AlreadyHasActiveSubscriptionFailure extends Failure {
  const AlreadyHasActiveSubscriptionFailure([super.message = 'Vous avez déjà un abonnement actif']);
}
class FeatureNotAllowedFailure extends Failure {
  const FeatureNotAllowedFailure([super.message = 'Cette fonctionnalité nécessite un abonnement VIP']);
}

class AdminPermissionFailure extends Failure {
  const AdminPermissionFailure([super.message = 'Accès administrateur requis']);
}
class CannotModifySelfFailure extends Failure {
  const CannotModifySelfFailure([super.message = 'Vous ne pouvez pas modifier votre propre compte']);
}

class SyncUnauthorizedFailure extends Failure {
  const SyncUnauthorizedFailure([super.message = 'Synchronisation non autorisée']);
}
class SyncRateLimitFailure extends Failure {
  const SyncRateLimitFailure([super.message = 'Trop de tentatives de synchronisation']);
}
class SyncInProgressFailure extends Failure {
  const SyncInProgressFailure([super.message = 'Synchronisation déjà en cours']);
}
