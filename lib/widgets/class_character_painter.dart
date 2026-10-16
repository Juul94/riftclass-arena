import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/player_class.dart';

/// Shared painter for all four classes. Designed as flowing silhouettes
/// (not stacked primitives) with one bold accent color, expressive face,
/// and gentle floating motion. Internal coordinates are centered on
/// `(0, 0)` with feet around `y = 30` and head top around `y = -40`.
void paintClassCharacter(
  Canvas canvas, {
  required PlayerClassName className,
  required Color color,
  required Offset center,
  double scale = 1,
  double phase = 0,
  double attack = 0,
  bool moving = false,
  bool includeGround = false,
  bool flashing = false,
}) {
  _Renderer(
    className: className,
    accent: flashing ? const Color(0xFFFF5566) : color,
    phase: phase,
    attack: attack,
    moving: moving,
  ).paint(canvas, center, scale, includeGround);
}

class _Renderer {
  _Renderer({
    required this.className,
    required this.accent,
    required this.phase,
    required this.attack,
    required this.moving,
  });

  final PlayerClassName className;
  final Color accent;
  final double phase;
  final double attack;
  final bool moving;

  // ── Motion ──
  double get _bob => moving
      ? sin(phase * 3.0) * 0.8
      : sin(phase * 1.3) * 1.5;
  double get _sway => moving
      ? sin(phase * 3.0 + 0.4) * 0.025
      : sin(phase * 0.9) * 0.014;
  double get _windA => sin(phase * 1.6) * 1.6;
  double get _windB => sin(phase * 1.6 + 0.8) * 1.2;
  double get _pulse => (sin(phase * 1.8) + 1) * 0.5;

  Paint _fill(Color c) => Paint()
    ..isAntiAlias = true
    ..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..isAntiAlias = true
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w;

  Paint _shader(Shader s) => Paint()
    ..isAntiAlias = true
    ..shader = s;

  Paint _glow(Color c, double sigma) => Paint()
    ..isAntiAlias = true
    ..color = c
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  // ═══════════════════════════════════════════════
  //  ENTRY
  // ═══════════════════════════════════════════════
  void paint(Canvas canvas, Offset center, double scale, bool includeGround) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    if (includeGround) {
      _aura(canvas);
      _ground(canvas);
    }

