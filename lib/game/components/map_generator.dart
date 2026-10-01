import 'dart:math';

import 'package:flame/components.dart';

import '../dyno_game.dart';
import '../game_config.dart';
import 'cave.dart';
import 'collidable_sprite.dart';
import 'obstacles/moving_wall.dart';
import 'obstacles/patrol_enemy.dart';
import 'obstacles/pitfall.dart';

/// Spawns and scrolls obstacles from right to left across the playfield.
class MapGenerator extends Component with HasGameReference<DynoGame> {
  MapGenerator({
    required this.groundY,
    this.scrollSpeed = GameConfig.scrollSpeed,
    this.minSpawnInterval = GameConfig.minSpawnInterval,
    this.maxSpawnInterval = GameConfig.maxSpawnInterval,
    this.minGap = GameConfig.minObstacleGap,
    this.poolSize = 5,
    this.caveChance = GameConfig.caveChance,
    this.pitfallChance = GameConfig.pitfallSpawnChance,
    this.movingWallChance = GameConfig.movingWallSpawnChance,
    this.enemyChance = GameConfig.enemySpawnChance,
    Random? random,
  }) : _random = random ?? Random();

  final double groundY;
  final double scrollSpeed;
  final double minSpawnInterval;
  final double maxSpawnInterval;
  final double minGap;
  final int poolSize;
  final double caveChance;
  final double pitfallChance;
  final double movingWallChance;
  final double enemyChance;

  final Random _random;
  final List<PositionComponent> _active = [];
  late final List<CollidableSprite> _inactive;
  late final List<Cave> _inactiveCaves;
  late final List<Pitfall> _inactivePits;
  late final List<MovingWall> _inactiveMoving;
  late final List<PatrolEnemy> _inactiveEnemies;

  double _spawnTimer = 0;
  double _nextSpawnIn = 0;

  Iterable<CollidableSprite> get obstacles =>
      _active.whereType<CollidableSprite>();

  Iterable<Cave> get caves => _active.whereType<Cave>();

  void reset() {
    for (final obstacle in _active.toList()) {
      _recycle(obstacle);
    }
    _spawnTimer = 0;
    _scheduleNextSpawn(initial: true);
  }

  @override
  Future<void> onLoad() async {
    final pool = <CollidableSprite>[];
    for (var index = 0; index < poolSize; index++) {
      for (final artwork in [GameSprite.wallShort, GameSprite.wallTall]) {
        final obstacle = CollidableSprite(
          artwork: artwork,
          position: Vector2(
            -GameConfig.offscreenX,
            groundY - artwork.height,
          ),
        );
        await add(obstacle);
        pool.add(obstacle);
      }
    }
    _inactive = pool;

    final caves = <Cave>[];
    for (
      var columns = GameConfig.minCaveColumns;
      columns <= GameConfig.maxCaveColumns;
      columns++
    ) {
      final cave = Cave(groundY: groundY, columns: columns)
        ..position = Vector2(
          -GameConfig.offscreenX - columns * GameSprite.wallTall.width,
          0,
        );
      await add(cave);
      caves.add(cave);
    }
    _inactiveCaves = caves;

    _inactivePits = [];
    for (var index = 0; index < GameConfig.pitfallPoolSize; index++) {
      final pit = Pitfall(
        groundY: groundY,
        width: GameConfig.pitfallWidth,
      )..position = Vector2(-GameConfig.offscreenX, groundY);
      await add(pit);
      _inactivePits.add(pit);
    }

    _inactiveMoving = [];
    for (var index = 0; index < GameConfig.movingWallPoolSize; index++) {
      final wall = MovingWall(groundY: groundY)
        ..position = Vector2(-GameConfig.offscreenX, groundY);
      await add(wall);
      _inactiveMoving.add(wall);
    }

    _inactiveEnemies = [];
    for (var index = 0; index < GameConfig.enemyPoolSize; index++) {
      final enemy = PatrolEnemy(groundY: groundY)
        ..position = Vector2(-GameConfig.offscreenX, groundY);
      await add(enemy);
      _inactiveEnemies.add(enemy);
    }

    _scheduleNextSpawn(initial: true);
  }

  @override
  void update(double dt) {
    if (game.state == GameState.gameOver) {
      return;
    }
    _scrollObstacles(dt);

    if (game.state != GameState.playing) {
      return;
    }

    _updateSpawning(dt, game.size.x);
  }

