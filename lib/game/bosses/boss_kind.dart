import 'dart:math';

/// Boss archetypes spawned at distance milestones during a run.
enum BossKind {
  stoneGolem('Stone Golem'),
  twinSentinels('Twin Sentinels'),
  skyCrusher('Sky Crusher');

  const BossKind(this.displayName);

  final String displayName;

  static BossKind randomPick(Random random) {
    return values[random.nextInt(values.length)];
  }
}
