import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../components/cave.dart';
import '../components/collidable_sprite.dart';
import '../game_config.dart';
import 'boss_kind.dart';

/// A multi-part hazard that scrolls with the run until it leaves the screen.
class BossEncounter extends PositionComponent {
  BossEncounter({
    required this.kind,
    required this.groundY,
    required Vector2 spawnPosition,
  }) : super(position: spawnPosition, anchor: Anchor.topLeft);

  final BossKind kind;
  final double groundY;

  @override
  Future<void> onLoad() async {
    await add(
      TextComponent(
        text: kind.displayName,
        position: Vector2(0, -28),
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFFB71C1C),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    switch (kind) {
      case BossKind.stoneGolem:
        await _buildStoneGolem();
      case BossKind.twinSentinels:
        await _buildTwinSentinels();
      case BossKind.skyCrusher:
        await _buildSkyCrusher();
    }
  }

  Future<void> _buildStoneGolem() async {
    const artwork = GameSprite.wallTall;
    var x = 0.0;
    for (var column = 0; column < 5; column++) {
      if (column == 2) {
        x += artwork.width;
        continue;
      }
      await add(
        CollidableSprite(
          artwork: artwork,
          position: Vector2(x, groundY - artwork.height),
        ),
      );
      x += artwork.width;
    }
    size = Vector2(x, artwork.height);
  }

  Future<void> _buildTwinSentinels() async {
    const tall = GameSprite.wallTall;
    const short = GameSprite.wallShort;
    await add(
      CollidableSprite(
        artwork: tall,
        position: Vector2(0, groundY - tall.height),
      ),
    );
    await add(
      CollidableSprite(
        artwork: short,
        position: Vector2(tall.width + 40, groundY - short.height),
      ),
    );
    await add(
      CollidableSprite(
        artwork: tall,
        position: Vector2(tall.width + 40 + short.width + 40, groundY - tall.height),
      ),
    );
    size = Vector2(tall.width * 2 + short.width + 80, tall.height);
  }

  Future<void> _buildSkyCrusher() async {
    final cave = Cave(groundY: groundY, columns: 4)
      ..position = Vector2.zero();
    await add(cave);
    const short = GameSprite.wallShort;
    await add(
      CollidableSprite(
        artwork: short,
        position: Vector2(20, groundY - short.height),
      ),
    );
    await add(
      CollidableSprite(
        artwork: short,
        position: Vector2(cave.size.x - short.width - 20, groundY - short.height),
      ),
    );
    size = Vector2(cave.size.x, groundY);
  }

  bool get isOffScreen => position.x + size.x < 0;
}
