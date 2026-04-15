# Character.gd

## Overview
This script extends the base game's Character.gd to add player invulnerability features for testing and debugging purposes. It overrides damage-related functions to conditionally prevent player harm.

## Purpose
The Character.gd extension provides a "god mode" feature that allows players to:
- Test AI behavior without taking damage
- Safely observe firefights and enemy interactions
- Debug mod functionality without gameplay interruption
- Maintain full player control while being immune to harm

## Key Components

### Damage Prevention System
All damage functions check `_player_invulnerable()` before applying effects:

- **WeaponDamage()**: Prevents bullet damage
- **ExplosionDamage()**: Blocks explosive damage
- **BurnDamage()**: Stops fire damage over time
- **FallDamage()**: Prevents fall-related injuries
- **Death()**: Maintains player alive and healthy

### Invulnerability State Management
- **_player_invulnerable()**: Checks EnemyAISettings.player_invulnerable flag
- **_maintain_invulnerable_stats()**: Forces health/oxygen to maximum when invulnerable
- **Health()** and **Oxygen()**: Override to prevent stat decay

### State Preservation
When invulnerable, the script ensures:
- Health stays at 100%
- Oxygen remains full
- No damage flags are set
- Player remains alive and active

## Integration Points
- Extends `res://Scripts/Character.gd` (base player character)
- Reads from EnemyAISettings resource
- Works alongside base game damage systems
- Compatible with all player mechanics except damage

## Usage Context
- Primarily used for development and testing
- Activated via mod configuration menu
- Shows "Spectator Invulnerable: ON" in debug overlay when active
- Allows safe observation of AI combat scenarios

## Dependencies
- EnemyAISettings resource for invulnerability toggle
- Base Character.gd script for extension
- Compatible with game's damage and health systems