import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Simple sky and ground strip until dedicated art is added.
class Background extends PositionComponent {
  Background({required this.groundY});

  final double groundY;

  @override
  Future<void> onLoad() async {
    final gameSize = findGame()!.size;

    await add(
      RectangleComponent(
        size: gameSize,
        paint: Paint()..color = const Color(0xFFF7F7F7),
      ),
    );
    await add(
      RectangleComponent(
        position: Vector2(0, groundY),
        size: Vector2(gameSize.x, gameSize.y - groundY),
        paint: Paint()..color = const Color(0xFF535353),
      ),
    );
  }
}
