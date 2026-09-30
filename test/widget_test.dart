// Widget tests for the app shell that hosts the Flame game.
//
// The game itself is covered in test/game/dyno_game_test.dart; these tests
// only assert that the app boots into the title screen.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyno_app/game/dyno_game.dart';
import 'package:dyno_app/main.dart';

void main() {
  testWidgets('DynoRunnerApp builds without errors', (tester) async {
    await tester.pumpWidget(const DynoRunnerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(TitleScreen), findsOneWidget);
  });

  testWidgets('title screen starts a game', (tester) async {
    await tester.pumpWidget(const DynoRunnerApp());
    await tester.tap(find.text('Start game'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GameWidget<DynoGame>), findsOneWidget);
  });

  testWidgets('DynoRunnerApp hides the debug banner', (tester) async {
    await tester.pumpWidget(const DynoRunnerApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
