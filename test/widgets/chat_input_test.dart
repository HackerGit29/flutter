import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aricie/widgets/chat/chat_input.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://placeholder.supabase.co',
      anonKey: 'placeholder-anon-key',
    );
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('ChatInput renders text field and action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        ChatInput(onSendMessage: (_) {}),
      ),
    );
    // Only pump a few frames — pumpAndSettle would time out on repeating animations
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    final TextField textField = tester.widget(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);

    // Dispose widget tree to clear pending timers from flutter_animate
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Typing text and tapping send invokes callback and clears field',
      (WidgetTester tester) async {
    String sentMessage = '';

    await tester.pumpWidget(
      buildTestableWidget(
        ChatInput(
          onSendMessage: (msg) {
            sentMessage = msg;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Enter text
    await tester.enterText(find.byType(TextField), 'Test message');
    await tester.pump(const Duration(milliseconds: 300));

    // Verify text is entered
    final TextField textFieldBefore = tester.widget(find.byType(TextField));
    expect(textFieldBefore.controller?.text, 'Test message');

    // Tap send button
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify callback was called
    expect(sentMessage, 'Test message');

    // Verify text field is cleared
    final TextField textFieldAfter = tester.widget(find.byType(TextField));
    expect(textFieldAfter.controller?.text, isEmpty);

    // Dispose widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('didUpdateWidget updates text controller when editingText changes',
      (WidgetTester tester) async {
    // First build WITHOUT editingText
    await tester.pumpWidget(
      buildTestableWidget(
        ChatInput(onSendMessage: (_) {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final TextField textField1 = tester.widget(find.byType(TextField));
    expect(textField1.controller?.text, isEmpty);

    // Rebuild WITH editingText — triggers didUpdateWidget
    await tester.pumpWidget(
      buildTestableWidget(
        ChatInput(
          onSendMessage: (_) {},
          editingText: 'Texte à modifier',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final TextField textField2 = tester.widget(find.byType(TextField));
    expect(textField2.controller?.text, 'Texte à modifier');

    // Update to a different editingText
    await tester.pumpWidget(
      buildTestableWidget(
        ChatInput(
          onSendMessage: (_) {},
          editingText: 'Nouveau texte',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final TextField textField3 = tester.widget(find.byType(TextField));
    expect(textField3.controller?.text, 'Nouveau texte');

    // Dispose widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Send button does nothing when text is empty or whitespace',
      (WidgetTester tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      buildTestableWidget(
        ChatInput(
          onSendMessage: (_) {
            callCount++;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap send with empty text — should not invoke callback
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 0);

    // Enter whitespace only
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump(const Duration(milliseconds: 300));

    // Tap send with whitespace — should still not invoke callback
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(callCount, 0);

    // Dispose widget tree
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });
}
