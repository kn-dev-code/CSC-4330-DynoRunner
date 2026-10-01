import 'dart:math';

import 'package:flutter/material.dart';

import '../game_config.dart';

/// Temporary and permanent boosts the player can pick up during a run.
enum PowerUpType {
  invulnerability(
    'Invulnerable',
    Color(0xFF42A5F5),
    GameConfig.invulnerabilityDuration,
  ),
  superspeed('Super Speed', Color(0xFFFF9800), GameConfig.superspeedDuration),
  antigravity('Anti-Gravity', Color(0xFFAB47BC), GameConfig.antigravityDuration),
  extraLife('Extra Life', Color(0xFFE53935), null);

  const PowerUpType(this.label, this.color, this.durationSeconds);

  final String label;
  final Color color;

  /// `null` means the effect does not expire (extra life bank).
  final double? durationSeconds;

  static PowerUpType randomPick(Random random) {
    return values[random.nextInt(values.length)];
  }
}
