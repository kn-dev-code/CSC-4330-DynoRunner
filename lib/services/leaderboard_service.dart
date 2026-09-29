import 'dart:convert';

import 'package:http/http.dart' as http;

import 'leaderboard_entry.dart';

/// Talks to the dyno leaderboard HTTP API (see [defaultBaseUrl] / `server/`).
class LeaderboardService {
  LeaderboardService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? defaultBaseUrl;

  static const defaultBaseUrl = String.fromEnvironment(
    'LEADERBOARD_URL',
    defaultValue: 'http://127.0.0.1:8080',
  );

  final http.Client _client;
  final String _baseUrl;

  Uri get _leaderboardUri => Uri.parse('$_baseUrl/leaderboard');

  Future<List<LeaderboardEntry>> fetchLeaderboard() async {
    final response = await _client.get(_leaderboardUri);
    if (response.statusCode != 200) {
      throw LeaderboardException(
        'Could not load leaderboard (${response.statusCode})',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final entries = body['entries'] as List<dynamic>;
    return entries
        .map((entry) => LeaderboardEntry.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<LeaderboardEntry> submitScore({
    required String playerName,
    required double distanceMeters,
    required double money,
  }) async {
    final response = await _client.post(
      _leaderboardUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'playerName': playerName,
        'distanceMeters': distanceMeters,
        'money': money,
      }),
    );

    if (response.statusCode != 200) {
      throw LeaderboardException(
        'Could not submit score (${response.statusCode})',
      );
    }

    return LeaderboardEntry.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  void dispose() => _client.close();
}

class LeaderboardException implements Exception {
  LeaderboardException(this.message);

  final String message;

  @override
  String toString() => message;
}
