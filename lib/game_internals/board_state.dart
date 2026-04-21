import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'player.dart';
import 'playing_area.dart';

class BoardState {
  final VoidCallback onWin;

  final PlayingArea trick = PlayingArea();

  final Player player = Player();

  BoardState({required this.onWin}) {
    player.addListener(_handlePlayerChange);
  }

  void dispose() {
    player.removeListener(_handlePlayerChange);
    trick.dispose();
  }

  void _handlePlayerChange() {
    if (player.hand.isEmpty) {
      onWin();
    }
  }
}
