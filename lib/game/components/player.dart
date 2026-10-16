// ignore_for_file: unused_element

import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart'
    show Alignment, LinearGradient, RadialGradient, HSLColor;

import '../../models/player_class.dart';
import '../../widgets/class_character_painter.dart';
import '../config.dart';
import '../riftclass_game.dart';
import 'enemy.dart';
import 'projectile.dart';

/// Archero-style chibi player with big head, bouncy animations,
/// squash-stretch, and lively movement.
class Player extends PositionComponent
    with HasGameReference<RiftclassGame>, CollisionCallbacks {
  Player({required this.classData})
    : super(
        size: Vector2.all(GameConfig.playerRadius * 2),
        anchor: Anchor.center,
      );

  final PlayerClassData classData;

  // ── Stats ──
  late double maxHealth;
  late double health;
  late double speed;
  late double damage;
  late double attacksPerSecond;
  late double attackRange;

  // ── Timers ──
  double _attackTimer = 0;
  double _flashTimer = 0;
  double _abilityCooldown = 0;
  double _dustTimer = 0;

  // ── Animation ──
  double _time = 0;
  double _walkCycle = 0;
  double _idleBreath = 0;
  double _attackAnim = 0; // 1→0 on attack
  double _squashY = 1.0; // squash-stretch Y scale
  double _squashX = 1.0; // squash-stretch X scale
  double _bounceY = 0.0; // vertical bounce offset
  double _leanAngle = 0.0;
  double _orbitalAngle = 0.0;
  double _weaponGlow = 0.0;
  double _landSquash = 0.0; // landing squash after bounce

  Vector2 velocity = Vector2.zero();
  bool get isMoving => velocity.length2 > 1;

  final List<AbilityState> acquiredAbilities = [];

  @override
  Future<void> onLoad() async {
    maxHealth = classData.baseHealth;
    health = maxHealth;
    speed = classData.baseSpeed;
    damage = classData.baseDamage;
    attacksPerSecond = classData.attacksPerSecond;
    attackRange = classData.attackRange;
    add(CircleHitbox()..collisionType = CollisionType.active);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_flashTimer > 0) _flashTimer -= dt;
    if (_abilityCooldown > 0) _abilityCooldown -= dt;

    // Attack anim decay
    if (_attackAnim > 0) {
      _attackAnim -= dt * 6.0;
      if (_attackAnim < 0) _attackAnim = 0;
    }

    _orbitalAngle += dt * 2.0;
    if (_orbitalAngle > 2 * pi) _orbitalAngle -= 2 * pi;
    _weaponGlow = (sin(_time * 3.0) + 1.0) * 0.5;

    // ── Smooth scale recovery ──
    _squashY += (1.0 - _squashY) * dt * 8.0;
    _squashX += (1.0 - _squashX) * dt * 8.0;
    if (_landSquash > 0) {
      _landSquash -= dt * 6.0;
      if (_landSquash < 0) _landSquash = 0;
    }

    if (isMoving) {
      _walkCycle += dt * 6.0; // smooth glide cycle
      if (_walkCycle > 2 * pi) _walkCycle -= 2 * pi;
      _idleBreath = 0;

      // Smooth glide — very subtle vertical motion
      _bounceY = sin(_walkCycle) * 1.2;
      // Minimal scale variation for fluid feel
      _squashY = 1.0 + sin(_walkCycle) * 0.015;
      _squashX = 1.0 - sin(_walkCycle) * 0.008;

      // Body lean (smooth)
      final targetLean = (velocity.x / speed).clamp(-1.0, 1.0) * 0.06;
      _leanAngle += (targetLean - _leanAngle) * dt * 6.0;
    } else {
      // Idle: gentle floating sway
      _idleBreath += dt * 2.0;
      if (_idleBreath > 2 * pi) _idleBreath -= 2 * pi;
      _bounceY = sin(_idleBreath) * 1.0;
      _walkCycle += (0 - _walkCycle) * dt * 4.0;
      _leanAngle += (0 - _leanAngle) * dt * 4.0;
    }

    // Movement
    if (isMoving) {
      position += velocity * dt;
      _clampToRoom();

      // Dust puffs at the feet while running
      _dustTimer -= dt;
      if (_dustTimer <= 0) {
        _dustTimer = 0.14;
        game.groundFx.dust(position + Vector2(0, 20));
      }
    }

    // Auto-attack
    if (!isMoving) {
      _attackTimer += dt;
      final interval = 1.0 / attacksPerSecond;
      if (_attackTimer >= interval) {
        _attackTimer -= interval;
        _autoAttack();
      }
    } else {
      _attackTimer = 0;
    }

    priority = position.y.toInt();
  }

  void _clampToRoom() {
    final r = GameConfig.playerRadius;
    const margin = 44.0;
    position.x = position.x.clamp(
      margin + r,
      GameConfig.roomWidth - margin - r,
    );
    position.y = position.y.clamp(60 + r, GameConfig.roomHeight - 28 - r);
  }

  // ═══════════════════════════════════════════════════════
  //  COMBAT (preserved from before)
  // ═══════════════════════════════════════════════════════

  void _autoAttack() {
    final enemies = parent?.children.whereType<Enemy>().toList();
    if (enemies == null || enemies.isEmpty) return;
    Enemy? closest;
    double closestDist = double.infinity;
    for (final e in enemies) {
      if (e.isDead) continue;
      final d = position.distanceTo(e.position);
      if (d < closestDist) {
        closestDist = d;
        closest = e;
      }
    }
    if (closest == null || closestDist > attackRange) return;

    // Attack recoil (subtle)
    _attackAnim = 1.0;
    _squashY = 0.93;
    _squashX = 1.05;

    _fireAt(closest);
    if (_abilityCooldown <= 0) _triggerAbilities(closest, enemies);
  }

  void _fireAt(Enemy target) {
    final dir = (target.position - position).normalized();
    final multiShot = _abilityLevel('multi_shot');
    final projectileCount = 1 + multiShot;
    final spreadAngle = multiShot > 0 ? 0.15 * multiShot : 0.0;
    final piercing = _abilityLevel('piercing');

    final ProjectileStyle style;
    switch (classData.id) {
      case PlayerClassName.archer:
        style = ProjectileStyle.arrow;
      case PlayerClassName.mage:
        style = ProjectileStyle.frostBolt;
      case PlayerClassName.warrior:
        style = ProjectileStyle.swordSlash;
      case PlayerClassName.necromancer:
        style = ProjectileStyle.soulBolt;
    }

    final chainLevel = _abilityLevel('chain_lightning');

    for (int i = 0; i < projectileCount; i++) {
      double angleOffset = 0;
      if (projectileCount > 1) {
        angleOffset = spreadAngle * (i - (projectileCount - 1) / 2);
      }
      final cos_ = cos(angleOffset);
      final sin_ = sin(angleOffset);
      final rotated = Vector2(
        dir.x * cos_ - dir.y * sin_,
        dir.x * sin_ + dir.y * cos_,
      );
      parent?.add(
        Projectile(
          pos: position.clone(),
          direction: rotated,
          damage: damage,
          color: classData.color,
          fromPlayer: true,
          piercing: piercing + chainLevel,
          style: style,
        ),
      );
    }

    if (chainLevel > 0) {
      final others =
          parent?.children
              .whereType<Enemy>()
              .where(
                (e) =>
                    !e.isDead &&
                    e != target &&
                    position.distanceTo(e.position) < attackRange,
              )
              .take(chainLevel)
              .toList() ??
          [];
      for (final e in others) {
        final d = (e.position - position).normalized();
        parent?.add(
          Projectile(
            pos: position.clone(),
            direction: d,
            damage: damage * 0.6,
            color: const Color(0xFFFFFF44),
            fromPlayer: true,
            piercing: 0,
            style: ProjectileStyle.frostBolt,
            speed: GameConfig.projectileSpeed * 1.3,
          ),
        );
      }
    }

    final whirlwindLevel = _abilityLevel('whirlwind');
    if (whirlwindLevel > 0) {
      final aoeRange = 60.0 + whirlwindLevel * 15;
      final aoeDmg = damage * (0.3 + whirlwindLevel * 0.15);
      final nearby =
          parent?.children
              .whereType<Enemy>()
              .where(
                (e) => !e.isDead && position.distanceTo(e.position) < aoeRange,
              )
              .toList() ??
          [];
      for (final e in nearby) {
        e.takeDamage(aoeDmg);
      }
      // Visual: expanding slash ring on the ground
      game.groundFx.ring(
        position + Vector2(0, 16),
        classData.color,
        maxRadius: aoeRange,
        life: 0.3,
        strokeWidth: 4,
      );
      // Visual: slash ring around player
      for (var i = 0; i < 8; i++) {
        final a = i * pi / 4 + _time;
        parent?.add(
          Projectile(
            pos: position.clone(),
            direction: Vector2(cos(a), sin(a)),
            damage: 0,
            color: classData.color,
            fromPlayer: true,
            piercing: 99,
            style: ProjectileStyle.swordSlash,
            speed: 120,
          ),
        );
      }
    }

    final lifeDrainLevel = _abilityLevel('life_drain');
    if (lifeDrainLevel > 0) {
      heal(damage * 0.1 * lifeDrainLevel);
      // Visual: green healing wisp from target back to player
      final healDir = (position - target.position).normalized();
      parent?.add(
        Projectile(
          pos: target.position.clone(),
          direction: healDir,
          damage: 0,
          color: const Color(0xFF44FF88),
          fromPlayer: true,
          piercing: 99,
          style: ProjectileStyle.soulBolt,
          speed: 200,
        ),
      );
    }
  }

  void _triggerAbilities(Enemy target, List<Enemy> allEnemies) {
    final liveEnemies = allEnemies.where((e) => !e.isDead).toList();

    final frostNovaLevel = _abilityLevel('frost_nova');
    if (frostNovaLevel > 0) {
      final range = 80.0 + frostNovaLevel * 15;
      final dmg = damage * (0.5 + frostNovaLevel * 0.25);
      final nearby = liveEnemies
          .where((e) => position.distanceTo(e.position) < range)
          .toList();
      if (nearby.isNotEmpty) {
        for (final e in nearby) {
          e.takeDamage(dmg);
          e.applySlow(1.0 + frostNovaLevel * 0.5);
        }
        // Visual: icy shockwave + frost burst
        game.groundFx.ring(
          position.clone(),
          const Color(0xFFa8e0ff),
          maxRadius: range,
          life: 0.45,
          strokeWidth: 5,
        );
        game.effects.burst(
          position.clone(),
          const Color(0xFFd4f0ff),
          count: 12,
          speed: range * 2.2,
          size: 2.2,
          life: 0.4,
        );
        for (var i = 0; i < 8; i++) {
          final angle = i * pi / 4;
          parent?.add(
            Projectile(
              pos: position.clone(),
              direction: Vector2(cos(angle), sin(angle)),
              damage: 0,
              color: const Color(0xFFa8e0ff),
              fromPlayer: true,
              piercing: 99,
              style: ProjectileStyle.frostBolt,
              speed: 100,
            ),
          );
        }
        _abilityCooldown = 3.0 - frostNovaLevel * 0.3;
        return;
      }
    }

    final meteorLevel = _abilityLevel('meteor');
    if (meteorLevel > 0) {
      final dmg = damage * (2.0 + meteorLevel * 1.0);
      final range = 40.0 + meteorLevel * 10;
      target.takeDamage(dmg);
      for (final e in liveEnemies.where(
        (e) => e != target && e.position.distanceTo(target.position) < range,
      )) {
        e.takeDamage(dmg * 0.5);
      }
      // Visual: big fireball falling on target
      parent?.add(
        Projectile(
          pos: Vector2(target.position.x, target.position.y - 120),
          direction: Vector2(0, 1),
          damage: 0,
          color: const Color(0xFFFF6600),
          fromPlayer: true,
          piercing: 99,
          style: ProjectileStyle.frostBolt,
          speed: 200,
        ),
      );
      // Visual: explosion + shockwave + screen shake
      game.effects.deathBurst(target.position.clone(), const Color(0xFFFF6600), range * 0.5);
      game.groundFx.ring(
        target.position + Vector2(0, 8),
        const Color(0xFFFF8844),
        maxRadius: range,
        life: 0.4,
        strokeWidth: 5,
      );
      game.shakeCamera(intensity: 7, duration: 0.3);
      // Impact ring projectiles
      for (var i = 0; i < 6; i++) {
        final a = i * pi / 3;
        parent?.add(
          Projectile(
            pos: target.position.clone(),
            direction: Vector2(cos(a), sin(a)),
            damage: 0,
            color: const Color(0xFFFF4400),
            fromPlayer: true,
            piercing: 99,
            style: ProjectileStyle.frostBolt,
            speed: 80,
          ),
        );
      }
      _abilityCooldown = 4.0 - meteorLevel * 0.4;
      return;
    }

    final arrowRainLevel = _abilityLevel('arrow_rain');
    if (arrowRainLevel > 0) {
      final dmg = damage * (0.8 + arrowRainLevel * 0.4);
      final range = 70.0 + arrowRainLevel * 15;
      for (final e in liveEnemies.where(
        (e) => e.position.distanceTo(target.position) < range,
      )) {
        e.takeDamage(dmg);
      }
      // Visual: target zone marker
      game.groundFx.ring(
        target.position + Vector2(0, 6),
        classData.color,
        maxRadius: range,
        life: 0.5,
        strokeWidth: 3,
      );
      final rng = Random();
      for (var i = 0; i < 4 + arrowRainLevel; i++) {
        parent?.add(
          Projectile(
            pos: Vector2(
              target.position.x + rng.nextDouble() * 60 - 30,
              target.position.y - 80,
            ),
            direction: Vector2(0, 1),
            damage: 0,
            color: classData.color,
            fromPlayer: true,
            piercing: 0,
            style: ProjectileStyle.arrow,
            speed: 250,
          ),
        );
      }
      _abilityCooldown = 3.5 - arrowRainLevel * 0.3;
      return;
    }

    final shieldBashLevel = _abilityLevel('shield_bash');
    if (shieldBashLevel > 0) {
      target.takeDamage(damage * (1.0 + shieldBashLevel * 0.5));
      target.applySlow(1.5 + shieldBashLevel * 0.5);
      // Visual: big bash projectile towards target
      final bashDir = (target.position - position).normalized();
      parent?.add(
        Projectile(
          pos: position.clone(),
          direction: bashDir,
          damage: 0,
          color: const Color(0xFFAABBCC),
          fromPlayer: true,
          piercing: 99,
          style: ProjectileStyle.swordSlash,
          speed: 280,
        ),
      );
      _abilityCooldown = 3.0 - shieldBashLevel * 0.3;
      return;
    }

    final leapSlamLevel = _abilityLevel('leap_slam');
    if (leapSlamLevel > 0) {
      final dmg = damage * (1.5 + leapSlamLevel * 0.7);
      final range = 55.0 + leapSlamLevel * 12;
      for (final e in liveEnemies.where(
        (e) => e.position.distanceTo(target.position) < range,
      )) {
        e.takeDamage(dmg);
      }
      // Visual: ground-slam shockwave + dust + shake
      game.groundFx.ring(
        target.position + Vector2(0, 8),
        classData.color,
        maxRadius: range,
        life: 0.4,
        strokeWidth: 6,
      );
      game.groundFx.dust(target.position + Vector2(0, 10));
      game.shakeCamera(intensity: 6, duration: 0.25);
      // Visual: shockwave ring from target position
      for (var i = 0; i < 10; i++) {
        final a = i * pi / 5;
        parent?.add(
          Projectile(
            pos: target.position.clone(),
            direction: Vector2(cos(a), sin(a)),
            damage: 0,
            color: classData.color,
            fromPlayer: true,
            piercing: 99,
            style: ProjectileStyle.swordSlash,
            speed: 100,
          ),
        );
      }
      _abilityCooldown = 4.0 - leapSlamLevel * 0.4;
      return;
    }

    final skeletonLevel = _abilityLevel('skeleton');
    if (skeletonLevel > 0) {
      final rng = Random();
      final targets = liveEnemies.toList()..shuffle(rng);
      final count = skeletonLevel.clamp(1, 3);
      for (var i = 0; i < count && i < targets.length; i++) {
        final dir = (targets[i].position - position).normalized();
        parent?.add(
          Projectile(
            pos:
                position.clone() +
                Vector2(rng.nextDouble() * 20 - 10, rng.nextDouble() * 20 - 10),
            direction: dir,
            damage: damage * 0.5,
            color: const Color(0xFFe8e0c8),
            fromPlayer: true,
            piercing: 0,
            style: ProjectileStyle.soulBolt,
            speed: GameConfig.projectileSpeed * 0.8,
          ),
        );
      }
      _abilityCooldown = 2.0 - skeletonLevel * 0.2;
      return;
    }
  }

  int _abilityLevel(String id) {
    for (final a in acquiredAbilities) {
      if (a.data.id == id) return a.level;
    }
    return 0;
  }

  void takeDamage(double amount) {
    health -= amount;
    _flashTimer = 0.18;
    // Hit reaction (subtle)
    _squashX = 1.08;
    _squashY = 0.92;
    game.shakeCamera(intensity: 4, duration: 0.18);
    if (health <= 0) {
      health = 0;
      game.onPlayerDeath();
    }
  }

  void heal(double amount) {
    health = (health + amount).clamp(0, maxHealth);
  }

  // ═══════════════════════════════════════════════════════
  //  RENDERING — Dark Fantasy (Reference Art Style)
  // ═══════════════════════════════════════════════════════

  bool get _isFlashing => _flashTimer > 0;

  @override
  void render(Canvas canvas) {
    final c = _isFlashing ? const Color(0xFFFF4444) : classData.color;
    final cx = size.x / 2;
    final cy = size.y / 2;

    // Apply squash-stretch + bounce
    canvas.save();
    canvas.translate(cx, cy + 10);
    canvas.scale(_squashX, _squashY);
    canvas.translate(0, -_bounceY);
    canvas.rotate(_leanAngle);
    canvas.translate(-cx, -(cy + 10));

    // ── Ground rune circle (like reference images) ──
    _drawRuneCircle(canvas, cx, cy + 22, c);

    // ── Ground shadow ──
    final shadowScale = 1.0 - _bounceY * 0.005;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 23),
        width: 48 * shadowScale,
        height: 16 * shadowScale,
      ),
      Paint()
        ..color = const Color(0x44000000)
        ..isAntiAlias = true,
    );

    paintClassCharacter(
      canvas,
      className: classData.id,
      color: classData.color,
      center: Offset(cx, cy),
      phase: isMoving ? _walkCycle : _idleBreath,
      attack: _attackAnim,
      moving: isMoving,
      flashing: _isFlashing,
    );

    canvas.restore();
  }

  /// Animated glowing rune circle under the character.
  void _drawRuneCircle(Canvas canvas, double cx, double cy, Color c) {
    final runeAlpha = 0.25 + _weaponGlow * 0.15;
    // Outer ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 60, height: 22),
      Paint()
        ..color = c.withValues(alpha: runeAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Inner ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 44, height: 16),
      Paint()
        ..color = c.withValues(alpha: runeAlpha * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Rune marks (4 rotating glyphs)
    for (var i = 0; i < 4; i++) {
      final a = _orbitalAngle * 0.5 + i * (pi / 2);
      final rx = cx + cos(a) * 24;
      final ry = cy + sin(a) * 8;
      canvas.drawCircle(
        Offset(rx, ry),
        2.5,
        Paint()
          ..color = c.withValues(alpha: runeAlpha + 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // Cross lines inside circle
    canvas.drawLine(
      Offset(cx - 18, cy),
      Offset(cx + 18, cy),
      Paint()
        ..color = c.withValues(alpha: runeAlpha * 0.4)
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(cx, cy - 6),
      Offset(cx, cy + 6),
      Paint()
        ..color = c.withValues(alpha: runeAlpha * 0.4)
        ..strokeWidth = 0.8,
    );
    // Fill glow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: 56, height: 20),
      Paint()
        ..color = c.withValues(alpha: 0.05 + _weaponGlow * 0.03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  ARCHER — Dark ranger with glowing purple bow
  // ═══════════════════════════════════════════════════════
  void _renderArcher(Canvas canvas, double cx, double cy, Color c) {
    final atk = _attackAnim;
    final legSwing = sin(_walkCycle) * 2.5;

    // ── Legs (dark leather with 3D shading) ──
    _drawLegs(
      canvas,
      cx,
      cy + 12,
      legSwing,
      const Color(0xFF2a1e2e),
      const Color(0xFF3a2a1a),
    );

    // ── Cape behind (dark purple, flowing with depth) ──
    final cf = sin(_time * 4 + _walkCycle) * 3;
    final cape = Path()
      ..moveTo(cx - 11, cy + 0)
      ..cubicTo(
        cx - 8 + cf * 0.3,
        cy + 8,
        cx - 10 + cf,
        cy + 16,
        cx - 6 + cf,
        cy + 22,
      )
      ..lineTo(cx + 6 + cf * 0.5, cy + 22)
      ..cubicTo(
        cx + 10 + cf * 0.3,
        cy + 16,
        cx + 8 + cf * 0.2,
        cy + 8,
        cx + 11,
        cy + 0,
      )
      ..close();
    canvas.drawPath(
      cape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF3a2040),
            const Color(0xFF2a1a3a),
            const Color(0xFF1a0a2a),
          ],
        ).createShader(Rect.fromLTRB(cx - 14, cy, cx + 14, cy + 22)),
    );
    // Cape fold lines
    canvas.drawLine(
      Offset(cx - 2 + cf * 0.3, cy + 4),
      Offset(cx - 3 + cf, cy + 20),
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 0.8,
    );
    canvas.drawLine(
      Offset(cx + 3 + cf * 0.2, cy + 4),
      Offset(cx + 2 + cf * 0.5, cy + 20),
      Paint()
        ..color = const Color(0x15000000)
        ..strokeWidth = 1.2,
    );

    // ── Torso (dark leather vest with 3D gradient) ──
    final torsoRect = Rect.fromCenter(
      center: Offset(cx, cy + 4),
      width: 24,
      height: 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(5)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.4),
          colors: [
            const Color(0xFF4a3848),
            const Color(0xFF3a2a3e),
            const Color(0xFF2a1a2e),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(torsoRect),
    );
    // Chest contour (3D depth)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 3, cy + 2), width: 10, height: 8),
      -0.5,
      2.0,
      false,
      Paint()
        ..color = const Color(0x18FFFFFF)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    // Purple accent seam
    canvas.drawLine(
      Offset(cx, cy - 3),
      Offset(cx, cy + 11),
      Paint()
        ..color = c.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    // Arm guards (dark metal with gradient)
    final guardRect = Rect.fromCenter(
      center: Offset(cx - 14, cy + 2),
      width: 7,
      height: 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(guardRect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF3a3040),
            const Color(0xFF5a5060),
            const Color(0xFF3a3040),
          ],
        ).createShader(guardRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(guardRect, const Radius.circular(3)),
      Paint()
        ..color = c.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Belt with pouches ──
    final beltRect = Rect.fromCenter(
      center: Offset(cx, cy + 11),
      width: 26,
      height: 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beltRect, const Radius.circular(1.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF5a3828),
            const Color(0xFF4a3020),
            const Color(0xFF3a2018),
          ],
        ).createShader(beltRect),
    );
    // Buckle with highlight
    canvas.drawCircle(
      Offset(cx, cy + 11),
      2.5,
      Paint()..color = const Color(0xFFCCAA44),
    );
    canvas.drawCircle(
      Offset(cx - 0.5, cy + 10.5),
      1,
      Paint()..color = const Color(0x44FFFFFF),
    );
    // Pouch
    final pouch = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + 8, cy + 12.5),
            width: 5,
            height: 5,
          ),
          const Radius.circular(1.5),
        ),
      );
    canvas.drawPath(
      pouch,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [const Color(0xFF4a3420), const Color(0xFF3a2a1a)],
            ).createShader(
              Rect.fromCenter(
                center: Offset(cx + 8, cy + 12.5),
                width: 6,
                height: 6,
              ),
            ),
    );

    // ── Quiver on back ──
    final quiverRect = Rect.fromCenter(
      center: Offset(cx + 13, cy - 4),
      width: 7,
      height: 24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(quiverRect, const Radius.circular(3)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF4a3a2a),
            const Color(0xFF3a2a1a),
            const Color(0xFF2a1a10),
          ],
        ).createShader(quiverRect),
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(cx + 12 + i * 1.5, cy - 17 + sin(_time * 2 + i) * 0.4),
        Offset(cx + 12 + i * 1.5, cy - 14),
        Paint()
          ..color = c.withValues(alpha: 0.8)
          ..strokeWidth = 1.5,
      );
    }

    // ── BOW (large, glowing purple energy bow) ──
    final bowPull = atk * 7;
    final bowPaint = Paint()
      ..color = const Color(0xFF3a2030)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - 22, cy + 0),
        width: 14 + atk * 4,
        height: 42,
      ),
      -1.4,
      2.8,
      false,
      bowPaint,
    );
    // Wood grain highlight on bow
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - 21, cy + 0),
        width: 12 + atk * 4,
        height: 38,
      ),
      -1.2,
      2.4,
      false,
      Paint()
        ..color = const Color(0xFF5a3040)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Purple energy glow on bow
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - 22, cy + 0),
        width: 14 + atk * 4,
        height: 42,
      ),
      -1.4,
      2.8,
      false,
      Paint()
        ..color = c.withValues(alpha: 0.5 + atk * 0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Bow tips (ornate)
    canvas.drawCircle(
      Offset(cx - 20, cy - 20),
      3,
      Paint()
        ..color = c.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      Offset(cx - 20, cy + 20),
      3,
      Paint()
        ..color = c.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // String
    canvas.drawLine(
      Offset(cx - 20, cy - 20),
      Offset(cx - 20 + bowPull, cy),
      Paint()
        ..color = c.withValues(alpha: 0.7)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(cx - 20 + bowPull, cy),
      Offset(cx - 20, cy + 20),
      Paint()
        ..color = c.withValues(alpha: 0.7)
        ..strokeWidth = 1.5,
    );
    // Energy arrow
    if (atk > 0.15) {
      canvas.drawLine(
        Offset(cx - 20 + bowPull, cy),
        Offset(cx - 32, cy),
        Paint()
          ..color = c.withValues(alpha: 0.8 * atk)
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        Offset(cx - 33, cy),
        4 * atk,
        Paint()
          ..color = c.withValues(alpha: atk * 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── Arms with proper hands ──
    _drawArm(canvas, cx - 12, cy + 0, cx - 18, cy + 4, const Color(0xFFd4a574));
    _drawArm(canvas, cx + 12, cy + 2, cx + 15, cy + 9, const Color(0xFFd4a574));
    _drawHand(canvas, cx - 19, cy + 5, const Color(0xFFd4a574), size: 0.8);
    _drawHand(canvas, cx + 16, cy + 10, const Color(0xFFd4a574), size: 0.8);

    // ── Head (3D face with proper features) ──
    // Neck with gradient
    final neckRect = Rect.fromCenter(
      center: Offset(cx, cy - 7),
      width: 8,
      height: 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, const Radius.circular(3)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [
            const Color(0xFFdcb080),
            const Color(0xFFd4a574),
            const Color(0xFFc09060),
          ],
        ).createShader(neckRect),
    );

    // Face (detailed 3D)
    _drawHumanFace(canvas, cx, cy - 16, c);

    // Dark hair (swept back with volume/depth)
    final hair = Path()
      ..moveTo(cx - 14, cy - 14)
      ..cubicTo(cx - 15, cy - 22, cx - 12, cy - 30, cx - 6, cy - 31)
      ..cubicTo(cx - 2, cy - 32, cx + 2, cy - 32, cx + 6, cy - 31)
      ..cubicTo(cx + 12, cy - 30, cx + 15, cy - 22, cx + 14, cy - 14)
      ..cubicTo(cx + 12, cy - 17, cx + 4, cy - 23, cx, cy - 24)
      ..cubicTo(cx - 4, cy - 23, cx - 12, cy - 17, cx - 14, cy - 14)
      ..close();
    canvas.drawPath(
      hair,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.5),
          colors: [
            const Color(0xFF3a2418),
            const Color(0xFF2a1a10),
            const Color(0xFF1a0a08),
          ],
        ).createShader(Rect.fromLTRB(cx - 16, cy - 32, cx + 16, cy - 14)),
    );
    // Hair shine
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 3, cy - 26), width: 12, height: 8),
      -1.5,
      1.8,
      false,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    // Side hair strands (flowing)
    final strand = Path()
      ..moveTo(cx - 13, cy - 14)
      ..cubicTo(cx - 14, cy - 10, cx - 14.5, cy - 6, cx - 13, cy - 3);
    canvas.drawPath(
      strand,
      Paint()
        ..color = const Color(0xFF2a1a10)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    final strand2 = Path()
      ..moveTo(cx + 13, cy - 14)
      ..cubicTo(cx + 14, cy - 10, cx + 14.5, cy - 6, cx + 13, cy - 3);
    canvas.drawPath(
      strand2,
      Paint()
        ..color = const Color(0xFF2a1a10)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Purple scarf
    final scarfRect = Rect.fromCenter(
      center: Offset(cx, cy - 6),
      width: 18,
      height: 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(scarfRect, const Radius.circular(2.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF3a1a5a),
            const Color(0xFF5a2a7a),
            const Color(0xFF3a1a5a),
          ],
        ).createShader(scarfRect),
    );

    // Attack flash
    if (atk > 0.5) {
      canvas.drawCircle(
        Offset(cx - 32, cy),
        10 * atk,
        Paint()
          ..color = c.withValues(alpha: atk * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Ambient particles
    for (var i = 0; i < 3; i++) {
      final a = _orbitalAngle * 0.8 + i * (2 * pi / 3);
      final dist = 20.0 + sin(_time * 2 + i) * 4;
      canvas.drawCircle(
        Offset(cx + cos(a) * dist, cy + sin(a) * dist * 0.4),
        1.5,
        Paint()
          ..color = c.withValues(alpha: 0.2 + sin(_time * 3 + i) * 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  //  MAGE — Hooded figure, face hidden, glowing cyan runes
  // ═══════════════════════════════════════════════════════
  void _renderMage(Canvas canvas, double cx, double cy, Color c) {
    final atk = _attackAnim;
    final sway = isMoving
        ? sin(_walkCycle * 0.8) * 3.5
        : sin(_idleBreath * 0.5) * 1.5;

    // ── Full-length robe (dark, flowing, with 3D depth shading) ──
    final robe = Path()
      ..moveTo(cx - 15, cy - 6)
      ..cubicTo(
        cx - 16,
        cy + 4,
        cx - 18 + sway,
        cy + 14,
        cx - 14 + sway * 0.5,
        cy + 22,
      )
      ..lineTo(cx + 14 + sway, cy + 22)
      ..cubicTo(cx + 18 + sway, cy + 14, cx + 16, cy + 4, cx + 15, cy - 6)
      ..close();
    canvas.drawPath(
      robe,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF061018),
            const Color(0xFF0e1e2a),
            const Color(0xFF0a1520),
            const Color(0xFF040c14),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(Rect.fromLTRB(cx - 18, cy - 6, cx + 18, cy + 22)),
    );
    // Robe fold shadows (3D depth)
    canvas.drawLine(
      Offset(cx - 6 + sway * 0.2, cy + 0),
      Offset(cx - 7 + sway * 0.4, cy + 20),
      Paint()
        ..color = const Color(0x18000000)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 4 + sway * 0.2, cy + 0),
      Offset(cx + 5 + sway * 0.4, cy + 20),
      Paint()
        ..color = const Color(0x10FFFFFF)
        ..strokeWidth = 0.8,
    );
    // Glowing rune symbols on robe front
    final runeGlow = 0.35 + _weaponGlow * 0.35;
    canvas.drawLine(
      Offset(cx, cy - 2),
      Offset(cx, cy + 18),
      Paint()
        ..color = c.withValues(alpha: runeGlow * 0.5)
        ..strokeWidth = 1.2,
    );
    for (var i = 0; i < 4; i++) {
      final ry = cy + 2 + i * 5.0;
      final rw = 4.0 + sin(_time * 2 + i) * 1;
      canvas.drawLine(
        Offset(cx - rw, ry),
        Offset(cx + rw, ry),
        Paint()
          ..color = c.withValues(alpha: runeGlow * (0.6 - i * 0.1))
          ..strokeWidth = 1.2,
      );
    }
    // Robe hem glow
    canvas.drawLine(
      Offset(cx - 14 + sway * 0.5, cy + 22),
      Offset(cx + 14 + sway, cy + 22),
      Paint()
        ..color = c.withValues(alpha: 0.4 + _weaponGlow * 0.2)
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // ── Upper body / chest piece (dark with 3D gradient and cyan trim) ──
    final chestRect = Rect.fromCenter(
      center: Offset(cx, cy - 2),
      width: 26,
      height: 12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect, const Radius.circular(5)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.4),
          colors: [
            const Color(0xFF223840),
            const Color(0xFF1a2a30),
            const Color(0xFF101e24),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(chestRect),
    );
    // Belt (leather with gem — 3D)
    final beltRect = Rect.fromCenter(
      center: Offset(cx, cy + 3),
      width: 26,
      height: 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beltRect, const Radius.circular(1.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4a3828),
            const Color(0xFF3a2a1a),
            const Color(0xFF2a1a10),
          ],
        ).createShader(beltRect),
    );
    // Gem with radial glow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 3), width: 6, height: 5),
      Paint()
        ..shader =
            RadialGradient(
              colors: [const Color(0xFFFFFFFF), c, _darken(c, 0.3)],
              stops: const [0.0, 0.4, 1.0],
            ).createShader(
              Rect.fromCenter(center: Offset(cx, cy + 3), width: 6, height: 5),
            ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 3), width: 8, height: 7),
      Paint()
        ..color = c.withValues(alpha: 0.3 + _weaponGlow * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ── Arms (robed, dark with 3D shading) ──
    _drawArm(
      canvas,
      cx - 13,
      cy - 2,
      cx - 17,
      cy + 8,
      const Color(0xFF0a1520),
      thickness: 6,
    );
    _drawArm(
      canvas,
      cx + 13,
      cy - 2,
      cx + 17,
      cy + 6,
      const Color(0xFF0a1520),
      thickness: 6,
    );
    // Gloved hands (curved, not square)
    _drawGlovedHand(canvas, cx - 17, cy + 9, const Color(0xFF2a2a30));
    _drawGlovedHand(canvas, cx + 17, cy + 7, const Color(0xFF2a2a30));

    // ── STAFF (ornate, with swirling cyan flame orb) ──
    final stBob = sin(_time * 2) * 1.5;
    // Shaft (dark, ornate with wood grain)
    canvas.drawLine(
      Offset(cx + 18, cy + 18),
      Offset(cx + 16 + stBob, cy - 28),
      Paint()
        ..color = const Color(0xFF1a1020)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 18, cy + 18),
      Offset(cx + 16 + stBob, cy - 28),
      Paint()
        ..color = const Color(0xFF2a2030)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Staff wrappings
    for (var i = 0; i < 4; i++) {
      final wy = cy + 10 - i * 8.0;
      canvas.drawLine(
        Offset(cx + 17 - stBob * 0.1 * i, wy - 1),
        Offset(cx + 17 - stBob * 0.1 * i, wy + 1),
        Paint()
          ..color = const Color(0xFF4a3a20)
          ..strokeWidth = 5,
      );
    }
    // Ornate staff head (curved prongs)
    final orbX = cx + 16.0 + stBob;
    final orbY = cy - 32.0;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(orbX - 3, orbY + 6), width: 8, height: 18),
      -1.8,
      1.5,
      false,
      Paint()
        ..color = const Color(0xFF3a3040)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(orbX + 3, orbY + 6), width: 8, height: 18),
      0.3,
      1.5,
      false,
      Paint()
        ..color = const Color(0xFF3a3040)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── Swirling flame orb (LARGE cyan with 3D depth) ──
    final orbSz = 10.0 + atk * 6;
    for (var i = 0; i < 3; i++) {
      final fa = _time * 4 + i * (2 * pi / 3);
      final fx = orbX + cos(fa) * (orbSz * 0.6);
      final fy = orbY - sin(fa).abs() * (orbSz * 0.8) - 2;
      canvas.drawCircle(
        Offset(fx, fy),
        3 + sin(_time * 5 + i) * 1,
        Paint()
          ..color = c.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawCircle(
      Offset(orbX, orbY),
      orbSz + 8,
      Paint()
        ..color = c.withValues(alpha: 0.15 + atk * 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    // 3D orb with radial gradient
    canvas.drawCircle(
      Offset(orbX, orbY),
      orbSz,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.25, -0.3),
              colors: [const Color(0xDDFFFFFF), c, _darken(c, 0.3)],
              stops: const [0.0, 0.4, 1.0],
            ).createShader(
              Rect.fromCenter(
                center: Offset(orbX, orbY),
                width: orbSz * 2,
                height: orbSz * 2,
              ),
            ),
    );
    // Inner bright core
    canvas.drawCircle(
      Offset(orbX - 2, orbY - 2),
      orbSz * 0.35,
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Flame tip
    final flameTip = Path()
      ..moveTo(orbX - 3, orbY - orbSz * 0.5)
      ..cubicTo(
        orbX + sin(_time * 6) * 3,
        orbY - orbSz - 4,
        orbX + sin(_time * 6) * 2,
        orbY - orbSz - 6,
        orbX + 2,
        orbY - orbSz * 0.3,
      );
    canvas.drawPath(
      flameTip,
      Paint()
        ..color = c.withValues(alpha: 0.5)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // ── Head — DEEP HOOD (face hidden in shadow) with 3D hood shape ──
    // Chin barely visible
    canvas.drawCircle(
      Offset(cx, cy - 14),
      12,
      Paint()..color = const Color(0xFF1a2a30),
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 10), width: 12, height: 10),
      0.3,
      2.5,
      false,
      Paint()
        ..color = const Color(0xFFb8a090)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Hood (large, 3D shaded)
    final hood = Path()
      ..moveTo(cx - 17, cy - 6)
      ..cubicTo(cx - 18, cy - 12, cx - 16, cy - 22, cx - 10, cy - 26)
      ..cubicTo(cx - 6, cy - 30, cx - 2, cy - 32, cx, cy - 32)
      ..cubicTo(cx + 2, cy - 32, cx + 6, cy - 30, cx + 10, cy - 26)
      ..cubicTo(cx + 16, cy - 22, cx + 18, cy - 12, cx + 17, cy - 6)
      ..close();
    canvas.drawPath(
      hood,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.3),
          colors: [
            const Color(0xFF142028),
            const Color(0xFF0a1520),
            const Color(0xFF060e14),
          ],
        ).createShader(Rect.fromLTRB(cx - 18, cy - 32, cx + 18, cy - 6)),
    );
    // Hood rim highlight
    canvas.drawPath(
      hood,
      Paint()
        ..color = c.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Hood fold (3D depth line)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 5, cy - 20), width: 14, height: 20),
      -1.2,
      1.5,
      false,
      Paint()
        ..color = const Color(0x10FFFFFF)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    // Shadow void inside hood
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 18), width: 18, height: 14),
      Paint()..color = const Color(0xFF000008),
    );
    // Faint eye glint deep in hood
    final eyeGlint = 0.3 + sin(_time * 3) * 0.15;
    canvas.drawCircle(
      Offset(cx - 3, cy - 19),
      1.5,
      Paint()
        ..color = c.withValues(alpha: eyeGlint)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      Offset(cx + 3, cy - 19),
      1.5,
      Paint()
        ..color = c.withValues(alpha: eyeGlint)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // ── Floating particles (cyan sparkles) ──
    for (var i = 0; i < 6; i++) {
      final a = _orbitalAngle * 0.6 + i * (pi / 3);
      final dist = 22.0 + sin(_time * 2.5 + i) * 5;
      final px = cx + cos(a) * dist;
      final py = cy - 5 + sin(a) * dist * 0.4;
      canvas.drawCircle(
        Offset(px, py),
        2 + sin(_time * 3.5 + i) * 0.8,
        Paint()
          ..color = c.withValues(alpha: 0.25 + sin(_time * 2 + i) * 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  // ═══════════════════════════════════════════════════════
  //  WARRIOR — Heavy dark plate armor, closed visor
  // ═══════════════════════════════════════════════════════
  void _renderWarrior(Canvas canvas, double cx, double cy, Color c) {
    final atk = _attackAnim;
    final legSwing = sin(_walkCycle) * 2.5;

    // ── Heavy armored legs (greaves with 3D shading) ──
    _drawLegs(
      canvas,
      cx,
      cy + 12,
      legSwing,
      const Color(0xFF3a3a4a),
      const Color(0xFF2a2a3a),
    );

    // ── Tasset / waist plates (3D layered) ──
    final tasset = Path()
      ..moveTo(cx - 14, cy + 6)
      ..cubicTo(cx - 14.5, cy + 10, cx - 13, cy + 13, cx - 12, cy + 14)
      ..lineTo(cx + 12, cy + 14)
      ..cubicTo(cx + 13, cy + 13, cx + 14.5, cy + 10, cx + 14, cy + 6)
      ..close();
    canvas.drawPath(
      tasset,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4a4a5a),
            const Color(0xFF3a3a4a),
            const Color(0xFF2a2a3a),
          ],
        ).createShader(Rect.fromLTRB(cx - 15, cy + 6, cx + 15, cy + 14)),
    );
    canvas.drawPath(
      tasset,
      Paint()
        ..color = c.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── BREASTPLATE (heavy, 3D with gradient and emblem) ──
    final bpRect = Rect.fromCenter(
      center: Offset(cx, cy - 1),
      width: 28,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bpRect, const Radius.circular(5)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.35),
          colors: [
            const Color(0xFF5a5a6a),
            const Color(0xFF4a4a5a),
            const Color(0xFF3a3a4a),
            const Color(0xFF2a2a3a),
          ],
          stops: const [0.0, 0.3, 0.65, 1.0],
        ).createShader(bpRect),
    );
    // Chest plate contour (3D roundness)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 3, cy - 3), width: 14, height: 10),
      -0.8,
      2.2,
      false,
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    // Glowing V-emblem
    final embGlow = 0.4 + atk * 0.6;
    final emblem = Path()
      ..moveTo(cx - 6, cy - 8)
      ..lineTo(cx, cy + 2)
      ..lineTo(cx + 6, cy - 8);
    canvas.drawPath(
      emblem,
      Paint()
        ..color = c.withValues(alpha: embGlow)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Armor edge rim
    canvas.drawRRect(
      RRect.fromRectAndRadius(bpRect, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFF6a6a7a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Belt (3D) ──
    final beltRect = Rect.fromCenter(
      center: Offset(cx, cy + 7),
      width: 28,
      height: 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beltRect, const Radius.circular(1.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4a3828),
            const Color(0xFF3a2a1a),
            const Color(0xFF2a1a10),
          ],
        ).createShader(beltRect),
    );
    canvas.drawCircle(
      Offset(cx, cy + 7),
      2.5,
      Paint()..color = const Color(0xFFCCAA44),
    );
    canvas.drawCircle(
      Offset(cx - 0.5, cy + 6.5),
      1,
      Paint()..color = const Color(0x44FFFFFF),
    );

    // ── Massive pauldrons (3D, already updated helper) ──
    final pb = sin(_walkCycle) * 0.6;
    _drawPauldron(canvas, cx - 16, cy - 10 + pb, c, -1);
    _drawPauldron(canvas, cx + 16, cy - 10 - pb, c, 1);

    // ── Arms (armored with 3D gradient) ──
    final armRect1 = Rect.fromCenter(
      center: Offset(cx - 18, cy + 0),
      width: 9,
      height: 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(armRect1, const Radius.circular(4)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            const Color(0xFF5a5a6a),
            const Color(0xFF4a4a5a),
            const Color(0xFF3a3a4a),
          ],
        ).createShader(armRect1),
    );
    final armRect2 = Rect.fromCenter(
      center: Offset(cx + 18, cy + 0),
      width: 9,
      height: 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(armRect2, const Radius.circular(4)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            const Color(0xFF5a5a6a),
            const Color(0xFF4a4a5a),
            const Color(0xFF3a3a4a),
          ],
        ).createShader(armRect2),
    );
    // Gauntlet hands
    _drawGlovedHand(
      canvas,
      cx - 19,
      cy + 8,
      const Color(0xFF4a4a5a),
      size: 1.0,
    );
    _drawGlovedHand(
      canvas,
      cx + 19,
      cy + 8,
      const Color(0xFF4a4a5a),
      size: 1.0,
    );

    // ── SHIELD (left — large round with 3D depth) ──
    final sBob = sin(_walkCycle * 0.5) * 2;
    final shieldRect = Rect.fromCenter(
      center: Offset(cx - 20, cy + 2 + sBob),
      width: 28,
      height: 28,
    );
    // Shield body with 3D radial gradient
    canvas.drawCircle(
      Offset(cx - 20, cy + 2 + sBob),
      14,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [
            const Color(0xFF5a5a6a),
            const Color(0xFF3a3a4a),
            const Color(0xFF2a2a3a),
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(shieldRect),
    );
    // Shield rim
    canvas.drawCircle(
      Offset(cx - 20, cy + 2 + sBob),
      14,
      Paint()
        ..color = const Color(0xFF6a6a7a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Shield boss (3D center)
    canvas.drawCircle(
      Offset(cx - 20, cy + 2 + sBob),
      5,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [
                const Color(0xFF7a7a8a),
                const Color(0xFF5a5a6a),
                const Color(0xFF4a4a5a),
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(cx - 20, cy + 2 + sBob),
                width: 10,
                height: 10,
              ),
            ),
    );
    canvas.drawCircle(
      Offset(cx - 20, cy + 2 + sBob),
      5,
      Paint()
        ..color = c.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Shield gleam
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx - 24, cy - 4 + sBob),
        width: 14,
        height: 14,
      ),
      -1.5,
      1.2,
      false,
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // ── MASSIVE SWORD (right — glowing purple edge with 3D blade) ──
    final sAngle = -0.4 + atk * 2.3;
    canvas.save();
    canvas.translate(cx + 20, cy + 2);
    canvas.rotate(sAngle);
    // Blade with gradient (3D steel)
    final blade = Path()
      ..moveTo(-3, 6)
      ..lineTo(3, 6)
      ..lineTo(2.5, -32)
      ..lineTo(0, -38)
      ..lineTo(-2.5, -32)
      ..close();
    canvas.drawPath(
      blade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF6a6a7a),
            Color(0xFF9a9aaa),
            Color(0xFFb0b0c0),
            Color(0xFF8a8a9a),
            Color(0xFF6a6a7a),
          ],
          stops: [0.0, 0.3, 0.5, 0.7, 1.0],
        ).createShader(const Rect.fromLTRB(-3, -38, 3, 6)),
    );
    // Glowing purple edge
    canvas.drawLine(
      const Offset(0, -38),
      const Offset(0, 6),
      Paint()
        ..color = c.withValues(alpha: 0.5 + atk * 0.3)
        ..strokeWidth = 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Edge highlight
    canvas.drawLine(
      const Offset(-1.5, -36),
      const Offset(-1.5, 4),
      Paint()
        ..color = const Color(0x33FFFFFF)
        ..strokeWidth = 1,
    );
    // Crossguard (3D)
    final cgRect = Rect.fromCenter(
      center: const Offset(0, 6),
      width: 20,
      height: 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cgRect, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF5a5060),
            Color(0xFF4a4050),
            Color(0xFF3a3040),
          ],
        ).createShader(cgRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(cgRect, const Radius.circular(2)),
      Paint()
        ..color = c.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Grip (leather wrapped)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(0, 13), width: 5, height: 10),
        const Radius.circular(2),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFF2a1a10),
            Color(0xFF4a3a2a),
            Color(0xFF2a1a10),
          ],
        ).createShader(const Rect.fromLTRB(-2.5, 8, 2.5, 18)),
    );
    // Pommel (3D)
    canvas.drawCircle(
      const Offset(0, 18),
      4,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: const [Color(0xFF6a6070), Color(0xFF4a4050)],
            ).createShader(
              Rect.fromCenter(center: const Offset(0, 18), width: 8, height: 8),
            ),
    );
    // Swing trail
    if (atk > 0.3) {
      final trail = Path()
        ..moveTo(3, -32)
        ..quadraticBezierTo(16, -22, 18, -6);
      canvas.drawPath(
        trail,
        Paint()
          ..color = c.withValues(alpha: atk * 0.6)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.restore();

    // ── HELMET (closed visor, horns, dark — 3D shaded) ──
    // Base helmet (3D sphere)
    final helmRect = Rect.fromCenter(
      center: Offset(cx, cy - 18),
      width: 30,
      height: 30,
    );
    canvas.drawCircle(
      Offset(cx, cy - 18),
      15,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.25, -0.35),
          colors: [
            const Color(0xFF5a5a6a),
            const Color(0xFF4a4a5a),
            const Color(0xFF3a3a4a),
            const Color(0xFF2a2a3a),
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ).createShader(helmRect),
    );
    // Face plate (3D curved)
    final fpRect = Rect.fromCenter(
      center: Offset(cx, cy - 16),
      width: 20,
      height: 18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fpRect, const Radius.circular(5)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [
            const Color(0xFF4a4a5a),
            const Color(0xFF3a3a4a),
            const Color(0xFF2a2a3a),
          ],
        ).createShader(fpRect),
    );
    // Metal edge
    canvas.drawCircle(
      Offset(cx, cy - 18),
      15,
      Paint()
        ..color = const Color(0xFF6a6a7a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // T-visor slit (glowing)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - 20), width: 14, height: 4),
        const Radius.circular(1.5),
      ),
      Paint()
        ..color = c.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      Offset(cx, cy - 19),
      Offset(cx, cy - 13),
      Paint()
        ..color = c.withValues(alpha: 0.4)
        ..strokeWidth = 2.5,
    );
    // Horns (3D shaded)
    for (final dir in [-1, 1]) {
      final hornPath = Path()
        ..moveTo(cx + dir * 8, cy - 28)
        ..cubicTo(
          cx + dir * 10,
          cy - 32,
          cx + dir * 13,
          cy - 36,
          cx + dir * 14,
          cy - 38,
        );
      canvas.drawPath(
        hornPath,
        Paint()
          ..color = const Color(0xFF2a2a3a)
          ..strokeWidth = 4.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        hornPath,
        Paint()
          ..color = const Color(0xFF4a4a5a)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      // Horn tip glow
      canvas.drawCircle(
        Offset(cx + dir * 14, cy - 38),
        2,
        Paint()
          ..color = c.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // Center ridge (3D)
    canvas.drawLine(
      Offset(cx, cy - 30),
      Offset(cx, cy - 20),
      Paint()
        ..color = const Color(0xFF6a6a7a)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    // Helmet specular highlight
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 4, cy - 24), width: 12, height: 8),
      -1.5,
      1.5,
      false,
      Paint()
        ..color = const Color(0x22FFFFFF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  NECROMANCER — Skull face, green fire, skeletal
  // ═══════════════════════════════════════════════════════
  void _renderNecromancer(Canvas canvas, double cx, double cy, Color c) {
    final atk = _attackAnim;
    final sway = isMoving
        ? sin(_walkCycle * 0.7) * 4
        : sin(_idleBreath * 0.5) * 2;

    // ── Tattered dark robe (jagged hem with 3D depth) ──
    final robe = Path()..moveTo(cx - 15, cy - 4);
    robe.cubicTo(
      cx - 16,
      cy + 4,
      cx - 18 + sway,
      cy + 12,
      cx - 15 + sway * 0.5,
      cy + 18,
    );
    for (var i = 0; i < 10; i++) {
      final x = cx + 15 - i * 3.2;
      final y = cy + 22 + sin(_time * 3 + i) * 2.5 + sway * 0.3;
      robe.lineTo(x, i.isEven ? y + 3 : y - 2);
    }
    robe.cubicTo(cx + 18 + sway, cy + 12, cx + 16, cy + 4, cx + 15, cy - 4);
    robe.close();
    canvas.drawPath(
      robe,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF060410),
            const Color(0xFF0e0a1c),
            const Color(0xFF0a0818),
            const Color(0xFF040210),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(Rect.fromLTRB(cx - 18, cy - 4, cx + 18, cy + 25)),
    );
    // Robe fold shadows
    canvas.drawLine(
      Offset(cx - 5 + sway * 0.2, cy + 2),
      Offset(cx - 6 + sway * 0.4, cy + 20),
      Paint()
        ..color = const Color(0x12FFFFFF)
        ..strokeWidth = 0.8,
    );

    // ── Upper body (dark robe with leather straps — 3D) ──
    final chestRect = Rect.fromCenter(
      center: Offset(cx, cy - 1),
      width: 26,
      height: 14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect, const Radius.circular(5)),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.4),
          colors: [
            const Color(0xFF221430),
            const Color(0xFF1a0e24),
            const Color(0xFF10081a),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(chestRect),
    );
    // Leather cross-straps (3D with highlight)
    canvas.drawLine(
      Offset(cx - 10, cy - 6),
      Offset(cx + 5, cy + 5),
      Paint()
        ..color = const Color(0xFF2a1a10)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx - 10, cy - 6),
      Offset(cx + 5, cy + 5),
      Paint()
        ..color = const Color(0xFF3a2a1a)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 10, cy - 6),
      Offset(cx - 5, cy + 5),
      Paint()
        ..color = const Color(0xFF2a1a10)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 10, cy - 6),
      Offset(cx - 5, cy + 5),
      Paint()
        ..color = const Color(0xFF3a2a1a)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // Belt (3D)
    final beltRect = Rect.fromCenter(
      center: Offset(cx, cy + 5),
      width: 26,
      height: 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(beltRect, const Radius.circular(1.5)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF4a3828),
            const Color(0xFF3a2a1a),
            const Color(0xFF2a1a10),
          ],
        ).createShader(beltRect),
    );

    // ── Arms (robed, 3D shading) ──
    _drawArm(
      canvas,
      cx - 13,
      cy - 2,
      cx - 18,
      cy + 8,
      const Color(0xFF0a0818),
      thickness: 6,
    );
    _drawArm(
      canvas,
      cx + 13,
      cy - 2,
      cx + 18,
      cy + 6,
      const Color(0xFF0a0818),
      thickness: 6,
    );
    // Skeletal green hands with finger bones
    _drawSkeletalHand(canvas, cx - 18, cy + 9, const Color(0xFF8aaa6a), c);
    _drawSkeletalHand(canvas, cx + 18, cy + 7, const Color(0xFF8aaa6a), c);

    // ── SKULL STAFF (left hand, with green fire — 3D) ──
    final stBob = sin(_time * 1.8) * 1.5;
    // Shaft (dark wood, 3D)
    canvas.drawLine(
      Offset(cx - 19, cy + 18),
      Offset(cx - 17 + stBob, cy - 26),
      Paint()
        ..color = const Color(0xFF1a0e04)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx - 19, cy + 18),
      Offset(cx - 17 + stBob, cy - 26),
      Paint()
        ..color = const Color(0xFF2a1a0a)
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
    // Bone rings on staff (3D)
    for (var i = 0; i < 3; i++) {
      final bx = cx - 18 + stBob * (0.2 + i * 0.15);
      final by = cy - 2 - i * 8.0;
      canvas.drawCircle(
        Offset(bx, by),
        3.5,
        Paint()..color = const Color(0xFF8a8070).withValues(alpha: 0.4),
      );
      canvas.drawCircle(
        Offset(bx, by),
        3,
        Paint()
          ..shader =
              RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  const Color(0xFFd8d0b8),
                  const Color(0xFFc8c0a0),
                  const Color(0xFFa8a088),
                ],
              ).createShader(
                Rect.fromCenter(center: Offset(bx, by), width: 6, height: 6),
              ),
      );
    }
    // Skull on top (3D with shading)
    final skX = cx - 17.0 + stBob;
    final skY = cy - 30.0;
    final jaw = sin(_time * 3.5) * 1.5 + atk * 3;
    final skullRect = Rect.fromCenter(
      center: Offset(skX, skY),
      width: 16,
      height: 16,
    );
    canvas.drawCircle(
      Offset(skX, skY),
      8,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [
            const Color(0xFFe8e0c8),
            const Color(0xFFd8d0b8),
            const Color(0xFFb8b098),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(skullRect),
    );
    // Skull features (deeper eye sockets)
    for (final dir in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(skX + dir * 3, skY - 1),
          width: 5,
          height: 5.5,
        ),
        Paint()..color = const Color(0xFF1a1a1a),
      );
      // Green glowing eyes
      canvas.drawCircle(
        Offset(skX + dir * 3, skY - 1),
        2.5,
        Paint()
          ..color = c.withValues(alpha: 0.7)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(skX + dir * 3, skY - 1),
        1,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(skX, skY + 3), width: 3, height: 2.5),
      Paint()..color = const Color(0xFF1a1a1a),
    );
    // Jaw with teeth suggestion
    canvas.drawArc(
      Rect.fromCenter(center: Offset(skX, skY + 5 + jaw), width: 10, height: 5),
      0.2,
      2.7,
      false,
      Paint()
        ..color = const Color(0xFFc0b8a0)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Teeth marks
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(skX - 3 + i * 2.0, skY + 4.5),
        Offset(skX - 3 + i * 2.0, skY + 5.5 + jaw * 0.3),
        Paint()
          ..color = const Color(0xFFd8d0b8)
          ..strokeWidth = 1,
      );
    }
    // GREEN FIRE from skull (3D flame shapes)
    for (var i = 0; i < 3; i++) {
      final fa = _time * 5 + i * 2;
      final fh = 8 + sin(fa) * 3;
      final fx = skX + sin(fa * 0.7 + i) * 3;
      final flameRect = Rect.fromCenter(
        center: Offset(fx, skY - 8 - fh * 0.3),
        width: (5 - i).toDouble(),
        height: fh,
      );
      canvas.drawOval(
        flameRect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, 0.3),
            colors: [
              c.withValues(alpha: 0.5 - i * 0.12),
              c.withValues(alpha: 0.1),
            ],
          ).createShader(flameRect)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (3 + i * 2).toDouble(),
          ),
      );
    }

    // ── HEAD — Skull face in deep dark hood (3D) ──
    final hood = Path()
      ..moveTo(cx - 16, cy - 6)
      ..cubicTo(cx - 17, cy - 12, cx - 15, cy - 22, cx - 10, cy - 24)
      ..cubicTo(cx - 6, cy - 28, cx - 2, cy - 30, cx, cy - 30)
      ..cubicTo(cx + 2, cy - 30, cx + 6, cy - 28, cx + 10, cy - 24)
      ..cubicTo(cx + 15, cy - 22, cx + 17, cy - 12, cx + 16, cy - 6)
      ..close();
    canvas.drawPath(
      hood,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.3),
          colors: [
            const Color(0xFF120a1c),
            const Color(0xFF0a0818),
            const Color(0xFF040210),
          ],
        ).createShader(Rect.fromLTRB(cx - 17, cy - 30, cx + 17, cy - 6)),
    );
    canvas.drawPath(
      hood,
      Paint()
        ..color = c.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    // Hood fold line
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 4, cy - 18), width: 12, height: 18),
      -1.2,
      1.5,
      false,
      Paint()
        ..color = const Color(0x0AFFFFFF)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Skull FACE inside hood (3D shaded)
    final faceRect = Rect.fromCenter(
      center: Offset(cx, cy - 17),
      width: 20,
      height: 20,
    );
    canvas.drawCircle(
      Offset(cx, cy - 17),
      10,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [
            const Color(0xFFd8d0b8),
            const Color(0xFFc8c0a8),
            const Color(0xFFa8a088),
          ],
        ).createShader(faceRect),
    );
    // Skull eye sockets (deep, 3D)
    for (final dir in [-1, 1]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + dir * 4, cy - 19),
          width: 7,
          height: 7.5,
        ),
        Paint()..color = const Color(0xFF0a0a0a),
      );
      // GREEN GLOWING EYES
      final eyeG = 0.7 + _weaponGlow * 0.3 + atk * 0.3;
      canvas.drawCircle(
        Offset(cx + dir * 4, cy - 19),
        3,
        Paint()
          ..color = c.withValues(alpha: eyeG)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(cx + dir * 4, cy - 19),
        1.5,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
    // Nose hole
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 15), width: 3.5, height: 3.5),
      Paint()..color = const Color(0xFF1a1a1a),
    );
    // Jaw line with teeth
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy - 11), width: 14, height: 8),
      0.2,
      2.7,
      false,
      Paint()
        ..color = const Color(0xFFb0a890)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Cheekbone highlights (3D skull shape)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 5, cy - 16), width: 6, height: 5),
      -0.5,
      1.5,
      false,
      Paint()
        ..color = const Color(0x15FFFFFF)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // ── Orbiting green flames/souls (enhanced) ──
    for (var i = 0; i < 4; i++) {
      final a = _orbitalAngle + i * (pi / 2);
      final sd = 24.0 + sin(_time * 2 + i) * 4;
      final sx = cx + cos(a) * sd;
      final sy = cy - 2 + sin(a) * sd * 0.5;
      // Flame wisp with 3D glow
      canvas.drawCircle(
        Offset(sx, sy),
        5 + sin(_time * 3 + i) * 1,
        Paint()
          ..color = c.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawCircle(
        Offset(sx, sy),
        3,
        Paint()
          ..shader =
              RadialGradient(
                colors: [const Color(0xAAFFFFFF), c, c.withValues(alpha: 0.3)],
                stops: const [0.0, 0.4, 1.0],
              ).createShader(
                Rect.fromCenter(center: Offset(sx, sy), width: 6, height: 6),
              ),
      );
      // Flame trail upward
      final trail = Path()
        ..moveTo(sx, sy)
        ..cubicTo(
          sx + sin(_time * 4 + i) * 2,
          sy - 3,
          sx + sin(_time * 5 + i) * 3,
          sy - 5,
          sx + sin(_time * 4 + i) * 1.5,
          sy - 7,
        );
      canvas.drawPath(
        trail,
        Paint()
          ..color = c.withValues(alpha: 0.25)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }

    // ── Ground energy ──
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 22), width: 40, height: 14),
      Paint()
        ..color = c.withValues(alpha: 0.1 + sin(_time * 2.5) * 0.05)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════

  void _drawLegs(
    Canvas canvas,
    double cx,
    double cy,
    double swing,
    Color legColor,
    Color bootColor,
  ) {
    // Left leg — curved thigh-to-calf shape with 3D gradient
    final lx = cx - 6 + swing * 0.4;
    final ly = cy + swing.abs() * 0.2;
    final leftLeg = Path()
      ..moveTo(lx - 4.5, ly - 6)
      ..cubicTo(lx - 5, ly - 2, lx - 4.5, ly + 3, lx - 3.5, ly + 6)
      ..lineTo(lx + 3.5, ly + 6)
      ..cubicTo(lx + 4.5, ly + 3, lx + 5, ly - 2, lx + 4.5, ly - 6)
      ..close();
    canvas.drawPath(
      leftLeg,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _darken(legColor, 0.3),
                legColor,
                _lighten(legColor, 0.15),
                legColor,
              ],
              stops: const [0.0, 0.3, 0.55, 1.0],
            ).createShader(
              Rect.fromCenter(center: Offset(lx, ly), width: 10, height: 14),
            ),
    );
    // Knee highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(lx + 1, ly - 1), width: 4, height: 5),
      Paint()..color = _lighten(legColor, 0.12).withValues(alpha: 0.5),
    );

    // Right leg
    final rx = cx + 6 - swing * 0.4;
    final ry = cy + (-swing).abs() * 0.2;
    final rightLeg = Path()
      ..moveTo(rx - 4.5, ry - 6)
      ..cubicTo(rx - 5, ry - 2, rx - 4.5, ry + 3, rx - 3.5, ry + 6)
      ..lineTo(rx + 3.5, ry + 6)
      ..cubicTo(rx + 4.5, ry + 3, rx + 5, ry - 2, rx + 4.5, ry - 6)
      ..close();
    canvas.drawPath(
      rightLeg,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                _darken(legColor, 0.3),
                legColor,
                _lighten(legColor, 0.15),
                legColor,
              ],
              stops: const [0.0, 0.3, 0.55, 1.0],
            ).createShader(
              Rect.fromCenter(center: Offset(rx, ry), width: 10, height: 14),
            ),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(rx + 1, ry - 1), width: 4, height: 5),
      Paint()..color = _lighten(legColor, 0.12).withValues(alpha: 0.5),
    );

    // Left boot — rounded with toe curve and 3D shading
    final lbx = cx - 6 + swing * 0.5;
    final lby = cy + 6 + swing.abs() * 0.3;
    final leftBoot = Path()
      ..moveTo(lbx - 5, lby - 3)
      ..cubicTo(lbx - 5.5, lby, lbx - 5, lby + 2, lbx - 3, lby + 3)
      ..quadraticBezierTo(lbx, lby + 3.5, lbx + 4, lby + 3)
      ..cubicTo(lbx + 5.5, lby + 2.5, lbx + 5.5, lby, lbx + 5, lby - 3)
      ..close();
    canvas.drawPath(
      leftBoot,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.2, -0.4),
              colors: [
                _lighten(bootColor, 0.2),
                bootColor,
                _darken(bootColor, 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromCenter(center: Offset(lbx, lby), width: 12, height: 8),
            ),
    );
    // Boot sole
    canvas.drawLine(
      Offset(lbx - 4, lby + 3),
      Offset(lbx + 4, lby + 3),
      Paint()
        ..color = _darken(bootColor, 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Right boot
    final rbx = cx + 6 - swing * 0.5;
    final rby = cy + 6 + (-swing).abs() * 0.3;
    final rightBoot = Path()
      ..moveTo(rbx - 5, rby - 3)
      ..cubicTo(rbx - 5.5, rby, rbx - 5, rby + 2, rbx - 3, rby + 3)
      ..quadraticBezierTo(rbx, rby + 3.5, rbx + 4, rby + 3)
      ..cubicTo(rbx + 5.5, rby + 2.5, rbx + 5.5, rby, rbx + 5, rby - 3)
      ..close();
    canvas.drawPath(
      rightBoot,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.2, -0.4),
              colors: [
                _lighten(bootColor, 0.2),
                bootColor,
                _darken(bootColor, 0.3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromCenter(center: Offset(rbx, rby), width: 12, height: 8),
            ),
    );
    canvas.drawLine(
      Offset(rbx - 4, rby + 3),
      Offset(rbx + 4, rby + 3),
      Paint()
        ..color = _darken(bootColor, 0.5)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Draw a hand with curved fingers instead of a flat square/circle
  void _drawHand(
    Canvas canvas,
    double hx,
    double hy,
    Color skinColor, {
    double size = 1.0,
    double fingerSpread = 0.0,
  }) {
    final s = 3.5 * size;
    // Whole hand as one smooth silhouette — palm + fingers + thumb in a single path
    final hand = Path();
    // Start at wrist (bottom-left)
    hand.moveTo(hx - s * 0.7, hy + s * 0.6);
    // Left palm edge up to pinky
    hand.cubicTo(
      hx - s * 0.85,
      hy + s * 0.1,
      hx - s * 0.9,
      hy - s * 0.3,
      hx - s * 0.8 + fingerSpread * -1.5,
      hy - s * 0.7,
    );
    // Pinky finger (smooth taper up and back)
    hand.cubicTo(
      hx - s * 0.85,
      hy - s * 1.2,
      hx - s * 0.65,
      hy - s * 1.5,
      hx - s * 0.55 + fingerSpread * -1.0,
      hy - s * 1.35,
    );
    // Dip between pinky and ring
    hand.cubicTo(
      hx - s * 0.45,
      hy - s * 1.1,
      hx - s * 0.35,
      hy - s * 1.1,
      hx - s * 0.25 + fingerSpread * -0.5,
      hy - s * 1.2,
    );
    // Ring finger
    hand.cubicTo(
      hx - s * 0.3,
      hy - s * 1.55,
      hx - s * 0.05,
      hy - s * 1.6,
      hx + s * 0.0,
      hy - s * 1.45,
    );
    // Dip between ring and middle
    hand.cubicTo(
      hx + s * 0.05,
      hy - s * 1.2,
      hx + s * 0.15,
      hy - s * 1.15,
      hx + s * 0.2 + fingerSpread * 0.5,
      hy - s * 1.3,
    );
    // Middle finger (tallest)
    hand.cubicTo(
      hx + s * 0.15,
      hy - s * 1.7,
      hx + s * 0.4,
      hy - s * 1.75,
      hx + s * 0.45,
      hy - s * 1.55,
    );
    // Dip between middle and index
    hand.cubicTo(
      hx + s * 0.5,
      hy - s * 1.25,
      hx + s * 0.55,
      hy - s * 1.2,
      hx + s * 0.6 + fingerSpread * 1.0,
      hy - s * 1.3,
    );
    // Index finger
    hand.cubicTo(
      hx + s * 0.55,
      hy - s * 1.6,
      hx + s * 0.8,
      hy - s * 1.55,
      hx + s * 0.85,
      hy - s * 1.3,
    );
    // Right palm edge down to wrist
    hand.cubicTo(
      hx + s * 0.9,
      hy - s * 0.3,
      hx + s * 0.85,
      hy + s * 0.1,
      hx + s * 0.7,
      hy + s * 0.6,
    );
    // Bottom of palm (wrist)
    hand.cubicTo(
      hx + s * 0.3,
      hy + s * 0.75,
      hx - s * 0.3,
      hy + s * 0.75,
      hx - s * 0.7,
      hy + s * 0.6,
    );
    hand.close();
    canvas.drawPath(
      hand,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.15, -0.2),
              colors: [
                _lighten(skinColor, 0.15),
                skinColor,
                _darken(skinColor, 0.18),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromCenter(
                center: Offset(hx, hy - s * 0.3),
                width: s * 2.5,
                height: s * 3,
              ),
            )
        ..isAntiAlias = true,
    );
    // Thumb — smooth curved shape on the side
    final thumb = Path()
      ..moveTo(hx - s * 0.75, hy + s * 0.15)
      ..cubicTo(
        hx - s * 1.2,
        hy - s * 0.1,
        hx - s * 1.35,
        hy - s * 0.6,
        hx - s * 1.1,
        hy - s * 0.9,
      )
      ..cubicTo(
        hx - s * 0.9,
        hy - s * 1.05,
        hx - s * 0.7,
        hy - s * 0.8,
        hx - s * 0.65,
        hy - s * 0.5,
      )
      ..cubicTo(
        hx - s * 0.6,
        hy - s * 0.2,
        hx - s * 0.65,
        hy + s * 0.05,
        hx - s * 0.75,
        hy + s * 0.15,
      )
      ..close();
    canvas.drawPath(
      thumb,
      Paint()
        ..color = skinColor
        ..isAntiAlias = true,
    );
    // Subtle knuckle shading
    for (var i = 0; i < 4; i++) {
      final kx =
          hx - s * 0.55 + i * (s * 0.35) + fingerSpread * (i - 1.5) * 0.5;
      final ky = hy - s * 0.75;
      canvas.drawCircle(
        Offset(kx, ky),
        s * 0.18,
        Paint()
          ..color = _darken(skinColor, 0.08).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  /// Draw a gloved/armored hand (for mage, warrior, necromancer)
  void _drawGlovedHand(
    Canvas canvas,
    double hx,
    double hy,
    Color gloveColor, {
    double size = 1.0,
  }) {
    final s = 3.5 * size;
    // Entire gloved hand as one smooth silhouette
    final hand = Path();
    hand.moveTo(hx - s * 0.7, hy + s * 0.6);
    // Left edge up
    hand.cubicTo(
      hx - s * 0.85,
      hy + s * 0.1,
      hx - s * 0.9,
      hy - s * 0.2,
      hx - s * 0.8,
      hy - s * 0.6,
    );
    // Pinky
    hand.cubicTo(
      hx - s * 0.85,
      hy - s * 1.1,
      hx - s * 0.65,
      hy - s * 1.3,
      hx - s * 0.5,
      hy - s * 1.2,
    );
    // Dip
    hand.cubicTo(
      hx - s * 0.4,
      hy - s * 1.0,
      hx - s * 0.3,
      hy - s * 1.0,
      hx - s * 0.2,
      hy - s * 1.1,
    );
    // Ring
    hand.cubicTo(
      hx - s * 0.25,
      hy - s * 1.45,
      hx + s * 0.0,
      hy - s * 1.5,
      hx + s * 0.05,
      hy - s * 1.35,
    );
    // Dip
    hand.cubicTo(
      hx + s * 0.1,
      hy - s * 1.1,
      hx + s * 0.2,
      hy - s * 1.05,
      hx + s * 0.25,
      hy - s * 1.2,
    );
    // Middle (tallest)
    hand.cubicTo(
      hx + s * 0.2,
      hy - s * 1.6,
      hx + s * 0.45,
      hy - s * 1.6,
      hx + s * 0.5,
      hy - s * 1.4,
    );
    // Dip
    hand.cubicTo(
      hx + s * 0.55,
      hy - s * 1.15,
      hx + s * 0.6,
      hy - s * 1.1,
      hx + s * 0.65,
      hy - s * 1.2,
    );
    // Index
    hand.cubicTo(
      hx + s * 0.6,
      hy - s * 1.5,
      hx + s * 0.85,
      hy - s * 1.4,
      hx + s * 0.85,
      hy - s * 1.15,
    );
    // Right edge down
    hand.cubicTo(
      hx + s * 0.9,
      hy - s * 0.2,
      hx + s * 0.85,
      hy + s * 0.1,
      hx + s * 0.7,
      hy + s * 0.6,
    );
    // Wrist
    hand.cubicTo(
      hx + s * 0.3,
      hy + s * 0.75,
      hx - s * 0.3,
      hy + s * 0.75,
      hx - s * 0.7,
      hy + s * 0.6,
    );
    hand.close();
    canvas.drawPath(
      hand,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.2, -0.25),
              colors: [
                _lighten(gloveColor, 0.2),
                gloveColor,
                _darken(gloveColor, 0.25),
              ],
              stops: const [0.0, 0.45, 1.0],
            ).createShader(
              Rect.fromCenter(
                center: Offset(hx, hy - s * 0.3),
                width: s * 2.5,
                height: s * 3,
              ),
            )
        ..isAntiAlias = true,
    );
    // Gauntlet cuff at wrist
    final cuff = Path()
      ..moveTo(hx - s * 0.75, hy + s * 0.45)
      ..cubicTo(
        hx - s * 0.4,
        hy + s * 0.55,
        hx + s * 0.4,
        hy + s * 0.55,
        hx + s * 0.75,
        hy + s * 0.45,
      );
    canvas.drawPath(
      cuff,
      Paint()
        ..color = _lighten(gloveColor, 0.18)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    // Subtle knuckle plate highlight
    canvas.drawPath(
      Path()
        ..moveTo(hx - s * 0.5, hy - s * 0.55)
        ..cubicTo(
          hx - s * 0.2,
          hy - s * 0.65,
          hx + s * 0.2,
          hy - s * 0.65,
          hx + s * 0.5,
          hy - s * 0.55,
        ),
      Paint()
        ..color = _lighten(gloveColor, 0.15).withValues(alpha: 0.6)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  /// Draw a skeletal hand (for necromancer)
  void _drawSkeletalHand(
    Canvas canvas,
    double hx,
    double hy,
    Color boneColor,
    Color glowColor,
  ) {
    // Smooth wrist bone shape
    final wrist = Path()
      ..moveTo(hx - 2.5, hy + 3)
      ..cubicTo(hx - 3, hy + 1, hx - 2.5, hy - 0.5, hx, hy - 1)
      ..cubicTo(hx + 2.5, hy - 0.5, hx + 3, hy + 1, hx + 2.5, hy + 3)
      ..cubicTo(hx + 1, hy + 3.5, hx - 1, hy + 3.5, hx - 2.5, hy + 3)
      ..close();
    canvas.drawPath(
      wrist,
      Paint()
        ..color = boneColor
        ..isAntiAlias = true,
    );
    // Metacarpal bones — smooth tapered strokes fanning out
    final fingerAngles = [-0.35, -0.12, 0.08, 0.3];
    final fingerLengths = [7.5, 9.0, 9.5, 7.0];
    for (var i = 0; i < 4; i++) {
      final angle = fingerAngles[i] + sin(_time * 2.5 + i) * 0.04;
      final len = fingerLengths[i];
      final mx = hx + sin(angle) * len * 0.5;
      final my = hy - 1 - cos(angle) * len * 0.5;
      final tx = hx + sin(angle) * len;
      final ty = hy - 1 - cos(angle) * len;
      // Metacarpal (thicker base)
      canvas.drawLine(
        Offset(hx, hy - 0.5),
        Offset(mx, my),
        Paint()
          ..color = boneColor
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
      // Phalanx (thinner tip)
      canvas.drawLine(
        Offset(mx, my),
        Offset(tx, ty),
        Paint()
          ..color = _lighten(boneColor, 0.1)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true,
      );
      // Smooth joint at knuckle
      canvas.drawCircle(
        Offset(mx, my),
        1.2,
        Paint()
          ..color = _lighten(boneColor, 0.15)
          ..isAntiAlias = true,
      );
      // Fingertip
      canvas.drawCircle(
        Offset(tx, ty),
        0.8,
        Paint()
          ..color = _lighten(boneColor, 0.2)
          ..isAntiAlias = true,
      );
    }
    // Green glow around hand — soft radial
    canvas.drawCircle(
      Offset(hx, hy - 3),
      8,
      Paint()
        ..color = glowColor.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..isAntiAlias = true,
    );
  }

  void _drawPauldron(Canvas canvas, double x, double y, Color c, int dir) {
    // 3D layered shoulder plate with gradient
    final pRect = Rect.fromCenter(center: Offset(x, y), width: 17, height: 13);
    // Base plate with 3D gradient
    canvas.drawOval(
      pRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(dir * -0.3, -0.4),
          colors: [
            _lighten(const Color(0xFF5a5a6a), 0.2),
            const Color(0xFF4a4a5a),
            _darken(const Color(0xFF4a4a5a), 0.3),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(pRect),
    );
    // Edge rim — metallic highlight
    canvas.drawOval(
      pRect,
      Paint()
        ..color = const Color(0xFF7a7a8a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Top specular highlight
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x + dir * -2, y - 3), width: 8, height: 5),
      Paint()..color = const Color(0x22FFFFFF),
    );
    // Spike with 3D shading
    final spike = Path()
      ..moveTo(x + dir * 3, y - 4)
      ..lineTo(x + dir * 8, y - 14)
      ..lineTo(x + dir * 6, y - 3)
      ..close();
    canvas.drawPath(
      spike,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _lighten(const Color(0xFF4a4a5a), 0.15),
            _darken(const Color(0xFF4a4a5a), 0.2),
          ],
        ).createShader(Rect.fromLTRB(x, y - 14, x + dir * 8.0, y)),
    );
    // Spike tip gleam
    canvas.drawCircle(
      Offset(x + dir * 8.0, y - 14),
      1.5,
      Paint()
        ..color = const Color(0x44FFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    // Glow accent
    canvas.drawOval(
      pRect,
      Paint()
        ..color = c.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  /// Draw a 3D-shaded arm segment (curved, with gradient)
  void _drawArm(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    Color armColor, {
    double thickness = 5.5,
  }) {
    // Draw arm as a thick curved stroke with round caps for smoothness
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..color = _darken(armColor, 0.15)
        ..strokeWidth = thickness + 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(x1, y1),
      Offset(x2, y2),
      Paint()
        ..color = armColor
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );
    // Highlight edge
    final mx = (x1 + x2) / 2;
    final my = (y1 + y2) / 2;
    canvas.drawCircle(
      Offset(mx - 0.5, my - 1),
      thickness * 0.35,
      Paint()..color = _lighten(armColor, 0.15).withValues(alpha: 0.5),
    );
  }

  /// Draw a 3D face for human characters (archer)
  void _drawHumanFace(Canvas canvas, double cx, double cy, Color classColor) {
    final skinColor = const Color(0xFFd4a574);
    // Head shape — oval with gradient for 3D roundness
    final headRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 26,
      height: 28,
    );
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.25),
          colors: [
            _lighten(skinColor, 0.12),
            skinColor,
            _darken(skinColor, 0.2),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(headRect),
    );

    // Jaw contour (soft shadow under chin area)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 20, height: 22),
      0.4,
      2.3,
      false,
      Paint()
        ..color = _darken(skinColor, 0.12)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Eyes — almond-shaped with iris and pupil
    for (final side in [-1, 1]) {
      final ex = cx + side * 5.0;
      final ey = cy - 2.5;
      // Eye white
      final eyeShape = Path()
        ..moveTo(ex - 4, ey)
        ..cubicTo(ex - 2, ey - 2.5, ex + 2, ey - 2.5, ex + 4, ey)
        ..cubicTo(ex + 2, ey + 2, ex - 2, ey + 2, ex - 4, ey)
        ..close();
      canvas.drawPath(eyeShape, Paint()..color = const Color(0xFFF0EDE8));
      // Iris
      canvas.drawCircle(
        Offset(ex + 0.3, ey),
        2,
        Paint()..color = const Color(0xFF4a3020),
      );
      // Pupil
      canvas.drawCircle(
        Offset(ex + 0.3, ey),
        1,
        Paint()..color = const Color(0xFF1a1010),
      );
      // Class-colored glint
      canvas.drawCircle(
        Offset(ex - 0.5, ey - 0.8),
        0.7,
        Paint()..color = classColor.withValues(alpha: 0.7),
      );
      // Upper eyelid line
      final eyelid = Path()
        ..moveTo(ex - 4, ey)
        ..cubicTo(ex - 2, ey - 2.8, ex + 2, ey - 2.8, ex + 4, ey);
      canvas.drawPath(
        eyelid,
        Paint()
          ..color = const Color(0xFF2a1a10)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
      // Lower lash shadow
      canvas.drawPath(
        Path()
          ..moveTo(ex - 3, ey + 0.5)
          ..cubicTo(ex - 1, ey + 1.8, ex + 1, ey + 1.8, ex + 3, ey + 0.5),
        Paint()
          ..color = _darken(skinColor, 0.15)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
    }

    // Eyebrows (stern, angled)
    canvas.drawLine(
      Offset(cx - 8, cy - 5.5),
      Offset(cx - 2, cy - 5),
      Paint()
        ..color = const Color(0xFF2a1a10)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(cx + 2, cy - 5),
      Offset(cx + 8, cy - 5.5),
      Paint()
        ..color = const Color(0xFF2a1a10)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Nose — subtle curved shape
    final nose = Path()
      ..moveTo(cx, cy - 2)
      ..cubicTo(cx - 0.5, cy + 1, cx - 1.5, cy + 2.5, cx - 1.5, cy + 3)
      ..cubicTo(cx - 0.5, cy + 3.5, cx + 0.5, cy + 3.5, cx + 1.5, cy + 3)
      ..cubicTo(cx + 1.5, cy + 2.5, cx + 0.5, cy + 1, cx, cy - 2);
    canvas.drawPath(
      nose,
      Paint()
        ..color = _darken(skinColor, 0.1)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Mouth — curved line with lip shading
    final mouth = Path()
      ..moveTo(cx - 3.5, cy + 5)
      ..cubicTo(cx - 1, cy + 5.8, cx + 1, cy + 5.8, cx + 3.5, cy + 5);
    canvas.drawPath(
      mouth,
      Paint()
        ..color = const Color(0xFF9a6050)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Upper lip
    canvas.drawPath(
      Path()
        ..moveTo(cx - 3, cy + 4.5)
        ..cubicTo(cx - 1, cy + 4, cx + 1, cy + 4, cx + 3, cy + 4.5),
      Paint()
        ..color = const Color(0xFFb07060)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Cheek highlight (3D roundness)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 5, cy + 2), width: 6, height: 4),
      Paint()..color = _lighten(skinColor, 0.08).withValues(alpha: 0.4),
    );
  }

  // Color utility helpers
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
