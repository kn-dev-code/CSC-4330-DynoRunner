import 'dart:convert';

import 'package:http/http.dart' as http;

import 'leaderboard_entry.dart';
import 'player_identity.dart';

/// Talks to the dyno leaderboard HTTP API (see [defaultBaseUrl] / `server/`).
class LeaderboardService {
  LeaderboardService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? defaultBaseUrl;

  /// The deployed server on Render. To test against a local server, run with
  /// `--dart-define=LEADERBOARD_URL=http://127.0.0.1:8080`.
  static const defaultBaseUrl = String.fromEnvironment(
    'LEADERBOARD_URL',
    defaultValue: 'https://dyno-leaderboard.onrender.com',
  );

  final http.Client _client;
  final String _baseUrl;

  Uri get _leaderboardUri => Uri.parse('$_baseUrl/leaderboard');
  Uri get _runsUri => Uri.parse('$_baseUrl/runs');

  /// Hosts like Render's free tier sleep when idle and take up to a minute
  /// to wake, so this is sent at launch, before a run needs the server.
  Future<void> wakeServer() async {
    await _client.get(Uri.parse('$_baseUrl/health'));
  }

  /// Tells the server a run began so it can bound the submitted distance by
  /// the time played. Returns the run id to pass to [submitScore].
  Future<String> startRun() async {
    final response = await _client.post(
      _runsUri,
      headers: PlayerIdentity.instance.authHeaders,
    );
    if (response.statusCode != 200) {
      throw LeaderboardException(
        'Could not start run (${response.statusCode})',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['runId'] as String;
  }

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
    required String runId,
    required String playerName,
    required double distanceMeters,
    required double money,
  }) async {
    final response = await _client.post(
      _leaderboardUri,
      headers: {
        'Content-Type': 'application/json',
        ...PlayerIdentity.instance.authHeaders,
      },
      body: jsonEncode({
        'runId': runId,
        'playerName': playerName,
        'distanceMeters': distanceMeters,
        'money': money,
      }),
    );

    if (response.statusCode != 200) {
      throw LeaderboardException(
        response.body.isEmpty
            ? 'Could not submit score (${response.statusCode})'
            : response.body,
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
