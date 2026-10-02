import 'package:flame/components.dart';

/// Shared tuning values for scrolling speed, ground placement, and spawning.
class GameConfig {
  GameConfig._();

  static const scrollSpeed = 280.0;
  static const speedIncreasePerSecond = 4.0;
  static const minSpawnInterval = 1.5;
  static const maxSpawnInterval = 3.0;
  static const minObstacleGap = 150.0;
  static const spawnMargin = 20.0;
  static const offscreenX = 200.0;

  static const playerX = 50.0;
  static const gravity = 1200.0;
  // About 204px of jump height, enough to clear the 132px tall wall.
  static const jumpVelocity = -700.0;
  static const runFrameDuration = 0.1;

  /// Scroll speed is treated as pixels per second; divide by this for meters.
  static const pixelsPerMeter = 100.0;
  static const moneyPerMeter = 0.25;

  /// Chance that a spawn is a cave instead of a ground wall.
  static const caveChance = 0.3;
  static const minCaveColumns = 3;
  static const maxCaveColumns = 6;

  static const powerUpPoolSize = 4;
  static const powerUpSpawnInterval = 7.0;
  static const powerUpSpawnChance = 0.65;

  static const invulnerabilityDuration = 5.0;
  static const superspeedDuration = 4.0;
  static const antigravityDuration = 6.0;
  static const superspeedMultiplier = 1.55;
  static const antigravityScale = 0.4;

  static const bossIntervalMeters = 250.0;
  static const bossMoneyBonus = 50.0;

  static const pitfallSpawnChance = 0.12;
  static const movingWallSpawnChance = 0.1;
  static const enemySpawnChance = 0.08;
  static const pitfallPoolSize = 3;
  static const movingWallPoolSize = 3;
  static const enemyPoolSize = 4;
  static const pitfallWidth = 96.0;
  static const movingWallAmplitude = 36.0;
  static const movingWallFrequency = 2.8;
  static const enemyChaseSpeed = 90.0;

  /// Open space between the ground and a cave ceiling. The running dinosaur
  /// is 80px tall, so this leaves headroom without needing to jump.
  static const caveClearance = 110.0;

  /// Y coordinate of the ground surface where obstacles and the player align.
  static double groundY(Vector2 gameSize) => gameSize.y * 0.85;
}
