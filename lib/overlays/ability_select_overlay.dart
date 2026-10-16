import 'dart:math';

import 'package:flutter/material.dart';

import '../game/riftclass_game.dart';
import '../models/player_class.dart';

/// Custom ability icon painter that draws unique icons per ability.
class _AbilityIconPainter extends CustomPainter {
  final String abilityId;
  final Color color;

  _AbilityIconPainter({required this.abilityId, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    switch (abilityId) {
      // ── Archer abilities ──
      case 'multi_shot':
        _drawMultiShot(canvas, cx, cy);
      case 'piercing':
        _drawPiercing(canvas, cx, cy);
      case 'arrow_rain':
        _drawArrowRain(canvas, cx, cy);

      // ── Mage abilities ──
      case 'frost_nova':
        _drawFrostNova(canvas, cx, cy);
      case 'chain_lightning':
        _drawChainLightning(canvas, cx, cy);
      case 'meteor':
        _drawMeteor(canvas, cx, cy);

      // ── Warrior abilities ──
      case 'shield_bash':
        _drawShieldBash(canvas, cx, cy);
      case 'whirlwind':
        _drawWhirlwind(canvas, cx, cy);
      case 'leap_slam':
        _drawLeapSlam(canvas, cx, cy);

      // ── Necromancer abilities ──
      case 'skeleton':
        _drawSkeleton(canvas, cx, cy);
      case 'life_drain':
        _drawLifeDrain(canvas, cx, cy);
      case 'corpse_explode':
        _drawCorpseExplosion(canvas, cx, cy);

      default:
        _drawDefault(canvas, cx, cy);
    }
  }

  void _drawMultiShot(Canvas canvas, double cx, double cy) {
    final paint = Paint()..color = color..strokeWidth = 1.8..style = PaintingStyle.stroke;
    // Three arrows fanning out
    for (var i = -1; i <= 1; i++) {
      final offsetY = i * 5.0;
      final offsetX = i.abs() * 2.0;
      canvas.drawLine(Offset(cx - 8 + offsetX, cy + offsetY), Offset(cx + 6, cy + offsetY), paint);
      // Arrowhead
      final head = Path()
        ..moveTo(cx + 10, cy + offsetY)
        ..lineTo(cx + 6, cy + offsetY - 2.5)
        ..lineTo(cx + 6, cy + offsetY + 2.5)
        ..close();
      canvas.drawPath(head, Paint()..color = color);
    }
  }

  void _drawPiercing(Canvas canvas, double cx, double cy) {
    // Long arrow piercing through a target circle
    final arrowPaint = Paint()..color = color..strokeWidth = 2;
    canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), arrowPaint);
    // Arrowhead
    final head = Path()
      ..moveTo(cx + 14, cy)
      ..lineTo(cx + 10, cy - 3)
      ..lineTo(cx + 10, cy + 3)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
    // Target circle being pierced
    canvas.drawCircle(Offset(cx, cy), 7, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Break in circle to show piercing
    canvas.drawLine(Offset(cx - 2, cy), Offset(cx + 2, cy), Paint()..color = Colors.white..strokeWidth = 1);
  }

