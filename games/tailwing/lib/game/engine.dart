import 'dart:math' as math;

import 'combat_model.dart';
import 'stages.dart';
import 'animal_roster.dart';
import 'player_aircraft.dart';
import 'advanced_skill_catalog.dart';
part 'animal_combat.dart';
part 'projectile_pool.dart';
part 'enemy_behaviors.dart';
part 'advanced_skills.dart';

enum BattlePhase { playing, paused, won, lost }

enum EnemyKind { scout, sweeper, armored, boss, interceptor, charger, sentinel }

/// Transient visual events only: no random draws, collision or saved state.
enum EffectKind { muzzle, hit, explosion, shieldHit, damage, pulse, skill }

class CombatEffect {
  CombatEffect(this.position, this.kind, {this.size = 16});
  final Vec position;
  final EffectKind kind;
  final double size;
  double age = 0;
  double get lifetime => switch (kind) {
    EffectKind.explosion => .72,
    EffectKind.pulse => .65,
    EffectKind.damage => .32,
    EffectKind.skill => .35,
    _ => .16,
  };
  double get progress => (age / lifetime).clamp(0, 1);
}

class Projectile {
  Projectile(
    this.position,
    this.velocity, {
    this.damage = 10,
    this.friendly = false,
    this.collectible = true,
    this.precision = false,
  });
  Vec position;
  Vec velocity;
  double damage;
  bool friendly;
  bool collectible, precision;
  bool homing = false;
  double steeringRemaining = 1.2;
  ProjectilePool? _owner;
  bool _leased = false;
}

class Enemy {
  Enemy(this.position, this.kind)
    : health = switch (kind) {
        EnemyKind.scout => 20,
        EnemyKind.sweeper => 35,
        EnemyKind.armored => 70,
        EnemyKind.boss => 400,
        EnemyKind.interceptor => 32,
        EnemyKind.charger => 24,
        EnemyKind.sentinel => 110,
      };
  Vec position;
  final EnemyKind kind;
  double health;
  double get maxHealth => switch (kind) {
    EnemyKind.scout => 20,
    EnemyKind.sweeper => 35,
    EnemyKind.armored => 70,
    EnemyKind.boss => 400,
    EnemyKind.interceptor => 32,
    EnemyKind.charger => 24,
    EnemyKind.sentinel => 110,
  };
  double fireClock = 0;
  double age = 0;
  double motionAge = 0;
  double aim = 0;
  bool telegraph = false;
  double slowRemaining = 0, slowImmunity = 0;
  double shield = 0, laserAngle = 0;
  Vec? lockedTarget;
  final parts = <double>[55, 55];
  int bossPhase(double maximum) => health > maximum * 2 / 3
      ? 1
      : health > maximum / 3
      ? 2
      : 3;
  bool get laserWarning =>
      kind == EnemyKind.sentinel && age % 6 >= 2 && age % 6 < 3.2;
  bool get laserActive =>
      kind == EnemyKind.sentinel && age % 6 >= 3.2 && age % 6 < 4.4;
  double get radius => kind == EnemyKind.boss
      ? 42
      : kind == EnemyKind.sentinel
      ? 28
      : kind == EnemyKind.armored
      ? 22
      : 15;
}

