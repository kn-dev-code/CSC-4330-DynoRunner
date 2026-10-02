import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:mysql_client_plus/exception.dart';
import 'package:mysql_client_plus/mysql_client_plus.dart';

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

/// Where to reach the database, parsed from a URL like
/// `mysql://user:password@host:4000/database` (the format TiDB Cloud shows).
class DatabaseConfig {
  DatabaseConfig({
    required this.host,
    required this.port,
    required this.user,
    required this.password,
    required this.database,
  });

  factory DatabaseConfig.fromUrl(String url) {
    final uri = Uri.parse(url);
    if (uri.scheme != 'mysql' || uri.host.isEmpty) {
      throw FormatException('Expected mysql://user:password@host:port/db');
    }
    final separator = uri.userInfo.indexOf(':');
    final user = separator < 0
        ? uri.userInfo
        : uri.userInfo.substring(0, separator);
    final password = separator < 0 ? '' : uri.userInfo.substring(separator + 1);
    final database = uri.path.replaceFirst('/', '');
    if (user.isEmpty || database.isEmpty) {
      throw FormatException('The URL needs a user and a database name');
    }
    return DatabaseConfig(
      host: uri.host,
      port: uri.hasPort ? uri.port : 4000,
      user: Uri.decodeComponent(user),
      password: Uri.decodeComponent(password),
      database: Uri.decodeComponent(database),
    );
  }

  final String host;
  final int port;
  final String user;
  final String password;
  final String database;
}

