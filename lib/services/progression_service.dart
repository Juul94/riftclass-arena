import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/world_theme.dart';

/// Tracks player progression across worlds and levels.
class ProgressionService {
  ProgressionService._();
  static final ProgressionService instance = ProgressionService._();

  /// Key: 'world_{index}_level' → highest completed level (0-based)
  /// A value of -1 means no levels completed in that world.
  final Map<int, int> _completedLevels = {};

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < WorldData.worlds.length; i++) {
      _completedLevels[i] = prefs.getInt('world_${i}_level') ?? -1;
    }
  }

  /// Highest completed level in a world (-1 = none completed).
  int completedLevelInWorld(int worldIndex) {
    return _completedLevels[worldIndex] ?? -1;
  }

  /// Current level the player is on (next to play) in a world.
  int currentLevelInWorld(int worldIndex) {
    return (completedLevelInWorld(worldIndex) + 1).clamp(0, WorldData.levelsPerWorld - 1);
  }

  /// Whether a world is unlocked.
  /// World 0 is always unlocked. Others require previous world fully completed.
  bool isWorldUnlocked(int worldIndex) {
    if (worldIndex == 0) return true;
    return completedLevelInWorld(worldIndex - 1) >= WorldData.levelsPerWorld - 1;
  }

  /// Whether a world is fully completed.
  bool isWorldCompleted(int worldIndex) {
    return completedLevelInWorld(worldIndex) >= WorldData.levelsPerWorld - 1;
  }

  /// Mark a level as completed in a world.
  Future<void> completeLevel(int worldIndex, int levelIndex) async {
    final current = completedLevelInWorld(worldIndex);
    if (levelIndex > current) {
      _completedLevels[worldIndex] = levelIndex;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('world_${worldIndex}_level', levelIndex);
    }
  }

  /// Get the highest world that is unlocked (for default scroll position).
  int get highestUnlockedWorld {
    for (var i = WorldData.worlds.length - 1; i >= 0; i--) {
      if (isWorldUnlocked(i)) return i;
    }
    return 0;
  }

  @visibleForTesting
  void reset() {
    _completedLevels.clear();
    _initialized = false;
  }
}
