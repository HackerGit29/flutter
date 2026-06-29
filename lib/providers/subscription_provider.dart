import 'package:flutter/material.dart';
import 'package:aricie/core/di/injection_container.dart';
import 'package:aricie/domain/entities/subscription.dart';
import 'package:aricie/domain/usecases/license/get_user_subscription.dart';

class SubscriptionProvider extends ChangeNotifier {
  Subscription? _subscription;
  bool _isLoading = true;

  Subscription? get subscription => _subscription;
  bool get isLoading => _isLoading;
  bool get isVip => _subscription?.isVip ?? false;

  void reset() {
    _subscription = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadForUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    final result = await GetUserSubscription(sl()).callForUser(userId);
    result.fold(
      (_) => _subscription = null,
      (sub) => _subscription = sub,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    final result = await GetUserSubscription(sl()).call();
    result.fold(
      (_) => _subscription = null,
      (sub) => _subscription = sub,
    );

    _isLoading = false;
    notifyListeners();
  }
}
