import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the independently adjustable volumes for all game audio.
class SoundSettings extends ChangeNotifier {
  SoundSettings._();

  static final instance = SoundSettings._();

  static const _gameOverKey = 'gameOverVolume';
  static const _jumpKey = 'jumpVolume';
  static const _titleKey = 'titleVolume';
  static const _hitKey = 'hitVolume';
  static const _gameMusicKey = 'gameMusicVolume';

  double gameOverVolume = 0.7;
  double jumpVolume = 0.7;
  double titleVolume = 0.5;
  double hitVolume = 0.8;
  double gameMusicVolume = 0.5;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    gameOverVolume = preferences.getDouble(_gameOverKey) ?? gameOverVolume;
    jumpVolume = preferences.getDouble(_jumpKey) ?? jumpVolume;
    titleVolume = preferences.getDouble(_titleKey) ?? titleVolume;
    hitVolume = preferences.getDouble(_hitKey) ?? hitVolume;
    gameMusicVolume = preferences.getDouble(_gameMusicKey) ?? gameMusicVolume;
    notifyListeners();
  }

  void setGameOverVolume(double value) =>
      _set(_gameOverKey, value, (volume) => gameOverVolume = volume);

  void setJumpVolume(double value) =>
      _set(_jumpKey, value, (volume) => jumpVolume = volume);

  void setTitleVolume(double value) =>
      _set(_titleKey, value, (volume) => titleVolume = volume);

  void setHitVolume(double value) =>
      _set(_hitKey, value, (volume) => hitVolume = volume);

  void setGameMusicVolume(double value) =>
      _set(_gameMusicKey, value, (volume) => gameMusicVolume = volume);

  void _set(String key, double value, void Function(double) assign) {
    final volume = value.clamp(0.0, 1.0).toDouble();
    assign(volume);
    notifyListeners();
    unawaited(_save(key, volume));
  }

  Future<void> _save(String key, double value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(key, value);
  }
}
