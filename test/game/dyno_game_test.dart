import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyno_app/game/dyno_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynoGame', () {
    test('is a FlameGame', () {
      expect(DynoGame(), isA<FlameGame>());
    });

    test('starts in the intro state', () {
      expect(DynoGame().state, GameState.intro);
    });

    test('onLoad completes without throwing', () async {
      final game = DynoGame();
      game.onGameResize(Vector2(800, 600));
      await expectLater(game.onLoad(), completes);
    });

    test('state can advance through the game lifecycle', () {
      final game = DynoGame();

      game.state = GameState.playing;
      expect(game.state, GameState.playing);

      game.state = GameState.gameOver;
      expect(game.state, GameState.gameOver);
    });

    test('can pause and resume an active run', () {
      final game = DynoGame()..state = GameState.playing;

      game.pauseRun();
      expect(game.state, GameState.paused);

      game.resumeRun();
      expect(game.state, GameState.playing);
    });

    test('each instance owns its own state', () {
      final first = DynoGame()..state = GameState.playing;
      final second = DynoGame();

      expect(first.state, GameState.playing);
      expect(second.state, GameState.intro);
    });
  });

  test('GameState declares intro, playing, paused and gameOver', () {
    expect(
      GameState.values,
      orderedEquals(<GameState>[
        GameState.intro,
        GameState.playing,
        GameState.paused,
        GameState.gameOver,
      ]),
    );
  });
}
