import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/dyno_game.dart';
import 'overlays/overlays.dart';
import 'services/game_audio.dart';
import 'services/player_wallet.dart';
import 'services/sound_settings.dart';

final routeObserver = RouteObserver<ModalRoute<dynamic>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SoundSettings.instance.load();
  await PlayerWallet.instance.load();
  await GameAudio.initialize();
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
        '/sound-settings': (_) => const SoundSettingsScreen(),
        '/shop': (_) => const ShopScreen(),
      },
      navigatorObservers: [routeObserver],
      initialRoute: '/',
    );
  }
}

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with RouteAware {
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    unawaited(GameAudio.playTitleMusic());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) {
        routeObserver.unsubscribe(this);
      }
      _route = route;
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    unawaited(GameAudio.stopTitleMusic());
  }

  @override
  void didPopNext() {
    unawaited(GameAudio.playTitleMusic());
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    unawaited(GameAudio.stopBackgroundMusic());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => unawaited(GameAudio.playTitleMusic()),
        child: DecoratedBox(
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        'assets/images/dino_run_1.png',
                        height: 80,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        semanticLabel: 'Dinosaur',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap anywhere to enable music',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
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
                        onPressed: () {
                          unawaited(GameAudio.playGameMusic());
                          Navigator.of(context).pushNamed('/game');
                        },
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
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/shop'),
                        icon: const Icon(Icons.storefront),
                        label: const Text('Shop'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/sound-settings'),
                        icon: const Icon(Icons.volume_up),
                        label: const Text('Sound settings'),
                      ),
                    ],
                  ),
                ),
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
      appBar: AppBar(title: const Text('Dyno Run')),
      body: GameWidget<DynoGame>.controlled(
        gameFactory: () => DynoGame(
          startImmediately: true,
          runModifiers: playerUpgradesService.cachedModifiers,
          onRunStarted: () => unawaited(GameAudio.playGameMusic()),
          onRunEnded: () => unawaited(GameAudio.playGameOver()),
          onJump: () => unawaited(GameAudio.playJump()),
          onHit: () => unawaited(GameAudio.playHit()),
        ),
        overlayBuilderMap: {
          'hud': (context, game) => HudOverlay(game: game),
          'gameOver': (context, game) => GameOverOverlay(game: game),
          'pause': (context, game) => PauseOverlay(game: game),
        },
        initialActiveOverlays: const ['hud'],
      ),
    );
  }
}
