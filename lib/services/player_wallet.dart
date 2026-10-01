import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores money earned across every completed run on this device.
class PlayerWallet extends ChangeNotifier {
  PlayerWallet._();

  static final instance = PlayerWallet._();
  static const _balanceKey = 'walletBalance';

  double balance = 0;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    balance = preferences.getDouble(_balanceKey) ?? 0;
    notifyListeners();
  }

  void add(double amount) {
    if (amount <= 0) return;
    balance += amount;
    notifyListeners();
    unawaited(_save());
  }

  Future<void> _save() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setDouble(_balanceKey, balance);
    } catch (_) {
      // Widget and game-unit tests do not register platform preferences.
      // The in-memory balance remains available for the current session.
    }
  }
}
