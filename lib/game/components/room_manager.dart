import 'dart:math';

import 'package:flame/components.dart';

import '../../models/world_theme.dart';
import '../../services/progression_service.dart';
import '../config.dart';
import '../riftclass_game.dart';
import 'dark_portal.dart';
import 'enemy.dart';
import 'room.dart';

/// Manages progression: World → Level → Wave.
/// Each world has 10 levels, each level has 5 waves.
class RoomManager extends Component with HasGameReference<RiftclassGame> {
  RoomManager({required this.worldIndex, required this.levelIndex});

  int worldIndex;
  int levelIndex; // 0-based level within world (0..9)
  int currentWave = 0; // 0-based wave within level (0..4)
  int enemiesAlive = 0;
  bool roomCleared = false;

  WorldData get theme => WorldData.worlds[worldIndex.clamp(0, WorldData.worlds.length - 1)];
  bool get isBossWave => currentWave == WorldData.wavesPerLevel - 1;

  /// Difficulty scale based on world + level + wave.
  double get difficulty => worldIndex * 1.0 + levelIndex * 0.3 + currentWave * 0.1;

  final Random _rng = Random();

  /// Load the current wave (floor + enemies).
  void loadRoom() {
    roomCleared = false;

    // Remove old room + enemies + portals
    game.gameWorld.children.whereType<Room>().toList().forEach((r) => r.removeFromParent());
    game.gameWorld.children.whereType<Enemy>().toList().forEach((e) => e.removeFromParent());
    game.gameWorld.children.whereType<DarkPortal>().toList().forEach((p) => p.removeFromParent());

    // Add room floor with wave variation
    game.gameWorld.add(Room(theme: theme, waveVariant: currentWave));

    // Spawn enemies
    _spawnEnemies();

    // Reset player position
    game.player?.position = Vector2(
      GameConfig.roomWidth / 2,
      GameConfig.roomHeight * 0.75,
    );
  }

  void _spawnEnemies() {
    if (isBossWave) {
      _spawnBoss();
    } else {
      _spawnNormalWave();
    }
  }

  void _spawnNormalWave() {
    // More enemies in later waves/levels/worlds
    final baseCount = 3 + currentWave;
    final count = baseCount + (levelIndex * 0.4).floor() + worldIndex;

    final pool = theme.enemyPool;
    final margin = 60.0;
    final scaleFactor = difficulty;

    for (int i = 0; i < count; i++) {
      final type = pool[_rng.nextInt(pool.length)].scaled(scaleFactor.floor());
      final pos = Vector2(
        margin + _rng.nextDouble() * (GameConfig.roomWidth - 2 * margin),
        margin + _rng.nextDouble() * (GameConfig.roomHeight * 0.45 - margin),
      );
      game.gameWorld.add(Enemy(data: type, pos: pos));
    }
    enemiesAlive = count;
  }

  void _spawnBoss() {
    final bossData = theme.boss.scaled(difficulty.floor());
    game.gameWorld.add(Enemy(
      data: bossData,
      pos: Vector2(GameConfig.roomWidth / 2, GameConfig.roomHeight * 0.3),
    ));
    enemiesAlive = 1;

    // Spawn minions with boss in harder levels
    if (levelIndex >= 3) {
      final pool = theme.enemyPool;
      final minionCount = 1 + (levelIndex ~/ 3);
      for (int i = 0; i < minionCount; i++) {
        final type = pool[_rng.nextInt(pool.length)].scaled(difficulty.floor());
        final angle = (i / minionCount) * pi * 2;
        final pos = Vector2(
          GameConfig.roomWidth / 2 + 80 * cos(angle),
          GameConfig.roomHeight * 0.3 + 60 * sin(angle),
        );
        game.gameWorld.add(Enemy(data: type, pos: pos));
      }
      enemiesAlive += minionCount;
    }
  }

  /// Called when an enemy dies.
  void onEnemyKilled() {
    enemiesAlive--;
    if (enemiesAlive <= 0) {
      roomCleared = true;
      _onWaveCleared();
    }
  }

  void _onWaveCleared() {
    if (isBossWave) {
      // Level complete!
      _onLevelComplete();
    } else {
      // Spawn portal for next wave
      game.gameWorld.add(DarkPortal());
    }
  }

  void _onLevelComplete() async {
    // Save progression
    await ProgressionService.instance.completeLevel(worldIndex, levelIndex);

    if (levelIndex < WorldData.levelsPerWorld - 1) {
      // More levels in this world
      game.onLevelComplete();
    } else {
      // World fully completed
      game.onWorldComplete();
    }
  }

  /// Advance to next wave (called when player enters portal).
  void nextWave() {
    currentWave++;
    // Show ability select, then load next wave
    game.onWaveCleared();
  }

  /// Start next level after level complete.
  void nextLevel() {
    levelIndex++;
    currentWave = 0;
    loadRoom();
  }

  /// Reset for a new run on specific world/level.
  void reset(int world, int level) {
    worldIndex = world;
    levelIndex = level;
    currentWave = 0;
    enemiesAlive = 0;
    roomCleared = false;
  }
}
