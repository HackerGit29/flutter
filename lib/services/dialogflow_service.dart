import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:corsac_jwt/corsac_jwt.dart';

class DialogflowService {
  static DialogflowService? _instance;
  String? _accessToken;
  final String _projectId = 'concrete-fusion-410009';

  DialogflowService._();

  static DialogflowService get instance {
    _instance ??= DialogflowService._();
    return _instance!;
  }

  Future<void> initialize() async {
    try {
      final serviceAccount = await rootBundle.loadString(
        'service-account.json',
      );
      await _getAccessToken(serviceAccount);
    } catch (e) {
      debugPrint('Error initializing DialogFlow: $e');
      rethrow;
    }
  }

  Future<void> _getAccessToken(String serviceAccount) async {
    try {
      final credentials = json.decode(serviceAccount);
      final privateKey = credentials['private_key'];
      final clientEmail = credentials['client_email'];

      final jwt = _createJWT(clientEmail, privateKey);

      final response = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
          'assertion': jwt,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body);
        _accessToken = tokenData['access_token'];
      } else {
        throw Exception('Failed to get access token: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting access token: $e');
      rethrow;
    }
  }

 String _createJWT(String clientEmail, String privateKey) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiry = now + 3600;

    final builder = JWTBuilder()
      ..issuer = clientEmail
      ..subject = clientEmail
      ..audience = 'https://oauth2.googleapis.com/token'  // Changed audience to the token endpoint
      ..issuedAt = DateTime.fromMillisecondsSinceEpoch(now * 1000)
      ..expiresAt = DateTime.fromMillisecondsSinceEpoch(expiry * 1000)
      ..setClaim('scope', 'https://www.googleapis.com/auth/dialogflow');  // Added scope claim

    final signer = JWTRsaSha256Signer(privateKey: privateKey);
    final signedToken = builder.getSignedToken(signer);

    return signedToken.toString();
  }

  Future<Map<String, dynamic>> getResponse(
    String query,
    String sessionId,
  ) async {
    if (_accessToken == null) {
      await initialize();
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://dialogflow.googleapis.com/v2/projects/$_projectId/agent/sessions/$sessionId:detectIntent',
        ),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'queryInput': {
            'text': {'text': query, 'languageCode': 'fr'},
          },
          'queryParams': {'timeZone': DateTime.now().timeZoneName},
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final queryResult = data['queryResult'];

        return {
          'text':
              queryResult['fulfillmentText'] ??
              "Je suis désolé, je n'ai pas compris votre demande.",
          'intent': queryResult['intent']?['displayName'] ?? 'unknown',
          'confidence': queryResult['intentDetectionConfidence'] ?? 0.0,
          'parameters': queryResult['parameters'] ?? {},
        };
      } else {
        throw Exception('Failed to get response: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error getting DialogFlow response: $e');
      return {
        'text': "Désolé, une erreur s'est produite. Veuillez réessayer.",
        'intent': 'error',
        'confidence': 0.0,
        'parameters': {},
      };
    }
  }

  Future<void> refreshToken() async {
    _accessToken = null;
    await initialize();
  }
}
