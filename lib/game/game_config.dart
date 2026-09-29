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

  static const playerX = 50.0;
  static const gravity = 1200.0;
  static const jumpVelocity = -450.0;
  static const runFrameDuration = 0.1;

  /// Scroll speed is treated as pixels per second; divide by this for meters.
  static const pixelsPerMeter = 100.0;
  static const moneyPerMeter = 0.25;

  /// Chance that a spawn is a cave instead of a ground wall.
  static const caveChance = 0.3;
  static const minCaveColumns = 3;
  static const maxCaveColumns = 6;

  /// Open space between the ground and a cave ceiling. The running dinosaur
  /// is 80px tall, so this leaves headroom without needing to jump.
  static const caveClearance = 110.0;

  /// Y coordinate of the ground surface where obstacles and the player align.
  static double groundY(Vector2 gameSize) => gameSize.y * 0.85;
}
