class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isEdited;
  final DateTime timestamp;
  final bool isStreaming;
  final String? actionType;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.isEdited = false,
    required this.timestamp,
    this.isStreaming = false,
    this.actionType,
    this.isError = false,
  });

  ChatMessage copyWith({
    String? text,
    bool? isUser,
    bool? isEdited,
    DateTime? timestamp,
    bool? isStreaming,
    String? actionType,
    bool? isError,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isEdited: isEdited ?? this.isEdited,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      actionType: actionType ?? this.actionType,
      isError: isError ?? this.isError,
    );
  }
}
