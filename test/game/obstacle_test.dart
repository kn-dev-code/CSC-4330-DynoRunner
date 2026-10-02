import 'package:dyno_app/game/components/obstacles/pitfall.dart';
import 'package:dyno_app/game/components/obstacles/patrol_enemy.dart';
import 'package:dyno_app/game/components/map_generator.dart';
import 'package:dyno_app/game/game_config.dart';
import 'package:flame/collisions.dart';
import 'package:dyno_app/game/dyno_game.dart';
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

  test('pooled enemies stay inactive until spawned and after reset', () async {
    final game = await _loadGame();
    game.mapGenerator.removeFromParent();
    final generator = MapGenerator(
      groundY: game.player.groundY,
      minSpawnInterval: 5,
      maxSpawnInterval: 5,
      pitfallChance: 0,
      movingWallChance: 0,
      enemyChance: 1,
      caveChance: 0,
    );
    await game.world.add(generator);
    await game.ready();
    final enemies = generator.children.whereType<PatrolEnemy>().toList();
    for (var i = 0; i < 240; i++) {
      game.update(1 / 60);
    }
    expect(game.state, GameState.playing);
    for (final enemy in enemies) {
      expect(enemy.position.x, -GameConfig.offscreenX);
      expect(
        enemy.children.whereType<RectangleHitbox>().single.collisionType,
        CollisionType.inactive,
      );
    }
    for (var i = 0; i < 66; i++) {
      game.update(1 / 60);
    }
    final spawned = enemies.singleWhere((enemy) => enemy.position.x > 0);
    expect(spawned.position.x, greaterThan(game.player.position.x + 300));
    expect(spawned.position.y, game.player.groundY);
    expect(
      spawned.children.whereType<RectangleHitbox>().single.collisionType,
      CollisionType.passive,
    );
    generator.reset();
    for (var i = 0; i < 240; i++) {
      game.update(1 / 60);
    }
    expect(game.state, GameState.playing);
    for (final enemy in enemies) {
      expect(enemy.position.x, -GameConfig.offscreenX);
    }
    game.onRemove();
  });

  test('pitfall ends the run when the player is on the ground', () async {
    final game = await _loadGame();
    game.mapGenerator.removeFromParent();
    final groundY = game.player.groundY;
    final pit = Pitfall(groundY: groundY, width: 96)
      ..position = Vector2(40, groundY);
    await game.world.add(pit);
    await game.ready();

    game.update(0);

    expect(game.state, GameState.gameOver);
    expect(game.crashCause, CrashCause.pitfall);
    game.onRemove();
  });
}
