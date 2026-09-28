import 'package:flame/components.dart';

import '../game_config.dart';
import 'collidable_sprite.dart';

/// Overhead ceiling of stacked tall walls that the player runs underneath.
///
/// The ceiling hangs from the top of the screen and stops
/// [GameConfig.caveClearance] above the ground, so a running dinosaur passes
/// through without jumping. Each block keeps its hitbox so anything that
/// rises into the ceiling still collides with it.
class Cave extends PositionComponent {
  Cave({required this.groundY, required this.columns})
    : super(
        size: Vector2(
          columns * GameSprite.wallTall.width,
          groundY - GameConfig.caveClearance,
        ),
      );

  final double groundY;
  final int columns;

  /// Y coordinate of the ceiling's underside.
  double get ceilingY => groundY - GameConfig.caveClearance;

  @override
  Future<void> onLoad() async {
    const artwork = GameSprite.wallTall;
    final rows = (ceilingY / artwork.height).ceil();

    for (var column = 0; column < columns; column++) {
      for (var row = 1; row <= rows; row++) {
        await add(
          CollidableSprite(
            artwork: artwork,
            position: Vector2(
              column * artwork.width,
              ceilingY - row * artwork.height,
            ),
          ),
        );
      }
    }
  }
}
