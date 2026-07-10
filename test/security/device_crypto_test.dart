import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/security/device_crypto.dart';

void main() {
  group('DeviceCrypto', () {
    test('generateChallenge returns a sha256 hex string of the input', () {
      final challenge = DeviceCrypto.generateChallenge('test-nonce');
      expect(challenge, isNotEmpty);
      expect(challenge.length, 64); // SHA-256 output length in hex is 64 characters
    });

    test('generateNonce returns a unique sha256 hex string', () async {
      final nonce1 = DeviceCrypto.generateNonce();
      await Future.delayed(const Duration(milliseconds: 2));
      final nonce2 = DeviceCrypto.generateNonce();
      expect(nonce1, isNotEmpty);
      expect(nonce1.length, 64);
      // Nonces generated at different times/calls should usually be different
      expect(nonce1 != nonce2, isTrue);
    });

    test('verifySignature returns true for expected challenge match', () {
      const payload = 'my-payload';
      const publicKey = 'my-public-key';
      final expectedSignature = DeviceCrypto.generateChallenge(payload + publicKey);

      final isValid = DeviceCrypto.verifySignature(payload, expectedSignature, publicKey);
      expect(isValid, isTrue);
    });

    test('verifySignature returns false for wrong signature', () {
      const payload = 'my-payload';
      const publicKey = 'my-public-key';

      final isValid = DeviceCrypto.verifySignature(payload, 'wrong-signature', publicKey);
      expect(isValid, isFalse);
    });
  });
}
