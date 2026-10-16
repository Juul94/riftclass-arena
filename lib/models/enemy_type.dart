/// Types of enemies and their base stats.
enum EnemyKind { melee, ranged, boss }

class EnemyTypeData {
  final String name;
  final EnemyKind kind;
  final double health;
  final double damage;
  final double speed;
  final double radius;
  final double attackRange;
  final double attackCooldown; // seconds between attacks

  const EnemyTypeData({
    required this.name,
    required this.kind,
    required this.health,
    required this.damage,
    required this.speed,
    required this.radius,
    required this.attackRange,
    required this.attackCooldown,
  });

  /// Scale stats for a given world index (0‑based).
  EnemyTypeData scaled(int worldIndex) {
    final m = 1.0 + worldIndex * 0.35;
    return EnemyTypeData(
      name: name,
      kind: kind,
      health: health * m,
      damage: damage * m,
      speed: speed + worldIndex * 3,
      radius: radius,
      attackRange: attackRange,
      attackCooldown: attackCooldown * (1 - worldIndex * 0.02).clamp(0.4, 1.0),
    );
  }

  // ── Presets ──

  static const skeleton = EnemyTypeData(
    name: 'Skeleton',
    kind: EnemyKind.melee,
    health: 30,
    damage: 8,
    speed: 55,
    radius: 13,
    attackRange: 30,
    attackCooldown: 1.2,
  );

  static const spider = EnemyTypeData(
    name: 'Spider',
    kind: EnemyKind.melee,
    health: 25,
    damage: 6,
    speed: 75,
    radius: 12,
    attackRange: 28,
    attackCooldown: 0.9,
  );

  static const imp = EnemyTypeData(
    name: 'Imp',
    kind: EnemyKind.ranged,
    health: 20,
    damage: 10,
    speed: 40,
    radius: 10,
    attackRange: 180,
    attackCooldown: 1.8,
  );

  static const bat = EnemyTypeData(
    name: 'Bat',
    kind: EnemyKind.ranged,
    health: 15,
    damage: 5,
    speed: 65,
    radius: 9,
    attackRange: 140,
    attackCooldown: 1.4,
  );

  static const golem = EnemyTypeData(
    name: 'Golem',
    kind: EnemyKind.melee,
    health: 60,
    damage: 14,
    speed: 35,
    radius: 18,
    attackRange: 35,
    attackCooldown: 2.0,
  );

  static const necromancerEnemy = EnemyTypeData(
    name: 'Dark Mage',
    kind: EnemyKind.ranged,
    health: 35,
    damage: 12,
    speed: 30,
    radius: 12,
    attackRange: 200,
    attackCooldown: 2.2,
  );

  static const bossKnight = EnemyTypeData(
    name: 'Death Knight',
    kind: EnemyKind.boss,
    health: 250,
    damage: 20,
    speed: 40,
    radius: 28,
    attackRange: 45,
    attackCooldown: 1.5,
  );

  static const bossDragon = EnemyTypeData(
    name: 'Shadow Dragon',
    kind: EnemyKind.boss,
    health: 350,
    damage: 25,
    speed: 35,
    radius: 32,
    attackRange: 200,
    attackCooldown: 2.0,
  );

  /// All non‑boss enemies for spawning pools.
  static const List<EnemyTypeData> normalPool = [
    skeleton,
    spider,
    imp,
    bat,
    golem,
    necromancerEnemy,
  ];

  /// Boss pool indexed loosely.
  static const List<EnemyTypeData> bossPool = [bossKnight, bossDragon];
}
