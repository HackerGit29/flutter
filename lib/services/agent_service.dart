import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/security/rate_limiter.dart';

class AgentStreamEvent {
  final String event;
  final Map<String, dynamic> data;

  AgentStreamEvent(this.event, this.data);
}

class AgentService {
  static final AgentService instance = AgentService._();
  final SupabaseClient _supabase = Supabase.instance.client;
  final RateLimiter _rateLimiter = RateLimiter(maxRequests: 5);

  AgentService._();

  String get _edgeFunctionUrl =>
      '${AppConstants.supabaseUrl}/functions/v1/agent-orchestrator';

  Future<String> getAccessToken() async {
    final session = _supabase.auth.currentSession;
    return session?.accessToken ?? '';
  }

  Stream<AgentStreamEvent> streamMessage({
    required String message,
    required String sessionId,
    String mode = 'text',
    Map<String, dynamic>? confirmedToolCall,
  }) async* {
    debugPrint('[AgentService] streamMessage start: "$message"');
    final token = await getAccessToken();
    debugPrint('[AgentService] token length: ${token.length}');

    if (token.isEmpty) {
      debugPrint('[AgentService] No token - user not logged in');
      yield AgentStreamEvent('error', {
        'message': 'Vous devez être connecté pour utiliser l\'assistant.',
      });
      yield AgentStreamEvent('done', {});
      return;
    }

    if (!_rateLimiter.isAllowed) {
      final remaining = _rateLimiter.remaining;
      debugPrint('[AgentService] rate limit exceeded, remaining: $remaining');
      yield AgentStreamEvent('error', {
        'message': 'Limite de requêtes atteinte. Réessayez dans une minute.',
      });
      yield AgentStreamEvent('done', {});
      return;
    }

    const maxRetries = 3;
    http.StreamedResponse? response;
    String? lastError;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = Duration(seconds: pow(2, attempt - 1).toInt());
        debugPrint('[AgentService] retry #$attempt after ${delay.inSeconds}s');
        await Future.delayed(delay);
      }

      try {
        final url = Uri.parse(_edgeFunctionUrl);
        debugPrint('[AgentService] POST $url (attempt ${attempt + 1})');

        final request = http.Request('POST', url);

        request.headers.addAll({
          'Authorization': 'Bearer $token',
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        });

        request.body = jsonEncode({
          'message': message,
          'session_id': sessionId,
          'locale': 'fr-CM',
          'mode': mode,
          if (confirmedToolCall != null) 'confirmed_tool_call': confirmedToolCall,
        });

        response = await request.send().timeout(const Duration(seconds: 30));
        debugPrint('[AgentService] HTTP ${response.statusCode}');

        if (response.statusCode == 200) break;

        lastError = 'Erreur de communication avec l\'assistant (${response.statusCode}).';
        debugPrint('[AgentService] attempt $attempt failed: $lastError');
        response = null;
      } on TimeoutException {
        lastError = 'L\'assistant ne répond pas. Réessayez.';
        debugPrint('[AgentService] timeout on attempt $attempt');
        response = null;
      } catch (e) {
        lastError = 'Une erreur de connexion est survenue. Vérifiez votre connexion internet.';
        debugPrint('[AgentService] exception on attempt $attempt: $e');
        response = null;
      }
    }

    if (response == null) {
      yield AgentStreamEvent('error', {
        'message': lastError ?? 'Erreur inconnue.',
      });
      yield AgentStreamEvent('done', {});
      return;
    }

    String? currentEvent;
    int eventCount = 0;

    await for (final line
        in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      debugPrint('[AgentService] SSE line: "$line"');

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }

      if (line.startsWith('data:')) {
        final raw = line.substring(5).trim();
        if (raw.isEmpty) continue;

        try {
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          eventCount++;
          debugPrint('[AgentService] event #$eventCount: $currentEvent → $parsed');
          yield AgentStreamEvent(currentEvent ?? 'message', parsed);
        } catch (e) {
          debugPrint('[AgentService] parse error: $e | raw="$raw"');
        }
      }
    }

    debugPrint('[AgentService] stream done ($eventCount events)');
  }

  @Deprecated('Utiliser streamMessage() à la place')
  Future<Map<String, dynamic>> getResponse(
    String query,
    String sessionId,
  ) async {
    final events = await streamMessage(
      message: query,
      sessionId: sessionId,
    ).toList();

    String text = '';
    for (final event in events) {
      if (event.event == 'token') {
        text += event.data['content'] as String? ?? '';
      }
    }

    return {
      'text': text.isNotEmpty ? text : 'Je n\'ai pas compris votre demande.',
      'intent': 'conversation',
      'confidence': text.isNotEmpty ? 1.0 : 0.0,
      'parameters': {},
    };
  }
}
