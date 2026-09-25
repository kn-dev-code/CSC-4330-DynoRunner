import 'package:flame/game.dart';

import 'components/background.dart';
import 'components/map_generator.dart';
import 'game_config.dart';

enum GameState { intro, playing, gameOver }

class DynoGame extends FlameGame with HasCollisionDetection {
  GameState state = GameState.intro;

  late final Background background;
  late final MapGenerator mapGenerator;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    if (!hasLayout) {
      return;
    }

    await _buildWorld();
  }

  Future<void> _buildWorld() async {
    final groundY = GameConfig.groundY(size);

    background = Background(groundY: groundY);
    mapGenerator = MapGenerator(groundY: groundY);

    await world.addAll([background, mapGenerator]);

    // DaveyBoll will add Player component here
    // spvvn will hook up HUD overlays here

    // No intro flow yet — start scrolling so the map generator is visible.
    state = GameState.playing;
  }
}
