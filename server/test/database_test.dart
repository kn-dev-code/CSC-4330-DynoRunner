import 'dart:io';

import 'package:test/test.dart';

import '../lib/database.dart';

/// These tests need a MySQL-compatible database, such as a TiDB Cloud
/// cluster's built-in `test` database. They delete every row in it.
final _testDatabaseUrl = Platform.environment['TEST_DATABASE_URL'];

void main() {
  if (_testDatabaseUrl == null) {
    test(
      'database tests',
      () {},
      skip: 'Set TEST_DATABASE_URL to mysql://user:pass@host:4000/test',
    );
    return;
  }

  late LeaderboardDatabase database;
  late DateTime now;

  setUp(() async {
    final config = DatabaseConfig.fromUrl(_testDatabaseUrl!);
    if (!config.database.contains('test')) {
      fail(
        'Refusing to wipe "${config.database}"; use a database named *test*',
      );
    }
    now = DateTime.utc(2026, 1, 1);
    database = LeaderboardDatabase(config, clock: () => now);
    await database.open();
    await database.debugDeleteEverything();
  });

  tearDown(() => database.close());

  Future<LeaderboardRow> playRun({
    String token = 'token-a',
    String name = 'Sam',
    required Duration played,
    required double distance,
    required double money,
  }) async {
    final runId = await database.startRun(token);
    now = now.add(played);
    return database.submitRun(
      tokenHash: token,
      runId: runId,
      playerName: name,
      distanceMeters: distance,
      money: money,
    );
  }

  Matcher throwsApi(int status) => throwsA(
    isA<ApiException>().having((e) => e.statusCode, 'statusCode', status),
  );

  test('stores best distance and money per player', () async {
    await database.upsertScore(
      playerName: 'Alex',
      distanceMeters: 10,
      money: 2.5,
    );
    await database.upsertScore(playerName: 'Alex', distanceMeters: 8, money: 4);

    final entries = await database.listRanked();
    expect(entries.length, 1);
    expect(entries.first.playerName, 'Alex');
    expect(entries.first.distanceMeters, 10);
    expect(entries.first.money, 6.5);
  });

  test('ranks players by distance', () async {
    await database.upsertScore(playerName: 'Slow', distanceMeters: 5, money: 1);
    final fast = await database.upsertScore(
      playerName: 'Fast',
      distanceMeters: 20,
      money: 3,
    );

    final entries = await database.listRanked();
    expect(entries.map((e) => e.playerName).toList(), ['Fast', 'Slow']);
    expect(entries.first.rank, 1);
    expect(entries.last.rank, 2);
    expect(fast.rank, 1);
  });

  test('names are case-sensitive', () async {
    await database.upsertScore(playerName: 'Rex', distanceMeters: 5, money: 1);
    await database.upsertScore(playerName: 'rex', distanceMeters: 6, money: 1);

    expect(await database.listRanked(), hasLength(2));
  });

  test('reading a profile does not create a player', () async {
    final profile = await database.getProfile('Ghost');

    expect(profile.money, 0);
    expect(await database.listRanked(), isEmpty);
  });

  test('purchase deducts money and stores upgrade level', () async {
    await database.upsertScore(
      playerName: 'Sam',
      distanceMeters: 10,
      money: 100,
    );

    final profile = await database.purchaseUpgrade(
      tokenHash: 'token-a',
      playerName: 'Sam',
      upgradeId: 'jump_boost',
    );

    expect(profile.upgradeLevels['jump_boost'], 1);
    expect(profile.money, 75);
  });

  test('concurrent purchases cannot overspend', () async {
    await database.upsertScore(playerName: 'Sam', distanceMeters: 0, money: 25);

    final results = await Future.wait([
      for (var i = 0; i < 3; i++)
        database
            .purchaseUpgrade(
              tokenHash: 'token-a',
              playerName: 'Sam',
              upgradeId: 'jump_boost',
            )
            .then((_) => true, onError: (_) => false),
    ]);

    expect(results.where((ok) => ok), hasLength(1));
    final profile = await database.getProfile('Sam');
    expect(profile.money, 0);
    expect(profile.upgradeLevels['jump_boost'], 1);
  });

  test('score submit accumulates money on the server', () async {
    await playRun(
      played: const Duration(seconds: 30),
      distance: 10,
      money: 2.5,
    );
    final second = await playRun(
      played: const Duration(seconds: 30),
      distance: 5,
      money: 1.25,
    );

    expect(second.money, 3.75);
    expect(second.distanceMeters, 10);
  });

  test('a name belongs to the token that first used it', () async {
    await playRun(
      played: const Duration(seconds: 30),
      distance: 10,
      money: 2.5,
    );

    await expectLater(
      playRun(
        token: 'token-b',
        played: const Duration(seconds: 30),
        distance: 10,
        money: 2.5,
      ),
      throwsApi(403),
    );
    await expectLater(
      database.purchaseUpgrade(
        tokenHash: 'token-b',
        playerName: 'Sam',
        upgradeId: 'jump_boost',
      ),
      throwsApi(403),
    );
  });

  test('rejects distance that could not be run in the time played', () async {
    final limit = LeaderboardDatabase.maxDistanceForSeconds(10);

    await expectLater(
      playRun(
        played: const Duration(seconds: 10),
        distance: limit + 50,
        money: 0,
      ),
      throwsApi(400),
    );
  });

  test('rejects more money than the distance could earn', () async {
    await expectLater(
      playRun(played: const Duration(seconds: 60), distance: 100, money: 1000),
      throwsApi(400),
    );
  });

  test('coin magnet raises the money limit', () async {
    await database.upsertScore(playerName: 'Sam', distanceMeters: 0, money: 30);
    await database.purchaseUpgrade(
      tokenHash: 'token-a',
      playerName: 'Sam',
      upgradeId: 'coin_magnet',
    );

    final row = await playRun(
      played: const Duration(seconds: 60),
      distance: 100,
      money: 27.5,
    );

    expect(row.money, 27.5);
  });

  test('a run submitted twice at once is only counted once', () async {
    final runId = await database.startRun('token-a');
    now = now.add(const Duration(seconds: 30));
    Future<bool> submit() => database
        .submitRun(
          tokenHash: 'token-a',
          runId: runId,
          playerName: 'Sam',
          distanceMeters: 10,
          money: 2.5,
        )
        .then((_) => true, onError: (_) => false);

    final results = await Future.wait([submit(), submit()]);

    expect(results.where((ok) => ok), hasLength(1));
    expect((await database.getProfile('Sam')).money, 2.5);
  });

  test('starting a run discards the previous open run', () async {
    final first = await database.startRun('token-a');
    await database.startRun('token-a');
    now = now.add(const Duration(seconds: 30));

    await expectLater(
      database.submitRun(
        tokenHash: 'token-a',
        runId: first,
        playerName: 'Sam',
        distanceMeters: 10,
        money: 2.5,
      ),
      throwsApi(400),
    );
  });

  test('names with quotes, backslashes and emoji round-trip safely', () async {
    // The MySQL client builds SQL text itself rather than using prepared
    // statements, so these check its escaping.
    const names = [
      "O'Brien",
      r'back\slash',
      r"\'; DROP TABLE runs; --",
      'colon :name',
      '🦖 Dino',
    ];
    for (final name in names) {
      await playRun(
        token: 'token-$name',
        name: name,
        played: const Duration(seconds: 30),
        distance: 10,
        money: 2.5,
      );
    }

    final stored = (await database.listRanked()).map((e) => e.playerName);
    expect(stored, unorderedEquals(names));
    for (final name in names) {
      expect((await database.getProfile(name)).money, 2.5);
    }
  });

  test('recovers when the database kills a pooled connection', () async {
    final impatient = LeaderboardDatabase(
      DatabaseConfig.fromUrl(_testDatabaseUrl!),
      requestTimeout: const Duration(seconds: 3),
    );
    addTearDown(impatient.close);
    final id = await impatient.debugConnectionId();
    await database.debugKillConnection(id);

    // The request on the dead connection may fail, but it must not hang, and
    // the pool must keep working afterwards.
    try {
      await impatient.listRanked();
    } catch (_) {}
    for (var i = 0; i < 6; i++) {
      expect(await impatient.listRanked(), isEmpty);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
