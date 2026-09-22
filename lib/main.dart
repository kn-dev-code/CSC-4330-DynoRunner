import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/dyno_game.dart';

void main() {
  runApp(const DynoRunnerApp());
}

/// Root widget of the app.
///
/// Kept separate from [main] so widget tests can pump the app without
/// calling `runApp`.
class DynoRunnerApp extends StatelessWidget {
  const DynoRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<DynoGame>.controlled(
          gameFactory: DynoGame.new,
        ),
      ),
    );
  }
}
