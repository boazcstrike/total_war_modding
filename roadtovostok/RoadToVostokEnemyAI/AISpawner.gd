extends "res://Scripts/AISpawner.gd"

var EnemyAISettings = preload("res://RoadToVostokEnemyAI/EnemyAISettings.tres")
var SquadManager = preload("res://RoadToVostokEnemyAI/SquadManager.gd")
var spawnedThisMap = 0
var currentFactionName = "Unknown"
var factionPool: Array = []
var faction_spawn_scales = {}
var spawnLocationPools
var squad_manager
var active_per_faction = {}

const SPAWN_AUDIT_RAY_ABOVE = 3.0
const SPAWN_AUDIT_RAY_BELOW = 20.0
const SPAWN_AUDIT_BELOW_FLOOR_THRESHOLD = 2.5
const SPAWN_AUDIT_ABOVE_FLOOR_THRESHOLD = 6.0

func _ready():
    GetPoints()
    spawnLocationPools = spawns
    HidePoints()

    # Initialize squad manager
    squad_manager = SquadManager.new()
    add_child(squad_manager)

    # Initialize active per faction tracking
    active_per_faction = {"Bandit": 0, "Guard": 0, "Military": 0, "Punisher": 0}

    active = true
    spawnDistance = EnemyAISettings.spawn_distance
    spawnLimit = _get_spawn_limit()
    spawnPool = _get_spawn_pool()
    initialGuard = EnemyAISettings.initial_guard
    initialHider = EnemyAISettings.initial_hider
    noHiding = EnemyAISettings.disable_hiding

    _debug_log("Spawner ready on scene '%s' with zone '%s'" % [get_tree().current_scene.name, _zone_name()])
    _debug_log("Points: spawnLocationPools=%d, waypoints=%d, patrols=%d, covers=%d, hides=%d" % [spawnLocationPools.size(), waypoints.size(), patrols.size(), covers.size(), hides.size()])
    _debug_begin_map("Spawner initialized")

    if !active:
        _debug_log("Spawner inactive")
        return

    agent = _select_agent_scene()
    factionPool = _build_faction_pool()
    currentFactionName = _describe_faction_pool()
    faction_spawn_scales = {
        "Bandit": 0.8,
        "Guard": 1.0,
        "Military": 1.2
    }
    _debug_log("Selected faction pool for zone '%s': %s" % [_zone_name(), currentFactionName])

    CreatePools()
    _spawn_initial_population(_get_initial_population())

    if initialGuard:
        SpawnGuard()

    if initialHider:
        if randi_range(0, 100) < EnemyAISettings.initial_hider_chance:
            SpawnHider()
        else:
            _debug_log("Initial hider roll failed")

func _physics_process(delta):
    if !active:
        return

    spawnTime -= delta
    _debug_log("Spawn timer decremented to %.2f" % spawnTime)

    if spawnTime <= 0:
        var before_active = activeAgents
        var spawned_this_cycle = 0
        for _i in range(2):
            var available = get_valid_faction_to_spawn()
            if available.is_empty():
                _debug_log("No factions available for spawning")
                break
            var faction = available.pick_random()
            _debug_log("Spawn attempt for faction: %s active=%d limit=%d pool_remaining=%d" % [faction, activeAgents, spawnLimit, APool.get_child_count()])
            _spawn_for_faction_single(faction)
            spawned_this_cycle += 1
        if spawned_this_cycle == 0:
            _debug_log("Spawn skipped because no factions available or active AI reached limit (%d/%d)" % [activeAgents, spawnLimit])
            _debug_push_status("Active limit reached")

        var interval_profile = _get_spawn_interval_profile()
        var scale = 1.0
        if spawned_this_cycle > 0:
            var spawned_agent = agents.get_child(agents.get_child_count() - 1)
            var faction = str(spawned_agent.get_meta("enemy_ai_faction"))
            scale = faction_spawn_scales.get(faction, 1.0)
        spawnTime = randf_range(interval_profile["min"] * scale, interval_profile["max"] * scale)
        _debug_log("Next spawn timer set to %.2fs" % spawnTime)
        _debug_push_status("Spawn timer reset")

