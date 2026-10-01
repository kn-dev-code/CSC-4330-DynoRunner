import 'package:dyno_app/game/components/obstacles/pitfall.dart';
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
