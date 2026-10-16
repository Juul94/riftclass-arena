import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/riftclass_game.dart';
import '../screens/main_menu_screen.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.game});

  final RiftclassGame game;

  @override
  Widget build(BuildContext context) {
    final player = game.player;
    final didWin = player != null && player.health > 0;

    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                didWin ? 'VICTORY!' : 'DEFEATED',
                style: TextStyle(
                  color: didWin
                      ? const Color(0xFFfbbf24)
                      : const Color(0xFFef4444),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                didWin
                    ? 'All worlds conquered!'
                    : 'World ${game.roomManager.worldIndex + 1} – ${game.roomManager.theme.name}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 40),
              _OverlayButton(
                label: 'TRY AGAIN',
                color: GameConfig.archerColor,
                onTap: () => game.restart(),
              ),
              const SizedBox(height: 14),
              _OverlayButton(
                label: 'MAIN MENU',
                color: const Color(0xFF6b7280),
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (_) => const MainMenuScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}
