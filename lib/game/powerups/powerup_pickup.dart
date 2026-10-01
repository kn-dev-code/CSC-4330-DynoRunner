import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../dyno_game.dart';
import 'powerup_type.dart';

/// A collectible orb that applies a [PowerUpType] when touched by the player.
class PowerUpPickup extends PositionComponent with CollisionCallbacks {
  PowerUpPickup({
    required this.type,
    required Vector2 position,
  }) : super(
         position: position,
         size: Vector2.all(36),
         anchor: Anchor.center,
       );

  PowerUpType type;
  var collected = false;

  late CircleComponent _orb;
  late TextComponent _label;

  @override
  Future<void> onLoad() async {
    await add(
      CircleHitbox(
        radius: 18,
        collisionType: CollisionType.passive,
        isSolid: false,
      ),
    );
    _orb = CircleComponent(
      radius: 18,
      paint: Paint()..color = type.color,
    );
    await add(_orb);
    _label = TextComponent(
      text: _glyph(type),
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    await add(_label);
  }

  void reconfigure({required PowerUpType type, required Vector2 position}) {
    this.type = type;
    this.position = position;
    collected = false;
    if (isLoaded) {
      _orb.paint.color = type.color;
      _label.text = _glyph(type);
    }
  }

  void collect(DynoGame game) {
    if (collected) {
      return;
    }
    collected = true;
    game.powerUpManager.apply(type);
    game.powerUpSpawner.release(pickup: this);
  }

  static String _glyph(PowerUpType type) {
    return switch (type) {
      PowerUpType.invulnerability => 'S',
      PowerUpType.superspeed => '»',
      PowerUpType.antigravity => '↑',
      PowerUpType.extraLife => '+',
    };
  }
}