  void _drawArrowRain(Canvas canvas, double cx, double cy) {
    // Arrows falling from above
    final paint = Paint()..color = color..strokeWidth = 1.5;
    for (var i = 0; i < 5; i++) {
      final x = cx - 8 + i * 4.0;
      final y = cy - 6 + (i % 2) * 4.0;
      canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), paint);
      // Small arrowhead
      final h = Path()..moveTo(x, y + 6)..lineTo(x - 1.5, y + 3)..lineTo(x + 1.5, y + 3)..close();
      canvas.drawPath(h, Paint()..color = color);
    }
    // Cloud at top
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 10), width: 18, height: 6),
      Paint()..color = color.withValues(alpha: 0.3),
    );
  }

  void _drawFrostNova(Canvas canvas, double cx, double cy) {
    // Central burst with ice crystals radiating out
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = const Color(0xFFa8e0ff));
    // Ice shards radiating
    final shardPaint = Paint()..color = const Color(0xFFd4f0ff)..strokeWidth = 2;
    for (var i = 0; i < 6; i++) {
      final angle = i * 3.14159 / 3;
      final dx = cos(angle) * 10;
      final dy = sin(angle) * 10;
      canvas.drawLine(Offset(cx + dx * 0.4, cy + dy * 0.4), Offset(cx + dx, cy + dy), shardPaint);
      // Crystal tip
      canvas.drawCircle(Offset(cx + dx, cy + dy), 1.5, Paint()..color = Colors.white);
    }
    // Frost ring
    canvas.drawCircle(Offset(cx, cy), 11, Paint()..color = color.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawChainLightning(Canvas canvas, double cx, double cy) {
    // Zigzag lightning bolt connecting nodes
    final paint = Paint()..color = const Color(0xFFFFFF44)..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(cx - 10, cy - 6)
      ..lineTo(cx - 4, cy - 2)
      ..lineTo(cx - 6, cy + 2)
      ..lineTo(cx + 2, cy + 0)
      ..lineTo(cx + 0, cy + 4)
      ..lineTo(cx + 8, cy + 2)
      ..lineTo(cx + 6, cy + 6)
      ..lineTo(cx + 12, cy + 4);
    canvas.drawPath(path, paint);
    // Nodes (enemies)
    canvas.drawCircle(Offset(cx - 10, cy - 6), 2.5, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx + 2, cy), 2.5, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx + 12, cy + 4), 2.5, Paint()..color = color.withValues(alpha: 0.5));
    // Glow
    canvas.drawPath(path, Paint()..color = const Color(0x44FFFF44)..strokeWidth = 5..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _drawMeteor(Canvas canvas, double cx, double cy) {
    // Fiery meteor coming down
    // Trail
    final trail = Path()
      ..moveTo(cx - 4, cy - 10)
      ..quadraticBezierTo(cx - 8, cy - 4, cx - 3, cy + 2);
    canvas.drawPath(trail, Paint()..color = const Color(0xFFFF8833).withValues(alpha: 0.5)..strokeWidth = 3..style = PaintingStyle.stroke);
    final trail2 = Path()
      ..moveTo(cx + 2, cy - 12)
      ..quadraticBezierTo(cx + 4, cy - 6, cx + 1, cy + 0);
    canvas.drawPath(trail2, Paint()..color = const Color(0xFFFF4400).withValues(alpha: 0.4)..strokeWidth = 2..style = PaintingStyle.stroke);
    // Meteor rock
    canvas.drawCircle(Offset(cx, cy + 2), 6, Paint()..color = const Color(0xFFCC4400));
    canvas.drawCircle(Offset(cx, cy + 2), 6, Paint()..color = const Color(0xFFFF6600).withValues(alpha: 0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(cx - 1, cy + 1), 2.5, Paint()..color = const Color(0xFFFFAA33));
    // Impact ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 16, height: 5),
      Paint()..color = const Color(0xFFFF6600).withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
  }

  void _drawShieldBash(Canvas canvas, double cx, double cy) {
    // Shield shape
    final shield = Path()
      ..moveTo(cx - 6, cy - 8)
      ..lineTo(cx + 6, cy - 8)
      ..lineTo(cx + 7, cy + 2)
      ..lineTo(cx, cy + 8)
      ..lineTo(cx - 7, cy + 2)
      ..close();
    canvas.drawPath(shield, Paint()..color = const Color(0xFF5a6a8a));
    canvas.drawPath(shield, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Shield cross emblem
    canvas.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 4), Paint()..color = color..strokeWidth = 2);
    canvas.drawLine(Offset(cx - 4, cy - 1), Offset(cx + 4, cy - 1), Paint()..color = color..strokeWidth = 2);
    // Impact lines
    canvas.drawLine(Offset(cx + 9, cy - 4), Offset(cx + 13, cy - 6), Paint()..color = Colors.white70..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 9, cy), Offset(cx + 13, cy), Paint()..color = Colors.white70..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 9, cy + 4), Offset(cx + 13, cy + 6), Paint()..color = Colors.white70..strokeWidth = 1.5);
  }

  void _drawWhirlwind(Canvas canvas, double cx, double cy) {
    // Spinning blade arcs
    final paint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 20), 0, 2.0, false, paint);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 20), 2.5, 2.0, false, paint);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 20), 5.0, 2.0, false, paint);
    // Sword in center
    canvas.drawLine(Offset(cx, cy - 5), Offset(cx, cy + 5), Paint()..color = const Color(0xFFCCCCCC)..strokeWidth = 2);
    canvas.drawLine(Offset(cx - 3, cy - 2), Offset(cx + 3, cy - 2), Paint()..color = const Color(0xFF8B7500)..strokeWidth = 1.5);
    // Motion blur ring
    canvas.drawCircle(Offset(cx, cy), 11, Paint()..color = color.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _drawLeapSlam(Canvas canvas, double cx, double cy) {
    // Figure leaping up
    canvas.drawLine(Offset(cx, cy - 10), Offset(cx, cy - 4), Paint()..color = color..strokeWidth = 2);
    // Upward arrow
    final up = Path()..moveTo(cx, cy - 13)..lineTo(cx - 3, cy - 9)..lineTo(cx + 3, cy - 9)..close();
    canvas.drawPath(up, Paint()..color = color);
    // Impact crater below
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 5), width: 18, height: 8),
      Paint()..color = color.withValues(alpha: 0.3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 5), width: 18, height: 8),
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    // Shockwave lines
    canvas.drawLine(Offset(cx - 10, cy + 3), Offset(cx - 13, cy + 1), Paint()..color = Colors.white54..strokeWidth = 1.2);
    canvas.drawLine(Offset(cx + 10, cy + 3), Offset(cx + 13, cy + 1), Paint()..color = Colors.white54..strokeWidth = 1.2);
    canvas.drawLine(Offset(cx - 6, cy + 8), Offset(cx - 8, cy + 11), Paint()..color = Colors.white54..strokeWidth = 1.2);
    canvas.drawLine(Offset(cx + 6, cy + 8), Offset(cx + 8, cy + 11), Paint()..color = Colors.white54..strokeWidth = 1.2);
  }

  void _drawSkeleton(Canvas canvas, double cx, double cy) {
    // Skull
    canvas.drawCircle(Offset(cx, cy - 6), 5, Paint()..color = const Color(0xFFe8e8d0));
    canvas.drawCircle(Offset(cx - 2, cy - 7), 1.2, Paint()..color = color);
    canvas.drawCircle(Offset(cx + 2, cy - 7), 1.2, Paint()..color = color);
    // Jaw
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 4), width: 6, height: 4),
      0.2, 2.7, false,
      Paint()..color = const Color(0xFFd4d4c0)..strokeWidth = 1.2..style = PaintingStyle.stroke,
    );
    // Ribs
    for (var i = 0; i < 3; i++) {
      final y = cy + i * 3.0;
      canvas.drawLine(Offset(cx - 4, y), Offset(cx + 4, y), Paint()..color = const Color(0xFFd4d4c0)..strokeWidth = 1.2);
    }
    // Rising from ground glow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 10), width: 14, height: 5),
      Paint()..color = color.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  void _drawLifeDrain(Canvas canvas, double cx, double cy) {
    // Swirling soul energy being pulled in
    final paint = Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke;
    // Spiral in
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: 18, height: 18), 0, 3, false, paint);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, cy), width: 12, height: 12), 2, 3, false, Paint()..color = const Color(0xFF44FF44)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    // Heart/health in center
    final heart = Path()
      ..moveTo(cx, cy + 3)
      ..cubicTo(cx - 5, cy - 1, cx - 5, cy - 5, cx, cy - 3)
      ..cubicTo(cx + 5, cy - 5, cx + 5, cy - 1, cx, cy + 3);
    canvas.drawPath(heart, Paint()..color = const Color(0xFFFF4444));
    // Drain particles
    canvas.drawCircle(Offset(cx - 8, cy - 2), 1.5, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx + 7, cy + 3), 1.5, Paint()..color = color.withValues(alpha: 0.5));
  }

  void _drawCorpseExplosion(Canvas canvas, double cx, double cy) {
    // Explosion burst
    final burstPaint = Paint()..color = color..strokeWidth = 2..style = PaintingStyle.stroke;
    // Central skull
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = const Color(0xFFd4d4c0));
    canvas.drawCircle(Offset(cx - 1.2, cy - 1), 0.8, Paint()..color = color);
    canvas.drawCircle(Offset(cx + 1.2, cy - 1), 0.8, Paint()..color = color);
    // Explosion rays
    for (var i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final inner = 5.0;
      final outer = 10.0 + (i % 2) * 2;
      canvas.drawLine(
        Offset(cx + cos(angle) * inner, cy + sin(angle) * inner),
        Offset(cx + cos(angle) * outer, cy + sin(angle) * outer),
        burstPaint,
      );
    }
    // Green explosion cloud
    canvas.drawCircle(Offset(cx, cy), 11, Paint()..color = color.withValues(alpha: 0.15)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Bone fragments
    canvas.drawLine(Offset(cx + 8, cy - 6), Offset(cx + 10, cy - 8), Paint()..color = const Color(0xFFd4d4c0)..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx - 7, cy + 5), Offset(cx - 9, cy + 8), Paint()..color = const Color(0xFFd4d4c0)..strokeWidth = 1.5);
  }

  void _drawDefault(Canvas canvas, double cx, double cy) {
    canvas.drawCircle(Offset(cx, cy), 8, Paint()..color = color.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _AbilityIconPainter oldDelegate) =>
      oldDelegate.abilityId != abilityId || oldDelegate.color != color;
}