func _get_preset_profile() -> Dictionary:
    match EnemyAISettings.intensity_preset:
        1:
            return {
                "spawn_limit": 8,
                "spawn_pool": 24,
                "initial_population": 2,
                "spawn_min": 5.0,
                "spawn_max": 28.0
            }
        2:
            return {
                "spawn_limit": 12,
                "spawn_pool": 36,
                "initial_population": 4,
                "spawn_min": 4.0,
                "spawn_max": 20.0
            }
        3:
            return {
                "spawn_limit": 16,
                "spawn_pool": 48,
                "initial_population": 5,
                "spawn_min": 3.0,
                "spawn_max": 16.0
            }
        4:
            return {
                "spawn_limit": 32,
                "spawn_pool": 96,
                "initial_population": 10,
                "spawn_min": 1.5,
                "spawn_max": 8.0
            }
        5:
            return {
                "spawn_limit": 52,
                "spawn_pool": 156,
                "initial_population": 16,
                "spawn_min": 0.9,
                "spawn_max": 4.5
            }
        _:
            return {
                "spawn_limit": 16,
                "spawn_pool": 48,
                "initial_population": 6,
                "spawn_min": 10.0,
                "spawn_max": 60.0
            }

func _get_rate_scale() -> float:
    match EnemyAISettings.spawn_rate_adjustment:
        0:
            return 1.25
        2:
            return 0.75
        _:
            return 1.0

func _get_spawn_limit() -> int:
    var profile = _get_preset_profile()
    return max(1, profile["spawn_limit"] + EnemyAISettings.spawn_limit_bonus)

func _get_spawn_pool() -> int:
    var profile = _get_preset_profile()
    return max(1, profile["spawn_pool"] + EnemyAISettings.spawn_pool_bonus)

func _get_initial_population() -> int:
    return max(0, EnemyAISettings.initial_population + EnemyAISettings.initial_population_bonus)

func _get_spawn_interval_profile() -> Dictionary:
    var profile = _get_preset_profile()
    var rate_scale = _get_rate_scale()
    return {
        "min": max(0.5, profile["spawn_min"] * rate_scale),
        "max": max(1.0, profile["spawn_max"] * rate_scale)
    }

func _select_agent_scene():
    return _get_default_agent_scene()

func _get_default_agent_scene():
    if zone == Zone.Area05:
        return bandit
    elif zone == Zone.BorderZone:
        return guard
    elif zone == Zone.Vostok:
        return military

    return bandit

func _build_faction_pool() -> Array:
    var pool: Array = []
    var default_scene = _get_default_agent_scene()

    _append_faction_by_mode(pool, default_scene, bandit, EnemyAISettings.bandit_spawn_mode)
    _append_faction_by_mode(pool, default_scene, guard, EnemyAISettings.guard_spawn_mode)
    _append_faction_by_mode(pool, default_scene, military, EnemyAISettings.military_spawn_mode)

    return _dedupe_faction_pool(pool)

func _has_forced_faction_modes() -> bool:
    return EnemyAISettings.bandit_spawn_mode != 0 || EnemyAISettings.guard_spawn_mode != 0 || EnemyAISettings.military_spawn_mode != 0

func _append_faction_by_mode(pool: Array, default_scene, scene_resource, mode_value: int):
    var mode = int(mode_value)

    if mode == 2:
        return

    if mode == 1:
        pool.append(scene_resource)
        return

    if scene_resource == default_scene:
        pool.append(scene_resource)

func _dedupe_faction_pool(pool: Array) -> Array:
    var unique_pool: Array = []

    for scene_resource in pool:
        if !unique_pool.has(scene_resource):
            unique_pool.append(scene_resource)

    return unique_pool

func _describe_faction_pool() -> String:
    var names: Array[String] = []

    for scene_resource in factionPool:
        names.append(_packed_scene_name(scene_resource))

    if names.is_empty():
        return "None"

    return ", ".join(names)

func CreatePools():
    APool.global_position = Vector3(0, 1000, 0)
    BPool.global_position = Vector3(0, 1000, 0)

    var available_factions = factionPool
    if available_factions.is_empty():
        _debug_log("AI Spawner: No regular factions enabled for this zone. Regular AI pool will stay empty.")
    else:
        for _amount in spawnPool:
            var next_scene = available_factions.pick_random()
            _debug_log("Agent selected from pool: %s" % _packed_scene_name(next_scene))
            var newAgent = next_scene.instantiate()
            APool.add_child(newAgent, true)

            newAgent.boss = false
            newAgent.AISpawner = self
            var faction_name = _packed_scene_name(next_scene)
            newAgent.set_meta("enemy_ai_faction", faction_name)
            # Assign to squad
            var squad_id = squad_manager.assign_to_squad(newAgent, faction_name)
            _debug_log("Agent assigned to squad: %s" % squad_id)
            newAgent.global_position = APool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
            newAgent.Pause()

    var newBoss = punisher.instantiate()
    BPool.add_child(newBoss, true)

    newBoss.boss = true
    newBoss.AISpawner = self
    newBoss.set_meta("enemy_ai_faction", "Punisher")
    newBoss.global_position = BPool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
    newBoss.Pause()

    _debug_log("AI Spawner: Mixed pools created with factions: %s" % _describe_faction_pool())

