import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/player_class.dart';
import 'components/dark_portal.dart';
import 'components/effects.dart';
import 'components/enemy.dart';
import 'components/floating_joystick.dart';
import 'components/hud.dart';
import 'components/player.dart';
import 'components/room_manager.dart';
import 'config.dart';

/// Main Flame game.
class RiftclassGame extends FlameGame with HasCollisionDetection {
  RiftclassGame({
    required this.selectedClass,
    required this.worldIndex,
    required this.levelIndex,
  });

  final PlayerClassName selectedClass;
  final int worldIndex;
  final int levelIndex;

  Player? player;
  late RoomManager roomManager;
  late FloatingJoystick joystick;
  late World gameWorld;

  /// VFX layer rendered above all entities (sparks, damage numbers).
  late EffectsLayer effects;

  /// VFX layer rendered on the ground, under entities (dust, shockwaves).
  late EffectsLayer groundFx;

  // ── Camera (smooth follow + trauma shake) ──
  late PositionComponent _camTarget;
  final Vector2 _camPos = Vector2.zero();
  final Random _shakeRng = Random();
  double _shakeTime = 0;
  double _shakeDuration = 0;
  double _shakeIntensity = 0;

  // ── Lifecycle ──

  @override
  Color backgroundColor() => GameConfig.bgColor;

  @override
  Future<void> onLoad() async {
    gameWorld = World();
    add(gameWorld);

    final cam = CameraComponent(world: gameWorld);
    add(cam);

    groundFx = EffectsLayer(priority: -50);
    effects = EffectsLayer(priority: 900);
    gameWorld.add(groundFx);
    gameWorld.add(effects);

    roomManager = RoomManager(worldIndex: worldIndex, levelIndex: levelIndex);
    add(roomManager);

    final classData = PlayerClassData.all[selectedClass]!;
    player = Player(classData: classData);
    gameWorld.add(player!);

    joystick = FloatingJoystick();
    cam.viewport.add(joystick);
    cam.viewport.add(Hud());

    roomManager.loadRoom();

    _camPos.setFrom(player!.position);
    _camTarget = PositionComponent(position: player!.position.clone());
    gameWorld.add(_camTarget);
    cam.follow(_camTarget, snap: true);
  }

  /// Trauma-style camera shake. Bigger [intensity] = stronger displacement.
  void shakeCamera({double intensity = 5, double duration = 0.25}) {
    if (intensity >= _shakeIntensity * (_shakeTime / max(_shakeDuration, 0.01))) {
      _shakeIntensity = intensity;
      _shakeDuration = duration;
      _shakeTime = duration;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (player != null) {
      if (joystick.relativeDelta.length2 > 0.01) {
        player!.velocity = joystick.relativeDelta * player!.speed;
      } else {
        player!.velocity = Vector2.zero();
      }

      // Smooth camera follow
      final t = (dt * 6).clamp(0.0, 1.0);
      _camPos.add((player!.position - _camPos) * t);
    }

    // Shake offset (decays linearly)
    double sx = 0, sy = 0;
    if (_shakeTime > 0) {
      _shakeTime -= dt;
      final f = _shakeIntensity *
          (_shakeTime / max(_shakeDuration, 0.01)).clamp(0.0, 1.0);
      sx = (_shakeRng.nextDouble() * 2 - 1) * f;
      sy = (_shakeRng.nextDouble() * 2 - 1) * f;
    }
    _camTarget.position.setValues(_camPos.x + sx, _camPos.y + sy);
  }

  // ── Game events ──

  void onEnemyKilled(Enemy enemy) {
    roomManager.onEnemyKilled();
  }

  /// Called when player enters the dark portal after a wave clear.
  void onPortalEntered() {
    // Remove portal
    gameWorld.children.whereType<DarkPortal>().toList().forEach((p) => p.removeFromParent());
    roomManager.nextWave();
  }

  /// Called by room manager: wave cleared, show ability select then load next wave.
  void onWaveCleared() {
    overlays.add('abilitySelect');
    pauseEngine();
  }

  void onAbilitySelected() {
    overlays.remove('abilitySelect');
    resumeEngine();
    roomManager.currentWave; // already incremented
    roomManager.loadRoom();
  }

  /// Called when a full level (5 waves) is complete.
  void onLevelComplete() {
    // Heal player and advance to next level
    player?.health = player!.maxHealth;
    roomManager.nextLevel();
  }

  /// Called when entire world is complete.
  void onWorldComplete() {
    overlays.add('gameOver'); // reuse as victory screen
    pauseEngine();
  }

  void onPlayerDeath() {
    overlays.add('gameOver');
    pauseEngine();
  }

  void togglePause() {
    if (overlays.isActive('pauseMenu')) {
      overlays.remove('pauseMenu');
      resumeEngine();
    } else if (!overlays.isActive('gameOver') && !overlays.isActive('abilitySelect')) {
      overlays.add('pauseMenu');
      pauseEngine();
    }
  }

  void quitToMenu() {
    overlays.remove('pauseMenu');
    resumeEngine();
  }

  void onGameWon() {
    overlays.add('gameOver');
    pauseEngine();
  }

  void restart() {
    overlays.remove('gameOver');
    overlays.remove('abilitySelect');

    final classData = PlayerClassData.all[selectedClass]!;
    player?.removeFromParent();
    player = Player(classData: classData);
    gameWorld.add(player!);

    roomManager.reset(worldIndex, levelIndex);
    roomManager.loadRoom();

    _camPos.setFrom(player!.position);
    _camTarget.position.setFrom(player!.position);
    resumeEngine();
  }
}
