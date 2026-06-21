import 'dart:convert';
import 'package:crypto/crypto.dart';

class DeviceCrypto {
  // ponytail: placeholder for Ed25519 asymmetric signing. 
  // Real implementation requires 'cryptography' package.
  static String generateChallenge(String nonce) {
    final bytes = utf8.encode(nonce);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  static bool verifySignature(String payload, String signature, String publicKey) {
    try {
      // ponytail: This is still a naive hash. In production, use:
      // var verifier = Ed25519().verify(publicKey, signature, payload);
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
