# Config.gd

## Overview
This script handles the configuration interface for the Road to Vostok Enemy AI mod using the Mod Configuration Menu (MCM) system. It defines all available settings, their defaults, validation ranges, and tooltips.

## Purpose
Config.gd serves as the bridge between the mod's settings and the user interface:
- Defines all configurable options with metadata
- Loads and saves settings to/from disk
- Updates the EnemyAISettings resource when configuration changes
- Provides user-friendly descriptions and validation
- Handles MCM integration and compatibility

## Key Components

### Settings Definition (`_ready()`)
Creates comprehensive configuration entries for MCM with:
- **Meta information**: Mod version, ID, file paths
- **Setting types**: Dropdown, Int, Bool, Float sliders
- **Validation**: Min/max ranges, default values
- **User interface**: Names, tooltips, menu positioning

### Configuration Categories

#### Density Settings
- Intensity presets (6 levels from Default to Insane)
- Spawn rate adjustments (Lower/Vanilla/Higher)
- Bonus enemies (active, reserve, initial)

#### Faction Controls
- Individual faction enable/disable/force options
- Player faction alignment (Neutral/Bandit/Guard/Military)

#### Behavior Toggles
- Infighting within factions
- Inter-faction warfare
- Hide behavior controls
- Initial spawn types (guard, hider)

#### Advanced Multipliers
- Health scaling for regular and boss enemies
- Sensory multipliers (sight, hearing)
- Combat multipliers (accuracy, fire rate, alert duration)

#### Quality Features
- Corpse cleanup limits
- Debug overlay toggle
- God mode for testing
- Spawn pool replenishment

### Configuration Management
- **Loading**: Reads from `user://MCM/RoadToVostokEnemyAI/config.ini`
- **Saving**: Persists changes automatically
- **Migration**: Handles version updates and option changes
- **Validation**: Ensures values stay within acceptable ranges

### MCM Integration
- Registers with MCM system using mod ID and metadata
- Provides callback for configuration updates
- Syncs settings to EnemyAISettings resource
- Handles backwards compatibility

## File Structure
- Configuration saved to: `user://MCM/RoadToVostokEnemyAI/config.ini`
- Uses ConfigFile for structured storage
- Maintains mod version for migration purposes

## Dependencies
- Requires Mod Configuration Menu mod
- Depends on EnemyAISettings.tres resource
- Uses MCMHelpers for menu integration