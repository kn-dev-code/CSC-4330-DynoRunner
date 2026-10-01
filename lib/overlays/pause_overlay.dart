import 'dart:async';

import 'package:flutter/material.dart';

import '../game/dyno_game.dart';
import '../services/game_audio.dart';
import 'sound_settings_screen.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});

  final DynoGame game;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Paused',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: game.resumeRun,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      unawaited(GameAudio.playGameMusic());
                      game.startRun();
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Restart'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    ),
                    icon: const Icon(Icons.home),
                    label: const Text('Main menu'),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    leading: const Icon(Icons.volume_up),
                    title: const Text('Adjust sounds'),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SoundSettingsControls(),
                      ),
                    ],
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
