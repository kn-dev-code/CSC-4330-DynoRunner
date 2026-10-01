import 'dart:math';

import 'package:flame/components.dart';

import '../dyno_game.dart';
import '../game_config.dart';
import 'boss_encounter.dart';
import 'boss_kind.dart';

/// Spawns a random boss when the player reaches distance milestones.
class BossDirector extends Component with HasGameReference<DynoGame> {
  BossDirector({required this.groundY, Random? random})
    : _random = random ?? Random();

  final double groundY;
  final Random _random;

  BossEncounter? _active;
  double _nextBossAtMeters = GameConfig.bossIntervalMeters;

  bool get isEngaged => _active != null;

  BossKind? get activeBossKind => _active?.kind;

  void reset() {
    _active?.removeFromParent();
    _active = null;
    _nextBossAtMeters = GameConfig.bossIntervalMeters;
  }

  @override
  void update(double dt) {
    if (game.state == GameState.gameOver) {
      return;
    }

    if (_active != null) {
      _scrollBoss(dt);
      if (_active!.isOffScreen) {
        _completeBoss();
      }
      return;
    }

    if (game.state != GameState.playing) {
      return;
    }

    if (game.distanceMeters < _nextBossAtMeters) {
      return;
    }

    _spawnBoss();
    _nextBossAtMeters += GameConfig.bossIntervalMeters;
  }

  void _spawnBoss() {
    final kind = BossKind.randomPick(_random);
    final encounter = BossEncounter(
      kind: kind,
      groundY: groundY,
      spawnPosition: Vector2(game.size.x + GameConfig.spawnMargin, 0),
    );
    _active = encounter;
    game.world.add(encounter);
    game.refreshNotifier.value++;
  }

  void _scrollBoss(double dt) {
    final boss = _active;
    if (boss == null) {
      return;
    }
    boss.position.x -= game.currentScrollSpeed * dt;
  }

  void _completeBoss() {
    _active?.removeFromParent();
    _active = null;
    game.money += GameConfig.bossMoneyBonus;
    game.refreshNotifier.value++;
  }
}
