# EnemyAISettings.gd

## Overview
This is a Resource class that defines all configurable settings for the Road to Vostok Enemy AI mod. It uses Godot's resource system to store and manage mod configuration persistently.

## Purpose
EnemyAISettings serves as the central configuration store for the mod, containing:
- Intensity and spawn rate presets
- Faction override controls
- Infighting and warfare toggles
- Player alignment options
- Performance multipliers (health, sight, accuracy, etc.)
- Debug and testing features
- Corpse management settings

## Key Settings Categories

### Density & Spawning
- **intensity_preset**: Controls overall enemy density (Default to Insane)
- **spawn_rate_adjustment**: Affects reinforcement speed (Lower/Vanilla/Higher)
- **spawn_limit_bonus**: Extra active enemies beyond preset
- **spawn_pool_bonus**: Additional reserve enemies
- **initial_population_bonus**: More enemies at map start
- **spawn_distance**: Minimum distance from player for spawns

### Faction Controls
- **bandit_spawn_mode**: Allow/force/prevent bandit spawns
- **guard_spawn_mode**: Allow/force/prevent guard spawns
- **military_spawn_mode**: Allow/force/prevent military spawns

### Advanced Behaviors
- **bandit_infighting_enabled**: Bandits can fight each other
- **guard_infighting_enabled**: Guards can fight each other
- **military_infighting_enabled**: Military can fight each other
- **warfare_enabled**: Factions fight hostile factions
- **player_faction_alignment**: Make player allied with a faction

### Performance Multipliers
- **ai_health_multiplier**: Scales enemy health
- **boss_health_multiplier**: Scales boss health
- **ai_sight_multiplier**: Affects vision range
- **ai_hearing_multiplier**: Affects hearing range
- **ai_accuracy_multiplier**: Improves/f worsens shooting accuracy
- **ai_fire_rate_multiplier**: Changes firing speed
- **ai_gunshot_alert_duration**: How long enemies stay alert after gunfire

### Tactics & Behavior
- **ai_tactics_preset**: Aggression level (Passive/Default/Aggressive/Relentless)
- **initial_guard**: Spawn sentry at map start
- **initial_hider**: Chance for ambusher at map start
- **disable_hiding**: Prevent hide behavior

### Quality of Life
- **corpse_cleanup_limit**: Maximum dead bodies before cleanup
- **player_invulnerable**: God mode for testing
- **show_debug_overlay**: Display debug information
- **replenish_spawn_pool**: Keep spawning after deaths

## Resource Structure
- Extends Godot's `Resource` class
- Uses `@export` for editor-exposed properties
- Saved as `.tres` file for persistence
- Loaded by Config.gd and used throughout the mod

## Integration Points
- Referenced by all AI-related scripts
- Updated by Config.gd when settings change
- Used for conditional behavior in AI.gd and AISpawner.gd
- Controls debug overlay visibility in Main.gd