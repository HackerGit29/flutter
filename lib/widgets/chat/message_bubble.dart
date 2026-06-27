import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onCopy;
  final VoidCallback? onEdit;

  const MessageBubble({
    super.key,
    required this.message,
    this.onCopy,
    this.onEdit,
  });

  void _showActions(BuildContext context) {
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(100, 100, 100, 100),
      items: [
        PopupMenuItem<void>(
          child: ListTile(
            leading: const Icon(Icons.copy_rounded, size: 20),
            title: const Text('Copier', style: TextStyle(fontSize: 14)),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.pop(context);
              onCopy?.call();
            },
          ),
        ),
        if (message.isUser && onEdit != null)
          PopupMenuItem<void>(
            child: ListTile(
              leading: const Icon(Icons.edit_rounded, size: 20),
              title: const Text('Modifier', style: TextStyle(fontSize: 14)),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () {
                Navigator.pop(context);
                onEdit?.call();
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isError = message.isError;
    final isStreaming = message.isStreaming;

    Color bgColor;
    Color textColor;
    Color linkColor;

    if (isError) {
      bgColor = Theme.of(context).colorScheme.errorContainer;
      textColor = Theme.of(context).colorScheme.onErrorContainer;
      linkColor = textColor;
    } else if (message.isUser) {
      bgColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimary;
      linkColor = textColor.withValues(alpha: 0.8);
    } else {
      bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      linkColor = Theme.of(context).colorScheme.primary;
    }

    // Strip emojis from bot messages
    final displayText = message.isUser
        ? message.text
        : stripEmojis(message.text);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.only(
            bottom: 12,
            left: message.isUser ? 64 : 0,
            right: message.isUser ? 0 : 64,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: message.isUser
                  ? const Radius.circular(20)
                  : const Radius.circular(4),
              bottomRight: message.isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.actionType != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.power_settings_new_rounded,
                        size: 14,
                        color: !message.isUser
                            ? Theme.of(context).colorScheme.primary
                            : textColor.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _actionLabel(message.actionType!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: !message.isUser
                              ? Theme.of(context).colorScheme.primary
                              : textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              if (isStreaming && displayText.isEmpty)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: textColor.withValues(alpha: 0.6),
                  ),
                )
              else
                MarkdownBody(
                  data: displayText,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: textColor, fontSize: 16, height: 1.4),
                    strong: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    em: TextStyle(color: textColor, fontStyle: FontStyle.italic, fontSize: 16),
                    listBullet: TextStyle(color: textColor, fontSize: 16),
                    a: TextStyle(color: linkColor, decoration: TextDecoration.underline),
                    h1: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                    h2: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
                    h3: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
                    blockquote: TextStyle(color: textColor.withValues(alpha: 0.7), fontStyle: FontStyle.italic),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(top: BorderSide(color: textColor.withValues(alpha: 0.2))),
                    ),
                    listIndent: 24,
                  ),
                ),
              if (message.isEdited)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '(modifié)',
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.5),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              if (isStreaming && displayText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(
              begin: 0.2,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOutQuad,
            ),
      ),
    );
  }

  String _actionLabel(String actionType) {
    switch (actionType) {
      case 'turn_on_appliance':
        return 'Allumage en cours...';
      case 'turn_off_appliance':
        return 'Extinction en cours...';
      case 'get_realtime_consumption':
        return 'Lecture consommation';
      case 'get_device_status':
        return 'Vérification appareil';
      default:
        return actionType;
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Supprime les emojis du texte (appliqué aux réponses IA)
String stripEmojis(String text) {
  return text.replaceAll(RegExp(
    r'[\u{1F300}-\u{1F9FF}'
    r'\u{1FA00}-\u{1FA6F}'
    r'\u{1FA70}-\u{1FAFF}'
    r'\u{2600}-\u{27BF}'
    r'\u{FE00}-\u{FE0F}'
    r'\u{200D}'
    r']',
    unicode: true,
  ), '').trim();
}
