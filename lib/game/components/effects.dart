import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show TextDirection, TextPainter, TextSpan, TextStyle, FontWeight, Shadow;

/// Pooled VFX layer: particles, shockwave rings and floating damage numbers.
/// Everything is object-pooled and rendered in a single component to keep
/// per-frame allocations near zero (Archero-style juice without the lag).
class EffectsLayer extends Component {
  EffectsLayer({super.priority});

  static const int _maxParticles = 220;
  static const int _maxRings = 20;
  static const int _maxNumbers = 28;

  final List<_Particle> _particles =
      List.generate(_maxParticles, (_) => _Particle());
  final List<_Ring> _rings = List.generate(_maxRings, (_) => _Ring());
  final List<_DamageNumber> _numbers =
      List.generate(_maxNumbers, (_) => _DamageNumber());

  final Random _rng = Random();
  int _pIdx = 0;
  int _rIdx = 0;
  int _nIdx = 0;

  // Reused paints — never allocated in render.
  final Paint _fillPaint = Paint();
  final Paint _softPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  _Particle _claimParticle() {
    final p = _particles[_pIdx];
    _pIdx = (_pIdx + 1) % _maxParticles;
    return p;
  }

  // ── Spawn API ──

  /// Radial burst of sparks (impacts, hits).
  void burst(
    Vector2 pos,
    Color color, {
    int count = 8,
    double speed = 90,
    double size = 2.6,
    double life = 0.35,
    double gravity = 0,
    double spread = pi * 2,
    double baseAngle = 0,
    int shape = 0,
  }) {
    for (var i = 0; i < count; i++) {
      final p = _claimParticle();
      final a = baseAngle + (_rng.nextDouble() - 0.5) * spread;
      final v = speed * (0.5 + _rng.nextDouble() * 0.8);
      p
        ..active = true
        ..x = pos.x
        ..y = pos.y
        ..vx = cos(a) * v
        ..vy = sin(a) * v
        ..life = 0
        ..maxLife = life * (0.7 + _rng.nextDouble() * 0.6)
        ..size = size * (0.7 + _rng.nextDouble() * 0.7)
        ..endScale = 0.3
        ..gravity = gravity
        ..drag = 3.0
        ..color = color
        ..shape = shape
        ..rot = _rng.nextDouble() * pi * 2
        ..rotSpeed = (_rng.nextDouble() - 0.5) * 10;
    }
  }

  /// Big juicy death explosion: shards + glow flash + sparks.
  void deathBurst(Vector2 pos, Color color, double radius) {
    // Glow flash
    final flash = _claimParticle();
    flash
      ..active = true
      ..x = pos.x
      ..y = pos.y
      ..vx = 0
      ..vy = 0
      ..life = 0
      ..maxLife = 0.22
      ..size = radius * 1.6
      ..endScale = 1.8
      ..gravity = 0
      ..drag = 0
      ..color = color
      ..shape = 2
      ..rot = 0
      ..rotSpeed = 0;
    // Chunky shards with gravity
    burst(pos, color,
        count: (radius * 0.5).clamp(5, 12).toInt(),
        speed: 70 + radius * 2.5,
        size: radius * 0.22,
        life: 0.55,
        gravity: 260,
        shape: 1);
    // Bright sparks
    burst(pos, const Color(0xFFFFF0C8),
        count: 6, speed: 110 + radius * 2, size: 1.8, life: 0.3);
  }

  /// Soft dust puff (footsteps, landings).
  void dust(Vector2 pos, {Color color = const Color(0xFF8a8070)}) {
    for (var i = 0; i < 2; i++) {
      final p = _claimParticle();
      p
        ..active = true
        ..x = pos.x + (_rng.nextDouble() - 0.5) * 8
        ..y = pos.y + (_rng.nextDouble() - 0.5) * 3
        ..vx = (_rng.nextDouble() - 0.5) * 22
        ..vy = -8 - _rng.nextDouble() * 10
        ..life = 0
        ..maxLife = 0.4 + _rng.nextDouble() * 0.2
        ..size = 2.6 + _rng.nextDouble() * 2
        ..endScale = 2.2
        ..gravity = 0
        ..drag = 1.5
        ..color = color.withValues(alpha: 0.32)
        ..shape = 2
        ..rot = 0
        ..rotSpeed = 0;
    }
  }

  /// Expanding shockwave ring (ground-squashed ellipse by default).
  void ring(
    Vector2 pos,
    Color color, {
    double maxRadius = 40,
    double life = 0.35,
    double strokeWidth = 3,
    double squash = 0.45,
  }) {
    final r = _rings[_rIdx];
    _rIdx = (_rIdx + 1) % _maxRings;
    r
      ..active = true
      ..x = pos.x
      ..y = pos.y
      ..maxR = maxRadius
      ..life = 0
      ..maxLife = life
      ..color = color
      ..strokeW = strokeWidth
      ..squash = squash;
  }

