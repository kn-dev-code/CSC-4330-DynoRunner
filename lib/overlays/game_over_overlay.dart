import 'dart:async';

import 'package:flutter/material.dart';

import '../game/dyno_game.dart';
import '../services/game_audio.dart';
import '../services/leaderboard_service.dart';

class GameOverOverlay extends StatefulWidget {
  const GameOverOverlay({super.key, required this.game});

  final DynoGame game;

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  final _nameController = TextEditingController();
  final _leaderboard = LeaderboardService();
  var _submitting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.game.playerName;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _leaderboard.dispose();
    super.dispose();
  }

  Future<void> _submitScore() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Enter a name to submit.');
      return;
    }

    setState(() {
      _submitting = true;
      _status = null;
    });

    try {
      widget.game.playerName = name;
      await _leaderboard.submitScore(
        playerName: name,
        distanceMeters: widget.game.distanceMeters,
        money: widget.game.money,
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = 'Score saved to leaderboard.');
    } on LeaderboardException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _status = error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Game Over',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Distance: ${widget.game.distanceMeters.toStringAsFixed(1)} m',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Money: \$${widget.game.money.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Player name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _submitting ? null : _submitScore,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit to leaderboard'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    unawaited(GameAudio.playGameMusic());
                    widget.game.startRun();
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Replay'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/leaderboard');
                  },
                  icon: const Icon(Icons.leaderboard),
                  label: const Text('View leaderboard'),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Back to title screen'),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _status!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _status == 'Score saved to leaderboard.'
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