class BattleEngine {
  BattleEngine(
    this.loadout, {
    int? seed,
    StageDefinition? stage,
    CombatLoadout? partnerLoadout,
    this.playerOnly = false,
  }) : stage = stage ?? stages.first,
       _random = math.Random(seed ?? (stage ?? stages.first).seed) {
    loadout.sanitize();
    _configuration = _fingerprint;
    health = maxHealth;
    if (partnerLoadout != null) {
      partner = BattleEngine(
        partnerLoadout,
        stage: this.stage,
        playerOnly: true,
      );
      player = const Vec(120, 510);
      partner!.player = const Vec(240, 510);
    }
  }
  static const width = 360.0, height = 600.0;
  final CombatLoadout loadout;
  final math.Random _random;
  final StageDefinition stage;
  final bool playerOnly;
  BattleEngine? partner;
  BattlePhase phase = BattlePhase.playing;
  final playerAircraft = PlayerAircraft();
  Vec get player => playerAircraft.position;
  set player(Vec value) => playerAircraft.position = value;
  final List<Projectile> bullets = [];
  final projectilePool = ProjectilePool();
  final advanced = AdvancedSkillState();
  final List<Enemy> enemies = [];
  final animal = AnimalCombatState();
  AnimalPilot get pilot => animalPilot(character) ?? animalPilots.first;
  String get skillName => skill == 'signature' ? pilot.technique : skill;
  static const maxEffects = 48;
  final List<CombatEffect> effects = [];
  void _effect(Vec at, EffectKind kind, {double size = 16}) {
    if (kind == EffectKind.shieldHit &&
        effects.any(
          (e) =>
              e.kind == kind && e.age < .06 && (e.position - at).distance < 20,
        )) {
      return;
    }
    if (effects.length >= maxEffects) effects.removeAt(0);
    effects.add(CombatEffect(at, kind, size: size));
  }

  int get health => playerAircraft.hp;
  set health(int value) => playerAircraft.hp = value;
  int score = 0;
  int shotsFired = 0;
  int _defeated = 0;
  int _wave = 0;
  int _repairSegment = 0;
  double repairNotice = 0;
  double elapsed = 0, shieldRemaining = 0, skillRemaining = 0, cooldown = 0;
  double _shotClock = 0, _spawnClock = 0, _invulnerable = 0, _prismClock = 0;
  double _basicShieldCooldown = 0;
  double get basicShieldCooldown =>
      skill == 'barrier' ? cooldown : _basicShieldCooldown;
  bool activateBasicShield() {
    _validate();
    if (skill == 'barrier') return activateSkill();
    if (health <= 0 ||
        phase != BattlePhase.playing ||
        _basicShieldCooldown > 0) {
      return false;
    }
    _basicShieldCooldown = 10 * (equipment == 'tuner' ? .9 : 1);
    shieldRemaining = shieldDuration;
    _effect(player, EffectKind.skill, size: 42);
    return true;
  }

  bool _bossSpawned = false;
  bool _sentinelSpawned = false;
  late String _configuration;
  String get _fingerprint =>
      CatalogCategory.values.map(loadout.selected).join('/');
  String get aircraft => loadout.selected(CatalogCategory.aircraft);
  String get character => loadout.selected(CatalogCategory.character);
  String get skill => loadout.selected(CatalogCategory.skill);
  String get equipment => loadout.selected(CatalogCategory.equipment);
  int get maxHealth =>
      3 +
      (aircraft == 'safeguard' ? 1 : 0) +
      (character == 'eden' ? 1 : 0) -
      (aircraft == 'vector' ? 1 : 0) -
      (character == 'rion' ? 1 : 0);
  double get shotDamage =>
      10 *
      (character == 'rion' ? 1.2 : 1) *
      (character == 'eden' ? .75 : 1) *
      (equipment == 'tuner' ? 1.1 : 1) *
      (robotMode ? 1.5 : 1);
  bool get robotMode => skill == 'mecha' && skillRemaining > 0;
  double get shieldDuration => 2 + (character == 'eden' ? .5 : 0);
  double get skillRechargeDuration =>
      (advancedSkillSpecs[skill]?.cooldown ??
          (skill == 'signature'
              ? pilot.balance.cooldown
              : switch (skill) {
                  'focus' => 12.0,
                  'mecha' => 16.0,
                  'pulse' => 14.0,
                  _ => 10.0,
                })) *
      (equipment == 'tuner' ? .9 : 1);
  double get moveSpeed => aircraft == 'vector' ? 1.15 : 1;
  double get shotInterval =>
      .24 /
      (aircraft == 'vector' ? 1.15 : 1) /
      (skill == 'focus' && skillRemaining > 0 ? 2 : 1);
  bool get protected => shieldRemaining > 0;
  bool get hitReaction => _invulnerable > .65;
  int get defeated => _defeated;

  void _validate() {
    loadout.sanitize();
    if (_configuration != _fingerprint) {
      _configuration = _fingerprint;
      _clearTransientAbilities();
      cooldown = math.min(cooldown, 10);
      if (skill == 'barrier') {
        cooldown = math.max(cooldown, _basicShieldCooldown);
      }
      _discardBullets((b) => b.friendly);
      health = math.min(health, maxHealth);
    }
  }

