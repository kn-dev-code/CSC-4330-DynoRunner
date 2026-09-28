import 'dart:math';

import 'package:flame/components.dart';

import '../dyno_game.dart';
import '../game_config.dart';
import 'collidable_sprite.dart';

/// Spawns and scrolls obstacles from right to left across the playfield.
///
/// Obstacles are pre-loaded into a pool during [onLoad] so new walls can be
/// activated during [update] without enqueueing lifecycle events mid-frame.
class MapGenerator extends Component with HasGameReference<DynoGame> {
  MapGenerator({
    required this.groundY,
    this.scrollSpeed = GameConfig.scrollSpeed,
    this.minSpawnInterval = GameConfig.minSpawnInterval,
    this.maxSpawnInterval = GameConfig.maxSpawnInterval,
    this.minGap = GameConfig.minObstacleGap,
    this.poolSize = 5,
    Random? random,
  }) : _random = random ?? Random();

  final double groundY;
  final double scrollSpeed;
  final double minSpawnInterval;
  final double maxSpawnInterval;
  final double minGap;
  final int poolSize;

  final Random _random;
  final List<CollidableSprite> _active = [];
  late final List<CollidableSprite> _inactive;

  double _spawnTimer = 0;
  double _nextSpawnIn = 0;

  Iterable<CollidableSprite> get obstacles => _active;

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
    _scheduleNextSpawn(initial: true);
  }

  @override
  void update(double dt) {
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
        _recycle(obstacle);
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

  void _scheduleNextSpawn({bool initial = false}) {
    _nextSpawnIn = initial
        ? minSpawnInterval
        : minSpawnInterval +
              _random.nextDouble() * (maxSpawnInterval - minSpawnInterval);
  }
}
