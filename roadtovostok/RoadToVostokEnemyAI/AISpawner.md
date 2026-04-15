# AISpawner.gd

## Overview
This script extends the base game's AISpawner.gd to customize enemy spawning behavior for the Road to Vostok Enemy AI mod. It enhances spawn logic with faction pools, density controls, and quality auditing.

## Purpose
AISpawner.gd controls how and when enemies appear in the game world:
- Manages spawn pools and limits based on intensity presets
- Builds faction-specific enemy pools with override controls
- Handles initial population and reinforcements
- Audits spawn positions for quality (prevents stuck/floating enemies)
- Replenishes spawn pools to maintain long-term gameplay

## Key Components

### Spawn Pool Management
- **Faction Pools**: Creates separate pools for Bandits, Guards, Military, and Punisher (boss)
- **Pool Building**: Respects faction override settings (Map Default/On/Off)
- **Replenishment**: Adds enemies back to pool when others die (configurable)

### Density Control System
- **Intensity Profiles**: 6 preset levels (Default to Insane) with spawn limits, pools, and rates
- **Rate Scaling**: Adjusts reinforcement speed (Lower/Vanilla/Higher)
- **Bonus Enemies**: Adds extra active/reserve/initial enemies

### Spawn Quality Auditing
- **Position Validation**: Raycasts to detect floor surfaces
- **Suspicious Detection**: Flags spawns too high/low from ground
- **Delayed Auditing**: Checks spawn positions after initial placement
- **Event Logging**: Records problematic spawns for debugging

### Initial Population
- **Opening Spawns**: Places at least 12 enemies at map start (minimum across all presets), distributed in batches of 5 over 1 second for rapid population growth
- **Faction Diversity**: Spawns bandits, guards, and military simultaneously from faction-specific or shared spawn locations
- **Bandit Prioritization**: Ensures substantial bandit presence in early spawns
- **Special Roles**: Optional sentry (guard) and ambusher (hider) spawns
- **Population Limits**: Respects configured maximums and faction-specific caps

### Spawn Location Configuration
- **Faction-Specific Spawns**: Spawn points can be named with faction prefixes (e.g., `bandit_spawn1`, `guard_spawn2`) to restrict spawning to specific areas
- **Shared Locations**: If no faction-specific points exist, agents spawn from general spawn points
- **Scene Setup**: Add spawn point nodes in map scenes under a "Spawns" group, using faction prefixes for separation
- **Fallback Behavior**: Agents will use shared locations if faction-specific ones are unavailable

### Spawn Event Handling
- **Success Tracking**: Records successful spawns by faction and role
- **Debug Integration**: Updates main debug system with spawn events
- **Pool Management**: Maintains reserve counts and active limits

## Integration Points
- Extends `res://Scripts/AISpawner.gd` (base spawner)
- Communicates with Main.gd for debug/stats
- Uses EnemyAISettings for all configuration
- Works with AI.gd for spawned enemy behavior

## Spawn Roles
- **Wanderer**: Standard roaming enemies
- **Guard**: Stationary sentries
- **Hider**: Ambush-style enemies
- **Minion**: Support enemies (spawned by bosses)
- **Boss**: Punisher enemies with enhanced abilities

## Dependencies
- EnemyAISettings resource for configuration
- Base AISpawner.gd for core spawning logic
- Main.gd for debug and statistics tracking