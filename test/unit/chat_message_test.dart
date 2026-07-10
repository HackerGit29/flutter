import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    final timestamp = DateTime(2026, 1, 1);

    test('initializes with default values', () {
      final msg = ChatMessage(
        id: 'msg-1',
        text: 'hello',
        isUser: true,
        timestamp: timestamp,
      );

      expect(msg.id, 'msg-1');
      expect(msg.text, 'hello');
      expect(msg.isUser, true);
      expect(msg.isEdited, false);
      expect(msg.timestamp, timestamp);
      expect(msg.isStreaming, false);
      expect(msg.actionType, null);
      expect(msg.isError, false);
    });

    test('copyWith updates specified fields and preserves others', () {
      final msg = ChatMessage(
        id: 'msg-1',
        text: 'hello',
        isUser: true,
        timestamp: timestamp,
        isEdited: false,
        isStreaming: false,
        actionType: 'tip',
        isError: false,
      );

      final updated = msg.copyWith(
        text: 'world',
        isEdited: true,
        isStreaming: true,
        actionType: 'alert',
        isError: true,
      );

      expect(updated.id, 'msg-1');
      expect(updated.text, 'world');
      expect(updated.isUser, true);
      expect(updated.isEdited, true);
      expect(updated.timestamp, timestamp);
      expect(updated.isStreaming, true);
      expect(updated.actionType, 'alert');
      expect(updated.isError, true);
    });
  });
}
