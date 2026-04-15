# Main.gd

## Overview
This is the central script for the Road to Vostok Enemy AI mod. It serves as the main controller that orchestrates all mod functionality, manages global state, and provides debugging capabilities.

## Purpose
The Main.gd script acts as the mod's central hub with the following responsibilities:
- Initialize and override core game scripts (AI, AISpawner, Character)
- Manage debug overlay and logging
- Handle Mod Configuration Menu compatibility
- Track comprehensive statistics (spawns, deaths, hits, factions, etc.)
- Implement corpse cleanup system
- Provide global state management for the mod

## Key Components

### Script Overrides (`_override_script()`)
- Dynamically replaces base game scripts with mod-enhanced versions
- Uses GDScript's `take_over_path()` to inject custom behavior
- Applies to AI.gd, AISpawner.gd, and Character.gd

### Debug Overlay System
- Creates a canvas layer with debug information
- Displays real-time stats: map, zone, spawn limits, faction counts, combat statistics
- Shows corpse cleanup status and last events
- Toggleable via settings

### Statistics Tracking
- **Spawn Tracking**: Counts by faction (Bandit, Guard, Military, Punisher) and role (Wanderer, Guard, Hider, Minion, Boss)
- **Combat Statistics**: Hit locations (Torso, Head, Legs, Other), death counts, suspicious spawns
- **Corpse Management**: Tracks dead bodies, enforces cleanup limits, sequences removal

### MCM Compatibility
- Schedules and applies patches to Mod Configuration Menu
- Handles timing and error checking for compatibility layer
- Ensures settings integration works properly

### Corpse Cleanup System
- Maintains a list of corpse records with metadata
- Enforces configurable cleanup limits
- Removes oldest corpses when limit exceeded
- Tracks cleanup statistics

## Integration Points
- Runs as an autoload/singleton node
- Communicates with AISpawner for spawn events
- Updates EnemyAISettings resource
- Provides debug interface to AI agents

## Dependencies
- EnemyAISettings.tres resource
- MCMHelpers (optional, for configuration menu)
- Base game scripts for overriding