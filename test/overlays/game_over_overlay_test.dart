import 'package:dyno_app/game/dyno_game.dart';
import 'package:dyno_app/overlays/game_over_overlay.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpOverlay(WidgetTester tester, DynoGame game) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: GameOverOverlay(game: game))),
  );
}

void main() {
  for (final cause in CrashCause.values) {
    testWidgets('shows why the run ended: $cause', (tester) async {
      final game = DynoGame()..crashCause = cause;

      await _pumpOverlay(tester, game);

      expect(find.text('Game Over'), findsOneWidget);
      expect(find.text(cause.message), findsOneWidget);
    });
  }

  testWidgets('shows the score and money earned this run', (tester) async {
    final game = DynoGame()
      ..distanceMeters = 42.37
      ..money = 10.59;

    await _pumpOverlay(tester, game);

    expect(find.text('Distance: 42.4 m'), findsOneWidget);
    expect(find.text('Money: \$10.59'), findsOneWidget);
  });

  testWidgets('replay button restarts the run', (tester) async {
    final game = DynoGame();
    await tester.runAsync(() async {
      game.onGameResize(Vector2(800, 600));
      // ignore: invalid_use_of_internal_member
      await game.load();
      // ignore: invalid_use_of_internal_member
      game.mount();
      await game.ready();
    });
    game.startRun();
    game.update(1);
    game.endRun(cause: CrashCause.wall);
    expect(game.distanceMeters, greaterThan(0));

    await _pumpOverlay(tester, game);
    // Let the post-impact delay elapse, as it would before the overlay shows.
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Replay'));
    await tester.pump();

    expect(game.state, GameState.playing);
    expect(game.distanceMeters, 0);
    expect(game.money, 0);
    expect(game.crashCause, isNull);
    game.onRemove();
  });
}