class LeaderboardDatabase {
  LeaderboardDatabase(
    this.config, {
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 15),
  }) : _clock = clock ?? DateTime.now;

  final DatabaseConfig config;
  final DateTime Function() _clock;
  late final _ConnectionPool _pool = _ConnectionPool(
    config,
    timeout: requestTimeout,
  );

  /// Longest a request may wait on the database before failing.
  final Duration requestTimeout;

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
  static const leaderboardSize = 100;

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
        _scrollSpeed * seconds +
        0.5 * _speedIncreasePerSecond * seconds * seconds;
    return pixels * _superspeedMultiplier / _pixelsPerMeter;
  }

  /// Most money a run of [distanceMeters] could earn at [coinMagnetLevel].
  static double maxMoneyForDistance(
    double distanceMeters,
    int coinMagnetLevel,
  ) {
    final perMeter =
        _moneyPerMeter * (1 + coinMagnetLevel * _coinMagnetBonusPerLevel);
    final bosses = (distanceMeters / _bossIntervalMeters).floor();
    return distanceMeters * perMeter + bosses * _bossMoneyBonus;
  }

  /// Only a hash of each player's secret token is stored.
  static String hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  Future<void> open() async {
    // utf8mb4_bin keeps names case-sensitive, so "Rex" and "rex" are
    // different players.
    await _pool.execute('''
      CREATE TABLE IF NOT EXISTS leaderboard (
        player_name VARCHAR($maxNameLength) COLLATE utf8mb4_bin NOT NULL PRIMARY KEY,
        best_distance DOUBLE NOT NULL,
        money DOUBLE NOT NULL DEFAULT 0,
        token_hash CHAR(64) NULL,
        updated_at TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
          ON UPDATE CURRENT_TIMESTAMP(3),
        KEY leaderboard_rank (best_distance, player_name)
      ) DEFAULT CHARSET = utf8mb4
    ''');
    await _pool.execute('''
      CREATE TABLE IF NOT EXISTS player_upgrades (
        player_name VARCHAR($maxNameLength) COLLATE utf8mb4_bin NOT NULL,
        upgrade_id VARCHAR(32) NOT NULL,
        level INT NOT NULL DEFAULT 0,
        PRIMARY KEY (player_name, upgrade_id)
      ) DEFAULT CHARSET = utf8mb4
    ''');
    await _pool.execute('''
      CREATE TABLE IF NOT EXISTS runs (
        run_id CHAR(32) NOT NULL PRIMARY KEY,
        token_hash CHAR(64) NOT NULL UNIQUE,
        started_at BIGINT NOT NULL
      )
    ''');
  }

  Future<void> close() => _pool.close();

  /// Empties every table. Only for tests.
  Future<void> debugDeleteEverything() async {
    for (final table in ['runs', 'player_upgrades', 'leaderboard']) {
      await _pool.execute('DELETE FROM $table');
    }
  }

  /// The database's id for the connection a request would use next. Only for
  /// tests.
  Future<int> debugConnectionId() async {
    final result = await _pool.execute('SELECT CONNECTION_ID() AS id');
    return result.rows.first.typedColByName<int>('id')!;
  }

  /// Kills another connection's session, as the database might on its own.
  /// Only for tests.
  Future<void> debugKillConnection(int id) => _pool.execute('KILL $id');

  Future<List<LeaderboardRow>> listRanked() async {
    final result = await _pool.execute('''
      SELECT player_name, best_distance, money
      FROM leaderboard
      ORDER BY best_distance DESC, player_name ASC
      LIMIT $leaderboardSize
    ''');

    final rows = result.rows.toList();
    return [
      for (var index = 0; index < rows.length; index++)
        LeaderboardRow(
          rank: index + 1,
          playerName: rows[index].colByName('player_name')!,
          distanceMeters: rows[index].typedColByName<double>('best_distance')!,
          money: rows[index].typedColByName<double>('money')!,
        ),
    ];
  }

  /// Opens a new run for [tokenHash], replacing any run it left open, so a
  /// player can only have one run's worth of time counting at once.
  Future<String> startRun(String tokenHash) async {
    final random = Random.secure();
    final runId = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await _pool.execute(
      '''
      INSERT INTO runs (run_id, token_hash, started_at)
      VALUES (:run, :token, :started)
      ON DUPLICATE KEY UPDATE
        run_id = VALUES(run_id), started_at = VALUES(started_at)
      ''',
      {
        'run': runId,
        'token': tokenHash,
        'started': _clock().millisecondsSinceEpoch,
      },
    );
    return runId;
  }

  /// Validates a finished run against the time since [startRun] and the
  /// player's upgrades, then records it.
  Future<LeaderboardRow> submitRun({
    required String tokenHash,
    required String runId,
    required String playerName,
    required double distanceMeters,
    required double money,
  }) {
    if (!distanceMeters.isFinite || distanceMeters < 0) {
      throw ApiException(400, 'distanceMeters must be a non-negative number');
    }
    if (!money.isFinite || money < 0) {
      throw ApiException(400, 'money must be a non-negative number');
    }

    return _pool.transaction((conn) async {
      // Locking the run row means a run submitted twice at once is only
      // counted once.
      final run = await conn.execute(
        'SELECT started_at FROM runs WHERE run_id = :run AND token_hash = :token FOR UPDATE',
        {'run': runId, 'token': tokenHash},
      );
      if (run.rows.isEmpty) {
        throw ApiException(400, 'Unknown or already submitted run');
      }

      final startedAt = run.rows.first.typedColByName<int>('started_at')!;
      final elapsed = _clock().difference(
        DateTime.fromMillisecondsSinceEpoch(startedAt),
      );
      if (elapsed > maxRunDuration) {
        throw ApiException(400, 'Run expired');
      }
      // One meter of slack covers rounding and clock jitter.
      final seconds = elapsed.inMilliseconds / 1000;
      if (distanceMeters > maxDistanceForSeconds(seconds) + 1) {
        throw ApiException(400, 'Distance is not possible in the time played');
      }

      await _claimName(conn, playerName, tokenHash);
      final magnet = await _upgradeLevel(conn, playerName, 'coin_magnet');
      if (money > maxMoneyForDistance(distanceMeters, magnet) + 0.01) {
        throw ApiException(400, 'Money is not possible for that distance');
      }

      await conn.execute('DELETE FROM runs WHERE run_id = :run', {
        'run': runId,
      });
      await conn.execute(
        '''
        UPDATE leaderboard
        SET best_distance = GREATEST(best_distance, :distance),
            money = money + :money
        WHERE player_name = :name
        ''',
        {'distance': distanceMeters, 'money': money, 'name': playerName},
      );
      return _rankedRow(conn, playerName);
    });
  }

  /// Records a score with no validation; [submitRun] is the API entry point.
  Future<LeaderboardRow> upsertScore({
    required String playerName,
    required double distanceMeters,
    required double money,
  }) {
    return _pool.transaction((conn) async {
      await conn.execute(
        '''
        INSERT INTO leaderboard (player_name, best_distance, money)
        VALUES (:name, :distance, :money)
        ON DUPLICATE KEY UPDATE
          best_distance = GREATEST(best_distance, VALUES(best_distance)),
          money = money + VALUES(money)
        ''',
        {'name': playerName, 'distance': distanceMeters, 'money': money},
      );
      return _rankedRow(conn, playerName);
    });
  }

  /// Read-only: unknown players get an empty profile without creating a row.
  Future<PlayerProfileRow> getProfile(String playerName) {
    return _pool.withConnection((conn) => _profile(conn, playerName));
  }

  Future<PlayerProfileRow> purchaseUpgrade({
    required String tokenHash,
    required String playerName,
    required String upgradeId,
  }) {
    final maxLevel = upgradeCatalog[upgradeId];
    final baseCost = upgradeBaseCosts[upgradeId];
    if (maxLevel == null || baseCost == null) {
      throw ApiException(400, 'Unknown upgrade: $upgradeId');
    }

    return _pool.transaction((conn) async {
      // _claimName locks the player's row, so concurrent purchases are
      // applied one at a time and cannot overspend.
      await _claimName(conn, playerName, tokenHash);

      final level = await _upgradeLevel(conn, playerName, upgradeId);
      if (level >= maxLevel) {
        throw ApiException(400, 'Upgrade already at max level');
      }

      final cost = baseCost * (level + 1);
      final moneyRow = await conn.execute(
        'SELECT money FROM leaderboard WHERE player_name = :name FOR UPDATE',
        {'name': playerName},
      );
      final money = moneyRow.rows.first.typedColByName<double>('money')!;
      if (money < cost) {
        throw ApiException(400, 'Not enough money');
      }

      await conn.execute(
        'UPDATE leaderboard SET money = money - :cost WHERE player_name = :name',
        {'cost': cost, 'name': playerName},
      );
      await conn.execute(
        '''
        INSERT INTO player_upgrades (player_name, upgrade_id, level)
        VALUES (:name, :upgrade, 1)
        ON DUPLICATE KEY UPDATE level = level + 1
        ''',
        {'name': playerName, 'upgrade': upgradeId},
      );

      return _profile(conn, playerName);
    });
  }

  Future<PlayerProfileRow> _profile(
    MySQLConnection conn,
    String playerName,
  ) async {
    final moneyRow = await conn.execute(
      'SELECT money FROM leaderboard WHERE player_name = :name',
      {'name': playerName},
    );
    final money = moneyRow.rows.isEmpty
        ? 0.0
        : moneyRow.rows.first.typedColByName<double>('money')!;

    final upgrades = await conn.execute(
      'SELECT upgrade_id, level FROM player_upgrades WHERE player_name = :name',
      {'name': playerName},
    );

    return PlayerProfileRow(
      playerName: playerName,
      money: money,
      upgradeLevels: {
        for (final row in upgrades.rows)
          row.colByName('upgrade_id')!: row.typedColByName<int>('level')!,
      },
    );
  }

  /// [playerName]'s row with its position in the same order as [listRanked].
  Future<LeaderboardRow> _rankedRow(
    MySQLConnection conn,
    String playerName,
  ) async {
    final result = await conn.execute(
      '''
      SELECT player_name, best_distance, money,
        (SELECT COUNT(*) FROM leaderboard other
         WHERE other.best_distance > me.best_distance
            OR (other.best_distance = me.best_distance
                AND other.player_name < me.player_name)) + 1 AS player_rank
      FROM leaderboard me
      WHERE player_name = :name
      ''',
      {'name': playerName},
    );
    final row = result.rows.first;
    return LeaderboardRow(
      rank: row.typedColByName<int>('player_rank')!,
      playerName: row.colByName('player_name')!,
      distanceMeters: row.typedColByName<double>('best_distance')!,
      money: row.typedColByName<double>('money')!,
    );
  }

  Future<int> _upgradeLevel(
    MySQLConnection conn,
    String playerName,
    String upgradeId,
  ) async {
    final rows = await conn.execute(
      'SELECT level FROM player_upgrades WHERE player_name = :name AND upgrade_id = :upgrade',
      {'name': playerName, 'upgrade': upgradeId},
    );
    return rows.rows.isEmpty
        ? 0
        : rows.rows.first.typedColByName<int>('level')!;
  }

  /// Ensures [playerName] exists and belongs to [tokenHash], and locks its
  /// row until the transaction ends. Names that have never been claimed go to
  /// the first token that writes to them.
  Future<void> _claimName(
    MySQLConnection conn,
    String playerName,
    String tokenHash,
  ) async {
    if (playerName.isEmpty || playerName.length > maxNameLength) {
      throw ApiException(400, 'playerName must be 1-$maxNameLength characters');
    }

    await conn.execute(
      '''
      INSERT INTO leaderboard (player_name, best_distance, money, token_hash)
      VALUES (:name, 0, 0, :token)
      ON DUPLICATE KEY UPDATE player_name = player_name
      ''',
      {'name': playerName, 'token': tokenHash},
    );
    final existing = await conn.execute(
      'SELECT token_hash FROM leaderboard WHERE player_name = :name FOR UPDATE',
      {'name': playerName},
    );

    final owner = existing.rows.first.colByName('token_hash');
    if (owner == null) {
      await conn.execute(
        'UPDATE leaderboard SET token_hash = :token WHERE player_name = :name',
        {'token': tokenHash, 'name': playerName},
      );
    } else if (owner != tokenHash) {
      throw ApiException(403, 'That name belongs to another player');
    }
  }
}

