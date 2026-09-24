import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyno_app/game/dyno_game.dart';

void main() {
  group('DynoGame', () {
    test('is a FlameGame', () {
      expect(DynoGame(), isA<FlameGame>());
    });

    test('starts in the intro state', () {
      expect(DynoGame().state, GameState.intro);
    });

    test('onLoad completes without throwing', () async {
      await expectLater(DynoGame().onLoad(), completes);
    });

    test('state can advance through the game lifecycle', () {
      final game = DynoGame();

      game.state = GameState.playing;
      expect(game.state, GameState.playing);

      game.state = GameState.gameOver;
      expect(game.state, GameState.gameOver);
    });

    test('each instance owns its own state', () {
      final first = DynoGame()..state = GameState.playing;
      final second = DynoGame();

      expect(first.state, GameState.playing);
      expect(second.state, GameState.intro);
    });
  });

  test('GameState declares intro, playing and gameOver', () {
    expect(
      GameState.values,
      orderedEquals(<GameState>[
        GameState.intro,
        GameState.playing,
        GameState.gameOver,
      ]),
    );
  });
}
