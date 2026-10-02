import 'dart:io';

import 'package:test/test.dart';

import '../lib/database.dart';

void main() {
  late File dbFile;
  late LeaderboardDatabase database;
  late DateTime now;

  setUp(() async {
    dbFile = File(
      '${Directory.systemTemp.path}/dyno_upgrades_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    now = DateTime.utc(2026, 1, 1);
    database = LeaderboardDatabase(dbFile.path, clock: () => now);
    await database.open();
  });

  tearDown(() {
    // Windows cannot delete a SQLite file that is still open.
    database.close();
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  LeaderboardRow playRun({
    String token = 'token-a',
    String name = 'Sam',
    required Duration played,
    required double distance,
    required double money,
  }) {
    final runId = database.startRun(token);
    now = now.add(played);
    return database.submitRun(
      tokenHash: token,
      runId: runId,
      playerName: name,
      distanceMeters: distance,
      money: money,
    );
  }

  test('purchase deducts money and stores upgrade level', () {
    database.upsertScore(
      playerName: 'Sam',
      distanceMeters: 10,
      money: 100,
    );

    final profile = database.purchaseUpgrade(
      tokenHash: 'token-a',
      playerName: 'Sam',
      upgradeId: 'jump_boost',
    );

    expect(profile.upgradeLevels['jump_boost'], 1);
    expect(profile.money, 75);
  });

  test('score submit accumulates money on the server', () {
    playRun(played: const Duration(seconds: 30), distance: 10, money: 2.5);
    final second = playRun(
      played: const Duration(seconds: 30),
      distance: 5,
      money: 1.25,
    );

    expect(second.money, 3.75);
    expect(second.distanceMeters, 10);
  });

  test('a name belongs to the token that first used it', () {
    playRun(played: const Duration(seconds: 30), distance: 10, money: 2.5);

    expect(
      () => playRun(
        token: 'token-b',
        played: const Duration(seconds: 30),
        distance: 10,
        money: 2.5,
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
    expect(
      () => database.purchaseUpgrade(
        tokenHash: 'token-b',
        playerName: 'Sam',
        upgradeId: 'jump_boost',
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('rejects distance that could not be run in the time played', () {
    final limit = LeaderboardDatabase.maxDistanceForSeconds(10);

    expect(
      () => playRun(
        played: const Duration(seconds: 10),
        distance: limit + 50,
        money: 0,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('rejects more money than the distance could earn', () {
    expect(
      () => playRun(
        played: const Duration(seconds: 60),
        distance: 100,
        money: 1000,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('coin magnet raises the money limit', () {
    database.upsertScore(playerName: 'Sam', distanceMeters: 0, money: 30);
    database.purchaseUpgrade(
      tokenHash: 'token-a',
      playerName: 'Sam',
      upgradeId: 'coin_magnet',
    );

    final row = playRun(
      played: const Duration(seconds: 60),
      distance: 100,
      money: 27.5,
    );

    expect(row.money, 27.5);
  });

  test('a run can only be submitted once', () {
    final runId = database.startRun('token-a');
    now = now.add(const Duration(seconds: 30));
    database.submitRun(
      tokenHash: 'token-a',
      runId: runId,
      playerName: 'Sam',
      distanceMeters: 10,
      money: 2.5,
    );

    expect(
      () => database.submitRun(
        tokenHash: 'token-a',
        runId: runId,
        playerName: 'Sam',
        distanceMeters: 10,
        money: 2.5,
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('starting a run discards the previous open run', () {
    final first = database.startRun('token-a');
    database.startRun('token-a');
    now = now.add(const Duration(seconds: 30));

    expect(
      () => database.submitRun(
        tokenHash: 'token-a',
        runId: first,
        playerName: 'Sam',
        distanceMeters: 10,
        money: 2.5,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
