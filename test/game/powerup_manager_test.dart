import 'package:dyno_app/game/dyno_game.dart';
import 'package:dyno_app/game/powerups/powerup_manager.dart';
import 'package:dyno_app/game/powerups/powerup_type.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PowerUpManager', () {
    late DynoGame game;
    late PowerUpManager manager;

    setUp(() async {
      game = DynoGame()..state = GameState.playing;
      game.onGameResize(Vector2(800, 600));
      // ignore: invalid_use_of_internal_member
      await game.load();
      manager = game.powerUpManager;
    });

    test('extra life absorbs a fatal hit', () {
      manager.apply(PowerUpType.extraLife);
      expect(manager.tryAbsorbHit(), isTrue);
      expect(manager.extraLives, 0);
      expect(manager.tryAbsorbHit(), isFalse);
    });

    test('invulnerability absorbs hits without consuming lives', () {
      manager.apply(PowerUpType.invulnerability);
      manager.apply(PowerUpType.extraLife);
      expect(manager.tryAbsorbHit(), isTrue);
      expect(manager.extraLives, 1);
    });

    test('timed effects expire', () {
      manager.apply(PowerUpType.superspeed);
      expect(manager.scrollSpeedMultiplier, greaterThan(1));

      for (var frame = 0; frame < 300; frame++) {
        manager.update(1 / 60);
      }

      expect(manager.scrollSpeedMultiplier, 1);
    });
  });
}
