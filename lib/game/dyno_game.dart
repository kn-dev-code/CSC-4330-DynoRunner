import 'dart:async';

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

/// What the player ran into to end the run.
enum CrashCause {
  wall('You crashed into a wall.'),
  cave('You hit your head on a cave ceiling.');

  const CrashCause(this.message);

  final String message;
}

class DynoGame extends FlameGame
    with HasCollisionDetection, TapCallbacks, KeyboardEvents {
  DynoGame({
    this.startImmediately = false,
    this.onRunStarted,
    this.onRunEnded,
    this.onJump,
    this.onHit,
  });

  final bool startImmediately;
  final VoidCallback? onRunStarted;
  final VoidCallback? onRunEnded;
  final VoidCallback? onJump;
  final VoidCallback? onHit;
  GameState state = GameState.intro;

  late final Background background;
  late final MapGenerator mapGenerator;
  late final Player player;

  String playerName = 'Runner';
  double distanceMeters = 0;
  double money = 0;
  double _runSeconds = 0;

  /// Why the last run ended, or null while a run is in progress.
  CrashCause? crashCause;

  double get currentScrollSpeed =>
      (GameConfig.scrollSpeed + _runSeconds * GameConfig.speedIncreasePerSecond)
          .clamp(GameConfig.scrollSpeed, GameConfig.maxScrollSpeed);

  double get speedMultiplier => currentScrollSpeed / GameConfig.scrollSpeed;

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
    if (startImmediately) {
      startRun();
    }
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
    _runSeconds = 0;
    distanceMeters = 0;
    money = 0;
    crashCause = null;
    mapGenerator.reset();
    player.resetToGround();
    state = GameState.playing;
    hideOverlay('gameOver');
    onRunStarted?.call();
  }

  void endRun({CrashCause? cause}) {
    if (state != GameState.playing) {
      return;
    }
    state = GameState.gameOver;
    crashCause = cause;
    unawaited(_showGameOverAfterImpact());
  }

  Future<void> _showGameOverAfterImpact() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (state == GameState.gameOver) {
      showOverlay('gameOver');
      onRunEnded?.call();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (state != GameState.playing) {
      return;
    }

    distanceMeters += currentScrollSpeed * dt / GameConfig.pixelsPerMeter;
    _runSeconds += dt;
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
