import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AgentService {
  static AgentService? _instance;
  final String _apiUrl = 'https://micro.uksouth.cloudapp.azure.com/api/v1/prediction/f8f99c35-cf84-4a8f-b602-44860a9a0e4e';

  AgentService._();

  static AgentService get instance {
    _instance ??= AgentService._();
    return _instance!;
  }

  Future<void> initialize() async {
    // Aucune initialisation spéciale requise pour Flowise
    debugPrint('AgentService initialisé');
  }

  Future<Map<String, dynamic>> getResponse(
    String query,
    String sessionId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'question': query,
          'sessionId': sessionId, 
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Adaptation de la réponse au format attendu par l'application
        return {
          'text': data['text'] ?? data['answer'] ?? "Je suis désolé, je n'ai pas compris votre demande.",
          'intent': 'conversation', 
          'confidence': 1.0, 
          'parameters': {}, 
        };
      } else {
        throw Exception('Échec de la réponse: ${response.body}');
      }
    } catch (e) {
      debugPrint('Erreur lors de la communication avec Flowise: $e');
      return {
        'text': "Désolé, une erreur s'est produite. Veuillez réessayer.",
        'intent': 'error',
        'confidence': 0.0,
        'parameters': {},
      };
    }
  }
}