import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../../dyno_game.dart';
import '../player_hazard.dart';

/// Ground gap — the dinosaur falls in if it runs over the pit while grounded.
class Pitfall extends PositionComponent implements PlayerHazard {
  Pitfall({required this.groundY, required double width})
    : super(
        size: Vector2(width, 36),
        anchor: Anchor.bottomLeft,
      );

  final double groundY;

  @override
  CrashCause get crashCause => CrashCause.pitfall;

  @override
  Future<void> onLoad() async {
    await add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFF1A1A1A),
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
}
