import 'package:flame/components.dart';

import '../dyno_game.dart';
import '../game_config.dart';
import 'powerup_type.dart';

/// Tracks active power-up timers and spare lives for the current run.
class PowerUpManager extends Component with HasGameReference<DynoGame> {
  int extraLives = 0;
  final Map<PowerUpType, double> _remainingSeconds = {};

  bool get isInvulnerable =>
      _remainingSeconds.containsKey(PowerUpType.invulnerability);

  double get scrollSpeedMultiplier =>
      _remainingSeconds.containsKey(PowerUpType.superspeed)
      ? GameConfig.superspeedMultiplier
      : 1;

  double get gravityScale =>
      _remainingSeconds.containsKey(PowerUpType.antigravity)
      ? GameConfig.antigravityScale
      : 1;

  Iterable<MapEntry<PowerUpType, double>> get activeTimedEffects =>
      _remainingSeconds.entries;

  void reset() {
    extraLives = 0;
    _remainingSeconds.clear();
  }

  void apply(PowerUpType type) {
    switch (type) {
      case PowerUpType.extraLife:
        extraLives++;
      default:
        final duration = type.durationSeconds;
        if (duration != null) {
          _remainingSeconds[type] = duration;
        }
    }
    game.refreshNotifier.value++;
  }

  /// Returns true if a fatal hit was absorbed (shield or extra life).
  bool tryAbsorbHit() {
    if (isInvulnerable) {
      return true;
    }
    if (extraLives > 0) {
      extraLives--;
      game.refreshNotifier.value++;
      return true;
    }
    return false;
  }

  double remainingSeconds(PowerUpType type) => _remainingSeconds[type] ?? 0;

  @override
  void update(double dt) {
    if (game.state != GameState.playing || _remainingSeconds.isEmpty) {
      return;
    }

    final expired = <PowerUpType>[];
    for (final entry in _remainingSeconds.entries) {
      final next = entry.value - dt;
      if (next <= 0) {
        expired.add(entry.key);
      } else {
        _remainingSeconds[entry.key] = next;
      }
    }

    if (expired.isEmpty) {
      return;
    }

    for (final type in expired) {
      _remainingSeconds.remove(type);
    }
    game.refreshNotifier.value++;
  }
}
