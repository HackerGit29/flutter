import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/repositories/admin_repository.dart';
import 'package:aricie/domain/repositories/auth_repository.dart';
import 'package:aricie/screens/admin/admin_box_detail_screen.dart';

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

  Widget wrap() => MaterialApp(home: AdminBoxDetailScreen(box: kBox));

  group('AdminBoxDetailScreen', () {
    testWidgets('renders box info and an empty sync history', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Actif'), findsOneWidget);
      expect(find.text(kBox.uidHardware), findsOneWidget);
      expect(find.text('Aucune synchronisation'), findsOneWidget);
    });

    testWidgets('resetting the box shows a confirmation dialog then a success snackbar',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser'));
      await tester.pumpAndSettle();

      expect(find.text('Réinitialiser le boîtier'), findsOneWidget);

      await tester.tap(find.text('Réinitialiser').last);
      await tester.pump();
      await tester.pump();

      expect(find.text('Boîtier réinitialisé'), findsOneWidget);
    });

    testWidgets('cancelling the reset dialog does nothing', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Boîtier réinitialisé'), findsNothing);
    });

    testWidgets('assigning the box with a user id shows a success snackbar',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assigner'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'ID utilisateur'), 'user-2');
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Assigner'),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Boîtier assigné'), findsOneWidget);
    });

    testWidgets('leaving the assign dialog user id empty does nothing', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assigner'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Assigner'),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Boîtier assigné'), findsNothing);
    });

    testWidgets('forcing a sync shows a confirmation dialog then reloads logs',
        (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Forcer sync'));
      await tester.pumpAndSettle();

      expect(find.text('Forcer la synchronisation'), findsOneWidget);

      await tester.tap(find.text('Forcer'));
      await tester.pumpAndSettle();

      expect(find.text('Synchronisation forcée'), findsOneWidget);
    });

    testWidgets('overriding ownership with an empty reason does nothing', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Override'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'user-2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ownership modifié'), findsNothing);
      expect(find.text('Erreur lors de l\'override'), findsNothing);
    });

    testWidgets('overriding ownership with a reason succeeds', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Override'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'user-2');
      await tester.enterText(fields.last, 'Fraud investigation');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirmer'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ownership modifié'), findsOneWidget);
    });

    testWidgets('shows an error snackbar when reset fails', (tester) async {
      adminRepo.operationFails = true;
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Réinitialiser'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réinitialiser').last);
      await tester.pump();
      await tester.pump();

      expect(find.text('Erreur lors de la réinitialisation'), findsOneWidget);
    });
  });
}
