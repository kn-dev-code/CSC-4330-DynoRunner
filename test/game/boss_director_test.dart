import 'dart:math';

import 'package:dyno_app/game/bosses/boss_director.dart';
import 'package:dyno_app/game/bosses/boss_encounter.dart';
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

  test('spawns a boss when distance crosses the interval', () async {
    final game = await _loadGame();
    game.mapGenerator.removeFromParent();
    game.powerUpSpawner.removeFromParent();

    game.distanceMeters = GameConfig.bossIntervalMeters;
    game.update(0);

    expect(game.bossEncounterActive, isTrue);
    game.onRemove();
  });

  test('awards bonus money when a boss leaves the screen', () async {
    final game = await _loadGame();
    game.mapGenerator.removeFromParent();
    game.powerUpSpawner.removeFromParent();
    game.bossDirector.removeFromParent();

    final director = BossDirector(groundY: 510, random: Random(0));
    await game.world.add(director);
    await game.ready();

    game.distanceMeters = GameConfig.bossIntervalMeters;
    director.update(0);
    await game.ready();
    expect(director.isEngaged, isTrue);

    game.update(0);
    final startMoney = game.money;
    final boss = game.world.children.whereType<BossEncounter>().first;
    boss.position.x = -boss.size.x - 1;
    director.update(0);

    expect(director.isEngaged, isFalse);
    expect(game.money, startMoney + GameConfig.bossMoneyBonus);

    // The bonus must survive later frames that recompute distance money.
    game.update(0.1);
    expect(
      game.money,
      greaterThanOrEqualTo(startMoney + GameConfig.bossMoneyBonus),
    );
    game.onRemove();
  });
}
