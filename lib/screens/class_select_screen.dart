import 'package:flutter/material.dart';

import '../game/config.dart';
import '../models/player_class.dart';
import '../widgets/class_preview.dart';
import 'world_select_screen.dart';

class ClassSelectScreen extends StatelessWidget {
  const ClassSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameConfig.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'CHOOSE YOUR CLASS',
              style: TextStyle(
                color: Color(0xCCFFFFFF),
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Each class has unique abilities',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: PlayerClassData.all.values
                    .map((c) => _ClassCard(
                          classData: c,
                          onTap: () => _startGame(context, c.id),
                        ))
                    .toList(),
              ),
            ),
            // Back button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '← BACK',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _startGame(BuildContext context, PlayerClassName className) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorldSelectScreen(selectedClass: className),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.classData, required this.onTap});

  final PlayerClassData classData;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = classData.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: c.withValues(alpha: 0.1), blurRadius: 12),
          ],
        ),
        child: Row(
          children: [
            // Animated class preview
            ClassPreview(
              classData: classData,
              size: 80,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classData.displayName.toUpperCase(),
                    style: TextStyle(
                      color: c,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    classData.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Stat bars
                  _StatBar('HP', classData.baseHealth / 130, c),
                  const SizedBox(height: 3),
                  _StatBar('SPD', classData.baseSpeed / 170, c),
                  const SizedBox(height: 3),
                  _StatBar('DMG', classData.baseDamage / 18, c),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar(this.label, this.ratio, this.color);

  final String label;
  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
