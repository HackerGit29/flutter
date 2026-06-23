import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../models/chat_message.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input.dart';
import '../../services/agent_service.dart';
import '../../services/voice_service.dart';
import 'package:uuid/uuid.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isVoiceMode = false;
  late AnimationController _animationController;
  final AgentService _agentService = AgentService.instance;
  late String _sessionId;
  StreamSubscription<AgentStreamEvent>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _sessionId = const Uuid().v4();
    _showWelcomeMessage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }

  void _showWelcomeMessage() {
    Future.delayed(const Duration(milliseconds: 600), () {
      _addBotMessage(
        "Bonjour ! Je suis Aricie, votre assistante. Comment puis-je vous aider aujourd'hui ?",
      );
    });
  }

  void _addMessage(String text, bool isUser) {
    final message = ChatMessage(
      text: text,
      isUser: isUser,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });

    _scrollToBottom();

    if (isUser) {
      _streamResponse(text);
    }
  }

  void _addBotMessage(String text, {String? actionType, bool isError = false}) {
    final message = ChatMessage(
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      actionType: actionType,
      isError: isError,
    );

    setState(() {
      _isTyping = false;
      _messages.add(message);
    });

    _scrollToBottom();

    // Voice mode : lire la réponse
    if (_isVoiceMode && !isError) {
      VoiceService.instance.speak(text);
    }
  }

  void _streamResponse(String userMessage) {
    _streamSubscription?.cancel();

    setState(() {
      _isTyping = true;
    });

    // Ajouter un message bot vide (streaming)
    final streamingMessage = ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    setState(() {
      _messages.add(streamingMessage);
    });

    final stream = _agentService.streamMessage(
      message: userMessage,
      sessionId: _sessionId,
      mode: _isVoiceMode ? 'voice' : 'text',
    );

    String fullText = '';
    String? currentActionType;

    _streamSubscription = stream.listen(
      (event) {
        if (!mounted) return;

        switch (event.event) {
          case 'token':
            final content = event.data['content'] as String? ?? '';
            fullText += content;
            _updateLastBotMessage(
              text: fullText,
              isStreaming: true,
              actionType: currentActionType,
            );
            break;

          case 'tool_pending':
            final label = event.data['label'] as String?;
            final tool = event.data['tool'] as String?;
            currentActionType = tool;
            if (label != null) {
              fullText = '$label...\n';
              _updateLastBotMessage(
                text: fullText,
                isStreaming: true,
                actionType: tool,
              );
            }
            break;

          case 'tool_result':
            final success = event.data['success'] as bool? ?? false;
            if (success) {
              fullText += '✓ Terminé.\n';
            } else {
              final reason = event.data['reason'] as String?;
              fullText +=
                  '⚠️ ${reason == 'appliance_not_found_or_ambiguous' ? 'Appareil introuvable.' : 'Action non disponible.'}\n';
            }
            _updateLastBotMessage(
              text: fullText,
              isStreaming: true,
              actionType: currentActionType,
            );
            break;

          case 'error':
            final msg = event.data['message'] as String? ??
                'Une erreur est survenue.';
            fullText += msg;
            _updateLastBotMessage(
              text: fullText,
              isStreaming: false,
              isError: true,
            );
            break;

          case 'done':
            _finalizeBotMessage(fullText, actionType: currentActionType);
            break;
        }
      },
      onError: (error) {
        if (!mounted) return;
        _finalizeBotMessage(
          'Désolé, une erreur technique est survenue.',
          isError: true,
        );
      },
      onDone: () {
        if (!mounted) return;
        _finalizeBotMessage(fullText, actionType: currentActionType);
      },
    );
  }

  void _updateLastBotMessage({
    required String text,
    bool isStreaming = false,
    String? actionType,
    bool isError = false,
  }) {
    setState(() {
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages[_messages.length - 1] = ChatMessage(
          text: text,
          isUser: false,
          timestamp: _messages.last.timestamp,
          isStreaming: isStreaming,
          actionType: actionType,
          isError: isError,
        );
      }
    });
    _scrollToBottom();
  }

  void _finalizeBotMessage(String text,
      {String? actionType, bool isError = false}) {
    setState(() {
      _isTyping = false;
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        _messages[_messages.length - 1] = ChatMessage(
          text: text,
          isUser: false,
          timestamp: _messages.last.timestamp,
          actionType: actionType,
          isError: isError,
        );
      }
    });

    // Voice mode : lire la réponse terminée
    if (_isVoiceMode && !isError && text.isNotEmpty) {
      VoiceService.instance.speak(text);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
    });

    if (_isVoiceMode) {
      _addBotMessage(
        "Mode vocal activé. Vous pouvez me parler ou écrire, je vous répondrai à voix haute.",
      );
    } else {
      VoiceService.instance.stopSpeaking();
      _addBotMessage("Mode vocal désactivé.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Lottie.asset(
                'assets/animations/chatbot_avatar.json',
                controller: _animationController,
                onLoaded: (_) {
                  _animationController.repeat();
                },
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant Énergie',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  _isTyping ? 'En train d\'écrire...' : 'En ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isTyping
                        ? Theme.of(context).colorScheme.primary
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle mode vocal
          IconButton(
            icon: Icon(
              _isVoiceMode ? Icons.record_voice_over : Icons.voice_over_off,
              color: _isVoiceMode
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _toggleVoiceMode,
            tooltip: _isVoiceMode
                ? 'Désactiver le mode vocal'
                : 'Activer le mode vocal',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _streamSubscription?.cancel();
              setState(() {
                _messages.clear();
              });
              Future.delayed(const Duration(milliseconds: 300), () {
                _showWelcomeMessage();
              });
            },
            tooltip: 'Nouvelle conversation',
          ),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/animations/chatbot_avatar.json',
                          width: 200,
                          height: 200,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Commencez une conversation',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dites "éteins le chauffe-eau" ou "quelle est ma consommation ?"',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  )
                : AnimationLimiter(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final showDate =
                            index == 0 ||
                            !_isSameDay(
                              message.timestamp,
                              _messages[index - 1].timestamp,
                            );

                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 350),
                          child: SlideAnimation(
                            verticalOffset: 20.0,
                            child: FadeInAnimation(
                              child: Column(
                                children: [
                                  if (showDate)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceVariant,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _formatDate(message.timestamp),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  MessageBubble(message: message),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          if (_isTyping && _messages.isNotEmpty && !_messages.last.isStreaming)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TypingIndicator(),
              ),
            ),
          ChatInput(
            onSendMessage: (text) {
              _addMessage(text, true);
            },
            isVoiceMode: _isVoiceMode,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return "Aujourd'hui";
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return "Hier";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}
