import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config.dart';
import '../riftclass_game.dart';
import 'player.dart';

/// A dark, animated portal that appears after clearing a wave.
/// Player enters it to proceed to the next wave.
class DarkPortal extends PositionComponent
    with HasGameReference<RiftclassGame>, CollisionCallbacks {
  DarkPortal()
      : super(
          size: Vector2.all(80),
          anchor: Anchor.center,
          priority: 50,
        );

  double _time = 0;
  double _spawnAnim = 0; // 0→1 spawn-in animation
  bool _playerEntered = false;

  static const double _portalRadius = 32;

  @override
  Future<void> onLoad() async {
    position = Vector2(GameConfig.roomWidth / 2, GameConfig.roomHeight / 2);
    add(CircleHitbox(radius: 22)..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_spawnAnim < 1.0) {
      _spawnAnim = (_spawnAnim + dt * 1.5).clamp(0, 1);
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player && !_playerEntered) {
      _playerEntered = true;
      game.onPortalEntered();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_spawnAnim <= 0) return;

    final cx = size.x / 2;
    final cy = size.y / 2;
    final scale = _easeOutBack(_spawnAnim);
    final radius = _portalRadius * scale;

    canvas.save();
    canvas.translate(cx, cy);

    // ── Ground crack effect ──
    final crackPaint = Paint()
      ..color = Color.fromARGB((180 * scale).toInt(), 80, 0, 120)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4 + _time * 0.3;
      final len = radius + 6 + sin(_time * 2 + i) * 4;
      canvas.drawLine(Offset.zero, Offset(cos(angle) * len, sin(angle) * len), crackPaint);
    }

    // ── Outer dark aura ring ──
    canvas.drawCircle(
      Offset.zero, radius + 16,
      Paint()
        ..color = Color.fromARGB((60 * scale).toInt(), 100, 0, 180)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // ── Swirling ring particles ──
    final ringPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (var i = 0; i < 12; i++) {
      final angle = _time * 2.5 + i * (2 * pi / 12);
      final dist = radius + 4 + sin(_time * 3 + i * 0.8) * 3;
      final px = cos(angle) * dist;
      final py = sin(angle) * dist * 0.7; // squashed vertically (perspective)
      final alpha = (0.4 + sin(_time * 4 + i) * 0.2) * scale;
      ringPaint.color = Color.fromARGB(
        (alpha * 255).toInt(),
        120 + (sin(_time + i) * 40).toInt(),
        0,
        180 + (cos(_time + i) * 50).toInt(),
      );
      canvas.drawCircle(Offset(px, py), 3 + sin(_time * 2 + i) * 1, ringPaint);
    }

    // ── Main vortex (dark gradient circle) ──
    final vortexGrad = [
      const Color(0xFF000000),
      const Color(0xFF0a0020),
      const Color(0xFF1a0040),
      Color.fromARGB((200 * scale).toInt(), 80, 0, 160),
    ];
    final vortexPaint = Paint()
      ..shader = Gradient.radial(
        Offset.zero, radius,
        vortexGrad,
        [0.0, 0.4, 0.75, 1.0],
      );
    canvas.drawCircle(Offset.zero, radius, vortexPaint);

    // ── Inner spiral arms ──
    final spiralPaint = Paint()
      ..color = const Color(0x44a855f7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (var arm = 0; arm < 3; arm++) {
      final path = Path();
      for (var t = 0.0; t < 1.0; t += 0.05) {
        final angle = t * 4 * pi + _time * 3 + arm * (2 * pi / 3);
        final dist = t * radius * 0.85;
        final x = cos(angle) * dist;
        final y = sin(angle) * dist * 0.7;
        if (t == 0.0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, spiralPaint);
    }

    // ── Center bright core (pulsing) ──
    final corePulse = 1.0 + sin(_time * 5) * 0.2;
    canvas.drawCircle(
      Offset.zero, 6 * corePulse * scale,
      Paint()
        ..color = const Color(0xAAc084fc)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset.zero, 3 * corePulse * scale,
      Paint()..color = const Color(0xDDFFFFFF),
    );

    // ── Outer edge glow ring ──
    canvas.drawCircle(
      Offset.zero, radius,
      Paint()
        ..color = Color.fromARGB((120 * scale).toInt(), 160, 80, 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + sin(_time * 4) * 1
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // ── Floating souls/wisps being sucked in ──
    for (var i = 0; i < 5; i++) {
      final phase = _time * 1.5 + i * 1.2;
      final dist = radius + 20 - (phase % 3.0) / 3.0 * (radius + 20);
      final angle = phase * 2.5 + i * (2 * pi / 5);
      final wx = cos(angle) * dist;
      final wy = sin(angle) * dist * 0.65;
      final wAlpha = ((1.0 - dist / (radius + 20)) * 0.6 * scale).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(wx, wy), 2.5,
        Paint()
          ..color = Color.fromARGB((wAlpha * 255).toInt(), 200, 150, 255)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    canvas.restore();
  }

  double _easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
  }
}
