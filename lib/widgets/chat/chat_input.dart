import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/voice_service.dart';

enum MicState { idle, recording, processing }

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

class _ChatInputState extends State<ChatInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  bool _canSend = false;
  MicState _micState = MicState.idle;
  final VoiceService _voiceService = VoiceService.instance;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_checkCanSend);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulseController.dispose();
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

  void _onMicPress() async {
    if (_micState != MicState.idle) return;

    setState(() => _micState = MicState.recording);
    _pulseController.repeat(reverse: true);

    await _voiceService.startListening(
      onResult: (text) {
        if (text.isNotEmpty) {
          _textController.text = text;
          _textController.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        }
      },
      onDone: () {
        // Transcribe result arrived, auto-send
        final text = _textController.text.trim();
        if (text.isNotEmpty) {
          widget.onSendMessage(text);
          _textController.clear();
        }
        if (mounted) {
          setState(() => _micState = MicState.idle);
          _pulseController.reset();
        }
      },
    );
  }

  void _onMicRelease() async {
    if (_micState != MicState.recording) return;

    setState(() => _micState = MicState.processing);
    _pulseController.reset();

    await _voiceService.stopListening();
    // stopListening will trigger onResult → onDone → auto-send
  }

  @override
  Widget build(BuildContext context) {
    final isIdle = _micState == MicState.idle;
    final isRecording = _micState == MicState.recording;
    final isProcessing = _micState == MicState.processing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Microphone button — hold to talk
            GestureDetector(
              onTapDown: isIdle ? (_) => _onMicPress() : null,
              onTapUp: isRecording ? (_) => _onMicRelease() : null,
              onTapCancel: isRecording ? _onMicRelease : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isRecording
                      ? Theme.of(context).colorScheme.error
                      : isProcessing
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3)
                          : widget.isVoiceMode
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1)
                              : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: isRecording
                      ? [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        )
                      : Icon(
                          isRecording ? Icons.mic_rounded : Icons.mic_rounded,
                          color: isRecording
                              ? Colors.white
                              : widget.isVoiceMode
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                        ),
                ),
              ).animate(target: isRecording ? 1 : 0).scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.15, 1.15),
                    curve: Curves.easeInOut,
                  ),
            ),
            const SizedBox(width: 8),
            // Text input
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  readOnly: isRecording || isProcessing,
                  decoration: InputDecoration(
                    hintText: isRecording
                        ? 'Parlez...'
                        : isProcessing
                            ? 'Transcription...'
                            : 'Écrivez votre message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.7),
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
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded),
                color: _canSend
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
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
