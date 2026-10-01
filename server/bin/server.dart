import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../lib/database.dart';

Future<void> main(List<String> args) async {
  final port = int.tryParse(
        Platform.environment['PORT'] ?? '',
      ) ??
      8080;
  final dbPath =
      Platform.environment['DB_PATH'] ?? 'data/leaderboard.sqlite';
  final database = LeaderboardDatabase(dbPath);
  await database.open();

  final router = Router()
    ..get('/leaderboard', (_) => _listHandler(database))
    ..post('/leaderboard', (request) => _submitHandler(request, database))
    ..get(
      '/players/<name>/profile',
      (Request request, String name) => _profileHandler(database, name),
    )
    ..post(
      '/players/<name>/upgrades',
      (Request request, String name) => _purchaseHandler(request, database, name),
    )
    ..get('/health', (_) => Response.ok('ok'));

  final handler = Pipeline()
      .addMiddleware(_corsMiddleware)
      .addMiddleware(logRequests())
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  // ignore: avoid_print
  print('Leaderboard server listening on http://${server.address.host}:${server.port}');
}

Future<Response> _listHandler(LeaderboardDatabase database) async {
  final entries = database.listRanked();
  return Response.ok(
    jsonEncode({
      'entries': [
        for (final entry in entries)
          {
            'rank': entry.rank,
            'playerName': entry.playerName,
            'distanceMeters': entry.distanceMeters,
            'money': entry.money,
          },
      ],
    }),
    headers: _jsonHeaders,
  );
}

Future<Response> _submitHandler(
  Request request,
  LeaderboardDatabase database,
) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final name = (json['playerName'] as String?)?.trim();
    final distance = json['distanceMeters'];
    final money = json['money'];

    if (name == null || name.isEmpty) {
      return Response(400, body: 'playerName is required', headers: _jsonHeaders);
    }
    if (distance is! num || money is! num) {
      return Response(
        400,
        body: 'distanceMeters and money must be numbers',
        headers: _jsonHeaders,
      );
    }

    final saved = database.upsertScore(
      playerName: name,
      distanceMeters: distance.toDouble(),
      money: money.toDouble(),
    );

    return Response.ok(
      jsonEncode({
        'rank': saved.rank,
        'playerName': saved.playerName,
        'distanceMeters': saved.distanceMeters,
        'money': saved.money,
      }),
      headers: _jsonHeaders,
    );
  } on FormatException {
    return Response(400, body: 'Invalid JSON body', headers: _jsonHeaders);
  }
}

Response _profileHandler(LeaderboardDatabase database, String name) {
  final profile = database.getProfile(name.trim());
  return Response.ok(
    jsonEncode({
      'playerName': profile.playerName,
      'money': profile.money,
      'upgrades': profile.upgradeLevels,
    }),
    headers: _jsonHeaders,
  );
}

Future<Response> _purchaseHandler(
  Request request,
  LeaderboardDatabase database,
  String name,
) async {
  try {
    final body = await request.readAsString();
    final json = jsonDecode(body) as Map<String, dynamic>;
    final upgradeId = json['upgradeId'] as String?;
    if (upgradeId == null || upgradeId.isEmpty) {
      return Response(400, body: 'upgradeId is required', headers: _jsonHeaders);
    }

    final profile = database.purchaseUpgrade(
      playerName: name.trim(),
      upgradeId: upgradeId,
    );

    return Response.ok(
      jsonEncode({
        'playerName': profile.playerName,
        'money': profile.money,
        'upgrades': profile.upgradeLevels,
      }),
      headers: _jsonHeaders,
    );
  } on StateError catch (error) {
    return Response(400, body: error.message, headers: _jsonHeaders);
  } on ArgumentError catch (error) {
    return Response(400, body: '${error.message}', headers: _jsonHeaders);
  } on FormatException {
    return Response(400, body: 'Invalid JSON body', headers: _jsonHeaders);
  }
}

const _jsonHeaders = {'Content-Type': 'application/json'};

Middleware _corsMiddleware = (Handler inner) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: _corsHeaders);
    }
    final response = await inner(request);
    return response.change(headers: _corsHeaders);
  };
};

const _corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};
