import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class LeaderboardRow {
  LeaderboardRow({
    required this.rank,
    required this.playerName,
    required this.distanceMeters,
    required this.money,
  });

  final int rank;
  final String playerName;
  final double distanceMeters;
  final double money;
}

class LeaderboardDatabase {
  LeaderboardDatabase(this.path);

  final String path;
  Database? _db;

  Future<void> open() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    _db = sqlite3.open(path);
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard (
        player_name TEXT PRIMARY KEY,
        best_distance REAL NOT NULL,
        money REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  List<LeaderboardRow> listRanked() {
    final db = _requireDb;
    final result = db.select('''
      SELECT player_name, best_distance, money
      FROM leaderboard
      ORDER BY best_distance DESC, player_name ASC
    ''');

    return [
      for (var index = 0; index < result.length; index++)
        LeaderboardRow(
          rank: index + 1,
          playerName: result[index]['player_name'] as String,
          distanceMeters: (result[index]['best_distance'] as num).toDouble(),
          money: (result[index]['money'] as num).toDouble(),
        ),
    ];
  }

  LeaderboardRow upsertScore({
    required String playerName,
    required double distanceMeters,
    required double money,
  }) {
    final db = _requireDb;
    final existing = db.select(
      'SELECT best_distance, money FROM leaderboard WHERE player_name = ?',
      [playerName],
    );

    final now = DateTime.now().toUtc().toIso8601String();
    if (existing.isEmpty) {
      db.execute(
        'INSERT INTO leaderboard (player_name, best_distance, money, updated_at) VALUES (?, ?, ?, ?)',
        [playerName, distanceMeters, money, now],
      );
    } else {
      final previousBest = (existing.first['best_distance'] as num).toDouble();
      final best = distanceMeters > previousBest ? distanceMeters : previousBest;
      db.execute(
        'UPDATE leaderboard SET best_distance = ?, money = ?, updated_at = ? WHERE player_name = ?',
        [best, money, now, playerName],
      );
    }

    final ranked = listRanked();
    return ranked.firstWhere((row) => row.playerName == playerName);
  }

  Database get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('Database not opened');
    }
    return db;
  }
}
