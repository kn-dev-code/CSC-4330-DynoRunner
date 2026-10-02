import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'database.dart';

/// The HTTP API, separate from `bin/server.dart` so tests can call it without
/// opening a port.
Handler buildHandler(LeaderboardDatabase database, {bool logging = true}) {
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
      (Request request, String name) =>
          _purchaseHandler(request, database, name),
    )
    ..get('/health', (_) => Response.ok('ok'));

  var pipeline = const Pipeline().addMiddleware(_corsMiddleware);
  if (logging) {
    pipeline = pipeline.addMiddleware(logRequests());
  }
  return pipeline.addMiddleware(_errorMiddleware).addHandler(router.call);
}

Future<Response> _listHandler(LeaderboardDatabase database) async {
  final entries = await database.listRanked();
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

Future<Response> _startRunHandler(
  Request request,
  LeaderboardDatabase database,
) async {
  final runId = await database.startRun(_requireTokenHash(request));
  return Response.ok(jsonEncode({'runId': runId}), headers: _jsonHeaders);
}

Future<Response> _submitHandler(
  Request request,
  LeaderboardDatabase database,
) async {
  final tokenHash = _requireTokenHash(request);
  final json = await _readJson(request);
  final name = json['playerName'];
  final runId = json['runId'];
  final distance = json['distanceMeters'];
  final money = json['money'];

  if (name is! String || name.trim().isEmpty) {
    throw ApiException(400, 'playerName is required');
  }
  if (runId is! String || runId.isEmpty) {
    throw ApiException(400, 'runId is required');
  }
  if (distance is! num || money is! num) {
    throw ApiException(400, 'distanceMeters and money must be numbers');
  }

  final saved = await database.submitRun(
    tokenHash: tokenHash,
    runId: runId,
    playerName: name.trim(),
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

Future<Response> _profileHandler(
  LeaderboardDatabase database,
  String name,
) async {
  final profile = await database.getProfile(name.trim());
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
  final upgradeId = json['upgradeId'];
  if (upgradeId is! String || upgradeId.isEmpty) {
    throw ApiException(400, 'upgradeId is required');
  }

  final profile = await database.purchaseUpgrade(
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
    } catch (error, stackTrace) {
      // Returned rather than rethrown so the response still gets CORS
      // headers and the request log records it.
      stderr.writeln('${request.method} ${request.url}: $error\n$stackTrace');
      return Response.internalServerError(body: 'Internal server error');
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
