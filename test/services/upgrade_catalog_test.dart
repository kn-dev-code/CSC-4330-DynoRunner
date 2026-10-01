import 'package:dyno_app/services/upgrade_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RunUpgradeModifiers scales with upgrade levels', () {
    final modifiers = RunUpgradeModifiers.fromLevels({
      UpgradeId.jumpBoost.id: 2,
      UpgradeId.coinMagnet.id: 1,
      UpgradeId.ironHide.id: 1,
      UpgradeId.pitSpikes.id: 1,
    });

    expect(modifiers.jumpMultiplier, closeTo(1.16, 0.001));
    expect(modifiers.moneyMultiplier, closeTo(1.1, 0.001));
    expect(modifiers.startInvulnSeconds, 1.5);
    expect(modifiers.pitfallsIgnoredPerRun, 1);
  });
}
