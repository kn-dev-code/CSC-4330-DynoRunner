import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../dyno_game.dart';
import '../../game_config.dart';
import '../player_hazard.dart';

/// Hostile that drifts toward the player while the world scrolls.
class PatrolEnemy extends PositionComponent
    with HasGameReference<DynoGame>, CollisionCallbacks
    implements PlayerHazard {
  PatrolEnemy({required this.groundY})
    : super(size: Vector2(48, 48), anchor: Anchor.bottomLeft);

  final double groundY;
  bool _isActive = false;
  late final RectangleHitbox _hitbox;

  void spawnAt(double x) {
    position.setValues(x, groundY);
    _isActive = true;
    _hitbox.collisionType = CollisionType.passive;
  }

  void deactivate() {
    _isActive = false;
    _hitbox.collisionType = CollisionType.inactive;
    position.setValues(-GameConfig.offscreenX, groundY);
  }

  @override
  CrashCause get crashCause => CrashCause.enemy;

  @override
  Future<void> onLoad() async {
    position.y = groundY;
    await add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFFD32F2F),
      ),
    );
    _hitbox = RectangleHitbox(
      size: size,
      collisionType: CollisionType.inactive,
      isSolid: true,
    );
    await add(_hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isActive || game.state != GameState.playing) {
      return;
    }

    final playerX = game.player.position.x;
    final deltaX = playerX - position.x;
    if (deltaX.abs() > 4) {
      position.x += deltaX.sign * GameConfig.enemyChaseSpeed * dt;
    }
  }
}
