/// Permanent upgrades purchased with server-stored money.
enum UpgradeId {
  jumpBoost(
    'jump_boost',
    'Stronger Legs',
    'Higher jumps per level.',
    baseCost: 25,
    maxLevel: 5,
  ),
  coinMagnet(
    'coin_magnet',
    'Coin Magnet',
    'Earn more run money per level.',
    baseCost: 30,
    maxLevel: 5,
  ),
  ironHide(
    'iron_hide',
    'Iron Hide',
    'Start each run with brief invulnerability.',
    baseCost: 40,
    maxLevel: 3,
  ),
  pitSpikes(
    'pit_spikes',
    'Pit Spikes',
    'First pitfall each run is ignored.',
    baseCost: 35,
    maxLevel: 1,
  );

  const UpgradeId(
    this.id,
    this.title,
    this.description, {
    required this.baseCost,
    required this.maxLevel,
  });

  final String id;
  final String title;
  final String description;
  final double baseCost;
  final int maxLevel;

  double costForLevel(int currentLevel) {
    if (currentLevel >= maxLevel) {
      return double.infinity;
    }
    return baseCost * (currentLevel + 1);
  }

  static UpgradeId? fromId(String id) {
    for (final upgrade in values) {
      if (upgrade.id == id) {
        return upgrade;
      }
    }
    return null;
  }
}

/// Gameplay modifiers derived from owned upgrade levels.
class RunUpgradeModifiers {
  const RunUpgradeModifiers({
    this.jumpMultiplier = 1,
    this.moneyMultiplier = 1,
    this.startInvulnSeconds = 0,
    this.pitfallsIgnoredPerRun = 0,
  });

  final double jumpMultiplier;
  final double moneyMultiplier;
  final double startInvulnSeconds;
  final int pitfallsIgnoredPerRun;

  static const none = RunUpgradeModifiers();

  factory RunUpgradeModifiers.fromLevels(Map<String, int> levels) {
    final jump = levels[UpgradeId.jumpBoost.id] ?? 0;
    final magnet = levels[UpgradeId.coinMagnet.id] ?? 0;
    final hide = levels[UpgradeId.ironHide.id] ?? 0;
    final pits = levels[UpgradeId.pitSpikes.id] ?? 0;

    return RunUpgradeModifiers(
      jumpMultiplier: 1 + jump * 0.08,
      moneyMultiplier: 1 + magnet * 0.1,
      startInvulnSeconds: hide * 1.5,
      pitfallsIgnoredPerRun: pits.clamp(0, 1),
    );
  }
}
