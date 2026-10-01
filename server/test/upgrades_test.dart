import 'dart:io';

import 'package:test/test.dart';

import '../lib/database.dart';

void main() {
  late File dbFile;
  late LeaderboardDatabase database;

  setUp(() async {
    dbFile = File(
      '${Directory.systemTemp.path}/dyno_upgrades_${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    database = LeaderboardDatabase(dbFile.path);
    await database.open();
  });

  tearDown(() {
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
  });

  test('purchase deducts money and stores upgrade level', () {
    database.upsertScore(
      playerName: 'Sam',
      distanceMeters: 10,
      money: 100,
    );

    final profile = database.purchaseUpgrade(
      playerName: 'Sam',
      upgradeId: 'jump_boost',
    );

    expect(profile.upgradeLevels['jump_boost'], 1);
    expect(profile.money, 75);
  });

  test('score submit accumulates money on the server', () {
    database.upsertScore(
      playerName: 'Sam',
      distanceMeters: 10,
      money: 20,
    );
    final second = database.upsertScore(
      playerName: 'Sam',
      distanceMeters: 5,
      money: 15,
    );

    expect(second.money, 35);
  });
}
