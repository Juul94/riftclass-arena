import 'dart:ui';
import 'enemy_type.dart';

/// A world is a themed area with 10 levels (each level = 5 waves).
class WorldData {
  final int index;
  final String name;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final Color floorPrimary;
  final Color floorSecondary;
  final Color wallColor;
  final Color accentColor;
  final List<EnemyTypeData> enemyPool;
  final EnemyTypeData boss;

  const WorldData({
    required this.index,
    required this.name,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.floorPrimary,
    required this.floorSecondary,
    required this.wallColor,
    required this.accentColor,
    required this.enemyPool,
    required this.boss,
  });

  static const int levelsPerWorld = 10;
  static const int wavesPerLevel = 5;

  static final List<WorldData> worlds = [
    // ── World 1: Castle ──
    WorldData(
      index: 0,
      name: 'Forsaken Castle',
      subtitle: 'Ancient stone halls crawling with the undead',
      primaryColor: const Color(0xFF6b7280),
      secondaryColor: const Color(0xFF374151),
      floorPrimary: const Color(0xFF1e1e32),
      floorSecondary: const Color(0xFF252540),
      wallColor: const Color(0xFF12121f),
      accentColor: const Color(0xFF9ca3af),
      enemyPool: const [EnemyTypeData.skeleton, EnemyTypeData.bat, EnemyTypeData.spider],
      boss: EnemyTypeData.bossKnight,
    ),
    // ── World 2: Dark Shadow ──
    WorldData(
      index: 1,
      name: 'Shadow Abyss',
      subtitle: 'A realm of pure darkness and lost souls',
      primaryColor: const Color(0xFFa855f7),
      secondaryColor: const Color(0xFF581c87),
      floorPrimary: const Color(0xFF0f0a1e),
      floorSecondary: const Color(0xFF1a1230),
      wallColor: const Color(0xFF080510),
      accentColor: const Color(0xFFc084fc),
      enemyPool: const [EnemyTypeData.necromancerEnemy, EnemyTypeData.bat, EnemyTypeData.imp],
      boss: EnemyTypeData.bossDragon,
    ),
    // ── World 3: Dark Forest ──
    WorldData(
      index: 2,
      name: 'Cursed Forest',
      subtitle: 'Twisted trees hide ancient evils within',
      primaryColor: const Color(0xFF16a34a),
      secondaryColor: const Color(0xFF14532d),
      floorPrimary: const Color(0xFF0a1a0e),
      floorSecondary: const Color(0xFF142818),
      wallColor: const Color(0xFF061008),
      accentColor: const Color(0xFF4ade80),
      enemyPool: const [EnemyTypeData.spider, EnemyTypeData.golem, EnemyTypeData.skeleton],
      boss: EnemyTypeData.bossKnight,
    ),
  ];
}

/// Legacy alias for Room compatibility.
typedef WorldTheme = WorldData;
