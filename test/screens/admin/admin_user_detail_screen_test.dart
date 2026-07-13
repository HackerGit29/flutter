import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/screens/admin/admin_user_detail_screen.dart';

import '../../domain/usecases/admin/admin_mocks.dart';

void main() {
  late MockAdminRepo adminRepo;

  setUp(() {
    adminRepo = MockAdminRepo(getUserResult: kRegularUser);
    sl.registerLazySingleton<AdminRepository>(() => adminRepo);
    sl.registerLazySingleton<AuthRepository>(() => MockAuthRepo());
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget wrap() => MaterialApp(home: AdminUserDetailScreen(user: kRegularUser));

  group('AdminUserDetailScreen', () {
    testWidgets('shows user info and their assigned boxes', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text(kRegularUser.email), findsWidgets);
      expect(find.text('Boîtiers (1)'), findsOneWidget);
      expect(find.text(kBox.name), findsOneWidget);
    });

    testWidgets('shows "no box" message when the user has none', (tester) async {
      // getAllBoxes() always returns [kBox], which belongs to kRegularUser
      // (user-1), so a different target user hits the empty-boxes branch.
      await tester.pumpWidget(
        MaterialApp(home: AdminUserDetailScreen(user: kVipUser)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun boîtier assigné'), findsOneWidget);
    });

    testWidgets('suspending shows a confirmation dialog then a success snackbar',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Suspendre'));
      await tester.pumpAndSettle();

      expect(find.text('Suspendre l\'utilisateur'), findsOneWidget);

      await tester.tap(find.text('Suspendre').last);
      await tester.pump();
      await tester.pump();

      expect(find.text('Utilisateur suspendu'), findsOneWidget);
    });

    testWidgets('cancelling the suspend dialog does nothing', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Suspendre'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Utilisateur suspendu'), findsNothing);
    });

    testWidgets('changing role shows a success snackbar', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Changer rôle'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('VIP'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Rôle changé en vip'), findsOneWidget);
    });

    testWidgets('shows an error snackbar when suspend fails', (tester) async {
      adminRepo.operationFails = true;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Suspendre'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspendre').last);
      await tester.pump();
      await tester.pump();

      expect(find.text('Erreur'), findsOneWidget);
    });
  });
}