/// Flutter overlay shown between rooms for ability selection.
class AbilitySelectOverlay extends StatefulWidget {
  const AbilitySelectOverlay({super.key, required this.game});

  final RiftclassGame game;

  @override
  State<AbilitySelectOverlay> createState() => _AbilitySelectOverlayState();
}

class _AbilitySelectOverlayState extends State<AbilitySelectOverlay> {
  late List<AbilityData> _options;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _generateOptions();
  }

  void _generateOptions() {
    final player = widget.game.player!;
    final pool = List<AbilityData>.from(player.classData.abilities);

    // Shuffle and pick 3 (or fewer if pool is small)
    pool.shuffle(_rng);
    _options = pool.take(3).toList();
  }

  void _selectAbility(AbilityData ability) {
    final player = widget.game.player!;

    // Check if player already has this ability
    final existing = player.acquiredAbilities
        .where((a) => a.data.id == ability.id)
        .toList();

    if (existing.isNotEmpty && !existing.first.isMaxed) {
      existing.first.upgrade();
    } else if (existing.isEmpty) {
      player.acquiredAbilities.add(AbilityState(ability));
    }

    widget.game.onAbilitySelected();
  }

  @override
  Widget build(BuildContext context) {
    final classColor = widget.game.player!.classData.color;

    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ROOM CLEARED!',
                style: TextStyle(
                  color: Color(0xFFfbbf24),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose an upgrade',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 28),
              ..._options.map((ability) {
                // Show current level if acquired
                final existing = widget.game.player!.acquiredAbilities
                    .where((a) => a.data.id == ability.id)
                    .toList();
                final currentLevel = existing.isNotEmpty ? existing.first.level : 0;
                final isUpgrade = currentLevel > 0;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 6),
                  child: GestureDetector(
                    onTap: () => _selectAbility(ability),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: classColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: classColor.withValues(alpha: 0.4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: classColor.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Ability icon - custom painted unique icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: classColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: classColor.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _AbilityIconPainter(
                                abilityId: ability.id,
                                color: classColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      ability.name,
                                      style: TextStyle(
                                        color: classColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (isUpgrade) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              classColor.withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Lv.${currentLevel + 1}',
                                          style: TextStyle(
                                            color: classColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ability.description,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
