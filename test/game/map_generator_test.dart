import 'dart:math';

import 'package:dyno_app/game/components/collidable_sprite.dart';
import 'package:dyno_app/game/components/map_generator.dart';
import 'package:dyno_app/game/dyno_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

Future<DynoGame> _loadGame({GameState state = GameState.playing}) async {
  final game = DynoGame()..state = state;
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

  group('MapGenerator', () {
    test('does not spawn obstacles while the game is not playing', () async {
      final game = await _loadGame();
      game.state = GameState.intro;

      for (var frame = 0; frame < 120; frame++) {
        game.update(1 / 60);
      }

      expect(game.mapGenerator.obstacles, isEmpty);
      game.onRemove();
    });

    test('spawns obstacles over time when playing', () async {
      final game = await _loadGame();
      final generator = game.mapGenerator;

      for (var frame = 0; frame < 120; frame++) {
        game.update(1 / 60);
      }

      expect(generator.obstacles.length, greaterThanOrEqualTo(1));
      expect(
        generator.obstacles.map((obstacle) => obstacle.artwork).toSet(),
        anyOf([
          {GameSprite.wallShort},
          {GameSprite.wallTall},
          {GameSprite.wallShort, GameSprite.wallTall},
        ]),
      );
      game.onRemove();
    });

    test('scrolls obstacles left and removes off-screen ones', () async {
      final game = await _loadGame();
      final generator = MapGenerator(
        groundY: 510,
        scrollSpeed: 300,
        minSpawnInterval: 0,
        maxSpawnInterval: 0,
        minGap: 0,
        poolSize: 1,
        random: Random(0),
      );
      await game.world.add(generator);
      await game.ready();

      game.update(0);
      expect(generator.obstacles.length, 1);

      final obstacle = generator.obstacles.first;
      final startX = obstacle.position.x;

      game.update(1);
      expect(obstacle.position.x, lessThan(startX));

      game.state = GameState.intro;
      obstacle.position.x = -obstacle.size.x - 1;
      game.update(0);
      expect(generator.obstacles, isEmpty);
      game.onRemove();
    });

    test('aligns obstacle feet to the ground line', () async {
      final game = await _loadGame();
      const groundY = 510.0;
      final generator = MapGenerator(
        groundY: groundY,
        minSpawnInterval: 0,
        maxSpawnInterval: 0,
        minGap: 0,
        poolSize: 1,
        random: Random(1),
      );
      await game.world.add(generator);
      await game.ready();

      game.update(0);

      expect(generator.obstacles, isNotEmpty);
      for (final obstacle in generator.obstacles) {
        expect(
          obstacle.position.y + obstacle.size.y,
          closeTo(groundY, 0.001),
        );
      }
      game.onRemove();
    });
  });
}