func _spawn_initial_population(count: int):
    for _i in count:
        if activeAgents < spawnLimit:
            SpawnWanderer()

func SpawnWanderer():
    var before_active = activeAgents
    super()
    _handle_spawn_result("Wanderer", before_active)

func SpawnGuard():
    var before_active = activeAgents
    super()
    _handle_spawn_result("Guard", before_active)

func SpawnHider():
    var before_active = activeAgents
    super()
    _handle_spawn_result("Hider", before_active)

func SpawnMinion(spawnPosition):
    var before_active = activeAgents
    super(spawnPosition)
    _handle_spawn_result("Minion", before_active)

func SpawnBoss(spawnPosition):
    var before_active = activeAgents
    super(spawnPosition)
    _handle_spawn_result("Boss", before_active)

func _handle_spawn_result(spawn_type: String, before_active: int):
    if activeAgents > before_active:
        spawnedThisMap += 1
        var spawned_agent = agents.get_child(agents.get_child_count() - 1)
        var spawned_faction = "Unknown"
        if spawned_agent and spawned_agent.has_meta("enemy_ai_faction"):
            spawned_faction = str(spawned_agent.get_meta("enemy_ai_faction"))
            active_per_faction[spawned_faction] = active_per_faction.get(spawned_faction, 0) + 1
        var spawn_point_name = "none"
        if spawned_agent.currentPoint:
            spawn_point_name = spawned_agent.currentPoint.name
        _debug_log("Spawn point selected and assigned: %s for %s (%s)" % [spawn_point_name, spawn_type, spawned_faction])
        _debug_log("%s spawned successfully as %s. spawned_this_map=%d active=%d" % [spawn_type, spawned_faction, spawnedThisMap, activeAgents])
        _debug_record_spawn("%s spawned (%s)" % [spawn_type, spawned_faction], spawn_type, spawned_faction)
        _audit_spawned_agent(spawned_agent, spawn_type, "spawn")
        _schedule_spawn_audit(spawned_agent, spawn_type)

        var camera_pos = gameData.cameraPosition
        var distance_to_camera = spawned_agent.global_position.distance_to(camera_pos)
        _debug_log("Position selection: initial distance to camera %.2f" % distance_to_camera)
        if distance_to_camera < 30.0:
            var points = _get_spawn_points_for_faction(spawned_faction)
            _debug_log("Distance check failed, selecting new point from %d available for faction %s" % [points.size(), spawned_faction])
            var new_point = null
            for point in points:
                var point_distance = point.global_position.distance_to(camera_pos)
                _debug_log("Checking point %s: distance %.2f" % [point.name, point_distance])
                if point_distance >= 30.0:
                    new_point = point
                    _debug_log("Selected point %s with distance %.2f" % [point.name, point_distance])
                    break
            if new_point:
                spawned_agent.global_position = new_point.global_position
                _debug_log("Moved %s spawn to valid point due to camera proximity" % spawn_type)
            else:
                _debug_log("No valid point found for distance check")
    else:
        _debug_log("%s spawn failed. active=%d pool_remaining=%d" % [spawn_type, activeAgents, APool.get_child_count()])
        _debug_push_status("%s spawn failed" % spawn_type)

func replenish_regular_pool(faction_name: String):
    if !EnemyAISettings.replenish_spawn_pool:
        return

    if !can_spawn_faction(faction_name):
        _debug_log("Pool replenish skipped: faction %s at active limit" % faction_name)
        return

    var scene_resource = _scene_for_faction_name(faction_name)
    if scene_resource == null:
        _debug_log("Pool replenish skipped: no scene found for faction=%s" % faction_name)
        return

    _debug_log("Agent selected for pool replenish: %s" % faction_name)
    var newAgent = scene_resource.instantiate()
    APool.add_child(newAgent, true)

    newAgent.boss = false
    newAgent.AISpawner = self
    newAgent.set_meta("enemy_ai_faction", faction_name)
    # Assign to squad
    var squad_id = squad_manager.assign_to_squad(newAgent, faction_name)
    _debug_log("Replenished agent assigned to squad: %s" % squad_id)
    newAgent.global_position = APool.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
    newAgent.Pause()

    _debug_log("Pool replenished for faction=%s reserve=%d" % [faction_name, APool.get_child_count()])

