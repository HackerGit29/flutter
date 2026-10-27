import 'package:aricie/domain/repositories/license_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/core/errors/failures.dart';
import 'package:aricie/presentation/widgets/premium_gate_widget.dart';
import 'package:dartz/dartz.dart';
import 'package:get_it/get_it.dart';

class FakeLicenseRepositoryForWidget implements LicenseRepository {
  bool isAllowed = false;

  @override
  Future<Either<Failure, bool>> isFeatureAllowed(String featureName) async {
    return Right(isAllowed);
  }

  @override
  Future<Either<Failure, bool>> checkLicenseValidity() async => const Right(true);
  @override
  Future<Either<Failure, Subscription>> getUserSubscription() async => Left(const ServerFailure());
  @override
  Future<Either<Failure, Subscription>> getUserSubscriptionForUser(String userId) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, Subscription>> redeemProductKey(String key) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, Subscription>> upgradeToVip(String licenseKey) async => Left(const ServerFailure());
  @override
  Future<Either<Failure, Subscription>> cancelSubscription() async => Left(const ServerFailure());
}

void main() {
  late FakeLicenseRepositoryForWidget fakeRepo;

  setUpAll(() {
    fakeRepo = FakeLicenseRepositoryForWidget();
    sl.registerLazySingleton<LicenseRepository>(() => fakeRepo);
  });

  tearDownAll(() async {
    await sl.reset();
  });

  group('PremiumGateWidget', () {
    testWidgets('renders loading indicator initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumGateWidget(
              featureName: 'ai_chat',
              premiumChild: Text('Premium Content'),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders premiumChild when feature is allowed', (WidgetTester tester) async {
      fakeRepo.isAllowed = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumGateWidget(
              featureName: 'ai_chat',
              premiumChild: Text('Premium Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Premium Content'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders fallback when feature is not allowed', (WidgetTester tester) async {
      fakeRepo.isAllowed = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumGateWidget(
              featureName: 'ai_chat',
              premiumChild: Text('Premium Content'),
              fallback: Text('Custom Fallback'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Custom Fallback'), findsOneWidget);
      expect(find.text('Premium Content'), findsNothing);
    });

    testWidgets('renders default fallback when feature is not allowed and no custom fallback is provided', (WidgetTester tester) async {
      fakeRepo.isAllowed = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PremiumGateWidget(
              featureName: 'ai_chat',
              premiumChild: Text('Premium Content'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Fonctionnalité premium'), findsOneWidget);
      expect(find.text('Passer en VIP'), findsOneWidget);
    });
  });
}
