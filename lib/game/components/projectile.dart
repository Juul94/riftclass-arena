import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../config.dart';
import '../riftclass_game.dart';
import 'enemy.dart';
import 'player.dart';

/// Visual style of a projectile.
enum ProjectileStyle { arrow, frostBolt, swordSlash, soulBolt, generic }

/// A projectile that travels in a straight line, damaging the first
/// valid target it hits (or piercing through multiple).
class Projectile extends PositionComponent
    with HasGameReference<RiftclassGame>, CollisionCallbacks {
  Projectile({
    required Vector2 pos,
    required this.direction,
    required this.damage,
    required this.color,
    required this.fromPlayer,
    this.piercing = 0,
    this.style = ProjectileStyle.generic,
    double? speed,
  }) : _speed = speed ?? GameConfig.projectileSpeed,
       super(
          position: pos,
          size: Vector2.all(GameConfig.projectileRadius * 2),
          anchor: Anchor.center,
        );

  final Vector2 direction;
  final double damage;
  final Color color;
  final bool fromPlayer;
  final int piercing;
  final ProjectileStyle style;
  final double _speed;

  int _hitCount = 0;
  double _life = 0;
  static const double maxLife = 2.0;

  // ── Motion trail ──
  static const int _trailLen = 6;
  final List<Offset> _trail = [];
  final Paint _trailPaint = Paint();

  @override
  Future<void> onLoad() async {
    add(CircleHitbox()
      ..collisionType =
          fromPlayer ? CollisionType.active : CollisionType.active);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * _speed * dt;
    _life += dt;

    _trail.add(Offset(position.x, position.y));
    if (_trail.length > _trailLen) _trail.removeAt(0);

    if (_life > maxLife || _isOutOfBounds()) {
      removeFromParent();
    }
  }

  bool _isOutOfBounds() {
    return position.x < -20 ||
        position.x > GameConfig.roomWidth + 20 ||
        position.y < -20 ||
        position.y > GameConfig.roomHeight + 20;
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (fromPlayer && other is Enemy && !other.isDead) {
      if (damage > 0) {
        other.takeDamage(damage, knockback: direction);
        // Impact sparks spraying backwards from the hit
        game.effects.burst(
          position.clone(),
          color,
          count: 5,
          speed: 85,
          life: 0.25,
          spread: pi * 0.9,
          baseAngle: atan2(-direction.y, -direction.x),
        );
      }
      _hitCount++;
      if (_hitCount > piercing) {
        removeFromParent();
      }
    } else if (!fromPlayer && other is Player) {
      other.takeDamage(damage);
      game.effects.burst(
        position.clone(),
        color,
        count: 6,
        speed: 90,
        life: 0.25,
      );
      removeFromParent();
    }
  }

  // ── Rendering ──

  @override
  void render(Canvas canvas) {
    _renderTrail(canvas);
    switch (style) {
      case ProjectileStyle.arrow:
        _renderArrow(canvas);
      case ProjectileStyle.frostBolt:
        _renderFrostBolt(canvas);
      case ProjectileStyle.swordSlash:
        _renderSwordSlash(canvas);
      case ProjectileStyle.soulBolt:
        _renderSoulBolt(canvas);
      case ProjectileStyle.generic:
        _renderGeneric(canvas);
    }
  }

  /// Fading energy trail behind the projectile (local space conversion).
  void _renderTrail(Canvas canvas) {
    if (_trail.length < 2) return;
    final cx = size.x / 2;
    final cy = size.y / 2;
    for (var i = 0; i < _trail.length - 1; i++) {
      final t = (i + 1) / _trail.length;
      _trailPaint.color = color.withValues(alpha: 0.30 * t);
      canvas.drawCircle(
        Offset(
          _trail[i].dx - position.x + cx,
          _trail[i].dy - position.y + cy,
        ),
        3.2 * t,
        _trailPaint,
      );
    }
  }

  void _renderArrow(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final angle = atan2(direction.y, direction.x);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Arrow shaft
    canvas.drawLine(
      const Offset(-10, 0), const Offset(6, 0),
      Paint()..color = const Color(0xFF8B6914)..strokeWidth = 1.8,
    );

    // Arrowhead
    final head = Path()
      ..moveTo(10, 0)
      ..lineTo(5, -3)
      ..lineTo(6, 0)
      ..lineTo(5, 3)
      ..close();
    canvas.drawPath(head, Paint()..color = const Color(0xFFCCCCCC));

    // Fletching
    final fletch = Path()
      ..moveTo(-10, 0)
      ..lineTo(-8, -3)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(fletch, Paint()..color = color.withValues(alpha: 0.7));
    final fletch2 = Path()
      ..moveTo(-10, 0)
      ..lineTo(-8, 3)
      ..lineTo(-6, 0)
      ..close();
    canvas.drawPath(fletch2, Paint()..color = color.withValues(alpha: 0.7));

    // Trail glow
    canvas.drawLine(
      const Offset(-10, 0), const Offset(-4, 0),
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.restore();
  }

  void _renderFrostBolt(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final angle = atan2(direction.y, direction.x);

    // Frost glow
    canvas.drawCircle(
      Offset(cx, cy), 8,
      Paint()
        ..color = const Color(0xFF88CCFF).withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Ice crystal shape (elongated diamond)
    final crystal = Path()
      ..moveTo(8, 0)
      ..lineTo(2, -4)
      ..lineTo(-8, 0)
      ..lineTo(2, 4)
      ..close();
    canvas.drawPath(crystal, Paint()..color = const Color(0xFFa8e0ff));
    canvas.drawPath(crystal, Paint()..color = const Color(0xFFffffff).withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1);

    // Inner shard
    final inner = Path()
      ..moveTo(5, 0)
      ..lineTo(1, -2)
      ..lineTo(-4, 0)
      ..lineTo(1, 2)
      ..close();
    canvas.drawPath(inner, Paint()..color = const Color(0xFFd4f0ff));

    // Frost particles trailing
    canvas.drawCircle(const Offset(-6, -2), 1.5, Paint()..color = const Color(0xAAFFFFFF));
    canvas.drawCircle(const Offset(-8, 2), 1, Paint()..color = const Color(0x88FFFFFF));
    canvas.drawCircle(const Offset(-10, -1), 0.8, Paint()..color = const Color(0x66FFFFFF));

    canvas.restore();
  }

  void _renderSwordSlash(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final angle = atan2(direction.y, direction.x);

    // Slash glow
    canvas.drawCircle(
      Offset(cx, cy), 6,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Sword/energy slash arc
    final slash = Path()
      ..moveTo(8, 0)
      ..quadraticBezierTo(4, -6, -6, -4)
      ..lineTo(-4, -2)
      ..quadraticBezierTo(2, -3, 6, 0)
      ..close();
    canvas.drawPath(slash, Paint()..color = const Color(0xFFFFCC66));

    final slash2 = Path()
      ..moveTo(8, 0)
      ..quadraticBezierTo(4, 6, -6, 4)
      ..lineTo(-4, 2)
      ..quadraticBezierTo(2, 3, 6, 0)
      ..close();
    canvas.drawPath(slash2, Paint()..color = color.withValues(alpha: 0.7));

    // Bright edge
    canvas.drawLine(
      const Offset(-6, -4), const Offset(8, 0),
      Paint()..color = const Color(0xFFFFFFDD)..strokeWidth = 1.2,
    );

    canvas.restore();
  }

  void _renderSoulBolt(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Outer soul glow
    canvas.drawCircle(
      Offset(cx, cy), 10,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Wispy soul shape
    final angle = atan2(direction.y, direction.x);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);

    // Main wisp body
    final wisp = Path()
      ..moveTo(6, 0)
      ..quadraticBezierTo(3, -4, -2, -3)
      ..quadraticBezierTo(-6, -1, -8, 0)
      ..quadraticBezierTo(-6, 1, -2, 3)
      ..quadraticBezierTo(3, 4, 6, 0)
      ..close();
    canvas.drawPath(wisp, Paint()..color = color.withValues(alpha: 0.6));

    // Skull face in center
    canvas.drawCircle(const Offset(1, 0), 3, Paint()..color = color.withValues(alpha: 0.8));
    canvas.drawCircle(const Offset(0, -0.8), 0.8, Paint()..color = const Color(0xFF000000));
    canvas.drawCircle(const Offset(2, -0.8), 0.8, Paint()..color = const Color(0xFF000000));

    // Trail wisps
    canvas.drawCircle(const Offset(-6, -1), 1.5, Paint()..color = color.withValues(alpha: 0.3));
    canvas.drawCircle(const Offset(-9, 1), 1, Paint()..color = color.withValues(alpha: 0.2));

    canvas.restore();
  }

  void _renderGeneric(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final r = GameConfig.projectileRadius;

    canvas.drawCircle(
      center, r * 2.5,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(center, r, Paint()..color = color);
    canvas.drawCircle(center, r * 0.4, Paint()..color = const Color(0xFFFFFFFF));
  }
}
