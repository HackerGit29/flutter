import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/screens/admin/admin_subscription_detail_screen.dart';

import '../../domain/usecases/admin/admin_mocks.dart';

void main() {
  late MockAdminRepo adminRepo;

  setUp(() {
    adminRepo = MockAdminRepo();
    sl.registerLazySingleton<AdminRepository>(() => adminRepo);
    sl.registerLazySingleton<AuthRepository>(() => MockAuthRepo());
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap(Subscription subscription) => MaterialApp(
        home: AdminSubscriptionDetailScreen(subscription: subscription),
      );

  group('AdminSubscriptionDetailScreen', () {
    testWidgets('renders subscription details for an active subscription',
        (tester) async {
      await tester.pumpWidget(wrap(kSubscription));

      expect(find.text('Valide'), findsOneWidget);
      expect(find.text('vip'), findsOneWidget);
      expect(find.text('oui'), findsWidgets);

      final activateButton =
          tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Activer'));
      expect(activateButton.onPressed, isNull);
    });

    testWidgets('falls back to the userId when no owner is provided',
        (tester) async {
      await tester.pumpWidget(wrap(kSubscription));

      expect(find.text(kSubscription.userId), findsOneWidget);
    });

    testWidgets('revoking an active subscription shows a confirmation dialog',
        (tester) async {
      await tester.pumpWidget(wrap(kSubscription));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Révoquer'));
      await tester.pumpAndSettle();

      expect(find.text('Révoquer la licence'), findsOneWidget);

      await tester.tap(find.text('Révoquer').last);
      await tester.pumpAndSettle();

      expect(find.text('Licence révoquée'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('cancelling the revoke dialog leaves the subscription active',
        (tester) async {
      await tester.pumpWidget(wrap(kSubscription));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Révoquer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Valide'), findsOneWidget);
    });

    testWidgets('activating an inactive subscription shows a success snackbar',
        (tester) async {
      final inactive = Subscription(
        id: kSubscription.id,
        userId: kSubscription.userId,
        type: SubscriptionType.free,
        startDate: kSubscription.startDate,
        isActive: false,
        autoRenew: false,
        createdAt: kSubscription.createdAt,
      );

      await tester.pumpWidget(wrap(inactive));

      expect(find.text('Inactive'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Activer'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Licence activée'), findsOneWidget);
    });

    testWidgets('shows an error snackbar when activation fails',
        (tester) async {
      adminRepo.operationFails = true;
      final inactive = Subscription(
        id: kSubscription.id,
        userId: kSubscription.userId,
        type: SubscriptionType.free,
        startDate: kSubscription.startDate,
        isActive: false,
        autoRenew: false,
        createdAt: kSubscription.createdAt,
      );

      await tester.pumpWidget(wrap(inactive));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Activer'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Erreur lors de l\'activation'), findsOneWidget);
    });
  });
}