    canvas.save();
    canvas.translate(0, _bob);
    canvas.rotate(_sway);
    switch (className) {
      case PlayerClassName.archer:
        _archer(canvas);
      case PlayerClassName.mage:
        _mage(canvas);
      case PlayerClassName.warrior:
        _warrior(canvas);
      case PlayerClassName.necromancer:
        _necromancer(canvas);
    }
    canvas.restore();
    canvas.restore();
  }

  // ═══════════════════════════════════════════════
  //  BACKDROP
  // ═══════════════════════════════════════════════
  void _aura(Canvas canvas) {
    canvas.drawCircle(
      const Offset(0, -4),
      36,
      _glow(accent.withValues(alpha: 0.10 + _pulse * 0.05), 22),
    );
  }

  void _ground(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 33), width: 44, height: 9),
      _glow(const Color(0x55000000), 3),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 31), width: 52, height: 12),
      _stroke(accent.withValues(alpha: 0.28), 1.2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 31), width: 32, height: 7),
      _stroke(accent.withValues(alpha: 0.18), 0.8),
    );
  }

  // ═══════════════════════════════════════════════
  //  ARCHER — forest hunter, hooded, side-held bow
  // ═══════════════════════════════════════════════
  void _archer(Canvas canvas) {
    const cloak = Color(0xFF234A35);
    const cloakDeep = Color(0xFF132A1F);
    const tunic = Color(0xFF3A6248);
    const skin = Color(0xFFE6B98A);
    const leather = Color(0xFF2E1C13);

    final breath = sin(phase * 1.3) * 0.4;
    final draw = (attack * 6) + sin(phase * 2.2) * 0.6;

    // Body silhouette — tunic + skirt/legs as one flowing shape
    final body = Path()
      ..moveTo(-13, -10)
      ..cubicTo(-15, -2, -16, 14, -14, 28)
      ..quadraticBezierTo(0, 32, 14, 28)
      ..cubicTo(16, 14, 15, -2, 13, -10)
      ..cubicTo(7, -14, -7, -14, -13, -10)
      ..close();
    canvas.drawPath(
      body,
      _shader(
        ui.Gradient.linear(
          const Offset(0, -10),
          const Offset(0, 30),
          [tunic, cloak, cloakDeep],
          [0, 0.55, 1],
        ),
      ),
    );

    // Side cape ribbon (flowing behind)
    final cape = Path()
      ..moveTo(11, -8)
      ..cubicTo(20 + _windA, 4, 22 + _windA, 18, 16 + _windB, 28)
      ..quadraticBezierTo(8, 26, 7, 18)
      ..cubicTo(8, 8, 9, -2, 11, -8)
      ..close();
    canvas.drawPath(cape, _fill(cloakDeep.withValues(alpha: 0.9)));

    // Sash / belt
    canvas.drawPath(
      Path()
        ..moveTo(-13, 6)
        ..quadraticBezierTo(0, 9, 13, 6)
        ..lineTo(12, 11)
        ..quadraticBezierTo(0, 14, -12, 11)
        ..close(),
      _fill(leather),
    );
    canvas.drawCircle(Offset(0, 9 + breath * 0.2), 2.2, _fill(accent));
    canvas.drawCircle(
      Offset(-0.6, 8.4 + breath * 0.2),
      0.8,
      _fill(Colors.white.withValues(alpha: 0.6)),
    );

    // Bow — held to the side, slight outward angle
    canvas.save();
    canvas.translate(-18, -1);
    canvas.rotate(-0.18);
    _bow(canvas, draw);
    canvas.restore();

    // Front arm (just a small skin oval — keeps silhouette clean)
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-12, 2), width: 8, height: 10),
      _fill(skin),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-12, 2), width: 8, height: 10),
      _stroke(_darken(skin, 0.18), 0.6),
    );

    // Head + hood
    _head(canvas, Offset(0, -23 + breath), skin: skin);
    _archerHood(canvas, Offset(0, -23 + breath), cloak: cloak, deep: cloakDeep);

    // Quiver strap across body
    canvas.drawLine(
      const Offset(-10, -2),
      const Offset(11, 12),
      _stroke(leather, 1.6),
    );

    // Quiver tips peeking over shoulder
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(8 + i * 2.2, -8),
        Offset(7 + i * 2.2, -14),
        _stroke(accent.withValues(alpha: 0.85), 1.2),
      );
      canvas.drawCircle(
        Offset(7 + i * 2.2, -14.5),
        0.9,
        _fill(_lighten(accent, 0.2)),
      );
    }
  }

  void _bow(Canvas canvas, double draw) {
    // Wood arc
    final arc = Rect.fromCenter(
      center: const Offset(0, 0),
      width: 14,
      height: 44,
    );
    canvas.drawArc(arc, -1.55, 3.1, false, _stroke(const Color(0xFF1F1009), 4));
    canvas.drawArc(
      arc,
      -1.55,
      3.1,
      false,
      _stroke(const Color(0xFF5B3A24), 2.4),
    );
    canvas.drawArc(
      arc,
      -1.55,
      3.1,
      false,
      _stroke(accent.withValues(alpha: 0.55), 1.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Bow string — pulled back toward player when drawing
    const tipTop = Offset(0, -22);
    const tipBot = Offset(0, 22);
    final pull = Offset(2 + draw, 0);
    canvas.drawLine(tipTop, pull, _stroke(const Color(0xCCF0E6CC), 0.9));
    canvas.drawLine(pull, tipBot, _stroke(const Color(0xCCF0E6CC), 0.9));

    // Glowing arrow on string
    canvas.drawLine(
      pull,
      pull.translate(14, 0),
      _stroke(accent.withValues(alpha: 0.85), 1.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawCircle(
      pull.translate(14.5, 0),
      2,
      _fill(_lighten(accent, 0.2)),
    );
  }

  void _archerHood(
    Canvas canvas,
    Offset c, {
    required Color cloak,
    required Color deep,
  }) {
    // Hood as a soft horseshoe behind & above the head
    final hood = Path()
      ..moveTo(c.dx - 14, c.dy + 3)
      ..cubicTo(c.dx - 17, c.dy - 10, c.dx - 11, c.dy - 19, c.dx, c.dy - 21)
      ..cubicTo(c.dx + 11, c.dy - 19, c.dx + 17, c.dy - 10, c.dx + 14, c.dy + 3)
      ..cubicTo(c.dx + 9, c.dy + 6, c.dx - 9, c.dy + 6, c.dx - 14, c.dy + 3)
      ..close();
    canvas.drawPath(
      hood,
      _shader(
        ui.Gradient.linear(
          Offset(c.dx, c.dy - 22),
          Offset(c.dx, c.dy + 6),
          [cloak, deep],
        ),
      ),
    );
    // Inner shadow rim
    canvas.drawArc(
      Rect.fromCenter(center: c.translate(0, -2), width: 22, height: 22),
      -2.4,
      1.6,
      false,
      _stroke(_darken(deep, 0.2).withValues(alpha: 0.7), 2.4),
    );
  }

  // ═══════════════════════════════════════════════
  //  MAGE — arcane caster, full robe, glowing staff
  // ═══════════════════════════════════════════════
  void _mage(Canvas canvas) {
    const robe = Color(0xFF1A2C4D);
    const robeDeep = Color(0xFF0A1426);

    final cast = sin(phase * 2.0) * 1.2 + attack * 2;

    // Full-length robe silhouette
    final body = Path()
      ..moveTo(-12, -10)
      ..cubicTo(-18, 0, -20, 16, -16 + _windA * 0.3, 30)
      ..quadraticBezierTo(0, 33, 16 + _windB * 0.3, 30)
      ..cubicTo(20, 16, 18, 0, 12, -10)
      ..cubicTo(7, -13, -7, -13, -12, -10)
      ..close();
    canvas.drawPath(
      body,
      _shader(
        ui.Gradient.linear(
          const Offset(0, -12),
          const Offset(0, 32),
          [robe, _darken(robe, 0.1), robeDeep],
          [0, 0.55, 1],
        ),
      ),
    );

    // Glowing robe trim down the front
    final trim = Path()
      ..moveTo(0, -8)
      ..cubicTo(-1, 6, -2, 18, -0.5, 30);
    canvas.drawPath(
      trim,
      _stroke(accent.withValues(alpha: 0.55 + _pulse * 0.15), 1.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    // Hem accent
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, 30), width: 34, height: 8),
      -pi,
      pi,
      false,
      _stroke(accent.withValues(alpha: 0.45), 1.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // Belt with gem
    canvas.drawPath(
      Path()
        ..moveTo(-13, 6)
        ..quadraticBezierTo(0, 9, 13, 6)
        ..lineTo(12, 11)
        ..quadraticBezierTo(0, 14, -12, 11)
        ..close(),
      _fill(const Color(0xFF2A1A12)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 9), width: 7, height: 5),
      _shader(
        ui.Gradient.radial(
          const Offset(-1, 8),
          5,
          [Colors.white, accent, _darken(accent, 0.3)],
          [0, 0.45, 1],
        ),
      ),
    );

    // Sleeve hint on free hand — small extension off body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-13, 4 + cast * 0.6),
        width: 10,
        height: 9,
      ),
      _fill(robeDeep),
    );

    // Staff held on right side (taller than figure)
    canvas.save();
    canvas.translate(15, -2);
    canvas.rotate(0.06);
    _staff(
      canvas,
      top: const Offset(2, -36),
      bottom: const Offset(0, 28),
      withOrb: true,
    );
    canvas.restore();

    // Cast sparkles near free hand
    for (var i = 0; i < 3; i++) {
      final a = phase * 2 + i * 2.1;
      final r = 5.0 + i * 1.5;
      canvas.drawCircle(
        Offset(-13 + cos(a) * r, 4 + cast * 0.6 + sin(a) * r * 0.6),
        1.3,
        _glow(accent.withValues(alpha: 0.55), 2.4),
      );
    }

    // Head: deep hood, glowing eyes
    _hood(canvas, const Offset(0, -22), robe, robeDeep);
    _hoodEyes(canvas, const Offset(0, -22));
  }

  // ═══════════════════════════════════════════════
  //  WARRIOR — heavy knight, big helmet, sword + shield
  // ═══════════════════════════════════════════════
  void _warrior(Canvas canvas) {
    const plate = Color(0xFF7E8794);
    const plateDeep = Color(0xFF3A414D);
    const plateDark = Color(0xFF252A33);
    const leather = Color(0xFF2D1E16);

    final swing = attack * 1.2 + sin(phase * 1.1) * 0.06;

    // Body silhouette — plate skirt fused with torso
    final body = Path()
      ..moveTo(-15, -8)
      ..cubicTo(-17, 0, -18, 14, -16, 28)
      ..quadraticBezierTo(0, 32, 16, 28)
      ..cubicTo(18, 14, 17, 0, 15, -8)
      ..cubicTo(8, -12, -8, -12, -15, -8)
      ..close();
    canvas.drawPath(
      body,
      _shader(
        ui.Gradient.linear(
          const Offset(0, -10),
          const Offset(0, 30),
          [plate, plateDeep, plateDark],
          [0, 0.55, 1],
        ),
      ),
    );

    // Chest crest emblem
    final crest = Path()
      ..moveTo(-6, -3)
      ..lineTo(0, 9)
      ..lineTo(6, -3);
    canvas.drawPath(
      crest,
      _stroke(accent.withValues(alpha: 0.75), 2.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );

    // Belt
    canvas.drawPath(
      Path()
        ..moveTo(-15, 14)
        ..quadraticBezierTo(0, 17, 15, 14)
        ..lineTo(14, 19)
        ..quadraticBezierTo(0, 22, -14, 19)
        ..close(),
      _fill(leather),
    );

    // Pauldrons — single rounded curve, no rivets, no stacking
    _pauldron(canvas, const Offset(-13, -8), -1, plate, plateDeep);
    _pauldron(canvas, const Offset(13, -8), 1, plate, plateDeep);

    // Shield on left arm
    _shield(canvas, const Offset(-19, 4));

    // Sword on right, raised
    canvas.save();
    canvas.translate(18, 0);
    canvas.rotate(-0.5 + swing);
    _sword(canvas);
    canvas.restore();

    // Helmet on top — single sleek dome silhouette
    _helmet(canvas, const Offset(0, -23));
  }

  void _pauldron(Canvas canvas, Offset c, double side, Color base, Color deep) {
    final path = Path()
      ..moveTo(c.dx - side * 7, c.dy + 2)
      ..cubicTo(
        c.dx - side * 7,
        c.dy - 7,
        c.dx + side * 6,
        c.dy - 9,
        c.dx + side * 9,
        c.dy - 3,
      )
      ..cubicTo(
        c.dx + side * 10,
        c.dy + 3,
        c.dx + side * 5,
        c.dy + 6,
        c.dx - side * 7,
        c.dy + 2,
      )
      ..close();
    canvas.drawPath(
      path,
      _shader(
        ui.Gradient.linear(
          Offset(c.dx, c.dy - 8),
          Offset(c.dx, c.dy + 6),
          [_lighten(base, 0.1), deep],
        ),
      ),
    );
    canvas.drawCircle(
      Offset(c.dx + side * 6, c.dy - 4),
      1.6,
      _fill(accent.withValues(alpha: 0.85)),
    );
  }

  void _shield(Canvas canvas, Offset c) {
    final shield = Path()
      ..moveTo(c.dx, c.dy - 14)
      ..cubicTo(c.dx - 11, c.dy - 12, c.dx - 13, c.dy - 1, c.dx - 9, c.dy + 10)
      ..cubicTo(c.dx - 5, c.dy + 17, c.dx, c.dy + 19, c.dx, c.dy + 19)
      ..cubicTo(c.dx, c.dy + 19, c.dx + 5, c.dy + 17, c.dx + 9, c.dy + 10)
      ..cubicTo(c.dx + 13, c.dy - 1, c.dx + 11, c.dy - 12, c.dx, c.dy - 14)
      ..close();
    canvas.drawPath(
      shield,
      _shader(
        ui.Gradient.linear(
          Offset(c.dx - 6, c.dy - 12),
          Offset(c.dx + 6, c.dy + 16),
          [
            const Color(0xFF98A0AC),
            const Color(0xFF4A5260),
            const Color(0xFF252A33),
          ],
          [0, 0.55, 1],
        ),
      ),
    );
    canvas.drawPath(shield, _stroke(const Color(0xFFB5BCC6), 1.2));
    // Boss + accent
    canvas.drawCircle(c, 4.5, _fill(accent.withValues(alpha: 0.9)));
    canvas.drawCircle(
      c.translate(-1, -1),
      1.4,
      _fill(Colors.white.withValues(alpha: 0.5)),
    );
  }

  void _sword(Canvas canvas) {
    // Blade as a single elegant teardrop
    final blade = Path()
      ..moveTo(0, -34)
      ..cubicTo(-3, -28, -4, -10, -3, 6)
      ..quadraticBezierTo(0, 9, 3, 6)
      ..cubicTo(4, -10, 3, -28, 0, -34)
      ..close();
    canvas.drawPath(
      blade,
      _shader(
        ui.Gradient.linear(
          const Offset(-4, -30),
          const Offset(4, 6),
          [
            const Color(0xFFC8CFDA),
            const Color(0xFFEFF2F6),
            const Color(0xFF7A8290),
          ],
          [0, 0.4, 1],
        ),
      ),
    );
    // Fuller glow
    canvas.drawLine(
      const Offset(0, -30),
      const Offset(0, 4),
      _stroke(accent.withValues(alpha: 0.55), 1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
    // Crossguard
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, 5, 20, 5),
        const Radius.circular(2.5),
      ),
      _fill(const Color(0xFF564753)),
    );
    // Grip
    canvas.drawRect(
      const Rect.fromLTWH(-2, 9, 4, 9),
      _fill(const Color(0xFF2E1E15)),
    );
    // Pommel
    canvas.drawCircle(
      const Offset(0, 19),
      2.6,
      _fill(_lighten(accent, 0.05)),
    );
  }

  void _helmet(Canvas canvas, Offset c) {
    // Single smooth dome
    final dome = Path()
      ..moveTo(c.dx - 13, c.dy + 6)
      ..cubicTo(c.dx - 15, c.dy - 6, c.dx - 11, c.dy - 18, c.dx, c.dy - 19)
      ..cubicTo(c.dx + 11, c.dy - 18, c.dx + 15, c.dy - 6, c.dx + 13, c.dy + 6)
      ..cubicTo(c.dx + 9, c.dy + 10, c.dx - 9, c.dy + 10, c.dx - 13, c.dy + 6)
      ..close();
    canvas.drawPath(
      dome,
      _shader(
        ui.Gradient.linear(
          Offset(c.dx - 6, c.dy - 18),
          Offset(c.dx + 6, c.dy + 10),
          [
            const Color(0xFFA9B0BB),
            const Color(0xFF5C6470),
            const Color(0xFF2E343F),
          ],
          [0, 0.5, 1],
        ),
      ),
    );
    canvas.drawPath(dome, _stroke(const Color(0xFFC5CAD3), 1));
    // Visor slit — single horizontal line w/ glow
    canvas.drawLine(
      Offset(c.dx - 7, c.dy - 2),
      Offset(c.dx + 7, c.dy - 2),
      _stroke(const Color(0xFF1A1F28), 3),
    );
    canvas.drawLine(
      Offset(c.dx - 6, c.dy - 2),
      Offset(c.dx + 6, c.dy - 2),
      _stroke(accent.withValues(alpha: 0.95), 1.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    // Subtle nose ridge
    canvas.drawLine(
      Offset(c.dx, c.dy - 1),
      Offset(c.dx, c.dy + 7),
      _stroke(const Color(0xFF373D48), 1.2),
    );
  }

  // ═══════════════════════════════════════════════
  //  NECROMANCER — tattered robe, skull, soul wisps
  // ═══════════════════════════════════════════════
  void _necromancer(Canvas canvas) {
    const robe = Color(0xFF241338);
    const robeDeep = Color(0xFF0A0414);

    // Tattered robe — silhouette with ragged hem
    final body = Path()
      ..moveTo(-12, -10)
      ..cubicTo(-18, 0, -20, 14, -16 + _windA, 26);
    for (var i = 0; i <= 6; i++) {
      final x = -16 + i * (32 / 6) + _windA * (1 - i / 6) * 0.4;
      final y = 28 + (i.isEven ? 4 : 0) + sin(phase * 2 + i) * 0.6;
      body.lineTo(x, y);
    }
    body
      ..cubicTo(20, 14, 18, 0, 12, -10)
      ..cubicTo(7, -13, -7, -13, -12, -10)
      ..close();
    canvas.drawPath(
      body,
      _shader(
        ui.Gradient.linear(
          const Offset(0, -12),
          const Offset(0, 30),
          [robe, _darken(robe, 0.08), robeDeep],
          [0, 0.5, 1],
        ),
      ),
    );

    // Rib-cage cross strap
    canvas.drawLine(
      const Offset(-10, -2),
      const Offset(8, 10),
      _stroke(const Color(0xFF3A2A18), 1.6),
    );
    canvas.drawLine(
      const Offset(10, -2),
      const Offset(-8, 10),
      _stroke(const Color(0xFF3A2A18), 1.6),
    );

    // Wisps orbiting (drawn before head so they stay behind)
    for (var i = 0; i < 5; i++) {
      final a = phase * 0.9 + i * (2 * pi / 5);
      final r = 22 + sin(phase + i) * 2.5;
      final wx = cos(a) * r;
      final wy = -2 + sin(a) * r * 0.45;
      canvas.drawCircle(
        Offset(wx, wy),
        4.5,
        _glow(accent.withValues(alpha: 0.18), 4.5),
      );
      canvas.drawCircle(
        Offset(wx, wy),
        1.6,
        _fill(_lighten(accent, 0.25)),
      );
    }

    // Staff on left side
    canvas.save();
    canvas.translate(-15, -2);
    canvas.rotate(-0.06);
    _staff(
      canvas,
      top: const Offset(-2, -36),
      bottom: const Offset(0, 28),
      withSkull: true,
    );
    canvas.restore();

    // Head: deep hood, then skull face
    _hood(canvas, const Offset(0, -22), robe, robeDeep);
    _skullFace(canvas, const Offset(0, -22));
  }

  // ═══════════════════════════════════════════════
  //  SHARED HEAD / FACE
  // ═══════════════════════════════════════════════
  void _head(Canvas canvas, Offset c, {required Color skin}) {
    final rect = Rect.fromCenter(center: c, width: 22, height: 24);
    canvas.drawOval(
      rect,
      _shader(
        ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [_lighten(skin, 0.1), skin, _darken(skin, 0.12)],
          [0, 0.5, 1],
        ),
      ),
    );

    // Eyes
    for (final side in [-1.0, 1.0]) {
      final eye = c.translate(side * 4.2, -1);
      final shape = Path()
        ..moveTo(eye.dx - 2.6, eye.dy)
        ..quadraticBezierTo(eye.dx, eye.dy - 2.2, eye.dx + 2.6, eye.dy)
        ..quadraticBezierTo(eye.dx, eye.dy + 1.6, eye.dx - 2.6, eye.dy)
        ..close();
      canvas.drawPath(shape, _fill(const Color(0xFFF8F2E6)));
      canvas.drawCircle(
        eye.translate(side * 0.3, 0.2),
        1.4,
        _fill(_darken(accent, 0.25)),
      );
      canvas.drawCircle(
        eye.translate(side * 0.3, 0.2),
        0.6,
        _fill(const Color(0xFF12100C)),
      );
      canvas.drawCircle(
        eye.translate(-0.5, -0.6),
        0.4,
        _fill(Colors.white.withValues(alpha: 0.9)),
      );
    }

    // Mouth
    final mouth = Path()
      ..moveTo(c.dx - 1.6, c.dy + 5)
      ..quadraticBezierTo(c.dx, c.dy + 5.8, c.dx + 1.6, c.dy + 5);
    canvas.drawPath(mouth, _stroke(const Color(0xFF8E5246), 0.9));

    // Cheek blush
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-5, 2.5), width: 4, height: 2.2),
      _fill(const Color(0x18FF6B7A)),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(5, 2.5), width: 4, height: 2.2),
      _fill(const Color(0x18FF6B7A)),
    );
  }

  void _hood(Canvas canvas, Offset c, Color top, Color deep) {
    final hood = Path()
      ..moveTo(c.dx - 16, c.dy + 8)
      ..cubicTo(c.dx - 19, c.dy - 8, c.dx - 13, c.dy - 23, c.dx, c.dy - 24)
      ..cubicTo(c.dx + 13, c.dy - 23, c.dx + 19, c.dy - 8, c.dx + 16, c.dy + 8)
      ..cubicTo(c.dx + 9, c.dy + 11, c.dx - 9, c.dy + 11, c.dx - 16, c.dy + 8)
      ..close();
    canvas.drawPath(
      hood,
      _shader(
        ui.Gradient.linear(
          Offset(c.dx, c.dy - 22),
          Offset(c.dx, c.dy + 10),
          [_lighten(top, 0.05), top, deep],
          [0, 0.55, 1],
        ),
      ),
    );
    // Inner face cavity shadow
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(0, -1), width: 19, height: 21),
      _fill(const Color(0xFF03060E)),
    );
  }

  void _hoodEyes(Canvas canvas, Offset c) {
    final pulse = 0.7 + sin(phase * 2.6) * 0.25;
    for (final side in [-1.0, 1.0]) {
      final eye = c.translate(side * 3.6, -1);
      canvas.drawCircle(
        eye,
        4,
        _glow(accent.withValues(alpha: 0.35 * pulse), 4),
      );
      canvas.drawCircle(eye, 1.4, _fill(_lighten(accent, 0.25)));
    }
  }

  void _skullFace(Canvas canvas, Offset c) {
    final rect = Rect.fromCenter(
      center: c.translate(0, -1),
      width: 20,
      height: 22,
    );
    canvas.drawOval(
      rect,
      _shader(
        ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [
            const Color(0xFFEAE2CB),
            const Color(0xFFBAB098),
            const Color(0xFF8B8270),
          ],
          [0, 0.55, 1],
        ),
      ),
    );

    for (final side in [-1.0, 1.0]) {
      final eye = c.translate(side * 4, -3);
      canvas.drawOval(
        Rect.fromCenter(center: eye, width: 6.5, height: 7.5),
        _fill(const Color(0xFF050407)),
      );
      canvas.drawCircle(
        eye,
        2.6,
        _glow(accent.withValues(alpha: 0.6), 3),
      );
      canvas.drawCircle(
        eye,
        1,
        _fill(Colors.white.withValues(alpha: 0.85)),
      );
    }

    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 1.4, c.dy + 1.4)
        ..lineTo(c.dx, c.dy + 4.4)
        ..lineTo(c.dx + 1.4, c.dy + 1.4)
        ..close(),
      _fill(const Color(0xFF1F1B17)),
    );

    canvas.drawLine(
      c.translate(-4.2, 7.2),
      c.translate(4.2, 7.2),
      _stroke(const Color(0xFF564E40), 1.4),
    );
    for (var i = -2; i <= 2; i++) {
      canvas.drawLine(
        c.translate(i * 1.8, 6.4),
        c.translate(i * 1.8, 8.0),
        _stroke(const Color(0xFF6F6754), 0.6),
      );
    }
  }

  // ═══════════════════════════════════════════════
  //  SHARED STAFF / ORB / SKULL TOP
  // ═══════════════════════════════════════════════
  void _staff(
    Canvas canvas, {
    required Offset top,
    required Offset bottom,
    bool withOrb = false,
    bool withSkull = false,
  }) {
    final tipSway = Offset(sin(phase * 1.4) * 0.6, 0);
    final t = top + tipSway;
    canvas.drawLine(t, bottom, _stroke(const Color(0xFF1B0F0A), 4.2));
    canvas.drawLine(t, bottom, _stroke(const Color(0xFF55382A), 2.4));
    // Grip wrap mid-staff
    final gripA = Offset(
      t.dx + (bottom.dx - t.dx) * 0.55,
      t.dy + (bottom.dy - t.dy) * 0.55,
    );
    final gripB = Offset(
      t.dx + (bottom.dx - t.dx) * 0.7,
      t.dy + (bottom.dy - t.dy) * 0.7,
    );
    canvas.drawLine(gripA, gripB, _stroke(const Color(0xFF2A1A11), 4));

    if (withOrb) {
      _orb(canvas, t.translate(0, -2), 7);
    }
    if (withSkull) {
      _miniSkull(canvas, t.translate(0, -4));
    }
  }

  void _orb(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(
      c,
      r + 6,
      _glow(accent.withValues(alpha: 0.25 + _pulse * 0.12), 9),
    );
    canvas.drawCircle(
      c,
      r,
      _shader(
        ui.Gradient.radial(
          c.translate(-r * 0.3, -r * 0.35),
          r * 1.1,
          [
            Colors.white.withValues(alpha: 0.95),
            accent,
            _darken(accent, 0.3),
          ],
          [0, 0.4, 1],
        ),
      ),
    );
    canvas.drawCircle(
      c.translate(-r * 0.35, -r * 0.4),
      r * 0.22,
      _fill(Colors.white.withValues(alpha: 0.7)),
    );
  }

  void _miniSkull(Canvas canvas, Offset c) {
    final rect = Rect.fromCenter(center: c, width: 13, height: 14);
    canvas.drawOval(
      rect,
      _shader(
        ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [const Color(0xFFEAE2CB), const Color(0xFFA29879)],
        ),
      ),
    );
    for (final side in [-1.0, 1.0]) {
      final eye = c.translate(side * 2.7, -1);
      canvas.drawCircle(eye, 1.8, _fill(const Color(0xFF0A0810)));
      canvas.drawCircle(
        eye,
        1.6,
        _glow(accent.withValues(alpha: 0.7), 1.6),
      );
    }
    canvas.drawLine(
      c.translate(-2.4, 4.4),
      c.translate(2.4, 4.4),
      _stroke(const Color(0xFF4E483B), 0.9),
    );
  }

  // ═══════════════════════════════════════════════
  //  COLOR UTILS
  // ═══════════════════════════════════════════════
  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
