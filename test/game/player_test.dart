import 'package:dyno_app/game/components/collidable_sprite.dart';
import 'package:dyno_app/game/components/player.dart';
import 'package:dyno_app/game/dyno_game.dart';
import 'package:dyno_app/game/game_config.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DynoGame> _loadGame() async {
  final game = DynoGame()..state = GameState.playing;
  game.onGameResize(Vector2(800, 600));
  // ignore: invalid_use_of_internal_member
  await game.load();
  // ignore: invalid_use_of_internal_member
  game.mount();
  await game.ready();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Player', () {
    test('jump leaves the ground and returns on landing', () async {
      final game = await _loadGame();
      final player = game.player;
      final groundY = player.groundY;

      expect(player.onGround, isTrue);
      expect(player.position.y, groundY);

      player.jump();
      expect(player.onGround, isFalse);

      for (var frame = 0; frame < 120; frame++) {
        game.update(1 / 60);
      }

      expect(player.onGround, isTrue);
      expect(player.position.y, closeTo(groundY, 0.01));
      game.onRemove();
    });

    test('does not jump while already in the air', () async {
      final game = await _loadGame();
      final player = game.player;

      player.jump();
      final peakY = player.position.y;
      player.jump();
      game.update(1 / 120);

      expect(player.position.y, lessThanOrEqualTo(peakY));
      game.onRemove();
    });

    test('collision with a wall ends the run', () async {
      final game = await _loadGame();
      final groundY = game.player.groundY;
      final wall = CollidableSprite(
        artwork: GameSprite.wallShort,
        position: Vector2(
          GameConfig.playerX + 10,
          groundY - GameSprite.wallShort.height,
        ),
      );
      await game.world.add(wall);
      await game.ready();

      game.update(0);

      expect(game.state, GameState.gameOver);
      game.onRemove();
    });
  });
}
