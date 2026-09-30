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
        '/': (_) => const TitleScreen(),
        '/game': (_) => const GameScreen(),
        '/leaderboard': (_) => const LeaderboardScreen(),
      },
      initialRoute: '/',
    );
  }
}

class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF132238), Color(0xFF31516F)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.directions_run, size: 72, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'DYNO RUN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/game'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start game'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/leaderboard'),
                    icon: const Icon(Icons.leaderboard),
                    label: const Text('Leaderboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Sound settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
      ),
      body: GameWidget<DynoGame>.controlled(
        gameFactory: () => DynoGame(startImmediately: true),
        overlayBuilderMap: {
          'hud': (context, game) => HudOverlay(game: game),
          'gameOver': (context, game) => GameOverOverlay(game: game),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}
