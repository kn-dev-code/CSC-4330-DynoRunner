import 'package:dyno_app/game/components/collidable_sprite.dart';
import 'package:dyno_app/game/dyno_game.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final pose in GameSprite.values.where((sprite) => sprite.isPlayer)) {
    for (final wall in [GameSprite.wallShort, GameSprite.wallTall]) {
      test(
        '$pose detects $wall, ignores padding, and scales with artwork',
        () async {
          final game = DynoGame();
          game.onGameResize(Vector2(800, 600));
          // Headless test: perform the lifecycle normally driven by GameWidget.
          // ignore: invalid_use_of_internal_member
          await game.load();
          // ignore: invalid_use_of_internal_member
          game.mount();
          final player = CollidableSprite(artwork: pose);
          final obstacle = CollidableSprite(
            artwork: wall,
            position: Vector2(82, 0),
          );
          await game.addAll([player, obstacle]);
          await game.ready();
          game.update(0);
          for (final component in [player, obstacle]) {
            for (final hitbox
                in component.children.whereType<RectangleHitbox>()) {
              expect(hitbox.debugMode, isFalse);
              expect(hitbox.renderShape, isFalse);
            }
          }
          // The image is 88px wide, but the right edge contains empty pixels.
          expect(player.activeCollisions, isEmpty);

          obstacle.position.x = 48;
          game.update(0);
          expect(player.activeCollisions, contains(obstacle));

          obstacle.position.x = 200;
          game.update(0);
          expect(player.activeCollisions, isEmpty);

          player.scale = Vector2.all(2);
          obstacle.position.x = 120;
          game.update(0);
          expect(player.activeCollisions, contains(obstacle));
          game.onRemove();
        },
      );
    }
  }
}
