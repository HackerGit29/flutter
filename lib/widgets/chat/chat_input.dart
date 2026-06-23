import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/voice_service.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isVoiceMode;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.isVoiceMode = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _textController = TextEditingController();
  bool _canSend = false;
  bool _isListening = false;
  final VoiceService _voiceService = VoiceService.instance;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_checkCanSend);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _checkCanSend() {
    final text = _textController.text.trim();
    final canSend = text.isNotEmpty;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  void _handleSend() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _textController.clear();
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);

    await _voiceService.startListening(
      onResult: (text) {
        if (text.isNotEmpty) {
          widget.onSendMessage(text);
        }
      },
      onDone: () {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Microphone button
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: _isListening
                    ? Theme.of(context).colorScheme.error.withOpacity(0.2)
                    : widget.isVoiceMode
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                        : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isListening
                    ? const Icon(Icons.mic_off_rounded)
                    : Icon(
                        widget.isVoiceMode
                            ? Icons.record_voice_over_rounded
                            : Icons.mic_rounded,
                      ),
                onPressed: _toggleListening,
                color: _isListening
                    ? Theme.of(context).colorScheme.error
                    : widget.isVoiceMode
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primary,
                tooltip: _isListening
                    ? 'Arrêter l\'écoute'
                    : 'Dicter un message',
              ),
            ),
            // Text input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Écoute en cours...'
                        : 'Écrivez votre message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _canSend ? (_) => _handleSend() : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: _canSend
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded),
                color: _canSend
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.4),
                onPressed: _canSend ? _handleSend : null,
              ),
            ).animate(target: _canSend ? 1 : 0).scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.0, 1.0),
                  curve: Curves.elasticOut,
                  duration: const Duration(milliseconds: 300),
                ),
          ],
        ),
      ),
    );
  }
}
