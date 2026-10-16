import 'dart:ui';

/// Central game configuration constants.
class GameConfig {
  // ── Room ──
  static const double roomWidth = 480;
  static const double roomHeight = 640;

  // ── Isometric tile grid ──
  static const double tileW = 48;
  static const double tileH = 24;
  static const int gridCols = 10;
  static const int gridRows = 14;

  // ── Player ──
  static const double playerSpeed = 160;
  static const double playerRadius = 34;
  static const double playerBaseHealth = 100;

  // ── Auto‐attack ──
  static const double autoAttackRange = 220;
  static const double projectileSpeed = 320;
  static const double projectileRadius = 5;

  // ── Enemies ──
  static const double enemyMeleeSpeed = 55;
  static const double enemyRangedSpeed = 35;
  static const double enemyBossSpeed = 28;
  static const double enemyMeleeRadius = 14;
  static const double enemyRangedRadius = 12;
  static const double enemyBossRadius = 28;

  // ── Progression ──
  static const int wavesPerLevel = 5;
  static const int levelsPerWorld = 10;
  static const int totalWorlds = 3;

  // ── Palette ──
  static const Color bgColor = Color(0xFF0a0a1a);
  static const Color floorA = Color(0xFF1e1e32);
  static const Color floorB = Color(0xFF252540);
  static const Color wallColor = Color(0xFF12121f);
  static const Color wallTop = Color(0xFF1a1a30);

  static const Color archerColor = Color(0xFF4ade80);
  static const Color mageColor = Color(0xFF60a5fa);
  static const Color warriorColor = Color(0xFFf87171);
  static const Color necroColor = Color(0xFFc084fc);

  static const Color enemyColor = Color(0xFFf97316);
  static const Color bossColor = Color(0xFFfbbf24);

  static const Color hpBar = Color(0xFFef4444);
  static const Color hpBarBg = Color(0xFF3a1a1a);
  static const Color expColor = Color(0xFF22d3ee);

  // ── Glow ──
  static const double glowRadius = 18;
  static const double glowSigma = 8;
}
