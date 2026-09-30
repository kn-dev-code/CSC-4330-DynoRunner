import 'package:dyno_app/game/components/cave.dart';
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
    for (final fps in [30, 60, 120]) {
      for (final artwork in [GameSprite.wallShort, GameSprite.wallTall]) {
        test('clears $artwork and lands at $fps fps', () async {
          final game = await _loadGame();
          game.mapGenerator.removeFromParent();
          final player = game.player;
          final wall = CollidableSprite(
            artwork: artwork,
            position: Vector2(
              GameConfig.playerX + 190,
              player.groundY - artwork.height,
            ),
          );
          await game.world.add(wall);
          await game.ready();
          player.jump();
          var maxHeight = 0.0;
          for (var frame = 0; frame < fps * 1.5; frame++) {
            wall.position.x -= GameConfig.scrollSpeed / fps;
            game.update(1 / fps);
            final height = player.groundY - player.position.y;
            if (height > maxHeight) maxHeight = height;
            expect(game.state, GameState.playing);
          }
          expect(maxHeight, greaterThan(GameSprite.wallTall.height + 30));
          expect(player.onGround, isTrue);
          game.onRemove();
        });
      }
    }

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
      expect(game.crashCause, CrashCause.wall);
      game.onRemove();
    });

    test('jumping into a cave ceiling ends the run', () async {
      final game = await _loadGame();
      game.mapGenerator.removeFromParent();
      final player = game.player;
      final cave = Cave(groundY: player.groundY, columns: 3)
        ..position = Vector2(GameConfig.playerX, 0);
      await game.world.add(cave);
      await game.ready();

      game.update(0);
      expect(game.state, GameState.playing);

      player.jump();
      for (
        var frame = 0;
        frame < 60 && game.state == GameState.playing;
        frame++
      ) {
        game.update(1 / 60);
      }

      expect(game.state, GameState.gameOver);
      expect(game.crashCause, CrashCause.cave);
      game.onRemove();
    });

    test('running into the front of a cave mid-jump ends the run', () async {
      final game = await _loadGame();
      game.mapGenerator.removeFromParent();
      final player = game.player;
      final cave = Cave(groundY: player.groundY, columns: 3)
        ..position = Vector2(GameConfig.playerX + 200, 0);
      await game.world.add(cave);
      await game.ready();

      player.jump();
      for (var frame = 0; frame < 20; frame++) {
        game.update(1 / 60);
      }
      // Peak of the jump: slide the cave's front face into the dinosaur.
      cave.position.x = GameConfig.playerX + 40;
      game.update(0);

      expect(game.state, GameState.gameOver);
      expect(game.crashCause, CrashCause.cave);
      game.onRemove();
    });

    test('restarting clears the crash cause', () async {
      final game = await _loadGame();
      game.endRun(cause: CrashCause.wall);
      game.startRun();

      expect(game.state, GameState.playing);
      expect(game.crashCause, isNull);
      game.onRemove();
    });
  });
}
