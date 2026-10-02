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
    ..post('/runs', (request) => _startRunHandler(request, database))
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
      .addMiddleware(_errorMiddleware)
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

Response _startRunHandler(Request request, LeaderboardDatabase database) {
  final runId = database.startRun(_requireTokenHash(request));
  return Response.ok(jsonEncode({'runId': runId}), headers: _jsonHeaders);
}

Future<Response> _submitHandler(
  Request request,
  LeaderboardDatabase database,
) async {
  final tokenHash = _requireTokenHash(request);
  final json = await _readJson(request);
  final name = (json['playerName'] as String?)?.trim();
  final runId = json['runId'];
  final distance = json['distanceMeters'];
  final money = json['money'];

  if (name == null || name.isEmpty) {
    throw ApiException(400, 'playerName is required');
  }
  if (runId is! String || runId.isEmpty) {
    throw ApiException(400, 'runId is required');
  }
  if (distance is! num || money is! num) {
    throw ApiException(400, 'distanceMeters and money must be numbers');
  }

  final saved = database.submitRun(
    tokenHash: tokenHash,
    runId: runId,
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
  final tokenHash = _requireTokenHash(request);
  final json = await _readJson(request);
  final upgradeId = json['upgradeId'] as String?;
  if (upgradeId == null || upgradeId.isEmpty) {
    throw ApiException(400, 'upgradeId is required');
  }

  final profile = database.purchaseUpgrade(
    tokenHash: tokenHash,
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
}

/// Reads the player's secret from `Authorization: Bearer <token>`.
String _requireTokenHash(Request request) {
  final header = request.headers['authorization'] ?? '';
  const prefix = 'Bearer ';
  final token = header.startsWith(prefix)
      ? header.substring(prefix.length).trim()
      : '';
  if (token.length < LeaderboardDatabase.minTokenLength) {
    throw ApiException(401, 'Missing or invalid player token');
  }
  return LeaderboardDatabase.hashToken(token);
}

Future<Map<String, dynamic>> _readJson(Request request) async {
  try {
    final json = jsonDecode(await request.readAsString());
    if (json is Map<String, dynamic>) {
      return json;
    }
  } on FormatException {
    // Falls through to the error below.
  }
  throw ApiException(400, 'Invalid JSON body');
}

const _jsonHeaders = {'Content-Type': 'application/json'};

Middleware _errorMiddleware = (Handler inner) {
  return (Request request) async {
    try {
      return await inner(request);
    } on ApiException catch (error) {
      return Response(error.statusCode, body: error.message);
    }
  };
};

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
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
