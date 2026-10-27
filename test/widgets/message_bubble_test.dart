import
 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/models/chat_message.dart';
import 'package:aricie/widgets/chat/message_bubble.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  /// Helper to dispose the widget tree and clear pending animation timers
  Future<void> disposeWidgetTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('MessageBubble displays user message with correct alignment and text', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '1',
      text: 'Bonjour',
      isUser: true,
      timestamp: DateTime(2026, 1, 1, 14, 30),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(message: message),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bonjour'), findsOneWidget);
    expect(find.text('14:30'), findsOneWidget);

    final Align align = tester.widget(find.byType(Align).first);
    expect(align.alignment, Alignment.centerRight);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble displays agent message aligned left', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '2',
      text: 'Réponse du bot',
      isUser: false,
      timestamp: DateTime(2026, 1, 1, 14, 35),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(message: message),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Réponse du bot'), findsOneWidget);
    final Align align = tester.widget(find.byType(Align).first);
    expect(align.alignment, Alignment.centerLeft);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble shows typing/streaming loader when text is empty', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '4',
      text: '',
      isUser: false,
      isStreaming: true,
      timestamp: DateTime(2026, 1, 1, 14, 45),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(message: message),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble shows (modifié) when message is edited', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '5',
      text: 'Message édité',
      isUser: true,
      isEdited: true,
      timestamp: DateTime(2026, 1, 1, 14, 50),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(message: message),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('(modifié)'), findsOneWidget);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble shows action labels correctly', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '6',
      text: 'Éteindre la lumière',
      isUser: false,
      actionType: 'turn_off_appliance',
      timestamp: DateTime(2026, 1, 1, 14, 55),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(message: message),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Extinction en cours...'), findsOneWidget);
    expect(find.byIcon(Icons.power_settings_new_rounded), findsOneWidget);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble formats time correctly', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '8',
      text: 'Message avec heure',
      isUser: true,
      timestamp: DateTime(2026, 7, 10, 9, 5),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(message: message),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Time should be padded: 09:05
    expect(find.text('09:05'), findsOneWidget);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble long press opens context menu with Copier', (WidgetTester tester) async {
    var copyCalled = false;

    final message = ChatMessage(
      id: '7',
      text: 'Texte à copier',
      isUser: true,
      timestamp: DateTime(2026, 1, 1, 15, 00),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(
          message: message,
          onCopy: () {
            copyCalled = true;
          },
          onEdit: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Long press to open menu
    await tester.longPress(find.text('Texte à copier'));
    await tester.pump(const Duration(milliseconds: 500));

    // Menu should contain Copier and Modifier (user message + onEdit provided)
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Modifier'), findsOneWidget);

    // Tap Copier
    await tester.tap(find.text('Copier'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(copyCalled, isTrue);

    await disposeWidgetTree(tester);
  });

  testWidgets('MessageBubble does not show Modifier for bot messages', (WidgetTester tester) async {
    final message = ChatMessage(
      id: '9',
      text: 'Réponse bot',
      isUser: false,
      timestamp: DateTime(2026, 1, 1, 15, 10),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        MessageBubble(
          message: message,
          onCopy: () {},
          onEdit: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // Long press
    await tester.longPress(find.text('Réponse bot'));
    await tester.pump(const Duration(milliseconds: 500));

    // Should have Copier but NOT Modifier (bot message)
    expect(find.text('Copier'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);

    // Close menu
    await tester.tapAt(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));

    await disposeWidgetTree(tester);
  });
}
