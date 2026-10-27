import 'package:flutter_test/flutter_test.dart';
import 'package:aricie/core/security/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    test('allows requests up to maxRequests', () {
      final limiter = RateLimiter(maxRequests: 3, window: const Duration(seconds: 2));

      expect(limiter.remaining, 3);
      expect(limiter.isAllowed, true);
      expect(limiter.remaining, 2);
      expect(limiter.isAllowed, true);
      expect(limiter.remaining, 1);
      expect(limiter.isAllowed, true);
      expect(limiter.remaining, 0);
      expect(limiter.isAllowed, false);
      expect(limiter.remaining, 0);
    });

    test('resets request window after duration', () async {
      final limiter = RateLimiter(maxRequests: 2, window: const Duration(milliseconds: 100));

      expect(limiter.isAllowed, true);
      expect(limiter.isAllowed, true);
      expect(limiter.isAllowed, false);

      await Future.delayed(const Duration(milliseconds: 150));

      expect(limiter.isAllowed, true);
      expect(limiter.remaining, 1);
    });

    test('reset clears all timestamps', () {
      final limiter = RateLimiter(maxRequests: 2, window: const Duration(seconds: 10));

      expect(limiter.isAllowed, true);
      expect(limiter.isAllowed, true);
      expect(limiter.isAllowed, false);

      limiter.reset();

      expect(limiter.remaining, 2);
      expect(limiter.isAllowed, true);
    });
  });
}
