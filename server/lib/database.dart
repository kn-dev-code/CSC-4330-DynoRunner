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

class PlayerProfileRow {
  PlayerProfileRow({
    required this.playerName,
    required this.money,
    required this.upgradeLevels,
  });

  final String playerName;
  final double money;
  final Map<String, int> upgradeLevels;
}

class LeaderboardDatabase {
  LeaderboardDatabase(this.path);

  final String path;
  Database? _db;

  static const upgradeCatalog = {
    'jump_boost': 5,
    'coin_magnet': 5,
    'iron_hide': 3,
    'pit_spikes': 1,
  };

  static const upgradeBaseCosts = {
    'jump_boost': 25.0,
    'coin_magnet': 30.0,
    'iron_hide': 40.0,
    'pit_spikes': 35.0,
  };

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
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS player_upgrades (
        player_name TEXT NOT NULL,
        upgrade_id TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (player_name, upgrade_id)
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
      final previousMoney = (existing.first['money'] as num).toDouble();
      final best = distanceMeters > previousBest ? distanceMeters : previousBest;
      final totalMoney = previousMoney + money;
      db.execute(
        'UPDATE leaderboard SET best_distance = ?, money = ?, updated_at = ? WHERE player_name = ?',
        [best, totalMoney, now, playerName],
      );
    }

    final ranked = listRanked();
    return ranked.firstWhere((row) => row.playerName == playerName);
  }

  PlayerProfileRow getProfile(String playerName) {
    final db = _requireDb;
    _ensurePlayerRow(playerName);

    final moneyRow = db.select(
      'SELECT money FROM leaderboard WHERE player_name = ?',
      [playerName],
    );
    final money = moneyRow.isEmpty
        ? 0.0
        : (moneyRow.first['money'] as num).toDouble();

    final upgrades = db.select(
      'SELECT upgrade_id, level FROM player_upgrades WHERE player_name = ?',
      [playerName],
    );

    return PlayerProfileRow(
      playerName: playerName,
      money: money,
      upgradeLevels: {
        for (final row in upgrades)
          row['upgrade_id'] as String: row['level'] as int,
      },
    );
  }

  PlayerProfileRow purchaseUpgrade({
    required String playerName,
    required String upgradeId,
  }) {
    final maxLevel = upgradeCatalog[upgradeId];
    final baseCost = upgradeBaseCosts[upgradeId];
    if (maxLevel == null || baseCost == null) {
      throw ArgumentError('Unknown upgrade: $upgradeId');
    }

    final db = _requireDb;
    _ensurePlayerRow(playerName);

    final currentLevel = db.select(
      'SELECT level FROM player_upgrades WHERE player_name = ? AND upgrade_id = ?',
      [playerName, upgradeId],
    );
    final level = currentLevel.isEmpty ? 0 : currentLevel.first['level'] as int;
    if (level >= maxLevel) {
      throw StateError('Upgrade already at max level');
    }

    final cost = baseCost * (level + 1);
    final moneyRow = db.select(
      'SELECT money FROM leaderboard WHERE player_name = ?',
      [playerName],
    );
    final money = (moneyRow.first['money'] as num).toDouble();
    if (money < cost) {
      throw StateError('Not enough money');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    db.execute(
      'UPDATE leaderboard SET money = ?, updated_at = ? WHERE player_name = ?',
      [money - cost, now, playerName],
    );

    if (currentLevel.isEmpty) {
      db.execute(
        'INSERT INTO player_upgrades (player_name, upgrade_id, level) VALUES (?, ?, 1)',
        [playerName, upgradeId],
      );
    } else {
      db.execute(
        'UPDATE player_upgrades SET level = ? WHERE player_name = ? AND upgrade_id = ?',
        [level + 1, playerName, upgradeId],
      );
    }

    return getProfile(playerName);
  }

  void _ensurePlayerRow(String playerName) {
    final db = _requireDb;
    final existing = db.select(
      'SELECT player_name FROM leaderboard WHERE player_name = ?',
      [playerName],
    );
    if (existing.isNotEmpty) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    db.execute(
      'INSERT INTO leaderboard (player_name, best_distance, money, updated_at) VALUES (?, 0, 0, ?)',
      [playerName, now],
    );
  }

  Database get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('Database not opened');
    }
    return db;
  }
}