func _scene_for_faction_name(faction_name: String):
    match faction_name:
        "Bandit":
            return bandit
        "Guard":
            return guard
        "Military":
            return military
        _:
            return null

func _debug_main():
    return get_node_or_null("/root/EnemyAIMain")

func _debug_begin_map(event_text: String):
    var debug_main = _debug_main()
    if debug_main:
        debug_main.begin_map(get_tree().current_scene.name, _zone_name(), {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "last_event": event_text
        })

func _debug_record_spawn(event_text: String, role_name: String, faction_name: String):
    var debug_main = _debug_main()
    if debug_main:
        debug_main.record_spawn(event_text, activeAgents, {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "spawn_faction": faction_name,
            "spawn_role": role_name
        })

func _debug_push_status(event_text: String):
    var debug_main = _debug_main()
    if debug_main:
        var squad_count = 0
        if is_instance_valid(squad_manager) and squad_manager.has_method("get_total_squads"):
            squad_count = squad_manager.get_total_squads()
        debug_main.update_status(activeAgents, {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "squad_count": squad_count,
            "last_event": event_text
        })

func _debug_log(message: String):
    var debug_main = _debug_main()
    if debug_main:
        debug_main.log_debug(message)

func _schedule_spawn_audit(spawned_agent, spawn_type: String):
    await get_tree().create_timer(1.25, false).timeout
    _audit_spawned_agent(spawned_agent, spawn_type, "delayed")

func _audit_spawned_agent(spawned_agent, spawn_type: String, phase: String):
    if !is_instance_valid(spawned_agent):
        return

    var audit = _sample_floor_audit(spawned_agent)
    if !bool(audit.get("suspicious", false)):
        return

    var reason = str(audit.get("reason", "unknown"))
    var floor_y = float(audit.get("floor_y", spawned_agent.global_position.y))
    var delta_y = float(audit.get("delta_y", 0.0))
    var source_name = "Unknown"
    if spawned_agent.get("currentPoint") is Node3D:
        source_name = spawned_agent.currentPoint.name

    var event_text = "Suspicious %s spawn (%s): %s dy=%.2f floor=%.2f agent=%.2f point=%s" % [
        spawn_type,
        phase,
        reason,
        delta_y,
        floor_y,
        spawned_agent.global_position.y,
        source_name
    ]
    _debug_log(event_text)

    var debug_main = _debug_main()
    if debug_main:
        debug_main.record_suspicious_spawn(event_text, activeAgents, {
            "spawn_limit": spawnLimit,
            "spawn_pool": spawnPool,
            "spawn_distance": spawnDistance,
            "preset_name": _preset_name(),
            "rate_name": _rate_name(),
            "current_faction": currentFactionName,
            "last_event": event_text
        })

func _sample_floor_audit(spawned_agent) -> Dictionary:
    var origin = spawned_agent.global_position + Vector3(0, SPAWN_AUDIT_RAY_ABOVE, 0)
    var destination = spawned_agent.global_position + Vector3(0, -SPAWN_AUDIT_RAY_BELOW, 0)
    var query = PhysicsRayQueryParameters3D.create(origin, destination)
    query.exclude = [spawned_agent]

    var result = get_world_3d().direct_space_state.intersect_ray(query)
    if result.is_empty():
        return {
            "suspicious": true,
            "reason": "no_floor_hit"
        }

    var floor_y = float(result.position.y)
    var delta_y = floor_y - spawned_agent.global_position.y

    if delta_y > SPAWN_AUDIT_BELOW_FLOOR_THRESHOLD:
        return {
            "suspicious": true,
            "reason": "below_floor_surface",
            "floor_y": floor_y,
            "delta_y": delta_y
        }

    if delta_y < -SPAWN_AUDIT_ABOVE_FLOOR_THRESHOLD:
        return {
            "suspicious": true,
            "reason": "floating_above_floor",
            "floor_y": floor_y,
            "delta_y": delta_y
        }

    return {
        "suspicious": false,
        "floor_y": floor_y,
        "delta_y": delta_y
    }

func _zone_name() -> String:
    match zone:
        Zone.Area05:
            return "Area05"
        Zone.BorderZone:
            return "BorderZone"
        Zone.Vostok:
            return "Vostok"
        _:
            return "Unknown"

