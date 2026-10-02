import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
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

/// A rejected request; [statusCode] is the HTTP status the API should return.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => message;
}

class LeaderboardDatabase {
  LeaderboardDatabase(this.path, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final String path;
  final DateTime Function() _clock;
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

  static const maxNameLength = 24;
  static const minTokenLength = 16;

  /// Runs left open longer than this can no longer be submitted.
  static const maxRunDuration = Duration(hours: 6);

  // Mirrors the tuning in the app's lib/game/game_config.dart so the server
  // can bound what an honest run could have earned.
  static const _scrollSpeed = 280.0;
  static const _speedIncreasePerSecond = 4.0;
  static const _superspeedMultiplier = 1.55;
  static const _pixelsPerMeter = 100.0;
  static const _moneyPerMeter = 0.25;
  static const _coinMagnetBonusPerLevel = 0.1;
  static const _bossIntervalMeters = 250.0;
  static const _bossMoneyBonus = 50.0;

  /// Farthest a player could run in [seconds], assuming superspeed the whole
  /// time.
  static double maxDistanceForSeconds(double seconds) {
    final pixels =
        _scrollSpeed * seconds + 0.5 * _speedIncreasePerSecond * seconds * seconds;
    return pixels * _superspeedMultiplier / _pixelsPerMeter;
  }

  /// Most money a run of [distanceMeters] could earn at [coinMagnetLevel].
  static double maxMoneyForDistance(double distanceMeters, int coinMagnetLevel) {
    final perMeter =
        _moneyPerMeter * (1 + coinMagnetLevel * _coinMagnetBonusPerLevel);
    final bosses = (distanceMeters / _bossIntervalMeters).floor();
    return distanceMeters * perMeter + bosses * _bossMoneyBonus;
  }

  /// Only a hash of each player's secret token is stored.
  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Future<void> open() async {
    final file = File(path);
    await file.parent.create(recursive: true);
    _db = sqlite3.open(path);
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard (
        player_name TEXT PRIMARY KEY,
        best_distance REAL NOT NULL,
        money REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        token_hash TEXT
      )
    ''');
    final columns = _db!.select('PRAGMA table_info(leaderboard)');
    if (!columns.any((column) => column['name'] == 'token_hash')) {
      // Databases created before names were tied to a token.
      _db!.execute('ALTER TABLE leaderboard ADD COLUMN token_hash TEXT');
    }
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS player_upgrades (
        player_name TEXT NOT NULL,
        upgrade_id TEXT NOT NULL,
        level INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (player_name, upgrade_id)
      )
    ''');
    _db!.execute('''
      CREATE TABLE IF NOT EXISTS runs (
        run_id TEXT PRIMARY KEY,
        token_hash TEXT NOT NULL UNIQUE,
        started_at INTEGER NOT NULL
      )
    ''');
  }

