# AI Agents in Road to Vostok Enemy AI Mod

## Overview
The Road to Vostok Enemy AI mod enhances the base game's enemy system with four distinct AI agent types, each with unique behaviors, roles, and faction affiliations. These agents can engage in complex interactions including faction warfare and infighting.

## Agent Types

### Bandit
**Role**: Versatile, opportunistic enemies that roam and engage targets
- **Default Faction**: Appears in Area05 zones
- **Behavior**: Highly aggressive, focuses on direct combat
- **Special Features**:
  - Can be configured for infighting (fighting other bandits)
  - Participates in faction warfare against guards and military
  - Uses all standard AI behaviors (combat, hunt, hide, etc.)

### Guard
**Role**: Stationary sentries and area defenders
- **Default Faction**: Appears in BorderZone areas
- **Behavior**: More defensive, holds positions and patrols
- **Special Features**:
  - Optional infighting capability
  - Can spawn as initial "sentry" at map start
  - Participates in faction warfare
  - Prefers guard/patrol behaviors over aggressive pursuit

### Military
**Role**: Organized, tactical combatants with enhanced capabilities
- **Default Faction**: Appears in Vostok zones
- **Behavior**: Disciplined and aggressive, focuses on player threats
- **Special Features**:
  - Optional infighting within military ranks
  - Participates in faction warfare
  - Enhanced sensory ranges and accuracy
  - More likely to use cover and tactical positioning

### Punisher (Boss)
**Role**: Elite enemies with superior combat abilities
- **Faction**: Independent (not affected by faction controls)
- **Behavior**: Highly aggressive with enhanced stats
- **Special Features**:
  - 3x base health (further multiplied by boss_health_multiplier)
  - 2x damage output
  - Single spawn per map (not replenished)
  - Spawns minions when engaging targets
  - Immune to faction warfare and infighting

## Faction Dynamics

### Warfare System
When enabled, factions engage in cross-faction combat:
- **Bandits** attack Guards and Military
- **Guards** attack Bandits and Military
- **Military** attack Bandits and Guards
- **Punisher** ignores faction rules and targets all

### Infighting
Configurable same-faction combat:
- Allows bandits to fight bandits
- Allows guards to fight guards
- Allows military to fight military
- Punisher never infights

### Player Alignment
Player can become allied with one faction:
- **Neutral**: All factions hostile to player
- **Bandit**: Only bandits treat player as friendly
- **Guard**: Only guards treat player as friendly
- **Military**: Only military treat player as friendly

## Agent Behaviors

### Combat Roles
- **Wanderer**: Standard roaming enemies
- **Guard**: Stationary defenders
- **Hider**: Ambush specialists
- **Minion**: Boss-summoned support
- **Boss**: Elite Punisher enemies

### Tactical States
- **Combat**: Direct engagement
- **Hunt**: Pursuit of last known positions
- **Attack**: Close-range aggressive tactics
- **Shift**: Tactical repositioning
- **Hide/Cover/Vantage**: Defensive positioning
- **Guard/Patrol**: Area control
- **Ambush**: Stealth waiting
- **Return**: Regrouping after attacks

## Configuration Impact

### Density Presets
Agents spawn according to intensity levels:
- **Default**: Minimal spawns
- **Medium**: Balanced population
- **High**: Significant enemy presence
- **Very High**: Challenging encounters
- **Insane**: Maximum enemy density

### Performance Multipliers
All agents affected by:
- Health scaling (separate for bosses)
- Sensory ranges (sight/hearing)
- Combat effectiveness (accuracy/fire rate)
- Tactical timing (aggression presets)

### Spawn Controls
- Individual faction enable/disable/force options
- Minimum spawn distances
- Pool replenishment for sustained gameplay
- Initial population bonuses

## Debug Features
- Real-time spawn tracking by faction and role
- Combat statistics (hits by location)
- Target identification and priority logging
- Suspicious spawn detection and reporting