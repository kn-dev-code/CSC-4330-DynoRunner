import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../lib/database.dart';

void main() {
  late File dbFile;
  late LeaderboardDatabase database;

  setUp(() async {
    dbFile = File('${Directory.systemTemp.path}/dyno_test_${DateTime.now().microsecondsSinceEpoch}.sqlite');
    database = LeaderboardDatabase(dbFile.path);
    await database.open();
  });

  tearDown(() {
    // Windows cannot delete a SQLite file that is still open.
    database.close();
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  test('stores best distance and money per player', () {
    database.upsertScore(
      playerName: 'Alex',
      distanceMeters: 10,
      money: 2.5,
    );
    database.upsertScore(
      playerName: 'Alex',
      distanceMeters: 8,
      money: 4,
    );

    final entries = database.listRanked();
    expect(entries.length, 1);
    expect(entries.first.playerName, 'Alex');
    expect(entries.first.distanceMeters, 10);
    expect(entries.first.money, 6.5);
  });

  test('ranks players by distance', () {
    database.upsertScore(
      playerName: 'Slow',
      distanceMeters: 5,
      money: 1,
    );
    database.upsertScore(
      playerName: 'Fast',
      distanceMeters: 20,
      money: 3,
    );

    final entries = database.listRanked();
    expect(entries.map((e) => e.playerName).toList(), ['Fast', 'Slow']);
    expect(entries.first.rank, 1);
    expect(entries.last.rank, 2);
  });

  test('reading a profile does not create a player', () {
    final profile = database.getProfile('Ghost');

    expect(profile.money, 0);
    expect(database.listRanked(), isEmpty);
  });

  test('adds the token column to databases from before tokens', () async {
    database.close();
    dbFile.deleteSync();
    final legacy = sqlite3.open(dbFile.path);
    legacy.execute('''
      CREATE TABLE leaderboard (
        player_name TEXT PRIMARY KEY,
        best_distance REAL NOT NULL,
        money REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    legacy.execute(
      "INSERT INTO leaderboard VALUES ('Old', 12, 60, '2026-01-01')",
    );
    legacy.dispose();

    database = LeaderboardDatabase(dbFile.path);
    await database.open();
    final profile = database.purchaseUpgrade(
      tokenHash: 'first-claimer',
      playerName: 'Old',
      upgradeId: 'jump_boost',
    );

    expect(profile.money, 35);
  });
}
