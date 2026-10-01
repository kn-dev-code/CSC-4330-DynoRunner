import 'dart:math';

import 'package:flame/components.dart';

import '../components/collidable_sprite.dart';
import '../dyno_game.dart';
import '../game_config.dart';
import 'powerup_pickup.dart';
import 'powerup_type.dart';

/// Spawns floating power-ups ahead of the player during a run.
class PowerUpSpawner extends Component with HasGameReference<DynoGame> {
  PowerUpSpawner({required this.groundY, Random? random})
    : _random = random ?? Random();

  final double groundY;
  final Random _random;

  final List<PowerUpPickup> _inactive = [];
  final List<PowerUpPickup> _active = [];

  double _spawnTimer = 0;

  void reset() {
    for (final pickup in _active.toList()) {
      _recycle(pickup);
    }
    _spawnTimer = 0;
  }

  @override
  Future<void> onLoad() async {
    for (var index = 0; index < GameConfig.powerUpPoolSize; index++) {
      final pickup = PowerUpPickup(
        type: PowerUpType.invulnerability,
        position: Vector2(-GameConfig.offscreenX, _hoverY()),
      );
      await add(pickup);
      _inactive.add(pickup);
    }
  }

  @override
  void update(double dt) {
    if (game.state == GameState.gameOver) {
      return;
    }

    _scroll(dt);

    if (game.state != GameState.playing || game.bossEncounterActive) {
      return;
    }

    _spawnTimer += dt;
    if (_spawnTimer < GameConfig.powerUpSpawnInterval) {
      return;
    }

    _spawnTimer = 0;
    if (_random.nextDouble() > GameConfig.powerUpSpawnChance) {
      return;
    }

    _spawnPickup();
  }

  void _scroll(double dt) {
    final delta = game.currentScrollSpeed * dt;
    for (final pickup in _active.toList()) {
      pickup.position.x -= delta;
      if (pickup.position.x + pickup.size.x / 2 < 0) {
        _recycle(pickup);
      }
    }
  }

  void _spawnPickup() {
    if (_inactive.isEmpty) {
      return;
    }

    final pickup = _inactive.removeAt(_random.nextInt(_inactive.length));
    pickup.reconfigure(
      type: PowerUpType.randomPick(_random),
      position: Vector2(
        game.size.x + GameConfig.spawnMargin + 18,
        _hoverY(),
      ),
    );
    _active.add(pickup);
  }

  double _hoverY() => groundY - GameSprite.dinoJump.height - 24;

  void release({required PowerUpPickup pickup}) {
    _recycle(pickup);
  }

  void _recycle(PowerUpPickup pickup) {
    _active.remove(pickup);
    pickup.reconfigure(
      type: pickup.type,
      position: Vector2(-GameConfig.offscreenX, _hoverY()),
    );
    pickup.collected = false;
    _inactive.add(pickup);
  }
}
