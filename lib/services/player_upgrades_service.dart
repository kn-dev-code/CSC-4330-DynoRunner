import 'dart:convert';

import 'package:http/http.dart' as http;

import 'leaderboard_service.dart';
import 'player_profile.dart';
import 'upgrade_catalog.dart';

class PlayerUpgradesService {
  PlayerUpgradesService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? LeaderboardService.defaultBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  RunUpgradeModifiers cachedModifiers = RunUpgradeModifiers.none;
  PlayerProfile? lastProfile;

  Uri _profileUri(String playerName) =>
      Uri.parse('$_baseUrl/players/${Uri.encodeComponent(playerName)}/profile');

  Uri _purchaseUri(String playerName) => Uri.parse(
    '$_baseUrl/players/${Uri.encodeComponent(playerName)}/upgrades',
  );

  Future<PlayerProfile> fetchProfile(String playerName) async {
    final response = await _client.get(_profileUri(playerName));
    if (response.statusCode != 200) {
      throw PlayerUpgradesException(
        'Could not load profile (${response.statusCode})',
      );
    }
    final profile = PlayerProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    lastProfile = profile;
    cachedModifiers = RunUpgradeModifiers.fromLevels(profile.upgradeLevels);
    return profile;
  }

  Future<PlayerProfile> purchaseUpgrade({
    required String playerName,
    required UpgradeId upgrade,
  }) async {
    final response = await _client.post(
      _purchaseUri(playerName),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'upgradeId': upgrade.id}),
    );
    if (response.statusCode != 200) {
      throw PlayerUpgradesException(
        response.body.isEmpty
            ? 'Purchase failed (${response.statusCode})'
            : response.body,
      );
    }
    final profile = PlayerProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    lastProfile = profile;
    cachedModifiers = RunUpgradeModifiers.fromLevels(profile.upgradeLevels);
    return profile;
  }

  void dispose() => _client.close();
}

class PlayerUpgradesException implements Exception {
  PlayerUpgradesException(this.message);

  final String message;

  @override
  String toString() => message;
}
