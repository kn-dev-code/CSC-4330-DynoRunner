import 'dart:math';

import 'package:dyno_app/game/components/obstacles/pitfall.dart';
import 'package:dyno_app/game/components/obstacles/moving_wall.dart';
import 'package:dyno_app/game/components/obstacles/patrol_enemy.dart';

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
    test(
      'speed grows without a cap, freezes on loss and resets on restart',
      () async {
        final game = await _loadGame();
        game.mapGenerator.removeFromParent();
        await game.ready();
        expect(game.currentScrollSpeed, GameConfig.scrollSpeed);
        for (var i = 0; i < 600; i++) {
          game.update(1 / 60);
        }
        expect(game.currentScrollSpeed, closeTo(320, 0.001));
        expect(game.distanceMeters, greaterThan(28));
        game.endRun();
        final speedAtLoss = game.currentScrollSpeed;
        game.update(10);
        expect(game.currentScrollSpeed, speedAtLoss);
        game.startRun();
        expect(game.currentScrollSpeed, GameConfig.scrollSpeed);
        expect(game.distanceMeters, 0);
        for (var i = 0; i < 100; i++) {
          game.update(1);
        }
        expect(game.currentScrollSpeed, closeTo(680, 0.001));
        for (var i = 0; i < 100; i++) {
          game.update(1);
        }
        expect(game.currentScrollSpeed, closeTo(1080, 0.001));
        game.onRemove();
      },
    );

    test('scenery scrolls at the increased run speed', () async {
      final game = await _loadGame();
      game.mapGenerator.removeFromParent();
      await game.ready();
      game.update(10);
      final generator = MapGenerator(
        groundY: 510,
        minSpawnInterval: 0,
        maxSpawnInterval: 0,
        caveChance: 0,
        pitfallChance: 0,
        movingWallChance: 0,
        enemyChance: 0,
      );
      await game.world.add(generator);
      await game.ready();
      game.update(0);
      final wall = generator.obstacles.first;
      final x = wall.position.x;
      final speed = game.currentScrollSpeed;
      final distance = game.distanceMeters;
      game.update(0.1);
      expect(x - wall.position.x, closeTo(speed * 0.1, 0.001));
      expect(
        game.distanceMeters - distance,
        closeTo(speed * 0.1 / GameConfig.pixelsPerMeter, 0.001),
      );
      game.onRemove();
    });

    for (final caveChance in [0.0, 1.0]) {
      test('freezes scenery after losing (caves: $caveChance)', () async {
        final game = await _loadGame();
        final generator = MapGenerator(
          groundY: 510,
          minSpawnInterval: 0,
          maxSpawnInterval: 0,
          caveChance: caveChance,
          random: Random(0),
        );
        await game.world.add(generator);
        await game.ready();
        game.update(0);
        final scenery = <PositionComponent>[
          ...generator.obstacles,
          ...generator.caves,
        ];
        expect(scenery, hasLength(1));
        final startX = scenery.single.position.x;
        game.endRun();
        for (var frame = 0; frame < 120; frame++) {
          game.update(1 / 60);
        }
        expect(scenery.single.position.x, startX);
        expect(generator.obstacles.length + generator.caves.length, 1);
        game.startRun();
        game.update(1 / 60);
        expect(scenery.single.position.x, lessThan(startX));
        game.onRemove();
      });
    }

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

    for (final kind in ['wall', 'cave', 'pitfall', 'moving wall', 'enemy']) {
      test('spawns $kind over time when playing', () async {
        final game = await _loadGame();
        game.mapGenerator.removeFromParent();
        final generator = MapGenerator(
          groundY: game.player.groundY,
          caveChance: kind == 'cave' ? 1 : 0,
          pitfallChance: kind == 'pitfall' ? 1 : 0,
          movingWallChance: kind == 'moving wall' ? 1 : 0,
          enemyChance: kind == 'enemy' ? 1 : 0,
          random: Random(0),
        );
        await game.world.add(generator);
        await game.ready();

        // Pooled components are offscreen until they actually spawn.
        Iterable<PositionComponent> visibleObstacles() => generator.children
            .whereType<PositionComponent>()
            .where((obstacle) => obstacle.position.x > 0);
        expect(visibleObstacles(), isEmpty);
        for (var frame = 0; frame < 120; frame++) {
          game.update(1 / 60);
        }
        final obstacle = visibleObstacles().single;
        final expectedType = switch (kind) {
          'wall' => CollidableSprite,
          'cave' => Cave,
          'pitfall' => Pitfall,
          'moving wall' => MovingWall,
          'enemy' => PatrolEnemy,
          _ => throw StateError('Unknown obstacle kind'),
        };
        expect(obstacle.runtimeType, expectedType);
        expect(game.state, GameState.playing);
        game.onRemove();
      });
    }
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
