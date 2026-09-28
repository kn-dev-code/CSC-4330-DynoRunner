import 'package:flame/components.dart';
import 'package:flame/game.dart';

import 'components/background.dart';
import 'components/collidable_sprite.dart';
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
    // Map world coordinates 1:1 onto the screen. The default viewfinder
    // centers the origin, which pushes the ground line below the screen.
    camera.viewfinder.anchor = Anchor.topLeft;

    final groundY = GameConfig.groundY(size);

    background = Background(groundY: groundY);
    mapGenerator = MapGenerator(groundY: groundY);

    await world.addAll([background, mapGenerator]);

    // The dinosaur never moves horizontally; the map scrolls under it.
    await world.add(
      SpriteAnimationComponent(
        animation: SpriteAnimation.spriteList(
          [
            await loadSprite(GameSprite.dinoRun1.asset),
            await loadSprite(GameSprite.dinoRun2.asset),
          ],
          stepTime: 0.1,
        ),
        position: Vector2(50, groundY),
        anchor: Anchor.bottomLeft,
      ),
    );

    // DaveyBoll will add Player component here
    // spvvn will hook up HUD overlays here

    // No intro flow yet — start scrolling so the map generator is visible.
    state = GameState.playing;
  }
}

