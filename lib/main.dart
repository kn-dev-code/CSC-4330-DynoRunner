import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/dyno_game.dart';
import 'overlays/overlays.dart';

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
      routes: {
        '/': (_) => const GameScreen(),
        '/leaderboard': (_) => const LeaderboardScreen(),
      },
      initialRoute: '/',
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dyno Run'),
        actions: [
          IconButton(
            tooltip: 'Leaderboard',
            onPressed: () => Navigator.of(context).pushNamed('/leaderboard'),
            icon: const Icon(Icons.leaderboard),
          ),
        ],
      ),
      body: GameWidget<DynoGame>.controlled(
        gameFactory: DynoGame.new,
        overlayBuilderMap: {
          'hud': (context, game) => HudOverlay(game: game),
          'gameOver': (context, game) => GameOverOverlay(game: game),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}
