import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Secret token that proves to the server which player names this install
/// owns. Losing it (e.g. reinstalling) means losing those names.
class PlayerIdentity {
  PlayerIdentity._();

  static final instance = PlayerIdentity._();
  static const _tokenKey = 'playerToken';

  /// Replaced by the saved token in [load]; tests use this in-memory one.
  String token = _generateToken();

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_tokenKey);
    if (saved != null && saved.isNotEmpty) {
      token = saved;
    } else {
      await preferences.setString(_tokenKey, token);
    }
  }

  static String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
