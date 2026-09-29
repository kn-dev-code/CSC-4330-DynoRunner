import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'components/background.dart';
import 'components/map_generator.dart';
import 'components/player.dart';
import 'game_config.dart';

enum GameState { intro, playing, gameOver }

class DynoGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  GameState state = GameState.intro;

  late final Background background;
  late final MapGenerator mapGenerator;
  late final Player player;

  String playerName = 'Runner';
  double distanceMeters = 0;
  double money = 0;

  /// Bumps when gameplay stats change so Flutter overlays can rebuild.
  final refreshNotifier = ValueNotifier<int>(0);

  late final double _groundY;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (!hasLayout) {
      return;
    }

    await _buildWorld();
  }

  Future<void> _buildWorld() async {
    camera.viewfinder.anchor = Anchor.topLeft;

    _groundY = GameConfig.groundY(size);

    background = Background(groundY: _groundY);
    mapGenerator = MapGenerator(groundY: _groundY);
    player = Player(
      groundY: _groundY,
      position: Vector2(GameConfig.playerX, _groundY),
    );

    await world.addAll([background, mapGenerator, player]);
  }

  void showOverlay(String name) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.add(name);
    }
  }

  void hideOverlay(String name) {
    if (overlays.registeredOverlays.contains(name)) {
      overlays.remove(name);
    }
  }

  void startRun() {
    distanceMeters = 0;
    money = 0;
    player.resetToGround();
    state = GameState.playing;
    hideOverlay('gameOver');
  }

  void endRun() {
    if (state != GameState.playing) {
      return;
    }
    state = GameState.gameOver;
    showOverlay('gameOver');
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) {
      return;
    }

    distanceMeters += GameConfig.scrollSpeed * dt / GameConfig.pixelsPerMeter;
    money = distanceMeters * GameConfig.moneyPerMeter;
    refreshNotifier.value++;
  }

  @override
  void onTapUp(TapUpEvent event) {
    switch (state) {
      case GameState.intro:
        startRun();
      case GameState.playing:
        player.jump();
      case GameState.gameOver:
        break;
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final jumpPressed =
        keysPressed.contains(LogicalKeyboardKey.space) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp);

    if (jumpPressed) {
      if (state == GameState.intro) {
        startRun();
      } else if (state == GameState.playing) {
        player.jump();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
