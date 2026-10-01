import 'dart:math';

import 'package:flame/components.dart';

import '../../game_config.dart';
import '../collidable_sprite.dart';

/// Short wall that bobs vertically while scrolling with the map.
class MovingWall extends PositionComponent {
  MovingWall({required this.groundY})
    : super(anchor: Anchor.bottomLeft);

  final double groundY;
  double _phase = 0;

  late final CollidableSprite _wall;

  @override
  Future<void> onLoad() async {
    _wall = CollidableSprite(
      artwork: GameSprite.wallShort,
      position: Vector2.zero(),
      anchor: Anchor.bottomLeft,
    );
    await add(_wall);
    size = _wall.size;
    position.y = groundY;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _phase += dt * GameConfig.movingWallFrequency;
    _wall.position.y = sin(_phase) * GameConfig.movingWallAmplitude;
  }
}
