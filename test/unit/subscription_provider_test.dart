import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:aricie/providers/subscription_provider.dart';
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';

class MockLicenseRepository extends Mock implements LicenseRepository {}

void main() {
  late MockLicenseRepository mockRepository;
  late SubscriptionProvider provider;

  setUpAll(() {
    mockRepository = MockLicenseRepository();
    sl.registerLazySingleton<LicenseRepository>(() => mockRepository);
  });

  setUp(() {
    provider = SubscriptionProvider();
  });

  tearDown(() {
    reset(mockRepository);
  });

  group('SubscriptionProvider', () {
    final mockSubscription = Subscription(
      id: 'sub-123',
      userId: 'user-123',
      type: SubscriptionType.vip,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      isActive: true,
      autoRenew: true,
      createdAt: DateTime(2026, 1, 1),
    );

    test('initial state should be loading and subscription null', () {
      expect(provider.isLoading, true);
      expect(provider.subscription, isNull);
      expect(provider.isVip, false);
    });

    test('reset should clear session status and notify listeners', () {
      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      provider.reset();

      expect(provider.subscription, isNull);
      expect(provider.isLoading, false);
      expect(provider.isVip, false);
      expect(notified, true);
    });

    test('load should update subscription and set loading to false on success', () async {
      when(() => mockRepository.getUserSubscription()).thenAnswer((_) async => Right(mockSubscription));

      bool notified = false;
      provider.addListener(() {
        notified = true;
      });

      await provider.load();

      expect(provider.subscription, mockSubscription);
      expect(provider.isLoading, false);
      expect(provider.isVip, true);
      expect(notified, true);
      verify(() => mockRepository.getUserSubscription()).called(1);
    });

    test('load should set subscription to null when call returns failure', () async {
      when(() => mockRepository.getUserSubscription()).thenAnswer((_) async => const Left(ServerFailure()));

      await provider.load();

      expect(provider.subscription, isNull);
      expect(provider.isLoading, false);
      expect(provider.isVip, false);
    });

    test('loadForUser should update subscription and set loading to false on success', () async {
      const userId = 'user-123';
      when(() => mockRepository.getUserSubscriptionForUser(userId)).thenAnswer((_) async => Right(mockSubscription));

      await provider.loadForUser(userId);

      expect(provider.subscription, mockSubscription);
      expect(provider.isLoading, false);
      expect(provider.isVip, true);
      verify(() => mockRepository.getUserSubscriptionForUser(userId)).called(1);
    });

    test('loadForUser should set subscription to null when call returns failure', () async {
      const userId = 'user-123';
      when(() => mockRepository.getUserSubscriptionForUser(userId)).thenAnswer((_) async => const Left(ServerFailure()));

      await provider.loadForUser(userId);

      expect(provider.subscription, isNull);
      expect(provider.isLoading, false);
    });
  });
}
