import 'dart:io';

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
    expect(entries.first.money, 4);
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
}
