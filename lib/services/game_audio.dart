import 'dart:async';

import 'package:flame_audio/flame_audio.dart';

import 'sound_settings.dart';

/// Coordinates looping music and one-shot game sound effects.
///
/// Music uses a dedicated [AudioPlayer] rather than Flame's queued BGM helper
/// so it begins directly from the user's Start/Replay interaction.
class GameAudio {
  GameAudio._();

  static AudioPlayer? _backgroundPlayer;
  static AudioPlayer? _jumpPlayer;
  static String? _backgroundFile;
  static bool _enabled = false;

  /// Enables device audio after the application binding has been initialized.
  static Future<void> initialize() async {
    _enabled = true;
  }

  static Future<void> playTitleMusic() => _enabled
      ? _playBackground('title.mp3', SoundSettings.instance.titleVolume)
      : Future.value();

  static Future<void> playGameMusic() => _enabled
      ? _playBackground('theme.mp3', SoundSettings.instance.gameMusicVolume)
      : Future.value();

  static Future<void> stopBackgroundMusic() async {
    if (!_enabled) {
      return;
    }
    _backgroundFile = null;
    final player = _backgroundPlayer;
    _backgroundPlayer = null;
    if (player == null) {
      return;
    }
    await player.stop();
    await player.dispose();
  }

  static Future<void> stopTitleMusic() {
    if (_backgroundFile != 'title.mp3') {
      return Future.value();
    }
    return stopBackgroundMusic();
  }

  static Future<void> playJump() {
    if (!_enabled) {
      return Future.value();
    }
    final player = _jumpPlayer ??= AudioPlayer()
      ..audioCache = FlameAudio.audioCache;
    unawaited(player.setReleaseMode(ReleaseMode.stop));
    return player.play(
      AssetSource('jump.mp3'),
      volume: SoundSettings.instance.jumpVolume,
    );
  }

  static Future<void> playHit() {
    if (!_enabled) {
      return Future.value();
    }
    unawaited(stopBackgroundMusic());
    return _playEffect('hit.mp3', SoundSettings.instance.hitVolume);
  }

  static Future<void> playGameOver() {
    if (!_enabled) {
      return Future.value();
    }
    unawaited(stopBackgroundMusic());
    return _playEffect('gameover.mp3', SoundSettings.instance.gameOverVolume);
  }

  static Future<void> _playBackground(String fileName, double volume) {
    if (_backgroundFile == fileName && _backgroundPlayer != null) {
      final player = _backgroundPlayer!;
      unawaited(player.setReleaseMode(ReleaseMode.loop));
      return player.play(AssetSource(fileName), volume: volume);
    }

    unawaited(stopBackgroundMusic());
    final player = AudioPlayer()..audioCache = FlameAudio.audioCache;
    _backgroundFile = fileName;
    _backgroundPlayer = player;
    unawaited(player.setReleaseMode(ReleaseMode.loop));
    return player.play(AssetSource(fileName), volume: volume);
  }

  static Future<void> _playEffect(String fileName, double volume) async {
    try {
      await FlameAudio.play(fileName, volume: volume);
    } catch (_) {
      // Audio should never prevent gameplay if a platform audio backend fails.
    }
  }
}