  void _clearTransientAbilities() {
    shieldRemaining = 0;
    skillRemaining = 0;
    animal.clear();
    advanced.clear();
    _prismClock = 0;
    for (final enemy in enemies) {
      enemy.slowRemaining = 0;
      enemy.slowImmunity = 0;
    }
  }

  void pause() {
    if (phase == BattlePhase.playing) phase = BattlePhase.paused;
    partner?.pause();
  }

  void resume() {
    if (phase == BattlePhase.paused) {
      _validate();
      phase = BattlePhase.playing;
      partner?.resume();
    }
  }

  void moveBy(Vec delta) {
    if (health <= 0 ||
        phase != BattlePhase.playing ||
        !delta.dx.isFinite ||
        !delta.dy.isFinite) {
      return;
    }
    playerAircraft.moveBy(delta, multiplier: moveSpeed);
  }

  bool activateSkill() {
    _validate();
    if (health <= 0 || phase != BattlePhase.playing || cooldown > 0) {
      return false;
    }
    cooldown = skillRechargeDuration;
    final strategy = advancedSkillStrategies[skill];
    if (strategy != null) {
      strategy.activate(this);
      return true;
    }
    _effect(
      player,
      skill == 'pulse' ? EffectKind.pulse : EffectKind.skill,
      size: skill == 'pulse' ? 260 : 42,
    );
    switch (skill) {
      case 'signature':
        _activateAnimal();
      case 'barrier':
        shieldRemaining = shieldDuration;
        _basicShieldCooldown = cooldown;
      case 'focus':
        skillRemaining = 4;
      case 'mecha':
        skillRemaining = 5;
      case 'pulse':
        _discardBullets((b) => !b.friendly);
        for (final enemy in enemies) {
          damageEnemy(enemy, 40);
        }
        _collectDefeated();
    }
    return true;
  }

  void _fire() {
    shotsFired++;
    _effect(player + const Vec(0, -25), EffectKind.muzzle, size: 12);
    final refracting =
        skill == 'signature' && character == 'rion' && skillRemaining > 0;
    final spread = refracting
        ? [-pilot.balance.range, 0.0, pilot.balance.range]
        : robotMode
        ? [-.25, 0.0, .25]
        : character == 'eden'
        ? [-.24, 0.0, .24]
        : character == 'rion'
        ? [-.015, .015]
        : [-.04, .04];
    for (final angle in spread) {
      bullets.add(
        projectilePool.acquire(
          player + const Vec(0, -24),
          Vec(math.sin(angle) * 420, -math.cos(angle) * 420),
          damage: shotDamage * (refracting ? pilot.balance.damage : 1),
          friendly: true,
        ),
      );
    }
    if (equipment == 'echo') {
      for (final side in [-1, 1]) {
        bullets.add(
          projectilePool.acquire(
            player + Vec(side * 25, 0),
            Vec(side * 35, -390),
            damage: shotDamage * .5,
            friendly: true,
          ),
        );
      }
    }
  }

