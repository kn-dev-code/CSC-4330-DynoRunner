import 'package:flame/game.dart';
   import 'package:flutter/material.dart';
   import 'game/dyno_game.dart';

   void main() {
     runApp(
       MaterialApp(
         debugShowCheckedModeBanner: false,
         home: Scaffold(
           body: GameWidget(
             game: DynoGame(),
           ),
         ),
       ),
     );
   }