  void close() {
    _db?.dispose();
    _db = null;
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

  /// Opens a new run for [tokenHash], discarding any run it left open, so a
  /// player can only have one run's worth of time counting at once.
  String startRun(String tokenHash) {
    final db = _requireDb;
    final random = Random.secure();
    final runId = [
      for (var i = 0; i < 16; i++) random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    db.execute('DELETE FROM runs WHERE token_hash = ?', [tokenHash]);
    db.execute(
      'INSERT INTO runs (run_id, token_hash, started_at) VALUES (?, ?, ?)',
      [runId, tokenHash, _clock().millisecondsSinceEpoch],
    );
    return runId;
  }

  /// Validates a finished run against the time since [startRun] and the
  /// player's upgrades, then records it.
  LeaderboardRow submitRun({
    required String tokenHash,
    required String runId,
    required String playerName,
    required double distanceMeters,
    required double money,
  }) {
    final db = _requireDb;
    final run = db.select(
      'SELECT started_at FROM runs WHERE run_id = ? AND token_hash = ?',
      [runId, tokenHash],
    );
    if (run.isEmpty) {
      throw ApiException(400, 'Unknown or already submitted run');
    }
    if (!distanceMeters.isFinite || distanceMeters < 0) {
      throw ApiException(400, 'distanceMeters must be a non-negative number');
    }
    if (!money.isFinite || money < 0) {
      throw ApiException(400, 'money must be a non-negative number');
    }

    final elapsed = _clock().difference(
      DateTime.fromMillisecondsSinceEpoch(run.first['started_at'] as int),
    );
    if (elapsed > maxRunDuration) {
      db.execute('DELETE FROM runs WHERE run_id = ?', [runId]);
      throw ApiException(400, 'Run expired');
    }
    // One meter of slack covers rounding and clock jitter.
    final seconds = elapsed.inMilliseconds / 1000;
    if (distanceMeters > maxDistanceForSeconds(seconds) + 1) {
      throw ApiException(400, 'Distance is not possible in the time played');
    }

    _claimName(playerName, tokenHash);
    final magnet = _upgradeLevel(playerName, 'coin_magnet');
    if (money > maxMoneyForDistance(distanceMeters, magnet) + 0.01) {
      throw ApiException(400, 'Money is not possible for that distance');
    }

    db.execute('DELETE FROM runs WHERE run_id = ?', [runId]);
    return upsertScore(
      playerName: playerName,
      distanceMeters: distanceMeters,
      money: money,
    );
  }

  /// Records a score with no validation; [submitRun] is the API entry point.
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

    final now = _clock().toUtc().toIso8601String();
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

  /// Read-only: unknown players get an empty profile without creating a row.
  PlayerProfileRow getProfile(String playerName) {
    final db = _requireDb;
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
    required String tokenHash,
    required String playerName,
    required String upgradeId,
  }) {
    final maxLevel = upgradeCatalog[upgradeId];
    final baseCost = upgradeBaseCosts[upgradeId];
    if (maxLevel == null || baseCost == null) {
      throw ApiException(400, 'Unknown upgrade: $upgradeId');
    }

    final db = _requireDb;
    _claimName(playerName, tokenHash);

    final level = _upgradeLevel(playerName, upgradeId);
    if (level >= maxLevel) {
      throw ApiException(400, 'Upgrade already at max level');
    }

    final cost = baseCost * (level + 1);
    final moneyRow = db.select(
      'SELECT money FROM leaderboard WHERE player_name = ?',
      [playerName],
    );
    final money = (moneyRow.first['money'] as num).toDouble();
    if (money < cost) {
      throw ApiException(400, 'Not enough money');
    }

    final now = _clock().toUtc().toIso8601String();
    db.execute(
      'UPDATE leaderboard SET money = ?, updated_at = ? WHERE player_name = ?',
      [money - cost, now, playerName],
    );
    db.execute(
      '''
      INSERT INTO player_upgrades (player_name, upgrade_id, level) VALUES (?, ?, 1)
      ON CONFLICT (player_name, upgrade_id) DO UPDATE SET level = level + 1
      ''',
      [playerName, upgradeId],
    );

    return getProfile(playerName);
  }

  int _upgradeLevel(String playerName, String upgradeId) {
    final rows = _requireDb.select(
      'SELECT level FROM player_upgrades WHERE player_name = ? AND upgrade_id = ?',
      [playerName, upgradeId],
    );
    return rows.isEmpty ? 0 : rows.first['level'] as int;
  }

  /// Ensures [playerName] exists and belongs to [tokenHash]. Names that have
  /// never been claimed (new, or from before tokens existed) go to the first
  /// token that writes to them.
  void _claimName(String playerName, String tokenHash) {
    if (playerName.isEmpty || playerName.length > maxNameLength) {
      throw ApiException(
        400,
        'playerName must be 1-$maxNameLength characters',
      );
    }

    final db = _requireDb;
    final existing = db.select(
      'SELECT token_hash FROM leaderboard WHERE player_name = ?',
      [playerName],
    );
    if (existing.isEmpty) {
      db.execute(
        'INSERT INTO leaderboard (player_name, best_distance, money, updated_at, token_hash) VALUES (?, 0, 0, ?, ?)',
        [playerName, _clock().toUtc().toIso8601String(), tokenHash],
      );
      return;
    }

    final owner = existing.first['token_hash'] as String?;
    if (owner == null) {
      db.execute(
        'UPDATE leaderboard SET token_hash = ? WHERE player_name = ?',
        [tokenHash, playerName],
      );
    } else if (owner != tokenHash) {
      throw ApiException(403, 'That name belongs to another player');
    }
  }

  Database get _requireDb {
    final db = _db;
    if (db == null) {
      throw StateError('Database not opened');
    }
    return db;
  }
}
