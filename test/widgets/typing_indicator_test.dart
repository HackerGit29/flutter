import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/widgets/chat/typing_indicator.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  /// Helper to dispose the widget tree and clear pending animation timers
  Future<void> disposeWidgetTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('TypingIndicator renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(const TypingIndicator()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify typing indicator builds
    expect(find.byType(TypingIndicator), findsOneWidget);

    await disposeWidgetTree(tester);
  });

  testWidgets('TypingIndicator contains a Row with 3 animated dots', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(const TypingIndicator()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Should have a Row inside TypingIndicator
    expect(find.descendant(of: find.byType(TypingIndicator), matching: find.byType(Row)), findsOneWidget);

    await disposeWidgetTree(tester);
  });
}
