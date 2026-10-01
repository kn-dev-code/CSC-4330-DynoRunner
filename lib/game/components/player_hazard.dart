import '../dyno_game.dart';

/// Obstacle types that end the run on contact (handled outside [GameSprite] walls).
abstract interface class PlayerHazard {
  CrashCause get crashCause;
}