  void _scrollObstacles(double dt) {
    final delta = scrollSpeed * game.speedMultiplier * dt;

    for (final obstacle in _active.toList()) {
      obstacle.position.x -= delta;
      if (obstacle.position.x + obstacle.size.x < 0) {
        _recycle(obstacle);
      }
    }
  }

  void _updateSpawning(double dt, double gameWidth) {
    if (game.bossEncounterActive) {
      return;
    }

    _spawnTimer += dt;
    if (_spawnTimer < _nextSpawnIn || !_hasRoomForSpawn(gameWidth)) {
      return;
    }

    _spawnObstacle(gameWidth);
    _spawnTimer = 0;
    _scheduleNextSpawn();
  }

  bool _hasRoomForSpawn(double gameWidth) {
    if (_active.isEmpty) {
      return true;
    }

    final rightmostEdge = _active
        .map((obstacle) => obstacle.position.x + obstacle.size.x)
        .reduce(max);

    return rightmostEdge < gameWidth - minGap;
  }

  void _spawnObstacle(double gameWidth) {
    final roll = _random.nextDouble();
    var cursor = 0.0;

    cursor += pitfallChance;
    if (roll < cursor && _inactivePits.isNotEmpty) {
      _spawnPit(gameWidth);
      return;
    }

    cursor += movingWallChance;
    if (roll < cursor && _inactiveMoving.isNotEmpty) {
      _spawnMovingWall(gameWidth);
      return;
    }

    cursor += enemyChance;
    if (roll < cursor && _inactiveEnemies.isNotEmpty) {
      _spawnEnemy(gameWidth);
      return;
    }

    if (caveChance > 0 &&
        _inactiveCaves.isNotEmpty &&
        _random.nextDouble() < caveChance) {
      final cave = _inactiveCaves.removeAt(
        _random.nextInt(_inactiveCaves.length),
      );
      cave.position.x = gameWidth + GameConfig.spawnMargin;
      _active.add(cave);
      return;
    }

    final artwork = _random.nextBool()
        ? GameSprite.wallShort
        : GameSprite.wallTall;
    final obstacle = _takeFromPool(artwork);
    if (obstacle == null) {
      return;
    }

    obstacle.position = Vector2(
      gameWidth + GameConfig.spawnMargin,
      groundY - artwork.height,
    );
    _active.add(obstacle);
  }

  void _spawnPit(double gameWidth) {
    final pit = _inactivePits.removeAt(_random.nextInt(_inactivePits.length));
    pit.position = Vector2(gameWidth + GameConfig.spawnMargin, groundY);
    _active.add(pit);
  }

  void _spawnMovingWall(double gameWidth) {
    final wall = _inactiveMoving.removeAt(
      _random.nextInt(_inactiveMoving.length),
    );
    wall.position = Vector2(gameWidth + GameConfig.spawnMargin, groundY);
    _active.add(wall);
  }

  void _spawnEnemy(double gameWidth) {
    final enemy = _inactiveEnemies.removeAt(
      _random.nextInt(_inactiveEnemies.length),
    );
    enemy.position = Vector2(
      gameWidth + GameConfig.spawnMargin,
      groundY - enemy.size.y,
    );
    _active.add(enemy);
  }

  CollidableSprite? _takeFromPool(GameSprite artwork) {
    for (var index = 0; index < _inactive.length; index++) {
      final obstacle = _inactive[index];
      if (obstacle.artwork != artwork) {
        continue;
      }
      return _inactive.removeAt(index);
    }
    return null;
  }

  void _recycle(PositionComponent obstacle) {
    _active.remove(obstacle);
    switch (obstacle) {
      case final CollidableSprite wall:
        wall.position = Vector2(
          -GameConfig.offscreenX,
          groundY - wall.artwork.height,
        );
        _inactive.add(wall);
      case final Cave cave:
        cave.position.x = -GameConfig.offscreenX - cave.size.x;
        _inactiveCaves.add(cave);
      case final Pitfall pit:
        pit.position = Vector2(-GameConfig.offscreenX, groundY);
        _inactivePits.add(pit);
      case final MovingWall wall:
        wall.position = Vector2(-GameConfig.offscreenX, groundY);
        _inactiveMoving.add(wall);
      case final PatrolEnemy enemy:
        enemy.position = Vector2(-GameConfig.offscreenX, groundY - enemy.size.y);
        _inactiveEnemies.add(enemy);
      default:
        break;
    }
  }

  void _scheduleNextSpawn({bool initial = false}) {
    _nextSpawnIn = initial
        ? minSpawnInterval
        : minSpawnInterval +
              _random.nextDouble() * (maxSpawnInterval - minSpawnInterval);
  }
}
