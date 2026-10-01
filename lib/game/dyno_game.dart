import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/player_wallet.dart';
import '../services/upgrade_catalog.dart';
import 'components/background.dart';
import 'components/map_generator.dart';
import 'components/player.dart';
import 'bosses/boss_director.dart';
import 'game_config.dart';
import 'powerups/powerup_manager.dart';
import 'powerups/powerup_spawner.dart';
import 'powerups/powerup_type.dart';

enum GameState { intro, playing, paused, gameOver }

/// What the player ran into to end the run.
enum CrashCause {
  wall('You crashed into a wall.'),
  cave('You hit your head on a cave ceiling.'),
  pitfall('You fell into a pit.'),
  enemy('An enemy caught you.');

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
    this.runModifiers = RunUpgradeModifiers.none,
    PlayerWallet? wallet,
  }) : wallet = wallet ?? PlayerWallet.instance;

  final bool startImmediately;
  final VoidCallback? onRunStarted;
  final VoidCallback? onRunEnded;
  final VoidCallback? onJump;
  final VoidCallback? onHit;
  final RunUpgradeModifiers runModifiers;
  final PlayerWallet wallet;
  GameState state = GameState.intro;

  late final Background background;
  late final MapGenerator mapGenerator;
  late final Player player;
  late final PowerUpManager powerUpManager;
  late final PowerUpSpawner powerUpSpawner;
  late final BossDirector bossDirector;

  String playerName = 'Runner';
  double distanceMeters = 0;
  double money = 0;
  double _runSeconds = 0;

  /// Why the last run ended, or null while a run is in progress.
  CrashCause? crashCause;

  double get currentScrollSpeed {
    final ramp =
        (GameConfig.scrollSpeed + _runSeconds * GameConfig.speedIncreasePerSecond)
            .clamp(GameConfig.scrollSpeed, GameConfig.maxScrollSpeed);
    return ramp * powerUpManager.scrollSpeedMultiplier;
  }

  bool get bossEncounterActive => bossDirector.isEngaged;

  double get speedMultiplier => currentScrollSpeed / GameConfig.scrollSpeed;

  /// Bumps when gameplay stats change so Flutter overlays can rebuild.
  final refreshNotifier = ValueNotifier<int>(0);

  late final double _groundY;
  int _pitfallsIgnoredRemaining = 0;

  bool consumePitfallSkip() {
    if (_pitfallsIgnoredRemaining <= 0) {
      return false;
    }
    _pitfallsIgnoredRemaining--;
    refreshNotifier.value++;
    return true;
  }

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
    powerUpManager = PowerUpManager();
    powerUpSpawner = PowerUpSpawner(groundY: _groundY);
    bossDirector = BossDirector(groundY: _groundY);

    await world.addAll([
      background,
      mapGenerator,
      player,
      powerUpManager,
      powerUpSpawner,
      bossDirector,
    ]);
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
    powerUpManager.reset();
    powerUpSpawner.reset();
    bossDirector.reset();
    _pitfallsIgnoredRemaining = runModifiers.pitfallsIgnoredPerRun;
    if (runModifiers.startInvulnSeconds > 0) {
      powerUpManager.grantTimed(
        PowerUpType.invulnerability,
        runModifiers.startInvulnSeconds,
      );
    }
    player.resetToGround();
    state = GameState.playing;
    hideOverlay('gameOver');
    hideOverlay('pause');
    refreshNotifier.value++;
    onRunStarted?.call();
  }

  void endRun({CrashCause? cause}) {
    if (state != GameState.playing) {
      return;
    }
    state = GameState.gameOver;
    crashCause = cause;
    wallet.add(money);
    unawaited(_showGameOverAfterImpact());
  }

  void pauseRun() {
    if (state != GameState.playing) return;
    state = GameState.paused;
    showOverlay('pause');
    refreshNotifier.value++;
  }

  void resumeRun() {
    if (state != GameState.paused) return;
    state = GameState.playing;
    hideOverlay('pause');
    refreshNotifier.value++;
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
    if (state == GameState.paused) {
      return;
    }
    super.update(dt);

    if (state != GameState.playing) {
      return;
    }

    distanceMeters += currentScrollSpeed * dt / GameConfig.pixelsPerMeter;
    _runSeconds += dt;
    money =
        distanceMeters *
        GameConfig.moneyPerMeter *
        runModifiers.moneyMultiplier;
    refreshNotifier.value++;
  }

  @override
  void onTapUp(TapUpEvent event) {
    switch (state) {
      case GameState.intro:
        startRun();
      case GameState.playing:
        player.jump();
      case GameState.paused:
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
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.arrowUp;

    if (jumpPressed) {
      if (state == GameState.intro) {
        startRun();
      } else if (state == GameState.playing) {
        player.jump();
      }
      return KeyEventResult.handled;
    }

    final pausePressed =
        event.logicalKey == LogicalKeyboardKey.keyP ||
        event.logicalKey == LogicalKeyboardKey.escape;
    if (pausePressed) {
      if (state == GameState.playing) {
        pauseRun();
      } else if (state == GameState.paused) {
        resumeRun();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }
}
