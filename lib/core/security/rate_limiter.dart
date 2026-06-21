import 'dart:collection';
import 'package:aricie/core/constants.dart';

class RateLimiter {
  final Queue<DateTime> _timestamps = Queue();
  final int maxRequests;
  final Duration window;

  RateLimiter({
    this.maxRequests = AppConstants.syncRateLimitPerMinute,
    this.window = const Duration(minutes: 1),
  });

  bool get isAllowed {
    final now = DateTime.now();
    while (_timestamps.isNotEmpty && now.difference(_timestamps.first) > window) {
      _timestamps.removeFirst();
    }
    if (_timestamps.length >= maxRequests) return false;
    _timestamps.add(now);
    return true;
  }

  int get remaining {
    final now = DateTime.now();
    while (_timestamps.isNotEmpty && now.difference(_timestamps.first) > window) {
      _timestamps.removeFirst();
    }
    return maxRequests - _timestamps.length;
  }

  void reset() {
    _timestamps.clear();
  }
}
