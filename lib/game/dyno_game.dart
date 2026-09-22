import 'package:flame/game.dart';

enum GameState { intro, playing, gameOver }

class DynoGame extends FlameGame {
  GameState state = GameState.intro;

  @override
  Future<void> onLoad() async {
    // DaveyBoll will add Player component here
    // Justinat0r will add Spawner & Background here
    // spvvn will hook up HUD overlays here
  }
}
