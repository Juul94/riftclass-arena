import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import '../../models/enemy_type.dart';
import '../config.dart';
import '../riftclass_game.dart';
import 'player.dart';
import 'projectile.dart';

/// An enemy entity with simple AI and custom isometric rendering.
class Enemy extends PositionComponent
    with HasGameReference<RiftclassGame>, CollisionCallbacks {
  Enemy({
    required this.data,
    required Vector2 pos,
  }) : super(
          position: pos,
          size: Vector2.all(data.radius * 2),
          anchor: Anchor.center,
        );

  final EnemyTypeData data;

  late double health;
  late double maxHealth;
  bool isDead = false;
  double _attackCooldown = 0;
  double _flashTimer = 0;
  double _deathTimer = 0;
  double _slowTimer = 0; // when >0, movement speed halved

  // ── Juice ──
  double _time = 0;
  double _spawnAnim = 0; // 0→1 spawn pop-in
  late final double _bobPhase = Random().nextDouble() * pi * 2;
  final Vector2 _knockback = Vector2.zero();

  // Ranged enemies: preferred distance
  late double _preferredDist;

  @override
  Future<void> onLoad() async {
    maxHealth = data.health;
    health = maxHealth;
    _preferredDist = data.kind == EnemyKind.ranged
        ? data.attackRange * 0.7
        : 0;

    add(CircleHitbox()..collisionType = CollisionType.passive);

    // Spawn-in telegraph ring on the ground
    game.groundFx.ring(
      position + Vector2(0, data.radius * 0.45),
      _enemyColor,
      maxRadius: data.radius * 2.2,
      life: 0.45,
      strokeWidth: 2.5,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;

    if (_flashTimer > 0) _flashTimer -= dt;
    if (_slowTimer > 0) _slowTimer -= dt;

    // Death fade‑out
    if (isDead) {
      _deathTimer -= dt;
      if (_deathTimer <= 0) removeFromParent();
      return;
    }

    // Spawn pop-in: no AI until fully materialized
    if (_spawnAnim < 1) {
      _spawnAnim = (_spawnAnim + dt / 0.35).clamp(0.0, 1.0);
      priority = position.y.toInt();
      return;
    }

    // Knockback impulse decay
    if (_knockback.length2 > 1) {
      position += _knockback * dt;
      _knockback.scale((1 - dt * 8).clamp(0.0, 1.0));
    }

    final player = game.player;
    if (player == null) return;

    final toPlayer = player.position - position;
    final dist = toPlayer.length;

    // Speed modifier (slow debuff)
    final speedMod = _slowTimer > 0 ? 0.3 : 1.0;

    // ── Movement AI ──
    switch (data.kind) {
      case EnemyKind.melee:
      case EnemyKind.boss:
        if (dist > data.attackRange) {
          position += toPlayer.normalized() * data.speed * speedMod * dt;
        }
        break;
      case EnemyKind.ranged:
        if (dist > _preferredDist + 20) {
          position += toPlayer.normalized() * data.speed * speedMod * dt;
        } else if (dist < _preferredDist - 20) {
          position -= toPlayer.normalized() * data.speed * 0.6 * speedMod * dt;
        } else {
          final perp = Vector2(-toPlayer.y, toPlayer.x).normalized();
          position += perp * data.speed * 0.3 * speedMod * dt;
        }
        break;
    }

    _clampToRoom();

    // ── Attack ──
    _attackCooldown -= dt;
    if (_attackCooldown <= 0 && dist <= data.attackRange) {
      _attackCooldown = data.attackCooldown;
      _attack(player);
    }

    priority = position.y.toInt();
  }

  void _clampToRoom() {
    final r = data.radius;
    const margin = 44.0;
    position.x = position.x.clamp(margin + r, GameConfig.roomWidth - margin - r);
    position.y = position.y.clamp(60 + r, GameConfig.roomHeight - 28 - r);
  }

  void _attack(Player player) {
    if (data.kind == EnemyKind.ranged) {
      final dir = (player.position - position).normalized();
      parent?.add(Projectile(
        pos: position.clone(),
        direction: dir,
        damage: data.damage,
        color: _enemyColor,
        fromPlayer: false,
        speed: GameConfig.projectileSpeed * 0.7,
      ));
    } else {
      player.takeDamage(data.damage);
    }
  }

  // ── Damage ──

  void takeDamage(double amount, {Vector2? knockback}) {
    if (isDead) return;
    health -= amount;
    _flashTimer = 0.12;

    // Floating damage number + hit sparks
    game.effects.damageNumber(
      position - Vector2(0, data.radius + 10),
      amount,
      big: data.kind == EnemyKind.boss,
    );

    // Knockback (bosses are too heavy)
    if (knockback != null && data.kind != EnemyKind.boss) {
      _knockback.add(knockback.normalized() * 70);
    }

    if (health <= 0) {
      health = 0;
      _die();
    }
  }

  void _die() {
    isDead = true;
    _deathTimer = 0.25;

    // Juicy death explosion
    game.effects.deathBurst(position.clone(), _enemyColor, data.radius);
    game.groundFx.ring(
      position + Vector2(0, data.radius * 0.45),
      _enemyColor,
      maxRadius: data.radius * 2.8,
      life: 0.4,
    );
    if (data.kind == EnemyKind.boss) {
      game.shakeCamera(intensity: 11, duration: 0.55);
    } else {
      game.shakeCamera(intensity: 2.2, duration: 0.12);
    }

    game.onEnemyKilled(this);
  }

  /// Apply a slow/freeze debuff for [duration] seconds.
  void applySlow(double duration) {
    if (_slowTimer < duration) _slowTimer = duration;
  }

  // ── Rendering ──

  Color get _enemyColor =>
      data.kind == EnemyKind.boss ? GameConfig.bossColor : GameConfig.enemyColor;

  @override
  void render(Canvas canvas) {
    final deathFade = isDead ? (_deathTimer / 0.25).clamp(0.0, 1.0) : 1.0;
    if (deathFade <= 0) return;

    final isFlashing = _flashTimer > 0;
    final baseColor = isFlashing ? const Color(0xFFFFFFFF) : _enemyColor;
    final c = deathFade < 1.0
        ? baseColor.withValues(alpha: deathFade * 0.85)
        : baseColor;

    final cx = size.x / 2;
    final cy = size.y / 2;
    final r = data.radius;

    // ── Spawn pop-in scale + living idle bob (squash & stretch) ──
    final spawnScale = _easeOutBack(_spawnAnim);
    final bob = sin(_time * 3.2 + _bobPhase) * 0.035;
    canvas.save();
    canvas.translate(cx, cy + r * 0.5);
    canvas.scale(spawnScale * (1 + bob * 0.5), spawnScale * (1 - bob));
    canvas.translate(-cx, -(cy + r * 0.5));

    // Scale down on death
    if (isDead) {
      final s = deathFade;
      canvas.save();
      canvas.translate(cx * (1 - s), cy * (1 - s));
      canvas.scale(s);
    }

    // Ground shadow ellipse
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.5),
        width: r * 2.4,
        height: r * 0.9,
      ),
      Paint()..color = Color.fromARGB((0x44 * deathFade).toInt(), 0, 0, 0),
    );

    // Ground glow ring (like the reference image orange circles)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + r * 0.45),
        width: r * 2.6,
        height: r * 1.0,
      ),
      Paint()
        ..color = c.withValues(alpha: 0.35 * deathFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Dispatch to creature-specific render
    switch (data.name) {
      case 'Skeleton':
        _renderSkeleton(canvas, cx, cy, r, c);
      case 'Spider':
        _renderSpider(canvas, cx, cy, r, c);
      case 'Imp':
        _renderImp(canvas, cx, cy, r, c);
      case 'Bat':
        _renderBat(canvas, cx, cy, r, c);
      case 'Golem':
        _renderGolem(canvas, cx, cy, r, c);
      case 'Dark Mage':
        _renderDarkMage(canvas, cx, cy, r, c);
      case 'Death Knight':
        _renderDeathKnight(canvas, cx, cy, r, c);
      case 'Shadow Dragon':
        _renderDragon(canvas, cx, cy, r, c);
      default:
        _renderGenericEnemy(canvas, cx, cy, r, c);
    }

    // Health bar
    if (!isDead) _renderHealthBar(canvas, cx, cy, r);

    if (isDead) canvas.restore();

    canvas.restore(); // spawn/bob transform
  }

  static double _easeOutBack(double t) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    final x = t - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
  }

  // ════════════════════════════════════════════════════════
  //  SKELETON — bony warrior with exposed ribs and sword
  // ════════════════════════════════════════════════════════
  void _renderSkeleton(Canvas canvas, double cx, double cy, double r, Color c) {
    final bone = const Color(0xFFe8e0c8);
    final boneDark = const Color(0xFFb8b098);

    // Legs (bone sticks)
    canvas.drawLine(Offset(cx - 4, cy + 2), Offset(cx - 5, cy + r * 0.6), Paint()..color = bone..strokeWidth = 2.5);
    canvas.drawLine(Offset(cx + 4, cy + 2), Offset(cx + 5, cy + r * 0.6), Paint()..color = bone..strokeWidth = 2.5);
    // Feet
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 5, cy + r * 0.6), width: 5, height: 3), Paint()..color = boneDark);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 5, cy + r * 0.6), width: 5, height: 3), Paint()..color = boneDark);

    // Ribcage
    for (var i = 0; i < 3; i++) {
      final y = cy - 4 + i * 3.5;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, y), width: 12, height: 5),
        0.3, 2.5, false,
        Paint()..color = bone..strokeWidth = 1.5..style = PaintingStyle.stroke,
      );
    }

    // Spine
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 2), Paint()..color = bone..strokeWidth = 2);

    // Shoulders
    canvas.drawLine(Offset(cx - 8, cy - 6), Offset(cx + 8, cy - 6), Paint()..color = bone..strokeWidth = 2.5);

    // Arms
    canvas.drawLine(Offset(cx - 8, cy - 6), Offset(cx - 10, cy + 1), Paint()..color = bone..strokeWidth = 2);
    canvas.drawLine(Offset(cx + 8, cy - 6), Offset(cx + 10, cy - 1), Paint()..color = bone..strokeWidth = 2);

    // Skull
    canvas.drawCircle(Offset(cx, cy - 11), 5.5, Paint()..color = bone);
    canvas.drawCircle(Offset(cx, cy - 11), 5.5, Paint()..color = boneDark..style = PaintingStyle.stroke..strokeWidth = 0.8);
    // Eye sockets
    canvas.drawCircle(Offset(cx - 2, cy - 12), 1.8, Paint()..color = c);
    canvas.drawCircle(Offset(cx + 2, cy - 12), 1.8, Paint()..color = c);
    // Jaw
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 8), width: 7, height: 4),
      0.2, 2.7, false,
      Paint()..color = boneDark..strokeWidth = 1.2..style = PaintingStyle.stroke,
    );

    // Rusty sword in right hand
    canvas.drawLine(Offset(cx + 10, cy - 1), Offset(cx + 8, cy - 14), Paint()..color = const Color(0xFF8a8a8a)..strokeWidth = 2);
    canvas.drawLine(Offset(cx + 8, cy - 14), Offset(cx + 7, cy - 16), Paint()..color = const Color(0xFFaaaaaa)..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 7, cy - 2), Offset(cx + 13, cy - 2), Paint()..color = const Color(0xFF6a5a2a)..strokeWidth = 1.5);
  }

  // ════════════════════════════════════════════════════════
  //  SPIDER — 8-legged arachnid with fangs
  // ════════════════════════════════════════════════════════
  void _renderSpider(Canvas canvas, double cx, double cy, double r, Color c) {
    final bodyColor = const Color(0xFF1a1a3a);
    final legColor = const Color(0xFF2a2a4a);
    final markColor = c;

    // Legs (4 per side, jointed)
    for (var i = 0; i < 4; i++) {
      final angle = -0.8 + i * 0.5;
      final jointX = cx - r * 1.3 * cos(angle);
      final jointY = cy - 2 + i * 3 - 4;
      final tipX = cx - r * 1.8 * cos(angle) - 2;
      final tipY = jointY + 4;
      canvas.drawLine(Offset(cx - 3, cy - 2 + i * 3 - 4), Offset(jointX, jointY), Paint()..color = legColor..strokeWidth = 1.8);
      canvas.drawLine(Offset(jointX, jointY), Offset(tipX, tipY), Paint()..color = legColor..strokeWidth = 1.5);

      // Mirror right
      final jointXR = cx + r * 1.3 * cos(angle);
      final tipXR = cx + r * 1.8 * cos(angle) + 2;
      canvas.drawLine(Offset(cx + 3, cy - 2 + i * 3 - 4), Offset(jointXR, jointY), Paint()..color = legColor..strokeWidth = 1.8);
      canvas.drawLine(Offset(jointXR, jointY), Offset(tipXR, tipY), Paint()..color = legColor..strokeWidth = 1.5);
    }

    // Abdomen (rear, larger)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 3), width: r * 1.4, height: r * 1.1),
      Paint()..color = bodyColor,
    );
    // Pattern on abdomen
    canvas.drawCircle(Offset(cx, cy + 2), 3, Paint()..color = markColor.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx, cy + 5), 2, Paint()..color = markColor.withValues(alpha: 0.3));

    // Cephalothorax (front body, smaller)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 5), width: r * 0.9, height: r * 0.7),
      Paint()..color = bodyColor,
    );

    // Eyes (8 eyes, 2 rows)
    final eyeColor = const Color(0xFFFF3333);
    canvas.drawCircle(Offset(cx - 3, cy - 7), 1.5, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(cx + 3, cy - 7), 1.5, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(cx - 1.5, cy - 8), 1, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(cx + 1.5, cy - 8), 1, Paint()..color = eyeColor);
    canvas.drawCircle(Offset(cx - 4, cy - 5.5), 0.8, Paint()..color = eyeColor.withValues(alpha: 0.7));
    canvas.drawCircle(Offset(cx + 4, cy - 5.5), 0.8, Paint()..color = eyeColor.withValues(alpha: 0.7));

    // Fangs
    canvas.drawLine(Offset(cx - 2, cy - 3), Offset(cx - 2, cy - 0.5), Paint()..color = const Color(0xFFe8e0c0)..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 2, cy - 3), Offset(cx + 2, cy - 0.5), Paint()..color = const Color(0xFFe8e0c0)..strokeWidth = 1.5);

    // Shiny highlight on body
    canvas.drawCircle(Offset(cx - 2, cy - 6), 2, Paint()..color = const Color(0x22FFFFFF));
  }

  // ════════════════════════════════════════════════════════
  //  IMP — small demon with wings and trident
  // ════════════════════════════════════════════════════════
  void _renderImp(Canvas canvas, double cx, double cy, double r, Color c) {
    final skinColor = const Color(0xFF8B2252);
    final wingColor = const Color(0xFF5a1a3a);

    // Wings (bat-like)
    final wingL = Path()
      ..moveTo(cx - 4, cy - 4)
      ..lineTo(cx - r * 1.5, cy - 8)
      ..lineTo(cx - r * 1.3, cy - 3)
      ..lineTo(cx - r * 1.0, cy - 5)
      ..lineTo(cx - r * 0.7, cy - 1)
      ..lineTo(cx - 4, cy - 1)
      ..close();
    canvas.drawPath(wingL, Paint()..color = wingColor);

    final wingR = Path()
      ..moveTo(cx + 4, cy - 4)
      ..lineTo(cx + r * 1.5, cy - 8)
      ..lineTo(cx + r * 1.3, cy - 3)
      ..lineTo(cx + r * 1.0, cy - 5)
      ..lineTo(cx + r * 0.7, cy - 1)
      ..lineTo(cx + 4, cy - 1)
      ..close();
    canvas.drawPath(wingR, Paint()..color = wingColor);

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.0, height: r * 1.3),
      Paint()..color = skinColor,
    );

    // Legs
    canvas.drawLine(Offset(cx - 3, cy + 4), Offset(cx - 4, cy + r * 0.6), Paint()..color = skinColor..strokeWidth = 2.5);
    canvas.drawLine(Offset(cx + 3, cy + 4), Offset(cx + 4, cy + r * 0.6), Paint()..color = skinColor..strokeWidth = 2.5);

    // Head
    canvas.drawCircle(Offset(cx, cy - 7), 4.5, Paint()..color = skinColor);
    // Horns
    canvas.drawLine(Offset(cx - 3, cy - 10), Offset(cx - 4, cy - 14), Paint()..color = const Color(0xFF3a1a1a)..strokeWidth = 2);
    canvas.drawLine(Offset(cx + 3, cy - 10), Offset(cx + 4, cy - 14), Paint()..color = const Color(0xFF3a1a1a)..strokeWidth = 2);
    // Eyes (glowing)
    canvas.drawCircle(Offset(cx - 2, cy - 8), 1.5, Paint()..color = const Color(0xFFFFFF00));
    canvas.drawCircle(Offset(cx + 2, cy - 8), 1.5, Paint()..color = const Color(0xFFFFFF00));
    // Evil grin
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 5), width: 5, height: 3),
      0.2, 2.7, false,
      Paint()..color = const Color(0xFFFFFF00)..strokeWidth = 1..style = PaintingStyle.stroke,
    );

    // Tail
    final tail = Path()
      ..moveTo(cx, cy + 5)
      ..quadraticBezierTo(cx + 6, cy + 8, cx + 4, cy + 11)
      ..quadraticBezierTo(cx + 6, cy + 10, cx + 8, cy + 9);
    canvas.drawPath(tail, Paint()..color = skinColor..strokeWidth = 2..style = PaintingStyle.stroke);
    // Tail tip (arrowhead)
    final tip = Path()..moveTo(cx + 8, cy + 9)..lineTo(cx + 6, cy + 7)..lineTo(cx + 10, cy + 8)..close();
    canvas.drawPath(tip, Paint()..color = skinColor);

    // Fireball in hand
    canvas.drawCircle(Offset(cx + 6, cy - 2), 3, Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx + 6, cy - 2), 2, Paint()..color = const Color(0xFFFFCC00));
  }

  // ════════════════════════════════════════════════════════
  //  BAT — winged creature with sonar attack
  // ════════════════════════════════════════════════════════
  void _renderBat(Canvas canvas, double cx, double cy, double r, Color c) {
    final bodyColor = const Color(0xFF2a1a4a);
    final wingColor = const Color(0xFF3a2060);
    final wingMembrane = const Color(0xFF4a2870);

    // Wings spread wide
    // Left wing
    final wL = Path()
      ..moveTo(cx - 3, cy - 2)
      ..lineTo(cx - r * 1.6, cy - 6)
      ..lineTo(cx - r * 1.8, cy - 2)
      ..lineTo(cx - r * 1.5, cy + 1)
      ..lineTo(cx - r * 1.2, cy - 1)
      ..lineTo(cx - r * 0.8, cy + 2)
      ..lineTo(cx - 3, cy + 1)
      ..close();
    canvas.drawPath(wL, Paint()..color = wingMembrane);
    // Wing bones
    canvas.drawLine(Offset(cx - 3, cy - 2), Offset(cx - r * 1.6, cy - 6), Paint()..color = wingColor..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx - 3, cy - 1), Offset(cx - r * 1.5, cy + 1), Paint()..color = wingColor..strokeWidth = 1.2);
    canvas.drawLine(Offset(cx - 3, cy), Offset(cx - r * 0.8, cy + 2), Paint()..color = wingColor..strokeWidth = 1);

    // Right wing
    final wR = Path()
      ..moveTo(cx + 3, cy - 2)
      ..lineTo(cx + r * 1.6, cy - 6)
      ..lineTo(cx + r * 1.8, cy - 2)
      ..lineTo(cx + r * 1.5, cy + 1)
      ..lineTo(cx + r * 1.2, cy - 1)
      ..lineTo(cx + r * 0.8, cy + 2)
      ..lineTo(cx + 3, cy + 1)
      ..close();
    canvas.drawPath(wR, Paint()..color = wingMembrane);
    canvas.drawLine(Offset(cx + 3, cy - 2), Offset(cx + r * 1.6, cy - 6), Paint()..color = wingColor..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 3, cy - 1), Offset(cx + r * 1.5, cy + 1), Paint()..color = wingColor..strokeWidth = 1.2);
    canvas.drawLine(Offset(cx + 3, cy), Offset(cx + r * 0.8, cy + 2), Paint()..color = wingColor..strokeWidth = 1);

    // Body (small, furry)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 8, height: 10),
      Paint()..color = bodyColor,
    );

    // Head
    canvas.drawCircle(Offset(cx, cy - 5), 4, Paint()..color = bodyColor);
    // Ears (pointed)
    final earL = Path()..moveTo(cx - 3, cy - 7)..lineTo(cx - 5, cy - 12)..lineTo(cx - 1, cy - 8)..close();
    final earR = Path()..moveTo(cx + 3, cy - 7)..lineTo(cx + 5, cy - 12)..lineTo(cx + 1, cy - 8)..close();
    canvas.drawPath(earL, Paint()..color = bodyColor);
    canvas.drawPath(earR, Paint()..color = bodyColor);

    // Eyes (glowing)
    canvas.drawCircle(Offset(cx - 2, cy - 5.5), 1.5, Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    canvas.drawCircle(Offset(cx + 2, cy - 5.5), 1.5, Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));

    // Fangs
    canvas.drawLine(Offset(cx - 1, cy - 2.5), Offset(cx - 1, cy - 0.5), Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 1);
    canvas.drawLine(Offset(cx + 1, cy - 2.5), Offset(cx + 1, cy - 0.5), Paint()..color = const Color(0xFFFFFFFF)..strokeWidth = 1);

    // Feet (tiny claws)
    canvas.drawLine(Offset(cx - 2, cy + 4), Offset(cx - 3, cy + 6), Paint()..color = bodyColor..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 2, cy + 4), Offset(cx + 3, cy + 6), Paint()..color = bodyColor..strokeWidth = 1.5);
  }

  // ════════════════════════════════════════════════════════
  //  GOLEM — massive stone/crystal construct
  // ════════════════════════════════════════════════════════
  void _renderGolem(Canvas canvas, double cx, double cy, double r, Color c) {
    final stoneLight = const Color(0xFF6a6a7a);
    final stoneDark = const Color(0xFF3a3a4a);
    final crystalColor = c;

    // Legs (thick stone pillars)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 6, cy + 6), width: 8, height: 12), const Radius.circular(2)),
      Paint()..color = stoneDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 6, cy + 6), width: 8, height: 12), const Radius.circular(2)),
      Paint()..color = stoneDark,
    );

    // Torso (large rectangular stone)
    final torso = Path()
      ..moveTo(cx - r * 0.6, cy - 6)
      ..lineTo(cx + r * 0.6, cy - 6)
      ..lineTo(cx + r * 0.7, cy + 2)
      ..lineTo(cx - r * 0.7, cy + 2)
      ..close();
    canvas.drawPath(torso, Paint()..color = stoneLight);
    // Stone crack details
    canvas.drawLine(Offset(cx - 4, cy - 4), Offset(cx - 2, cy - 1), Paint()..color = stoneDark..strokeWidth = 1);
    canvas.drawLine(Offset(cx + 3, cy - 3), Offset(cx + 5, cy + 1), Paint()..color = stoneDark..strokeWidth = 1);

    // Arms (massive)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - r * 0.8, cy - 1), width: 8, height: 16), const Radius.circular(3)),
      Paint()..color = stoneDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + r * 0.8, cy - 1), width: 8, height: 16), const Radius.circular(3)),
      Paint()..color = stoneDark,
    );
    // Fist glow
    canvas.drawCircle(Offset(cx - r * 0.8, cy + 6), 4, Paint()..color = crystalColor.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx + r * 0.8, cy + 6), 4, Paint()..color = crystalColor.withValues(alpha: 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Head (small, angular)
    final head = Path()
      ..moveTo(cx - 5, cy - 8)
      ..lineTo(cx + 5, cy - 8)
      ..lineTo(cx + 4, cy - 14)
      ..lineTo(cx, cy - 16)
      ..lineTo(cx - 4, cy - 14)
      ..close();
    canvas.drawPath(head, Paint()..color = stoneLight);

    // Glowing crystal eye
    canvas.drawCircle(Offset(cx, cy - 11), 3, Paint()..color = crystalColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx, cy - 11), 2, Paint()..color = crystalColor);

    // Crystal shards on shoulders
    final shardL = Path()..moveTo(cx - r * 0.5, cy - 8)..lineTo(cx - r * 0.4, cy - 14)..lineTo(cx - r * 0.6, cy - 7)..close();
    canvas.drawPath(shardL, Paint()..color = crystalColor.withValues(alpha: 0.6));
    final shardR = Path()..moveTo(cx + r * 0.5, cy - 8)..lineTo(cx + r * 0.6, cy - 15)..lineTo(cx + r * 0.7, cy - 7)..close();
    canvas.drawPath(shardR, Paint()..color = crystalColor.withValues(alpha: 0.6));
  }

  // ════════════════════════════════════════════════════════
  //  DARK MAGE — floating caster with dark magic
  // ════════════════════════════════════════════════════════
  void _renderDarkMage(Canvas canvas, double cx, double cy, double r, Color c) {
    final robeColor = const Color(0xFF1a0a3a);
    final trimColor = const Color(0xFF8B00FF);

    // Floating robe (tattered bottom)
    final robe = Path()
      ..moveTo(cx - 8, cy - 4)
      ..lineTo(cx + 8, cy - 4)
      ..lineTo(cx + 10, cy + 6)
      ..lineTo(cx + 7, cy + 8)
      ..lineTo(cx + 4, cy + 6)
      ..lineTo(cx + 1, cy + 8)
      ..lineTo(cx - 2, cy + 6)
      ..lineTo(cx - 5, cy + 8)
      ..lineTo(cx - 8, cy + 6)
      ..lineTo(cx - 10, cy + 6)
      ..close();
    canvas.drawPath(robe, Paint()..color = robeColor);
    canvas.drawPath(robe, Paint()..color = trimColor.withValues(alpha: 0.3)..style = PaintingStyle.stroke..strokeWidth = 1);

    // Upper body
    final upper = Path()
      ..moveTo(cx, cy - 14)
      ..lineTo(cx + 9, cy - 4)
      ..lineTo(cx - 9, cy - 4)
      ..close();
    canvas.drawPath(upper, Paint()..color = robeColor);
    canvas.drawPath(upper, Paint()..color = trimColor.withValues(alpha: 0.4)..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Hood
    final hood = Path()
      ..moveTo(cx - 6, cy - 13)
      ..lineTo(cx + 6, cy - 13)
      ..lineTo(cx + 4, cy - 20)
      ..lineTo(cx, cy - 23)
      ..lineTo(cx - 4, cy - 20)
      ..close();
    canvas.drawPath(hood, Paint()..color = const Color(0xFF0a0020));

    // Glowing eyes in hood
    canvas.drawCircle(Offset(cx - 2.5, cy - 16), 1.5, Paint()..color = trimColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(Offset(cx + 2.5, cy - 16), 1.5, Paint()..color = trimColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    // Staff with orb
    canvas.drawLine(Offset(cx + 10, cy + 5), Offset(cx + 8, cy - 18), Paint()..color = const Color(0xFF2a1a0a)..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx + 8, cy - 20), 4, Paint()..color = trimColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(Offset(cx + 8, cy - 20), 3, Paint()..color = trimColor);

    // Floating dark energy particles
    canvas.drawCircle(Offset(cx - 8, cy - 10), 2, Paint()..color = trimColor.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(Offset(cx + 12, cy - 8), 1.5, Paint()..color = trimColor.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    // Rune circle beneath (floating effect)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 8), width: 20, height: 7),
      Paint()..color = trimColor.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 1,
    );
  }

  // ════════════════════════════════════════════════════════
  //  DEATH KNIGHT — armored undead boss with great sword
  // ════════════════════════════════════════════════════════
  void _renderDeathKnight(Canvas canvas, double cx, double cy, double r, Color c) {
    final armorDark = const Color(0xFF2a2a3a);
    final armorLight = const Color(0xFF4a4a5a);

    // Heavy legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 7, cy + 8), width: 10, height: 16), const Radius.circular(2)),
      Paint()..color = armorDark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 7, cy + 8), width: 10, height: 16), const Radius.circular(2)),
      Paint()..color = armorDark,
    );

    // Massive plate torso
    final torso = Path()
      ..moveTo(cx - r * 0.55, cy - 10)
      ..lineTo(cx + r * 0.55, cy - 10)
      ..lineTo(cx + r * 0.6, cy + 4)
      ..lineTo(cx - r * 0.6, cy + 4)
      ..close();
    canvas.drawPath(torso, Paint()..color = armorLight);
    // Chest emblem
    canvas.drawCircle(Offset(cx, cy - 4), 5, Paint()..color = c.withValues(alpha: 0.4));
    canvas.drawCircle(Offset(cx, cy - 4), 5, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Skull emblem
    canvas.drawCircle(Offset(cx, cy - 4), 3, Paint()..color = const Color(0xFFe8e0c0));
    canvas.drawCircle(Offset(cx - 1, cy - 5), 0.8, Paint()..color = c);
    canvas.drawCircle(Offset(cx + 1, cy - 5), 0.8, Paint()..color = c);

    // Massive shoulder pads with spikes
    final padL = Path()
      ..moveTo(cx - r * 0.4, cy - 12)
      ..lineTo(cx - r * 0.8, cy - 14)
      ..lineTo(cx - r * 0.9, cy - 8)
      ..lineTo(cx - r * 0.4, cy - 8)
      ..close();
    canvas.drawPath(padL, Paint()..color = armorDark);
    // Spike
    canvas.drawLine(Offset(cx - r * 0.8, cy - 14), Offset(cx - r * 0.85, cy - 20), Paint()..color = armorDark..strokeWidth = 3);

    final padR = Path()
      ..moveTo(cx + r * 0.4, cy - 12)
      ..lineTo(cx + r * 0.8, cy - 14)
      ..lineTo(cx + r * 0.9, cy - 8)
      ..lineTo(cx + r * 0.4, cy - 8)
      ..close();
    canvas.drawPath(padR, Paint()..color = armorDark);
    canvas.drawLine(Offset(cx + r * 0.8, cy - 14), Offset(cx + r * 0.85, cy - 20), Paint()..color = armorDark..strokeWidth = 3);

    // Helmet
    final helmet = Path()
      ..moveTo(cx - 7, cy - 14)
      ..lineTo(cx + 7, cy - 14)
      ..lineTo(cx + 6, cy - 22)
      ..lineTo(cx, cy - 26)
      ..lineTo(cx - 6, cy - 22)
      ..close();
    canvas.drawPath(helmet, Paint()..color = armorDark);
    // Visor glow
    canvas.drawLine(Offset(cx - 4, cy - 18), Offset(cx + 4, cy - 18), Paint()..color = c..strokeWidth = 2.5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    // Crown horn
    canvas.drawLine(Offset(cx, cy - 26), Offset(cx, cy - 32), Paint()..color = c..strokeWidth = 2);

    // Great sword (left side)
    canvas.drawLine(Offset(cx - r * 0.5, cy + 12), Offset(cx - r * 0.4, cy - 22), Paint()..color = const Color(0xFF8a8a9a)..strokeWidth = 3.5);
    canvas.drawLine(Offset(cx - r * 0.4, cy - 22), Offset(cx - r * 0.35, cy - 28), Paint()..color = const Color(0xFFaaaacc)..strokeWidth = 2.5);
    // Crossguard
    canvas.drawLine(Offset(cx - r * 0.7, cy - 0), Offset(cx - r * 0.2, cy - 0), Paint()..color = c..strokeWidth = 2.5);

    // Soul fire aura
    canvas.drawCircle(Offset(cx, cy - 4), r * 0.8, Paint()..color = c.withValues(alpha: 0.1)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }

  // ════════════════════════════════════════════════════════
  //  SHADOW DRAGON — large winged beast boss
  // ════════════════════════════════════════════════════════
  void _renderDragon(Canvas canvas, double cx, double cy, double r, Color c) {
    final bodyColor = const Color(0xFF1a0a2a);
    final scaleColor = const Color(0xFF3a1a5a);
    final wingColor = const Color(0xFF2a1040);
    final bellyColor = const Color(0xFF4a2060);

    // Wings (massive, bat-like)
    // Left wing
    final wingL = Path()
      ..moveTo(cx - 6, cy - 8)
      ..lineTo(cx - r * 1.4, cy - r * 0.8)
      ..lineTo(cx - r * 1.6, cy - r * 0.3)
      ..lineTo(cx - r * 1.3, cy - r * 0.1)
      ..lineTo(cx - r * 1.1, cy - r * 0.4)
      ..lineTo(cx - r * 0.8, cy)
      ..lineTo(cx - 6, cy - 2)
      ..close();
    canvas.drawPath(wingL, Paint()..color = wingColor);
    // Wing membrane veins
    canvas.drawLine(Offset(cx - 6, cy - 8), Offset(cx - r * 1.4, cy - r * 0.8), Paint()..color = scaleColor..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx - 6, cy - 5), Offset(cx - r * 1.3, cy - r * 0.1), Paint()..color = scaleColor..strokeWidth = 1.2);

    // Right wing
    final wingR = Path()
      ..moveTo(cx + 6, cy - 8)
      ..lineTo(cx + r * 1.4, cy - r * 0.8)
      ..lineTo(cx + r * 1.6, cy - r * 0.3)
      ..lineTo(cx + r * 1.3, cy - r * 0.1)
      ..lineTo(cx + r * 1.1, cy - r * 0.4)
      ..lineTo(cx + r * 0.8, cy)
      ..lineTo(cx + 6, cy - 2)
      ..close();
    canvas.drawPath(wingR, Paint()..color = wingColor);
    canvas.drawLine(Offset(cx + 6, cy - 8), Offset(cx + r * 1.4, cy - r * 0.8), Paint()..color = scaleColor..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx + 6, cy - 5), Offset(cx + r * 1.3, cy - r * 0.1), Paint()..color = scaleColor..strokeWidth = 1.2);

    // Tail (curving behind)
    final tail = Path()
      ..moveTo(cx, cy + 8)
      ..quadraticBezierTo(cx + 10, cy + 14, cx + 16, cy + 10)
      ..quadraticBezierTo(cx + 20, cy + 8, cx + 18, cy + 6);
    canvas.drawPath(tail, Paint()..color = bodyColor..strokeWidth = 4..style = PaintingStyle.stroke);
    // Tail spike
    final spike = Path()..moveTo(cx + 18, cy + 6)..lineTo(cx + 22, cy + 4)..lineTo(cx + 20, cy + 8)..close();
    canvas.drawPath(spike, Paint()..color = scaleColor);

    // Hind legs
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx - 6, cy + 6), width: 8, height: 12), const Radius.circular(3)),
      Paint()..color = bodyColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 6, cy + 6), width: 8, height: 12), const Radius.circular(3)),
      Paint()..color = bodyColor,
    );
    // Claws
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(Offset(cx - 6 + i * 2, cy + 11), Offset(cx - 6 + i * 2, cy + 14), Paint()..color = const Color(0xFFe8e0c0)..strokeWidth = 1.2);
      canvas.drawLine(Offset(cx + 6 + i * 2, cy + 11), Offset(cx + 6 + i * 2, cy + 14), Paint()..color = const Color(0xFFe8e0c0)..strokeWidth = 1.2);
    }

    // Body (bulky scaled)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 1.0, height: r * 1.2),
      Paint()..color = bodyColor,
    );
    // Belly scales
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: r * 0.5, height: r * 0.8),
      Paint()..color = bellyColor,
    );

    // Neck
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy - 14), Paint()..color = bodyColor..strokeWidth = 6);

    // Head (elongated dragon head)
    final head = Path()
      ..moveTo(cx - 6, cy - 14)
      ..lineTo(cx + 6, cy - 14)
      ..lineTo(cx + 8, cy - 18)
      ..lineTo(cx + 4, cy - 24)
      ..lineTo(cx, cy - 26)
      ..lineTo(cx - 4, cy - 24)
      ..lineTo(cx - 8, cy - 18)
      ..close();
    canvas.drawPath(head, Paint()..color = bodyColor);
    canvas.drawPath(head, Paint()..color = scaleColor..style = PaintingStyle.stroke..strokeWidth = 1);

    // Horns
    canvas.drawLine(Offset(cx - 5, cy - 18), Offset(cx - 8, cy - 26), Paint()..color = const Color(0xFF4a4a4a)..strokeWidth = 2.5);
    canvas.drawLine(Offset(cx + 5, cy - 18), Offset(cx + 8, cy - 26), Paint()..color = const Color(0xFF4a4a4a)..strokeWidth = 2.5);

    // Eyes (fierce, glowing)
    canvas.drawCircle(Offset(cx - 3, cy - 19), 2.5, Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(Offset(cx + 3, cy - 19), 2.5, Paint()..color = c..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(Offset(cx - 3, cy - 19), 1.5, Paint()..color = const Color(0xFFFFFF00));
    canvas.drawCircle(Offset(cx + 3, cy - 19), 1.5, Paint()..color = const Color(0xFFFFFF00));

    // Nostrils / snout
    canvas.drawCircle(Offset(cx - 1.5, cy - 23), 1, Paint()..color = c.withValues(alpha: 0.5));
    canvas.drawCircle(Offset(cx + 1.5, cy - 23), 1, Paint()..color = c.withValues(alpha: 0.5));

    // Fire breath glow from mouth
    canvas.drawCircle(Offset(cx, cy - 25), 4, Paint()..color = c.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    // Aura
    canvas.drawCircle(Offset(cx, cy), r * 0.8, Paint()..color = c.withValues(alpha: 0.08)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
  }

  // ════════════════════════════════════════════════════════
  //  GENERIC FALLBACK
  // ════════════════════════════════════════════════════════
  void _renderGenericEnemy(Canvas canvas, double cx, double cy, double r, Color c) {
    final body = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r * 0.8, cy)
      ..lineTo(cx, cy + r * 0.5)
      ..lineTo(cx - r * 0.8, cy)
      ..close();
    canvas.drawPath(body, Paint()..color = c.withValues(alpha: 0.8));
    canvas.drawPath(body, Paint()..color = c..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(Offset(cx - 3, cy - r * 0.3), 2, Paint()..color = const Color(0xFFFF3333));
    canvas.drawCircle(Offset(cx + 3, cy - r * 0.3), 2, Paint()..color = const Color(0xFFFF3333));
  }

  void _renderHealthBar(Canvas canvas, double cx, double cy, double r) {
    final barW = r * 2.4;
    final barH = 4.0;
    final barY = cy - r * 1.6;
    final barX = cx - barW / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barW, barH),
        const Radius.circular(2),
      ),
      Paint()..color = GameConfig.hpBarBg,
    );

    final ratio = (health / maxHealth).clamp(0.0, 1.0);
    if (ratio > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW * ratio, barH),
          const Radius.circular(2),
        ),
        Paint()..color = GameConfig.hpBar,
      );
    }
  }
}
