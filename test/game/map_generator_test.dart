import 'dart:math';

import 'package:dyno_app/game/components/cave.dart';
import 'package:dyno_app/game/components/collidable_sprite.dart';
import 'package:dyno_app/game/components/map_generator.dart';
import 'package:dyno_app/game/dyno_game.dart';
import 'package:dyno_app/game/game_config.dart';
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
      expect(game.mapGenerator.caves, isEmpty);
      game.onRemove();
    });

    test('spawns obstacles over time when playing', () async {
      final game = await _loadGame();
      final generator = game.mapGenerator;

      for (var frame = 0; frame < 120; frame++) {
        game.update(1 / 60);
      }

      expect(
        generator.obstacles.length + generator.caves.length,
        greaterThanOrEqualTo(1),
      );
      expect(
        generator.obstacles.map((obstacle) => obstacle.artwork).toSet(),
        anyOf([
          <GameSprite>{},
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
        caveChance: 0,
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
        caveChance: 0,
        random: Random(1),
      );
      await game.world.add(generator);
      await game.ready();

      game.update(0);

      expect(generator.obstacles, isNotEmpty);
      for (final obstacle in generator.obstacles) {
        expect(obstacle.position.y + obstacle.size.y, closeTo(groundY, 0.001));
      }
      game.onRemove();
    });

    test('spawns caves that scroll and recycle like walls', () async {
      final game = await _loadGame();
      final generator = MapGenerator(
        groundY: 510,
        scrollSpeed: 300,
        minSpawnInterval: 0,
        maxSpawnInterval: 0,
        minGap: 0,
        caveChance: 1,
        random: Random(0),
      );
      await game.world.add(generator);
      await game.ready();

      game.update(0);
      expect(generator.obstacles, isEmpty);
      expect(generator.caves.length, 1);

      final cave = generator.caves.first;
      final startX = cave.position.x;
      game.state = GameState.intro;
      game.update(1);
      expect(cave.position.x, lessThan(startX));

      cave.position.x = -cave.size.x - 1;
      game.update(0);
      expect(generator.caves, isEmpty);
      game.onRemove();
    });
  });

  group('Cave', () {
    test('leaves room for the running dinosaur without jumping', () async {
      final game = await _loadGame(state: GameState.intro);
      const groundY = 510.0;
      final cave = Cave(groundY: groundY, columns: 4);
      await game.world.add(cave);
      await game.ready();

      final blocks = cave.children.whereType<CollidableSprite>().toList();
      expect(blocks, isNotEmpty);
      expect(cave.size.x, 4 * GameSprite.wallTall.width);

      final ceilingBottom = blocks
          .map((block) => block.position.y + block.size.y)
          .reduce(max);
      final ceilingTop = blocks.map((block) => block.position.y).reduce(min);

      expect(ceilingBottom, closeTo(groundY - GameConfig.caveClearance, 0.001));
      expect(groundY - ceilingBottom, greaterThan(GameSprite.dinoRun1.height));
      // The ceiling reaches the top of the screen so it reads as a cave.
      expect(ceilingTop, lessThanOrEqualTo(0));
      game.onRemove();
    });

    test('does not collide with a dinosaur running underneath', () async {
      final game = await _loadGame(state: GameState.intro);
      final groundY = GameConfig.groundY(game.size);
      final cave = Cave(groundY: groundY, columns: 3)
        ..position = Vector2(200, 0);
      await game.world.addAll([
        CollidableSprite(
          artwork: GameSprite.dinoRun1,
          position: Vector2(240, groundY),
          anchor: Anchor.bottomLeft,
        ),
        cave,
      ]);
      await game.ready();

      game.update(0);
      final runner = game.world.children.whereType<CollidableSprite>().last;
      expect(runner.activeCollisions, isEmpty);
      game.onRemove();
    });
  });
}
