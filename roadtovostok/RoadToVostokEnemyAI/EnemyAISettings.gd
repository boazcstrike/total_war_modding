extends Resource
class_name EnemyAISettings

@export var intensity_preset = 0
@export var spawn_rate_adjustment = 1

@export var spawn_limit_bonus = 0
@export var spawn_pool_bonus = 0
@export var initial_population_bonus = 0
@export var spawn_distance = 100
@export var initial_guard = false
@export var initial_hider = false
@export var initial_hider_chance = 25
@export var disable_hiding = false

@export var enemy_type_override_enabled = false
@export var bandit_spawn_mode = 0
@export var guard_spawn_mode = 0
@export var military_spawn_mode = 0

@export var bandit_infighting_enabled = false
@export var guard_infighting_enabled = false
@export var military_infighting_enabled = false
@export var warfare_enabled = false
@export var player_faction_alignment = 0
@export var corpse_cleanup_limit = 20
@export var player_invulnerable = false
@export var show_debug_overlay = true
@export var replenish_spawn_pool = true

@export var ai_health_multiplier = 1.0
@export var boss_health_multiplier = 1.0
@export var ai_sight_multiplier = 1.0
@export var ai_hearing_multiplier = 1.0
@export var ai_accuracy_multiplier = 1.0
@export var ai_fire_rate_multiplier = 1.0
@export var ai_gunshot_alert_duration = 5.0

# 0=Passive, 1=Default, 2=Aggressive, 3=Relentless
@export var ai_tactics_preset = 1

# Corner hiding and peeking settings
@export var enable_corner_hiding = true
@export var corner_detection_range = 20.0
@export var peek_lean_intensity = 0.3
@export var prefer_exterior_corners = true

# Dynamic environmental adaptation
@export var enable_dynamic_cover = true
@export var enable_environmental_awareness = true
@export var environmental_update_frequency = 2.0
@export var weather_effects_enabled = true
@export var time_of_day_effects_enabled = true

# Interactive objects
@export var enable_interactive_objects = false
@export var door_interaction_range = 5.0
@export var vehicle_interaction_range = 8.0

var mcm_enabled = false
