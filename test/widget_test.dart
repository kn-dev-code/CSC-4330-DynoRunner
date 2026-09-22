// Widget tests for the app shell that hosts the Flame game.
//
// The game itself is covered in test/game/dyno_game_test.dart; these tests
// only assert that the app boots and hands the screen to a GameWidget.

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dyno_app/game/dyno_game.dart';
import 'package:dyno_app/main.dart';

void main() {
  testWidgets('DynoRunnerApp builds without errors', (tester) async {
    await tester.pumpWidget(const DynoRunnerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('DynoRunnerApp hosts a GameWidget for DynoGame', (tester) async {
    await tester.pumpWidget(const DynoRunnerApp());

    expect(find.byType(GameWidget<DynoGame>), findsOneWidget);
  });

  testWidgets('DynoRunnerApp hides the debug banner', (tester) async {
    await tester.pumpWidget(const DynoRunnerApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
