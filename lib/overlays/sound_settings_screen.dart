import 'package:flutter/material.dart';

import '../services/sound_settings.dart';

class SoundSettingsScreen extends StatelessWidget {
  const SoundSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sound settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [SoundSettingsControls()],
      ),
    );
  }
}

class SoundSettingsControls extends StatelessWidget {
  const SoundSettingsControls({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SoundSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            _VolumeSlider(
              label: 'Game Over Volume',
              value: settings.gameOverVolume,
              onChanged: settings.setGameOverVolume,
            ),
            _VolumeSlider(
              label: 'Jump Volume',
              value: settings.jumpVolume,
              onChanged: settings.setJumpVolume,
            ),
            _VolumeSlider(
              label: 'Title Volume',
              value: settings.titleVolume,
              onChanged: settings.setTitleVolume,
            ),
            _VolumeSlider(
              label: 'Hit Sound',
              value: settings.hitVolume,
              onChanged: settings.setHitVolume,
            ),
            _VolumeSlider(
              label: 'Game Music Volume',
              value: settings.gameMusicVolume,
              onChanged: settings.setGameMusicVolume,
            ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $percent%'),
          Slider(
            value: value,
            divisions: 20,
            label: '$percent%',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
