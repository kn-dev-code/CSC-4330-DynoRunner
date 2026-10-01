import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../dyno_game.dart';
import '../powerups/powerup_pickup.dart';
import '../game_config.dart';
import 'cave.dart';
import 'collidable_sprite.dart';

/// The controllable dinosaur: run animation on the ground, jump arc, wall hits.
class Player extends CollidableSprite with HasGameReference<DynoGame> {
  Player({
    required this.groundY,
    required Vector2 position,
  }) : super(
         artwork: GameSprite.dinoRun1,
         position: position,
         anchor: Anchor.bottomLeft,
       );

  final double groundY;

  double _velocityY = 0;
  bool onGround = true;
  double _runFrameTimer = 0;
  bool _runFrameToggle = false;
  GameSprite? _displayPose;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _setPose(GameSprite.dinoRun1);
  }

  void jump() {
    if (game.state != GameState.playing || !onGround) {
      return;
    }

    _velocityY = GameConfig.jumpVelocity;
    onGround = false;
    game.onJump?.call();
    unawaited(_setPose(GameSprite.dinoJump));
  }

  void resetToGround() {
    position.y = groundY;
    _velocityY = 0;
    onGround = true;
    _runFrameTimer = 0;
    unawaited(_setPose(GameSprite.dinoRun1));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (game.state != GameState.playing) {
      return;
    }

    if (!onGround) {
      _velocityY += GameConfig.gravity * game.powerUpManager.gravityScale * dt;
      position.y += _velocityY * dt;
      if (position.y >= groundY) {
        position.y = groundY;
        _velocityY = 0;
        onGround = true;
        unawaited(_setPose(GameSprite.dinoRun1));
      }
      return;
    }

    _runFrameTimer += dt;
    if (_runFrameTimer >= GameConfig.runFrameDuration) {
      _runFrameTimer = 0;
      _runFrameToggle = !_runFrameToggle;
      unawaited(
        _setPose(_runFrameToggle ? GameSprite.dinoRun2 : GameSprite.dinoRun1),
      );
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PowerUpPickup) {
      other.collect(game);
      return;
    }
    if (other is CollidableSprite && !other.artwork.isPlayer) {
      if (game.state != GameState.playing) {
        return;
      }
      if (game.powerUpManager.tryAbsorbHit()) {
        return;
      }
      game.onHit?.call();
      game.endRun(
        cause: other.parent is Cave ? CrashCause.cave : CrashCause.wall,
      );
    }
  }

  Future<void> _setPose(GameSprite pose) async {
    if (_displayPose == pose && sprite != null) {
      return;
    }
    _displayPose = pose;
    sprite = await Sprite.load(pose.asset);
    size = Vector2(pose.width, pose.height);
  }
}
