import 'package:flutter/material.dart';

import '../game/dyno_game.dart';

class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final DynoGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ValueListenableBuilder<int>(
          valueListenable: game.refreshNotifier,
          builder: (context, _, __) {
            final intro = game.state == GameState.intro;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  intro
                      ? 'Tap or press Space to start'
                      : 'Distance: ${game.distanceMeters.toStringAsFixed(1)} m',
                  style: const TextStyle(
                    color: Color(0xFF535353),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!intro) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Money: \$${game.money.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF535353),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Wallet: \$${game.wallet.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFF535353),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap / Space / ↑ to jump • P / Esc to pause',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
