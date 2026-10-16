import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../models/player_class.dart';
import '../models/world_theme.dart';
import '../services/progression_service.dart';
import 'game_screen.dart';

class WorldSelectScreen extends StatefulWidget {
  const WorldSelectScreen({super.key, required this.selectedClass});

  final PlayerClassName selectedClass;

  @override
  State<WorldSelectScreen> createState() => _WorldSelectScreenState();
}

class _WorldSelectScreenState extends State<WorldSelectScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _progression = ProgressionService.instance;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConfig.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            const Text(
              'SELECT WORLD',
              style: TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete all levels to unlock the next',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: WorldData.worlds.length,
                itemBuilder: (context, index) => _WorldCard(
                  world: WorldData.worlds[index],
                  isUnlocked: _progression.isWorldUnlocked(index),
                  isCompleted: _progression.isWorldCompleted(index),
                  currentLevel: _progression.currentLevelInWorld(index),
                  completedLevels: _progression.completedLevelInWorld(index) + 1,
                  animation: _ctrl,
                  onTap: () => _enterWorld(index),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '← BACK',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _enterWorld(int worldIndex) {
    if (!_progression.isWorldUnlocked(worldIndex)) return;
    final level = _progression.currentLevelInWorld(worldIndex);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          selectedClass: widget.selectedClass,
          worldIndex: worldIndex,
          levelIndex: level,
        ),
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({
    required this.world,
    required this.isUnlocked,
    required this.isCompleted,
    required this.currentLevel,
    required this.completedLevels,
    required this.animation,
    required this.onTap,
  });

  final WorldData world;
  final bool isUnlocked;
  final bool isCompleted;
  final int currentLevel;
  final int completedLevels;
  final Animation<double> animation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: isUnlocked ? onTap : null,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return CustomPaint(
              painter: _WorldCardPainter(
                world: world,
                isUnlocked: isUnlocked,
                isCompleted: isCompleted,
                completedLevels: completedLevels,
                animValue: animation.value,
              ),
              child: child,
            );
          },
          child: SizedBox(
            height: 140,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          world.name,
                          style: TextStyle(
                            color: isUnlocked ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      if (!isUnlocked)
                        Icon(Icons.lock, color: Colors.white.withValues(alpha: 0.3), size: 22),
                      if (isCompleted)
                        const Icon(Icons.star, color: Color(0xFFfbbf24), size: 22),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    world.subtitle,
                    style: TextStyle(
                      color: isUnlocked
                          ? world.accentColor.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.2),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  // Progress bar
                  if (isUnlocked) ...[
                    Row(
                      children: [
                        Text(
                          isCompleted
                              ? 'COMPLETED'
                              : 'LEVEL ${currentLevel + 1} / ${WorldData.levelsPerWorld}',
                          style: TextStyle(
                            color: isCompleted
                                ? const Color(0xFFfbbf24)
                                : world.accentColor.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completedLevels / WorldData.levelsPerWorld,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation(
                          isCompleted ? const Color(0xFFfbbf24) : world.accentColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorldCardPainter extends CustomPainter {
  _WorldCardPainter({
    required this.world,
    required this.isUnlocked,
    required this.isCompleted,
    required this.completedLevels,
    required this.animValue,
  });

  final WorldData world;
  final bool isUnlocked;
  final bool isCompleted;
  final int completedLevels;
  final double animValue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));

    // Background gradient
    final bgGrad = ui.Gradient.linear(
      Offset.zero,
      Offset(size.width, size.height),
      [
        world.floorPrimary,
        world.wallColor,
      ],
    );
    canvas.drawRRect(rrect, Paint()..shader = bgGrad);

    // Subtle animated accent particles (only if unlocked)
    if (isUnlocked) {
      final rng = Random(world.index * 7);
      for (var i = 0; i < 6; i++) {
        final baseX = rng.nextDouble() * size.width;
        final baseY = rng.nextDouble() * size.height;
        final phase = rng.nextDouble() * 2 * pi;
        final px = baseX + sin(animValue * 2 * pi + phase) * 8;
        final py = baseY + cos(animValue * 2 * pi + phase * 0.7) * 6;
        final alpha = (0.15 + sin(animValue * 2 * pi + i) * 0.08).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(px, py),
          2.5 + sin(animValue * 2 * pi + i * 1.5) * 1.0,
          Paint()
            ..color = world.accentColor.withValues(alpha: alpha)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
        );
      }
    }

    // Border
    final borderColor = isUnlocked
        ? world.accentColor.withValues(alpha: 0.4 + sin(animValue * 2 * pi) * 0.1)
        : Colors.white.withValues(alpha: 0.08);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isUnlocked ? 1.8 : 1.0,
    );

    // Lock overlay
    if (!isUnlocked) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0xAA000000));
      // Dark chain pattern
      final chainPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var i = 0; i < 3; i++) {
        final y = 30.0 + i * 35;
        canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), chainPaint);
      }
    }

    // Theme icons (drawn behind text, subtle)
    if (isUnlocked) {
      _drawThemeDecoration(canvas, size);
    }
  }

  void _drawThemeDecoration(Canvas canvas, Size size) {
    final paint = Paint()..color = world.accentColor.withValues(alpha: 0.06);

    switch (world.index) {
      case 0: // Castle — battlements
        for (var i = 0; i < 5; i++) {
          final x = size.width - 60 + i * 12.0;
          final h = 20 + (i % 2) * 10.0;
          canvas.drawRect(Rect.fromLTWH(x, size.height - h, 8, h), paint);
        }
      case 1: // Shadow — swirl
        final center = Offset(size.width - 40, size.height / 2);
        for (var i = 0; i < 3; i++) {
          final a = animValue * 2 * pi + i * (2 * pi / 3);
          canvas.drawCircle(
            Offset(center.dx + cos(a) * 18, center.dy + sin(a) * 18),
            6, paint,
          );
        }
      case 2: // Forest — trees
        for (var i = 0; i < 3; i++) {
          final x = size.width - 70 + i * 25.0;
          final trunk = Rect.fromCenter(center: Offset(x, size.height - 20), width: 4, height: 30);
          canvas.drawRect(trunk, paint);
          final tree = Path()
            ..moveTo(x - 12, size.height - 30)
            ..lineTo(x + 12, size.height - 30)
            ..lineTo(x, size.height - 55)
            ..close();
          canvas.drawPath(tree, paint);
        }
    }
  }

  @override
  bool shouldRepaint(_WorldCardPainter old) => old.animValue != animValue;
}
