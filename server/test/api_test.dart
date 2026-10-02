import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../lib/api.dart';
import '../lib/database.dart';

final _testDatabaseUrl = Platform.environment['TEST_DATABASE_URL'];
const _token = 'api-test-token-aaaaaaaaaaaa';

Future<Response> _send(
  Handler handler,
  String method,
  String path, {
  Object? body,
  String? token = _token,
}) async {
  return await handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: body is String ? body : jsonEncode(body),
    ),
  );
}

void main() {
  group('without a database', () {
    // Nothing listens on port 1, so any request that reaches the database
    // fails fast. Everything else must be decided before that.
    final database = LeaderboardDatabase(
      DatabaseConfig.fromUrl('mysql://u:p@127.0.0.1:1/test'),
      requestTimeout: const Duration(seconds: 3),
    );
    final handler = buildHandler(database, logging: false);

    test('health check answers with CORS headers', () async {
      final response = await _send(handler, 'GET', '/health');

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'ok');
      expect(response.headers['access-control-allow-origin'], '*');
    });

    test('CORS preflight allows the Authorization header', () async {
      final response = await _send(handler, 'OPTIONS', '/runs');

      expect(response.statusCode, 200);
      expect(
        response.headers['access-control-allow-headers'],
        contains('Authorization'),
      );
    });

    test('writes need a bearer token', () async {
      for (final token in [null, 'short', '']) {
        final response = await _send(handler, 'POST', '/runs', token: token);
        expect(response.statusCode, 401, reason: 'token: $token');
      }

      final basic = await handler(
        Request(
          'POST',
          Uri.parse('http://localhost/runs'),
          headers: {'authorization': 'Basic $_token'},
        ),
      );
      expect(basic.statusCode, 401);
    });

    test('rejects malformed bodies with 400, not 500', () async {
      final cases = <String, Object>{
        'not JSON': '{oops',
        'JSON array': '[1, 2]',
        'numeric name': {
          'runId': 'r',
          'playerName': 42,
          'distanceMeters': 1,
          'money': 0,
        },
        'missing run': {'playerName': 'Sam', 'distanceMeters': 1, 'money': 0},
        'string distance': {
          'runId': 'r',
          'playerName': 'Sam',
          'distanceMeters': 'far',
          'money': 0,
        },
      };
      for (final entry in cases.entries) {
        final response = await _send(
          handler,
          'POST',
          '/leaderboard',
          body: entry.value,
        );
        expect(response.statusCode, 400, reason: entry.key);
      }

      final upgrade = await _send(
        handler,
        'POST',
        '/players/Sam/upgrades',
        body: {'upgradeId': 7},
      );
      expect(upgrade.statusCode, 400);
    });

    test('database failures return 500 with CORS headers', () async {
      final response = await _send(handler, 'GET', '/leaderboard');

      expect(response.statusCode, 500);
      expect(await response.readAsString(), 'Internal server error');
      expect(response.headers['access-control-allow-origin'], '*');
    });

    test('unknown routes return 404', () async {
      final response = await _send(handler, 'GET', '/nope');

      expect(response.statusCode, 404);
    });
  });

  group(
    'with a database',
    skip: _testDatabaseUrl == null
        ? 'Set TEST_DATABASE_URL to mysql://user:pass@host:4000/test'
        : null,
    () {
      late LeaderboardDatabase database;
      late Handler handler;

      setUp(() async {
        final config = DatabaseConfig.fromUrl(_testDatabaseUrl!);
        if (!config.database.contains('test')) {
          fail('Refusing to wipe "${config.database}"');
        }
        database = LeaderboardDatabase(config);
        await database.open();
        await database.debugDeleteEverything();
        handler = buildHandler(database, logging: false);
      });

      tearDown(() => database.close());

      test('a full run, leaderboard and shop round trip', () async {
        const name = "O'Brien";
        final start = await _send(handler, 'POST', '/runs');
        expect(start.statusCode, 200);
        final runId =
            (jsonDecode(await start.readAsString()) as Map)['runId'] as String;

        await Future<void>.delayed(const Duration(seconds: 3));
        final submit = await _send(
          handler,
          'POST',
          '/leaderboard',
          body: {
            'runId': runId,
            'playerName': '  $name  ',
            'distanceMeters': 8,
            'money': 2,
          },
        );
        expect(submit.statusCode, 200, reason: await submit.readAsString());

        final board = await _send(handler, 'GET', '/leaderboard');
        final entries =
            (jsonDecode(await board.readAsString()) as Map)['entries'] as List;
        expect(entries.single['playerName'], name);
        expect(entries.single['rank'], 1);

        final path = '/players/${Uri.encodeComponent(name)}';
        final profile = await _send(handler, 'GET', '$path/profile');
        expect(jsonDecode(await profile.readAsString()), {
          'playerName': name,
          'money': 2.0,
          'upgrades': <String, dynamic>{},
        });

        final broke = await _send(
          handler,
          'POST',
          '$path/upgrades',
          body: {'upgradeId': 'jump_boost'},
        );
        expect(broke.statusCode, 400);
        expect(await broke.readAsString(), 'Not enough money');

        final thief = await _send(
          handler,
          'POST',
          '$path/upgrades',
          body: {'upgradeId': 'jump_boost'},
          token: 'someone-else-token-bbbbbbbb',
        );
        expect(thief.statusCode, 403);
      });
    },
  );
}
