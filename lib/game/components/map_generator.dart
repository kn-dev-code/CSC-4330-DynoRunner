import 'dart:math';

import 'package:flame/components.dart';

import '../dyno_game.dart';
import '../game_config.dart';
import 'cave.dart';
import 'collidable_sprite.dart';

/// Spawns and scrolls obstacles from right to left across the playfield.
///
/// Each spawn is either a short or tall ground wall, or a [Cave] ceiling the
/// player runs underneath. Everything is pre-loaded into a pool during
/// [onLoad] so new pieces can be activated during [update] without
/// enqueueing lifecycle events mid-frame.
class MapGenerator extends Component with HasGameReference<DynoGame> {
  MapGenerator({
    required this.groundY,
    this.scrollSpeed = GameConfig.scrollSpeed,
    this.minSpawnInterval = GameConfig.minSpawnInterval,
    this.maxSpawnInterval = GameConfig.maxSpawnInterval,
    this.minGap = GameConfig.minObstacleGap,
    this.poolSize = 5,
    this.caveChance = GameConfig.caveChance,
    Random? random,
  }) : _random = random ?? Random();

  final double groundY;
  final double scrollSpeed;
  final double minSpawnInterval;
  final double maxSpawnInterval;
  final double minGap;
  final int poolSize;
  final double caveChance;

  final Random _random;
  final List<PositionComponent> _active = [];
  late final List<CollidableSprite> _inactive;
  late final List<Cave> _inactiveCaves;

  double _spawnTimer = 0;
  double _nextSpawnIn = 0;

  /// Ground walls currently on screen.
  Iterable<CollidableSprite> get obstacles =>
      _active.whereType<CollidableSprite>();

  /// Caves currently on screen.
  Iterable<Cave> get caves => _active.whereType<Cave>();

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
    final delta = scrollSpeed * dt;

    for (final obstacle in _active.toList()) {
      obstacle.position.x -= delta;
      if (obstacle.position.x + obstacle.size.x < 0) {
        switch (obstacle) {
          case final CollidableSprite wall:
            _recycle(wall);
          case final Cave cave:
            _recycleCave(cave);
        }
      }
    }
  }

  void _updateSpawning(double dt, double gameWidth) {
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

  void _recycle(CollidableSprite obstacle) {
    _active.remove(obstacle);
    obstacle.position = Vector2(
      -GameConfig.offscreenX,
      groundY - obstacle.artwork.height,
    );
    _inactive.add(obstacle);
  }

  void _recycleCave(Cave cave) {
    _active.remove(cave);
    cave.position.x = -GameConfig.offscreenX - cave.size.x;
    _inactiveCaves.add(cave);
  }

  void _scheduleNextSpawn({bool initial = false}) {
    _nextSpawnIn = initial
        ? minSpawnInterval
        : minSpawnInterval +
              _random.nextDouble() * (maxSpawnInterval - minSpawnInterval);
  }
}
