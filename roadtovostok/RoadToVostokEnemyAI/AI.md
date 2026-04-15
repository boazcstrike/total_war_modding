# AI.gd

## Overview
This script extends the base game's AI.gd to add advanced enemy behaviors for the Road to Vostok Enemy AI mod. It introduces faction-based targeting, infighting, warfare, enhanced sensory systems, and tactical waypoint navigation.

## Purpose
AI.gd transforms basic enemy AI into a sophisticated system capable of:
- Targeting enemies from hostile factions
- Engaging in faction warfare and infighting
- Adapting behavior based on player faction alignment
- Using improved sensing (sight, hearing, audio cues)
- Applying configurable multipliers for combat effectiveness
- Following tactical presets for aggression levels
- Navigating tactical waypoints for cover, hiding, and positioning

## Key Components

### Hostile Targeting System
- **Faction Recognition**: Identifies enemies by faction metadata (`enemy_ai_faction`)
- **Warfare Logic**: Allows cross-faction combat when `warfare_enabled` is true
- **Infighting**: Permits same-faction combat when faction-specific infighting is enabled
- **Player Alignment**: Makes factions friendly to player based on `player_faction_alignment` setting

### Enhanced Sensing
- **Visual Detection**: Improved line-of-sight with configurable range multipliers (`ai_sight_multiplier`)
- **Audio Sensing**: Detects movement and gunfire at extended ranges with hearing multipliers
- **Gunshot Alerts**: Temporary heightened awareness after hearing shots (`ai_gunshot_alert_duration`)
- **Multi-Target Tracking**: Prioritizes visible/stable targets with hysteresis to prevent target switching

### Combat Enhancements
- **Accuracy System**: Distance-based spread with configurable multipliers (`ai_accuracy_multiplier`)
- **Fire Rate Control**: Adjustable firing speeds by weapon type, scaled by `ai_fire_rate_multiplier`
- **Health Scaling**: Separate multipliers for regular (`ai_health_multiplier`) and boss enemies (`boss_health_multiplier`)
- **Tactical Cycles**: Behavior timing based on aggression presets (`ai_tactics_preset`)

### Behavior States
- **Combat**: Direct engagement with targets, continuous firing when visible
- **Hunt**: Pursuit of last known positions, moves toward `lastKnownLocation`
- **Attack**: Aggressive close-range tactics with waypoint navigation
- **Shift**: Tactical repositioning using shift waypoints (`AI_WP` group)
- **Hide**: Seeks hiding points (`AI_HP` group) for ambush positioning
- **Cover**: Finds cover points (`AI_CP` group) behind obstacles
- **Vantage**: Locates vantage points (`AI_PP` group) for overwatch
- **Guard/Patrol**: Area control behaviors with slower movement
- **Return**: Regroups to original position after attacks

### Waypoint Navigation System
- **Point Groups**: Uses Godot node groups for tactical positioning:
  - `AI_HP` (Hide Points): Ambush locations
  - `AI_CP` (Cover Points): Defensive positions behind cover
  - `AI_PP` (Patrol/Vantage Points): Elevated or strategic spots
  - `AI_WP` (Waypoint Points): General navigation points
- **Selection Logic**: Filters points by distance (<40 units), line-of-sight, and directional requirements
- **Random Selection**: Picks randomly from valid points for varied behavior
- **Movement**: Uses `agent.set_target_position()` for pathfinding to selected points

### State Transitions
- **Decision Making**: Random-weighted choices in `Decision()` based on engagement distance
- **Automatic Transitions**: Triggered by navigation completion (`agent.is_target_reached()`), visibility changes, or distance thresholds
- **Cycle Timing**: Each state has configurable cycle lengths scaled by tactics preset

### Damage and Hit Detection
- **Hitbox Targeting**: Prioritizes torso hits with fallback logic for head/chest positioning
- **Root Collider Handling**: Special processing for AI body shots with faction validation
- **Debug Logging**: Records hit locations and damage application to `EnemyAIMain`

## Adding New Behaviors
To add new tactical behaviors like "corner wall hiding":

1. **Define Point Group**: Create new waypoint nodes with custom group (e.g., `AI_CW` for corner walls)
2. **Add Selection Function**: Create `GetCornerWallPoint()` similar to `GetHidePoint()` with corner-specific logic
3. **Add State**: Implement `CornerHide()` state with persistent positioning logic
4. **Update Decision**: Add corner hiding option to `Decision()` random choices
5. **State Transitions**: Add conditions for entering/exiting corner hide state

## Integration Points
- Extends `res://Scripts/AI.gd` (base AI behavior)
- Reads `EnemyAISettings` for all configuration
- Communicates with `Main.gd` for debug/stats
- Works with `AISpawner` for faction metadata

## Faction System
- **Bandit**: Default faction, configurable infighting (`bandit_infighting_enabled`)
- **Guard**: Law enforcement, optional infighting (`guard_infighting_enabled`)
- **Military**: Armed forces, optional infighting (`military_infighting_enabled`)
- **Punisher**: Boss enemies, enhanced capabilities (immune to faction rules)

### Cooperative AI Behaviors

**What's done**: Implemented squad-based behaviors where AI can communicate and coordinate actions.

- **Squad Formation**: Grouped AI into squads (2-4 agents) that share information about targets and positions.
- **Coordinated Attacks**: Implemented flanking maneuvers, covering fire, and pincer movements.
- **Information Sharing**: AI can alert nearby allies to threats via a simple messaging system.
- **Leadership Roles**: Designated squad leaders that make tactical decisions for the group.


## Dependencies
- `EnemyAISettings` resource for behavior configuration
- Base `AI.gd` for core movement and state logic
- `Main.gd` for debug overlay and statistics
- `AISpawner` for faction assignment and spawn metadata