func _preset_name() -> String:
    match EnemyAISettings.intensity_preset:
        1:
            return "Medium"
        2:
            return "Medium High"
        3:
            return "High"
        4:
            return "Very High"
        5:
            return "Insane"
        _:
            return "Default"

func _rate_name() -> String:
    match EnemyAISettings.spawn_rate_adjustment:
        0:
            return "Lower"
        2:
            return "Higher"
        _:
            return "Vanilla"

func _packed_scene_name(scene_resource) -> String:
    if scene_resource == bandit:
        return "Bandit"
    elif scene_resource == guard:
        return "Guard"
    elif scene_resource == military:
        return "Military"
    elif scene_resource == punisher:
        return "Punisher"
    return "Unknown"

func _get_spawn_points_for_faction(faction_name: String) -> Array:
    var prefix = faction_name.to_lower() + "_"
    var filtered = []
    for point in spawnLocationPools:
        if point.name.to_lower().begins_with(prefix):
            filtered.append(point)
    var selected = []
    var source = filtered if !filtered.is_empty() else spawnLocationPools
    for i in range(min(6, source.size())):
        var point = source.pick_random()
        if !selected.has(point):
            selected.append(point)
    return selected

func get_squad_manager():
    return squad_manager

func can_spawn_faction(faction: String) -> bool:
    var current = active_per_faction.get(faction, 0)
    if faction == "Bandit" or faction == "Guard":
        return (active_per_faction.get("Bandit", 0) + active_per_faction.get("Guard", 0)) < 24
    elif faction == "Military":
        return current < 4
    elif faction == "Punisher":
        return current < 1
    return false

func get_valid_faction_to_spawn() -> Array:
    var available = []
    for scene in factionPool:
        var name = _packed_scene_name(scene)
        if can_spawn_faction(name):
            available.append(name)
    return available

func decrement_active(faction: String):
    active_per_faction[faction] = max(0, active_per_faction.get(faction, 0) - 1)

func _spawn_for_faction_single(faction_name: String):
    if activeAgents >= spawnLimit:
        return
    var scene = _scene_for_faction_name(faction_name)
    if scene == null:
        return
    _debug_log("Agent selected from pool for faction spawn: %s" % faction_name)
    var newAgent = scene.instantiate()
    agents.add_child(newAgent)
    newAgent.boss = false
    newAgent.AISpawner = self
    newAgent.set_meta("enemy_ai_faction", faction_name)
    # Assign to squad
    var squad_id = squad_manager.assign_to_squad(newAgent, faction_name)
    _debug_log("Spawned agent assigned to squad: %s" % squad_id)
    var spawn_point = spawnLocationPools.pick_random() if !spawnLocationPools.is_empty() else null
    if spawn_point:
        _debug_log("Spawn point selected: %s for faction %s" % [spawn_point.name, faction_name])
        newAgent.global_position = spawn_point.global_position
        newAgent.currentPoint = spawn_point
    else:
        _debug_log("No spawn points available for faction %s" % faction_name)
    newAgent.Unpause()
    activeAgents += 1
    _handle_spawn_result("FactionSpawn", activeAgents - 1)

func _spawn_for_faction(faction_name: String):
    _debug_log("Spawn attempt for faction: %s" % faction_name)
    var scene = _scene_for_faction_name(faction_name)
    if scene == null:
        _debug_log("No scene for faction %s" % faction_name)
        return
    var spawned = 0
    for i in range(2):
        if activeAgents >= spawnLimit:
            break
        _debug_log("Agent selected from pool for faction spawn: %s" % faction_name)
        var newAgent = scene.instantiate()
        agents.add_child(newAgent)
        newAgent.boss = false
        newAgent.AISpawner = self
        newAgent.set_meta("enemy_ai_faction", faction_name)
        # Assign to squad
        var squad_id = squad_manager.assign_to_squad(newAgent, faction_name)
        _debug_log("Spawned agent assigned to squad: %s" % squad_id)
        var spawn_point = spawnLocationPools.pick_random() if !spawnLocationPools.is_empty() else null
        if spawn_point:
            _debug_log("Spawn point selected: %s for faction %s" % [spawn_point.name, faction_name])
            newAgent.global_position = spawn_point.global_position
            newAgent.currentPoint = spawn_point
        else:
            _debug_log("No spawn points available for faction %s" % faction_name)
        newAgent.Unpause()
        activeAgents += 1
        spawned += 1
        _handle_spawn_result("FactionSpawn", activeAgents - spawned)
    _debug_log("Spawned %d agents for faction %s" % [spawned, faction_name])