  /// Floating damage / heal number.
  void damageNumber(
    Vector2 pos,
    double amount, {
    Color color = const Color(0xFFFFE08A),
    bool big = false,
  }) {
    final n = _numbers[_nIdx];
    _nIdx = (_nIdx + 1) % _maxNumbers;
    n
      ..active = true
      ..x = pos.x + (_rng.nextDouble() - 0.5) * 14
      ..y = pos.y
      ..vy = -42
      ..life = 0
      ..maxLife = 0.7
      ..value = amount
      ..color = color
      ..fontSize = (big ? 16.0 : 11.0) + (amount / 40).clamp(0.0, 5.0);
  }

  // ── Simulation ──

  @override
  void update(double dt) {
    super.update(dt);
    for (final p in _particles) {
      if (!p.active) continue;
      p.life += dt;
      if (p.life >= p.maxLife) {
        p.active = false;
        continue;
      }
      p.vy += p.gravity * dt;
      final dragF = (1 - p.drag * dt).clamp(0.0, 1.0);
      p.vx *= dragF;
      p.vy *= dragF;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.rotSpeed * dt;
    }
    for (final r in _rings) {
      if (!r.active) continue;
      r.life += dt;
      if (r.life >= r.maxLife) r.active = false;
    }
    for (final n in _numbers) {
      if (!n.active) continue;
      n.life += dt;
      if (n.life >= n.maxLife) {
        n.active = false;
        continue;
      }
      n.y += n.vy * dt;
      n.vy *= (1 - 2.2 * dt).clamp(0.0, 1.0);
    }
  }

  // ── Rendering ──

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    for (final p in _particles) {
      if (!p.active) continue;
      final t = p.life / p.maxLife;
      final alpha = (1 - t).clamp(0.0, 1.0);
      final s = p.size * (1 + (p.endScale - 1) * t);
      switch (p.shape) {
        case 1: // shard
          _fillPaint.color = p.color.withValues(
              alpha: alpha * (p.color.a == 1.0 ? 1.0 : p.color.a));
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rot);
          canvas.drawRect(
              Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s),
              _fillPaint);
          canvas.restore();
        case 2: // soft glow
          _softPaint.color = p.color.withValues(alpha: alpha * p.color.a);
          canvas.drawCircle(Offset(p.x, p.y), s, _softPaint);
        default: // spark
          _fillPaint.color = p.color.withValues(alpha: alpha * p.color.a);
          canvas.drawCircle(Offset(p.x, p.y), s, _fillPaint);
      }
    }

    for (final r in _rings) {
      if (!r.active) continue;
      final t = (r.life / r.maxLife).clamp(0.0, 1.0);
      final eased = 1 - pow(1 - t, 3).toDouble(); // easeOutCubic
      final radius = r.maxR * eased;
      _ringPaint
        ..color = r.color.withValues(alpha: (1 - t) * 0.8)
        ..strokeWidth = r.strokeW * (1 - t * 0.6);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(r.x, r.y),
          width: radius * 2,
          height: radius * 2 * r.squash,
        ),
        _ringPaint,
      );
    }

    for (final n in _numbers) {
      if (!n.active) continue;
      final t = n.life / n.maxLife;
      // Pop in, fade out at the end.
      final scale = t < 0.15 ? 0.6 + (t / 0.15) * 0.5 : 1.1 - (t - 0.15) * 0.15;
      final alpha = t > 0.6 ? (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0) : 1.0;
      final tp = TextPainter(
        text: TextSpan(
          text: n.value >= 1 ? n.value.toInt().toString() : '1',
          style: TextStyle(
            color: n.color.withValues(alpha: alpha),
            fontSize: n.fontSize,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: Color.fromARGB((200 * alpha).toInt(), 0, 0, 0),
                offset: const Offset(1, 1.5),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(n.x, n.y);
      canvas.scale(scale);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }
}

class _Particle {
  bool active = false;
  double x = 0, y = 0, vx = 0, vy = 0;
  double life = 0, maxLife = 1;
  double size = 2, endScale = 1;
  double gravity = 0, drag = 0;
  double rot = 0, rotSpeed = 0;
  int shape = 0; // 0 spark, 1 shard, 2 soft glow
  Color color = const Color(0xFFFFFFFF);
}

class _Ring {
  bool active = false;
  double x = 0, y = 0;
  double maxR = 40;
  double life = 0, maxLife = 0.35;
  double strokeW = 3;
  double squash = 0.45;
  Color color = const Color(0xFFFFFFFF);
}

class _DamageNumber {
  bool active = false;
  double x = 0, y = 0, vy = 0;
  double life = 0, maxLife = 0.7;
  double value = 0;
  double fontSize = 12;
  Color color = const Color(0xFFFFE08A);
}