  void step(double dt) {
    if (phase != BattlePhase.playing || !dt.isFinite || dt <= 0) return;
    _validate();
    dt = math.min(
      dt,
      .05,
    ); // Never fast-forward after a stalled frame/background.
    elapsed += dt;
    playerAircraft.stepPresentation(dt);
    for (final effect in effects) {
      effect.age += dt;
    }
    effects.removeWhere((effect) => effect.age >= effect.lifetime);
    repairNotice = math.max(0, repairNotice - dt);
    final segment = (elapsed / 55).floor();
    if (segment > _repairSegment && segment <= 2) {
      _repairSegment = segment;
      if (health > 0) {
        health = math.min(maxHealth, health + 1);
      }
      repairNotice = 2;
    }
    cooldown = math.max(0, cooldown - dt);
    _basicShieldCooldown = math.max(0, _basicShieldCooldown - dt);
    shieldRemaining = math.max(0, shieldRemaining - dt);
    skillRemaining = math.max(0, skillRemaining - dt);
    _invulnerable = math.max(0, _invulnerable - dt);
    advancedSkillStrategies[skill]?.tick(this, dt);
    _tickAnimal(dt);
    _shotClock -= dt;
    if (_shotClock <= 0 && health > 0) {
      _fire();
      _shotClock += shotInterval;
    }
    if (equipment == 'prism') {
      _prismClock += dt;
      if (_prismClock >= 12) {
        _prismClock -= 12;
        shieldRemaining = math.max(shieldRemaining, 1);
      }
    }
    if (playerOnly) {
      return;
    }
    final second = partner;
    if (second != null) {
      second.step(dt);
      bullets.addAll(second.bullets);
      second.bullets.clear();
    }
    _spawnClock -= dt;
    if (elapsed > 4 && elapsed < stage.bossAt - 8 && _spawnClock <= 0) {
      final segment = (elapsed / 55).floor().clamp(0, 2);
      final kind = elapsed > 20 && _wave % 5 == 3
          ? EnemyKind.interceptor
          : elapsed > 30 && _wave % 5 == 4
          ? EnemyKind.charger
          : EnemyKind.values[(_wave + stage.formation + segment) % 3];
      final lane = stage.formation == 0
          ? (_wave % 5) * 58 + 64.0
          : stage.formation == 1
          ? (_wave.isEven ? 65.0 : 295.0)
          : 110.0 + (_wave % 3) * 70;
      enemies.add(Enemy(Vec(lane + _random.nextDouble() * 8, -30), kind));
      if (kind == EnemyKind.charger) {
        enemies.addAll([
          Enemy(Vec((lane - 32).clamp(30, 330), -55), kind),
          Enemy(Vec((lane + 32).clamp(30, 330), -55), kind),
        ]);
      }
      _wave++;
      _spawnClock = stage.spawnInterval - segment * .2;
    }
    if (!_sentinelSpawned && elapsed >= 80 && elapsed < stage.bossAt) {
      _sentinelSpawned = true;
      enemies.add(Enemy(const Vec(180, -40), EnemyKind.sentinel));
    }
    if (!_bossSpawned && elapsed >= stage.bossAt) {
      _bossSpawned = true;
      enemies.add(
        Enemy(const Vec(180, -60), EnemyKind.boss)..health = stage.bossHealth,
      );
    }
    for (final enemy in enemies) {
      if (enemy.health <= 0) continue;
      final enemyDt = advanced.freeze > 0 ? 0.0 : dt;
      enemy.age += enemyDt;
      final wasSlowed = enemy.slowRemaining > 0;
      enemy.slowRemaining = math.max(0, enemy.slowRemaining - dt);
      enemy.slowImmunity = math.max(0, enemy.slowImmunity - dt);
      if (wasSlowed && enemy.slowRemaining == 0) {
        enemy.slowImmunity = pilot.balance.slowImmunity;
      }
      if (skill == 'signature' &&
          character == 'tw_penguin' &&
          skillRemaining > 0 &&
          _animalTargetAllowed(enemy) &&
          enemy.slowImmunity <= 0 &&
          enemy.position.dy < player.dy &&
          player.dy - enemy.position.dy <= pilot.balance.range &&
          (enemy.position.dx - player.dx).abs() <= pilot.balance.width / 2) {
        enemy.slowRemaining = .1;
      }
      final slow = enemy.slowRemaining > 0
          ? (enemy.kind == EnemyKind.armored
                ? pilot.balance.armoredSlowFactor
                : pilot.balance.slowFactor)
          : 1.0;
      final fieldSlow =
          advancedSkillStrategies[skill]?.movementFactor(this, enemy) ?? 1.0;
      enemy.motionAge += enemyDt * slow * fieldSlow;
      final behavior = enemyBehaviors[enemy.kind];
      if (behavior != null) {
        behavior.tick(this, enemy, enemyDt, movementFactor: slow * fieldSlow);
        continue;
      }
      final speed = switch (enemy.kind) {
        EnemyKind.scout => 64.0,
        EnemyKind.sweeper => 42.0,
        EnemyKind.armored => 27.0,
        EnemyKind.boss => 38.0,
        _ => 0.0,
      };
      if (enemy.kind != EnemyKind.boss || enemy.position.dy < 85) {
        enemy.position += Vec(
          enemy.kind == EnemyKind.scout
              ? math.sin(enemy.motionAge * 3) * 38 * enemyDt * slow * fieldSlow
              : 0,
          speed * enemyDt * slow * fieldSlow,
        );
      } else {
        enemy.position = Vec(
          180 + math.sin(enemy.motionAge * (1 + stage.biome * .06)) * 78,
          85,
        );
      }
      enemy.fireClock += enemyDt;
      final period = enemy.kind == EnemyKind.boss ? 1.5 : 2.6;
      if (!enemy.telegraph &&
          enemy.position.dy < 350 &&
          enemy.fireClock >= period - .65) {
        enemy.telegraph = true;
        final target =
            second != null && second.health > 0 && (health <= 0 || _wave.isEven)
            ? second.player
            : (skill == 'signature' &&
                      character == 'tw_chameleon' &&
                      skillRemaining > 0 &&
                      _animalTargetAllowed(enemy)
                  ? animal.anchor ?? player
                  : player);
        enemy.aim =
            enemy.kind == EnemyKind.armored ||
                (enemy.kind == EnemyKind.boss && stage.bossPattern == 0)
            ? math.atan2(
                target.dx - enemy.position.dx,
                target.dy - enemy.position.dy,
              )
            : 0;
      }
      if (enemy.position.dy > 0 &&
          enemy.position.dy < 350 &&
          enemy.fireClock >= period) {
        enemy.fireClock = 0;
        enemy.telegraph = false;
        final angles = switch (enemy.kind) {
          EnemyKind.scout => [0.0],
          EnemyKind.sweeper => [-.35, 0.0, .35],
          EnemyKind.armored => [-.12, .12],
          EnemyKind.boss =>
            stage.bossPattern == 0
                ? [-.28, 0.0, .28]
                : stage.bossPattern == 1
                ? [-.65, -.32, 0.0, .32, .65]
                : enemy.health < stage.bossHealth / 2
                ? [-.8, -.4, .4, .8]
                : [-.5, 0.0, .5],
          _ => <double>[],
        };
        if (enemy.kind == EnemyKind.boss) {
          final phase = enemy.bossPhase(stage.bossHealth);
          if (phase >= 2 && enemy.parts[0] > 0) angles.add(-.92);
          if (phase >= 2 && enemy.parts[1] > 0) angles.add(.92);
          if (phase == 3) angles.addAll([-.16, .16]);
        }
        final rotation = stage.biome == 0
            ? 0.0
            : math.sin(enemy.age * .5) * stage.biome * .025;
        final aim = enemy.aim;
        for (final angle in angles) {
          bullets.add(
            projectilePool.acquire(
              enemy.position,
              Vec(
                math.sin(angle + aim + rotation) * stage.bulletSpeed,
                math.cos(angle + aim + rotation) * stage.bulletSpeed,
              ),
              collectible: enemy.kind != EnemyKind.boss,
            ),
          );
        }
      }
    }
    for (final bullet in bullets) {
      if (bullet.homing &&
          bullet.steeringRemaining > 0 &&
          (bullet.friendly || advanced.freeze <= 0)) {
        _steerProjectile(bullet, math.min(dt, bullet.steeringRemaining));
        bullet.steeringRemaining = math.max(0, bullet.steeringRemaining - dt);
      }
      if (bullet.friendly || advanced.freeze <= 0) {
        bullet.position += bullet.velocity * dt;
      }
    }
    final consumed = <Projectile>{};
    _interceptAnimal(consumed);
    for (final bullet in bullets) {
      if (consumed.contains(bullet)) continue;
      if (bullet.friendly) {
        for (final enemy in enemies) {
          if (enemy.health > 0 &&
              (bullet.position - enemy.position).distance < enemy.radius + 4) {
            damageEnemy(enemy, bullet.damage, impact: bullet.position);
            _relayAnimal(enemy, bullet);
            _effect(bullet.position, EffectKind.hit);
            consumed.add(bullet);
            break;
          }
        }
      } else if (_absorbProjectile(bullet)) {
        consumed.add(bullet);
      } else if (health > 0 &&
          playerAircraft.hitbox.contains(player, bullet.position)) {
        consumed.add(bullet);
        _damagePlayer();
      } else if (second != null &&
          second.health > 0 &&
          (bullet.position - second.player).distance < 10) {
        consumed.add(bullet);
        second._damagePlayer();
      }
    }
    for (final enemy in enemies) {
      if (enemy.health > 0 &&
          (enemy.position - player).distance < enemy.radius + 5) {
        _damagePlayer();
        if (enemy.kind == EnemyKind.charger) enemy.health = 0;
      }
      if (second != null &&
          second.health > 0 &&
          enemy.health > 0 &&
          (enemy.position - second.player).distance < enemy.radius + 5) {
        second._damagePlayer();
        if (enemy.kind == EnemyKind.charger) enemy.health = 0;
      }
    }
    _discardBullets(
      (b) =>
          consumed.contains(b) ||
          b.position.dy < -50 ||
          b.position.dy > height + 30 ||
          b.position.dx < -30 ||
          b.position.dx > width + 30,
    );
    _collectDefeated();
    enemies.removeWhere((e) => e.position.dy > height + 60);
    if (health <= 0 && (second == null || second.health <= 0)) {
      phase = BattlePhase.lost;
    }
    if (elapsed >= stage.timeLimit && phase == BattlePhase.playing) {
      phase = BattlePhase.lost;
    }
    if (phase == BattlePhase.won || phase == BattlePhase.lost) {
      // No more simulation ticks run on the result screen. Cancel lingering
      // beacons/decoys/decks/collected rounds now, without a late counter shot.
      _clearTransientAbilities();
      cooldown = 0;
    }
  }

