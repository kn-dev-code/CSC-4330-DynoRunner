import 'package:flame/components.dart';

/// Shared tuning values for scrolling speed, ground placement, and spawning.
class GameConfig {
  GameConfig._();

  static const scrollSpeed = 200.0;
  static const minSpawnInterval = 1.5;
  static const maxSpawnInterval = 3.0;
  static const minObstacleGap = 150.0;
  static const spawnMargin = 20.0;
  static const offscreenX = 200.0;

  /// Y coordinate of the ground surface where obstacles and the player align.
  static double groundY(Vector2 gameSize) => gameSize.y * 0.85;
}
