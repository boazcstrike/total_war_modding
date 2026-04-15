# Agents Documentation Summary

## AI-suggestions.md
Comprehensive enhancement suggestions for the Road to Vostok Enemy AI mod, including cooperative squad behaviors, dynamic environmental adaptation, advanced combat tactics, learning systems, communication networks, personality variations, performance optimizations, advanced pathfinding, game system integration, and debug tools. Features prioritized implementation roadmap and technical considerations for modularity and compatibility.

## AISpawner.md
Extends base AISpawner.gd to customize enemy spawning with faction-specific pools, density control presets, spawn quality auditing, initial population management, configurable spawn locations, and event tracking. Manages reinforcement rates, pool replenishment, and integration with mod settings.

## EnemyAISettings.md
Resource class containing all configurable settings for the mod, organized into categories: density/spawning controls, faction overrides, advanced behaviors (infighting, warfare, enemy squads), performance multipliers (health, sight, accuracy), tactical presets, and quality-of-life features like corpse cleanup and debug overlays. This is a Resource class that defines all configurable settings for the Road to Vostok Enemy AI mod. It uses Godot's resource system to store and manage mod configuration persistently.

## EnemyAISettings.tres
Godot resource file storing default configuration values for EnemyAISettings. Contains serialized data for all exported variables including the new enemy_squads_enabled setting (default: true). This file gets preloaded by scripts and updated by the MCM configuration system at runtime.

## AI.md
Extends base AI.gd with advanced enemy behaviors including faction-based targeting system, infighting/warfare logic, enhanced sensory detection, configurable combat multipliers, tactical waypoint navigation, behavior state management, and cooperative squad coordination with messaging systems.

## readme.md
Empty file with no content.

## Config.md
Handles Mod Configuration Menu integration, defining all settings with metadata, validation ranges, and tooltips. Manages loading/saving configuration, updates EnemyAISettings resource, and ensures MCM compatibility with migration support.

## Character.md
Extends base Character.gd to implement player invulnerability (god mode) for testing purposes. Prevents all damage types while maintaining player control and stat preservation, activated via mod settings.

## Main.md
Central orchestrator script managing mod initialization, script overrides, debug overlay system, comprehensive statistics tracking (spawns, deaths, hits), MCM compatibility, and corpse cleanup system. Acts as the mod's main controller and global state manager.

## MCMCompat_Main.md
Extends Mod Configuration Menu Main.gd for compatibility integration. Creates configuration button in settings menu, handles visibility management, applies compatibility patches to MCM system, and ensures seamless integration across different game scenes.

## Bug Fix Patterns
When extending base AI/AISpawner scripts:
- Always call `new_agent.Activate()` after instantiating and configuring spawned agents to ensure they begin their behavior states
- Decrement `AISpawner.activeAgents` in the `Death()` function to maintain accurate active AI counts
- When overriding spawn functions, ensure base functionality is preserved or replicated

When adding new preset options to MCM configuration:
- Update the initial `config.set_value` options array in Config.gd `_ready()` function
- Update the `_sync_dropdown_options` call to include the new option for existing users