/// A small connection pool. mysql_client_plus's own pool leaks a connection
/// whenever a callback throws, which every rejected request would do.
///
/// It also never notices a connection the database has dropped: queries on
/// one simply never return. So every use has a deadline, connections that
/// miss it are discarded, and long-idle connections are checked before reuse.
class _ConnectionPool {
  _ConnectionPool(this.config, {required this.timeout});

  final DatabaseConfig config;

  /// Longest one request may hold a connection, including connecting.
  final Duration timeout;

  static const _maxConnections = 5;

  /// Idle connections older than this are dropped rather than reused.
  static const _maxIdle = Duration(minutes: 5);

  /// Idle connections older than this are pinged before being reused.
  static const _checkAfterIdle = Duration(seconds: 30);
  static const _checkTimeout = Duration(seconds: 3);

  final _idle = <({MySQLConnection conn, DateTime since})>[];
  final _waiters = <Completer<void>>[];
  var _open = 0;

  Future<IResultSet> execute(String sql, [Map<String, dynamic>? params]) =>
      withConnection((conn) => conn.execute(sql, params));

  Future<T> withConnection<T>(
    Future<T> Function(MySQLConnection conn) action,
  ) async {
    // No timeout here: an abandoned _acquire would still take a connection
    // and never release it. Each step inside it has its own deadline, and
    // waiting for a busy connection is bounded by its holder's deadline.
    final conn = await _acquire();
    var healthy = true;
    try {
      return await action(conn).timeout(timeout);
    } on TimeoutException {
      healthy = false;
      rethrow;
    } on MySQLClientException {
      // Client-side failures (timeouts, closed sockets) leave the connection
      // in an unknown state. Errors the server reports are fine to reuse.
      healthy = false;
      rethrow;
    } on SocketException {
      healthy = false;
      rethrow;
    } finally {
      _release(conn, healthy: healthy);
    }
  }

