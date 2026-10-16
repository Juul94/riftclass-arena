import 'dart:ui';
import '../game/config.dart';

// ─────────────────────────────────────────────────────────
//  Player classes & abilities
// ─────────────────────────────────────────────────────────

enum PlayerClassName { archer, mage, warrior, necromancer }

/// Metadata for one upgrade‐able ability.
class AbilityData {
  final String id;
  final String name;
  final String description;
  final int maxLevel;

  const AbilityData({
    required this.id,
    required this.name,
    required this.description,
    this.maxLevel = 5,
  });
}

/// Runtime state for an acquired ability.
class AbilityState {
  final AbilityData data;
  int level;

  AbilityState(this.data, {this.level = 1});

  bool get isMaxed => level >= data.maxLevel;
  void upgrade() {
    if (!isMaxed) level++;
  }
}

/// Static definition of a player class.
class PlayerClassData {
  final PlayerClassName id;
  final String displayName;
  final String description;
  final double baseHealth;
  final double baseSpeed;
  final double baseDamage;
  final double attacksPerSecond;
  final double attackRange;
  final bool isMelee;
  final Color color;
  final List<AbilityData> abilities; // 3 upgrade abilities

  const PlayerClassData({
    required this.id,
    required this.displayName,
    required this.description,
    required this.baseHealth,
    required this.baseSpeed,
    required this.baseDamage,
    required this.attacksPerSecond,
    required this.attackRange,
    this.isMelee = false,
    required this.color,
    required this.abilities,
  });

  static final Map<PlayerClassName, PlayerClassData> all = {
    PlayerClassName.archer: const PlayerClassData(
      id: PlayerClassName.archer,
      displayName: 'Archer',
      description: 'Swift ranged striker with piercing arrows',
      baseHealth: 80,
      baseSpeed: 170,
      baseDamage: 12,
      attacksPerSecond: 3.2,
      attackRange: 240,
      color: GameConfig.archerColor,
      abilities: [
        AbilityData(
          id: 'multi_shot',
          name: 'Multi‑Shot',
          description: 'Fire extra arrows in a spread',
        ),
        AbilityData(
          id: 'piercing',
          name: 'Piercing Arrow',
          description: 'Arrows pass through enemies',
        ),
        AbilityData(
          id: 'arrow_rain',
          name: 'Arrow Rain',
          description: 'Arrows rain down on a target area',
        ),
      ],
    ),
    PlayerClassName.mage: const PlayerClassData(
      id: PlayerClassName.mage,
      displayName: 'Mage',
      description: 'Arcane caster with devastating AoE',
      baseHealth: 70,
      baseSpeed: 140,
      baseDamage: 15,
      attacksPerSecond: 2.4,
      attackRange: 220,
      color: GameConfig.mageColor,
      abilities: [
        AbilityData(
          id: 'frost_nova',
          name: 'Frost Nova',
          description: 'Freeze nearby enemies briefly',
        ),
        AbilityData(
          id: 'chain_lightning',
          name: 'Chain Lightning',
          description: 'Lightning bounces between enemies',
        ),
        AbilityData(
          id: 'meteor',
          name: 'Meteor',
          description: 'Call down a devastating meteor',
        ),
      ],
    ),
    PlayerClassName.warrior: const PlayerClassData(
      id: PlayerClassName.warrior,
      displayName: 'Warrior',
      description: 'Heavy melee fighter with high durability',
      baseHealth: 130,
      baseSpeed: 130,
      baseDamage: 18,
      attacksPerSecond: 2.8,
      attackRange: 50,
      isMelee: true,
      color: GameConfig.warriorColor,
      abilities: [
        AbilityData(
          id: 'shield_bash',
          name: 'Shield Bash',
          description: 'Dash forward and stun enemies',
        ),
        AbilityData(
          id: 'whirlwind',
          name: 'Whirlwind',
          description: 'Spin attack hitting all nearby',
        ),
        AbilityData(
          id: 'leap_slam',
          name: 'Leap Slam',
          description: 'Jump to a location dealing AoE damage',
        ),
      ],
    ),
    PlayerClassName.necromancer: const PlayerClassData(
      id: PlayerClassName.necromancer,
      displayName: 'Necromancer',
      description: 'Dark summoner commanding undead minions',
      baseHealth: 75,
      baseSpeed: 135,
      baseDamage: 10,
      attacksPerSecond: 2.6,
      attackRange: 200,
      color: GameConfig.necroColor,
      abilities: [
        AbilityData(
          id: 'skeleton',
          name: 'Summon Skeleton',
          description: 'Raise a skeleton to fight for you',
        ),
        AbilityData(
          id: 'life_drain',
          name: 'Life Drain',
          description: 'Drain enemy life to heal yourself',
        ),
        AbilityData(
          id: 'corpse_explode',
          name: 'Corpse Explosion',
          description: 'Explode fallen enemies for AoE',
        ),
      ],
    ),
  };
}
