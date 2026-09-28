import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

enum GameState { intro, playing, gameOver }

class DynoGame extends FlameGame {
  GameState state = GameState.intro;

  /// How fast the map scrolls left under the dinosaur, in pixels per second.
  static const double scrollSpeed = 300;

  @override
  Color backgroundColor() => const Color(0xFFF7F7F7);

  @override
  Future<void> onLoad() async {
    final groundY = size.y * 0.75;

    add(RectangleComponent(
      position: Vector2(0, groundY),
      size: Vector2(size.x, 2),
      paint: Paint()..color = const Color(0xFF535353),
    ));

    add(MapScroller(groundY: groundY));

    // The dinosaur never moves horizontally; the map scrolls under it.
    add(SpriteAnimationComponent(
      animation: SpriteAnimation.spriteList(
        [await loadSprite('dino_run_1.png'), await loadSprite('dino_run_2.png')],
        stepTime: 0.1,
      ),
      position: Vector2(50, groundY),
      anchor: Anchor.bottomLeft,
    ));

    // DaveyBoll will add Player component here
    // spvvn will hook up HUD overlays here
  }
}

/// Spawns walls off the right edge of the screen and scrolls them left.
class MapScroller extends Component with HasGameReference<DynoGame> {
  MapScroller({required this.groundY});

  final double groundY;
  final _random = Random();
  late final Sprite _shortWall;
  late final Sprite _tallWall;
  double _untilNextWall = 0;

  @override
  Future<void> onLoad() async {
    _shortWall = await game.loadSprite('wall_short.png');
    _tallWall = await game.loadSprite('wall_tall.png');
  }

  @override
  void update(double dt) {
    super.update(dt);

    _untilNextWall -= dt;
    if (_untilNextWall <= 0) {
      _untilNextWall = 1.2 + _random.nextDouble();
      add(SpriteComponent(
        sprite: _random.nextBool() ? _shortWall : _tallWall,
        position: Vector2(game.size.x, groundY),
        anchor: Anchor.bottomLeft,
      ));
    }

    for (final wall in children.query<SpriteComponent>()) {
      wall.x -= DynoGame.scrollSpeed * dt;
      if (wall.x + wall.width < 0) {
        wall.removeFromParent();
      }
    }
  }
}
