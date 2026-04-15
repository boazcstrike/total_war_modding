# AI CornerHide Enhancement Plan

## Current CornerHide Behavior
- AI moves to and stays at corner positions persistently
- Uses dynamic corner detection with raycasts
- Includes peek mechanics with lean offsets
- Integrated into decision system as State_CornerHide

## Enhancement: Distant Shot Response (>50 units)

### Trigger Conditions
- Shot detected from >50 units away (using existing gunshot detection)
- AI is not already in CornerHide state
- AI is facing away from shot direction (angle > threshold)
- Shot direction can be determined (from gunshot vector or player position)

### New Behavior Sequence
1. **Crouch Phase** (0.5-1.0 seconds)
   - Immediately crouch upon detecting distant shot
   - Reduce movement speed to 0 during crouch
   - Play crouch animation if available
   - Maintain current facing direction

2. **Directional Corner Run** (until corner reached)
   - Calculate corner position perpendicular to shot direction for cover
   - Run towards corner while crouched (if possible) or at normal speed
   - Use perimeter movement if direct path blocked
   - Transition to full CornerHide behavior once corner reached

### Technical Implementation ✅

#### Detection Logic
- ✅ Modified `FireDetection()` to detect shots >50 units away
- ✅ Added `_trigger_distant_shot_corner_response()` function
- ✅ Added `_is_already_corner_hiding()` check

#### State Management
- ✅ Added crouch state variables: `is_corner_crouching`, `corner_crouch_timer`, `distant_shot_direction`
- ✅ Modified `CornerHide()` to handle crouch phase (0 speed/turn during crouch)
- ✅ Added state reset in `ChangeState()` when leaving CornerHide

#### Movement Logic
```gdscript
func _find_directional_corner(shot_direction: Vector3) -> Vector3:
    # Find cover perpendicular to shot direction
    # Search left/right and back directions relative to threat
    # Verify corner provides line-of-sight blockage from threat
    # Prioritize closer corners with better cover scores
```

### Edge Cases Handled ✅
- ✅ No corner found: Falls back to regular corner finding
- ✅ Multiple shots: Only triggers if not already corner hiding
- ✅ Existing corner hiding: Won't interrupt current corner behavior
- ✅ AI facing shot direction: Won't trigger if already looking toward threat
- ✅ Squad coordination: Uses existing squad message system

### Integration Points ✅
- ✅ `FireDetection()` modified to trigger distant shot response
- ✅ `CornerHide()` updated for crouch-to-run transition
- ✅ New directional corner finding functions added
- ✅ Compatible with existing peek mechanics</content>
<parameter name="filePath">ai-corder.md