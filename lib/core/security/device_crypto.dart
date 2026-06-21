import 'dart:convert';
import 'package:crypto/crypto.dart';

class DeviceCrypto {
  static String generateChallenge(String nonce) {
    final bytes = utf8.encode(nonce);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  static bool verifySignature(String payload, String signature, String publicKey) {
    try {
      final expected = generateChallenge(payload + publicKey);
      return expected == signature;
    } catch (_) {
      return false;
    }
  }

  static String generateNonce() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return sha256.convert(utf8.encode(now.toString())).toString();
  }
}
