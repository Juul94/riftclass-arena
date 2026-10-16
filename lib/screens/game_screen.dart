import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../game/riftclass_game.dart';
import '../models/player_class.dart';
import '../overlays/ability_select_overlay.dart';
import '../overlays/game_over_overlay.dart';
import '../overlays/pause_menu_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.selectedClass,
    this.worldIndex = 0,
    this.levelIndex = 0,
  });

  final PlayerClassName selectedClass;
  final int worldIndex;
  final int levelIndex;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final RiftclassGame _game;

  @override
  void initState() {
    super.initState();
    _game = RiftclassGame(
      selectedClass: widget.selectedClass,
      worldIndex: widget.worldIndex,
      levelIndex: widget.levelIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          GameWidget(
            game: _game,
            overlayBuilderMap: {
              'abilitySelect': (ctx, game) =>
                  AbilitySelectOverlay(game: game as RiftclassGame),
              'gameOver': (ctx, game) =>
                  GameOverOverlay(game: game as RiftclassGame),
              'pauseMenu': (ctx, game) =>
                  PauseMenuOverlay(game: game as RiftclassGame),
            },
          ),
          Positioned(
            bottom: 16,
            right: 12,
            child: SafeArea(
              child: GestureDetector(
                onTap: () {
                  _game.togglePause();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.pause, color: Colors.white70, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
