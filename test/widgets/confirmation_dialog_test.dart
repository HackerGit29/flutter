import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/widgets/confirmation_dialog.dart';

void main() {
  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showConfirmationDialog(
                    context,
                    title: 'Titre de Test',
                    body: 'Corps de Test',
                    confirmLabel: 'Confirmer',
                    cancelLabel: 'Annuler',
                  );
                  // We show the result in a SnackBar or another dialog to verify it
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Result: $result')),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            );
          },
        ),
      ),
    );
  }

  testWidgets('showConfirmationDialog displays title, body, and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Tap to show dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog content
    expect(find.text('Titre de Test'), findsOneWidget);
    expect(find.text('Corps de Test'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);
    expect(find.text('Confirmer'), findsOneWidget);
  });

  testWidgets('showConfirmationDialog returns false when cancel is pressed', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Show dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Tap Cancel
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    // Dialog should be gone
    expect(find.text('Titre de Test'), findsNothing);

    // Verify result is false
    expect(find.text('Result: false'), findsOneWidget);
  });

  testWidgets('showConfirmationDialog returns true when confirm is pressed', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());

    // Show dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Tap Confirm
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    // Dialog should be gone
    expect(find.text('Titre de Test'), findsNothing);

    // Verify result is true
    expect(find.text('Result: true'), findsOneWidget);
  });
}
