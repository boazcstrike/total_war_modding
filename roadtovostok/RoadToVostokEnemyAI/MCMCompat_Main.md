# MCMCompat_Main.gd

## Overview
This script extends the base Mod Configuration Menu (MCM) Main.gd script to provide compatibility and integration for the Road to Vostok Enemy AI mod. It handles the creation and management of the mod's configuration button within the game's settings interface.

## Purpose
The primary purpose of this script is to:
- Add a configuration button to the game's settings menu
- Handle visibility changes of the settings menu
- Apply compatibility patches to the MCM system to work properly with the mod
- Ensure the mod's settings interface integrates seamlessly with the game's existing menu system

## Key Components

### Button Creation (`CreateMCMButton()`)
- Creates a button with the text "Mod Configuration Menu"
- Positions it in the top-right corner of the settings menu
- Connects the button to the MCM toggle function
- Handles different scene contexts (Menu vs. gameplay scenes)

### Visibility Management
- Monitors settings menu visibility changes
- Updates button visibility accordingly
- Handles different parent-child relationships in the scene hierarchy

### MCM Compatibility Patching
- Checks for vulnerable signatures in the base MCM script
- Applies patches to ensure proper functionality
- Takes over the MCM script path to inject compatibility fixes

## Integration Points
- Extends `res://ModConfigurationMenu/Main.gd`
- Interacts with `MCMHelpers` for menu management
- Works across different game scenes (Menu, Map, etc.)
- Patches the live MCM instance when necessary

## Dependencies
- Requires Mod Configuration Menu mod to be installed
- Depends on `MCMHelpers` singleton for menu operations
- Uses `mcmMenuScene` resource for the menu UI