  /// Runs [action] in a transaction, rolling back if it throws.
  Future<T> transaction<T>(Future<T> Function(MySQLConnection conn) action) {
    return withConnection((conn) async {
      await conn.execute('BEGIN');
      try {
        final result = await action(conn);
        await conn.execute('COMMIT');
        return result;
      } catch (_) {
        // If this fails too, withConnection discards the connection, and the
        // database rolls back the transaction when the connection closes.
        await conn.execute('ROLLBACK');
        rethrow;
      }
    });
  }

  Future<void> close() async {
    for (final idle in _idle) {
      _discard(idle.conn);
    }
    _idle.clear();
  }

  Future<MySQLConnection> _acquire() async {
    while (true) {
      while (_idle.isNotEmpty) {
        final idle = _idle.removeLast();
        final age = DateTime.now().difference(idle.since);
        if (idle.conn.connected &&
            age < _maxIdle &&
            (age < _checkAfterIdle || await _isAlive(idle.conn))) {
          return idle.conn;
        }
        _open--;
        _discard(idle.conn);
      }
      if (_open < _maxConnections) {
        _open++;
        try {
          return await _connect();
        } catch (_) {
          _open--;
          _wakeWaiter();
          rethrow;
        }
      }
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
  }

  Future<bool> _isAlive(MySQLConnection conn) async {
    try {
      await conn.execute('SELECT 1').timeout(_checkTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<MySQLConnection> _connect() async {
    final conn = await MySQLConnection.createConnection(
      host: config.host,
      port: config.port,
      userName: config.user,
      password: config.password,
      databaseName: config.database,
      secure: true,
      collation: 'utf8mb4_general_ci',
      // The package accepts any certificate by default; verify it instead.
      onBadCertificate: (_) => false,
    ).timeout(timeout);
    await conn.connect(timeoutMs: timeout.inMilliseconds);
    // TiDB's default isolation reads a snapshot from when the transaction
    // began, even after waiting on a row lock, so a purchase that waited for
    // another would still see the old balance. READ COMMITTED gives each
    // statement the latest committed data.
    await conn
        .execute('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED')
        .timeout(timeout);
    return conn;
  }

  void _release(MySQLConnection conn, {required bool healthy}) {
    if (healthy && conn.connected) {
      _idle.add((conn: conn, since: DateTime.now()));
    } else {
      _open--;
      _discard(conn);
    }
    _wakeWaiter();
  }

  /// Closes [conn] if it is in a state that allows it. A connection stuck
  /// mid-query refuses to close; dropping it lets the database end the
  /// session when it notices the dead socket.
  void _discard(MySQLConnection conn) {
    try {
      unawaited(conn.close().catchError((_) {}));
    } catch (_) {
      // close() throws synchronously in some states.
    }
  }

  void _wakeWaiter() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }
}