  void _damagePlayer() {
    if (protected) {
      _effect(player, EffectKind.shieldHit, size: 35);
      return;
    }
    if (_invulnerable > 0) return;
    health = math.max(0, health - 1);
    _invulnerable = 1;
    _effect(player, EffectKind.damage, size: 38);
  }

  void _collectDefeated() {
    for (final enemy in enemies.where((e) => e.health <= 0)) {
      _effect(enemy.position, EffectKind.explosion, size: enemy.radius * 3);
      score += enemy.kind == EnemyKind.boss ? 1000 : 100;
      _defeated++;
      if (enemy.kind == EnemyKind.boss &&
          (health > 0 || (partner?.health ?? 0) > 0)) {
        phase = BattlePhase.won;
      }
    }
    enemies.removeWhere((e) => e.health <= 0);
  }

  void _discardBullets(bool Function(Projectile) predicate) {
    bullets.removeWhere((b) {
      if (!predicate(b)) return false;
      if (!animal.captured.contains(b)) b._owner?.release(b);
      return true;
    });
  }

  void damageEnemy(
    Enemy enemy,
    double damage, {
    Vec? impact,
    bool allowSharing = true,
  }) {
    if (enemy.shield > 0) {
      final blocked = math.min(enemy.shield, damage);
      enemy.shield -= blocked;
      damage -= blocked;
    }
    if (enemy.kind == EnemyKind.boss && impact != null) {
      for (var i = 0; i < 2; i++) {
        final part = enemy.position + Vec(i == 0 ? -28 : 28, 12);
        if (enemy.parts[i] > 0 && (impact - part).distance < 16) {
          enemy.parts[i] = math.max(0, enemy.parts[i] - damage);
          if (enemy.parts[i] == 0) {
            _effect(part, EffectKind.explosion, size: 32);
          }
          break;
        }
      }
    }
    enemy.health -= damage;
    if (allowSharing &&
        damage > 0 &&
        skill == 'chain' &&
        advanced.phase == SkillStage.active &&
        advanced.tethered.contains(enemy)) {
      for (final linked in advanced.tethered) {
        if (!identical(enemy, linked) &&
            linked.health > 0 &&
            enemies.contains(linked)) {
          damageEnemy(linked, damage * .3, allowSharing: false);
        }
      }
    }
  }
}
