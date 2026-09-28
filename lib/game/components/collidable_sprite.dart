import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

/// The existing artwork, in its original pixel dimensions.
enum GameSprite {
  dinoJump('dino_jump.png', 88, 80),
  dinoRun1('dino_run_1.png', 88, 80),
  dinoRun2('dino_run_2.png', 88, 80),
  wallShort('wall_short.png', 56, 68),
  wallTall('wall_tall.png', 56, 132);

  const GameSprite(this.asset, this.width, this.height);

  final String asset;
  final double width;
  final double height;

  bool get isPlayer => this == dinoJump || this == dinoRun1 || this == dinoRun2;
}

/// Sprite with collision bounds that exclude transparent padding.
///
/// Add to a game with HasCollisionDetection. Use [scale] to resize both
/// the artwork and hitboxes together, and showHitboxes to see the bounds.
/// CollisionCallbacks lets callers inspect activeCollisions or override
/// onCollisionStart without coupling these assets to game-over behavior.
class CollidableSprite extends SpriteComponent with CollisionCallbacks {
  CollidableSprite({
    required this.artwork,
    super.position,
    super.scale,
    super.anchor,
    this.showHitboxes = false,
  }) : super(size: Vector2(artwork.width, artwork.height));

  final GameSprite artwork;
  final bool showHitboxes;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(artwork.asset);

    if (artwork.isPlayer) {
      // Stable bounds across running/jumping poses: head and torso only.
      // Tail and moving feet are excluded to make near misses forgiving.
      await addAll([
        _box(44, 4, 32, 28, CollisionType.active),
        _box(20, 32, 32, 36, CollisionType.active),
      ]);
    } else {
      // Slight inset from the stone border. Passive walls collide with the
      // active player, but do not spend time checking other walls.
      await add(
        _box(
          2,
          2,
          artwork.width - 4,
          artwork.height - 4,
          CollisionType.passive,
        ),
      );
    }
  }

  RectangleHitbox _box(
    double x,
    double y,
    double width,
    double height,
    CollisionType type,
  ) => RectangleHitbox(
    position: Vector2(x, y),
    size: Vector2(width, height),
    collisionType: type,
    isSolid: true,
  )..debugMode = showHitboxes;
}
