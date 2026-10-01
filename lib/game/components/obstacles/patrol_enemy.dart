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
    : super(
        size: Vector2(48, 48),
        anchor: Anchor.bottomLeft,
      );

  final double groundY;

  @override
  CrashCause get crashCause => CrashCause.enemy;

  @override
  Future<void> onLoad() async {
    position.y = groundY - size.y;
    await add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFFD32F2F),
      ),
    );
    await add(
      RectangleHitbox(
        size: size,
        collisionType: CollisionType.passive,
        isSolid: true,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.state != GameState.playing) {
      return;
    }

    final playerX = game.player.position.x;
    final deltaX = playerX - position.x;
    if (deltaX.abs() > 4) {
      position.x += deltaX.sign * GameConfig.enemyChaseSpeed * dt;
    }
  }
}
