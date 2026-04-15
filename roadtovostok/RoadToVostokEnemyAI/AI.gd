extends "res://Scripts/AI.gd"

var EnemyAISettings = preload("res://RoadToVostokEnemyAI/EnemyAISettings.tres")

var currentAITarget: Node3D
var currentAITargetVisible = false
var currentAITargetDistance = 9999.0
var targetRefreshTimer = 0.0
var targetRefreshCycle = 0.4
var targetRefreshJitter = 0.0
var targetVisibilityTimer = 0.0
var targetVisibilityJitter = 0.0
var aiAudioSenseTimer = 0.0
var aiAudioSenseJitter = 0.0
var targetLabel = "None"
var previousAITargetVisible = false
var playerPriorityTimer = 0.0
var playerPriorityReason = ""
var lastAISoundTarget: Node3D
var lastAISoundReason = ""
var aiAudioLogCooldowns = {}

# Squad variables
var squad_id = ""
var is_squad_leader = false
var squad_manager

# Squad state timers
var flankTimer = 0.0
var flankCycle = 2.0
var coverTimer = 0.0
var coverCycle = 3.0
var rallyTimer = 0.0
var rallyCycle = 1.5
var cornerHideTimer = 0.0
var cornerHideCycle = 4.0

const PLAYER_PRIORITY_LOS_TIME = 3.0
const PLAYER_PRIORITY_HEARING_TIME = 2.5
const PLAYER_PRIORITY_GUNSHOT_TIME = 3.5
const AI_HEARING_RUN_DISTANCE = 22.0
const AI_HEARING_WALK_DISTANCE = 8.0
const AI_HEARING_GUNSHOT_DISTANCE = 60.0
const AI_GUNSHOT_MEMORY_TIME = 1.25
const AI_AUDIO_LOG_COOLDOWN = 2.0

# Squad states
const State_Flank = "Flank"
const State_CoverAlly = "CoverAlly"
const State_Rally = "Rally"
const State_CornerHide = "CornerHide"

func Activate():
    if boss:
        health = 300.0 * EnemyAISettings.boss_health_multiplier
    else:
        health = 100.0 * EnemyAISettings.ai_health_multiplier

    targetRefreshJitter = randf_range(0.0, 0.12)
    targetRefreshTimer = randf_range(0.0, _current_target_refresh_cycle())
    targetVisibilityJitter = randf_range(0.0, 0.06)
    targetVisibilityTimer = randf_range(0.0, _current_target_visibility_cycle())
    aiAudioSenseJitter = randf_range(0.0, 0.1)
    aiAudioSenseTimer = randf_range(0.0, _current_ai_audio_cycle())

    # Squad setup
    squad_id = get_meta("squad_id", "")
    is_squad_leader = get_meta("squad_leader", false)
    if is_instance_valid(AISpawner) and AISpawner.has_method("get_squad_manager"):
        squad_manager = AISpawner.get_squad_manager()

    super()
    _notify_debug_state_change("", currentState)

func Parameters(delta):
    super(delta)
    _refresh_player_alignment_state()
    if playerPriorityTimer > 0.0:
        playerPriorityTimer = max(0.0, playerPriorityTimer - delta)

        if _player_priority_active():
            lastKnownLocation = playerPosition
            LKL = playerPosition

    _update_hostile_ai_targeting(delta)
    if EnemyAISettings.enable_environmental_awareness:
        _update_environmental_awareness(delta)

func Sensor(delta):
    sensorTimer += delta
    aiAudioSenseTimer -= delta

    if sensorTimer > sensorCycle:
        var player_detected = _sense_player_los()

        if _custom_ai_targeting_active():
            _update_target_visibility()

            if !player_detected and _has_valid_ai_target() and currentAITargetVisible:
                lastKnownLocation = _get_ai_target_position()
                playerVisible = true

                if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
                    Decision()
                elif currentState == State.Ambush:
                    ChangeState("Combat")

        if !_player_priority_active() and _custom_ai_targeting_active() and !_has_stable_visible_ai_target() and aiAudioSenseTimer <= 0.0:
            _sense_ai_audio()
            aiAudioSenseTimer = _current_ai_audio_cycle()

        if !playerVisible:
            Hearing()

        sensorTimer = 0.0

func LOSCheck(target: Vector3):
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)

    if gameData.TOD == 4 and !gameData.flashlight and !boss:
        LOS.target_position = Vector3(0, 0, (25 + extraVisibility) * sight_multiplier)
    elif gameData.fog and !boss:
        LOS.target_position = Vector3(0, 0, (100 + extraVisibility) * sight_multiplier)
    else:
        LOS.target_position = Vector3(0, 0, 200 * sight_multiplier)

    LOS.look_at(target, Vector3.UP, true)
    LOS.force_raycast_update()

    if LOS.is_colliding() and LOS.get_collider().is_in_group("Player"):
        lastKnownLocation = playerPosition
        playerVisible = true
        _activate_player_priority("LOS", PLAYER_PRIORITY_LOS_TIME)
    else:
        playerVisible = false

func Hearing():
    if !_can_target_player():
        return

    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var run_distance = 20.0 * hearing_multiplier
    var walk_distance = 5.0 * hearing_multiplier

    if (playerDistance3D < run_distance and gameData.isRunning) or (playerDistance3D < walk_distance and gameData.isWalking):
        if currentState != State.Ambush:
            lastKnownLocation = playerPosition

        _activate_player_priority("Hearing", PLAYER_PRIORITY_HEARING_TIME)

func FireDetection(delta):
    if !_can_target_player():
        return

    fireDetectionTime = EnemyAISettings.ai_gunshot_alert_duration
    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var local_alert_distance = 50.0 * hearing_multiplier

    if gameData.isFiring and !playerVisible:
        if fireVector > 0.95:
            lastKnownLocation = playerPosition
            _activate_player_priority("Gunshot", PLAYER_PRIORITY_GUNSHOT_TIME)

            fireDetected = true
            extraVisibility = 50.0 * max(0.25, EnemyAISettings.ai_sight_multiplier)
        elif playerDistance3D < local_alert_distance:
            if currentState != State.Ambush:
                lastKnownLocation = playerPosition

            _activate_player_priority("Nearby gunshot", PLAYER_PRIORITY_GUNSHOT_TIME)

            fireDetected = true
            extraVisibility = 50.0 * max(0.25, EnemyAISettings.ai_sight_multiplier)

    if fireDetected:
        fireDetectionTimer += delta

        if fireDetectionTimer > fireDetectionTime:
            extraVisibility = 0.0
            fireDetectionTimer = 0.0
            fireDetected = false

func Decision():
    var engagement_distance = _get_engagement_distance()
    var engagement_visible = _engagement_visible()
    var can_direct_attack = _can_direct_attack_target()

    # Squad coordination
    if is_squad_leader and is_instance_valid(squad_manager) and squad_manager.get_squad_size(self) > 1:
        # Leader can initiate coordinated actions
        if randf() < 0.3 and engagement_visible and engagement_distance < 50:
            squad_manager.send_squad_message(self, {
                "type": "flank_target",
                "position": _get_engagement_position(),
                "sender": self
            })

    if engagement_distance > 20:
        var decision = randi_range(1, 12)  # Increased for new options

        if decision == 1:
            ChangeState("Combat")
        elif decision == 2 and !AISpawner.noHiding:
            ChangeState("Hide")
        elif decision == 3:
            ChangeState("Cover")
        elif decision == 4:
            ChangeState("Vantage")
        elif decision == 5:
            ChangeState("Defend")
        elif decision == 6 and engagement_visible and engagement_distance < 100 and can_direct_attack:
            ChangeState("Hunt")
        elif decision == 7 and engagement_visible and engagement_distance < 100 and can_direct_attack:
            ChangeState("Shift")
        elif decision == 8 and engagement_visible and engagement_distance < 100 and can_direct_attack and (weaponData.weaponAction != "Manual"):
            ChangeState("Attack")
        elif decision == 9 and !AISpawner.noHiding and EnemyAISettings.enable_corner_hiding:
            ChangeState("CornerHide")
        elif decision == 10 and is_squad_leader and engagement_visible and engagement_distance < 50:
            # Leader calls for rally
            var rally_pos = _get_engagement_position() + (global_position - _get_engagement_position()).normalized() * 10.0
            squad_manager.send_squad_message(self, {
                "type": "rally",
                "position": rally_pos,
                "sender": self
            })
            ChangeState("Combat")
        elif decision == 11 and !is_squad_leader and engagement_visible and engagement_distance < 30:
            # Non-leader can request cover
            squad_manager.send_squad_message(self, {
                "type": "need_cover",
                "position": global_position,
                "sender": self
            })
            ChangeState("Combat")
        else:
            ChangeState("Combat")
    else:
        var decision_close = randi_range(1, 4)

        if decision_close == 1:
            ChangeState("Combat")
        elif decision_close == 2:
            ChangeState("Defend")
        elif decision_close == 3 and engagement_visible and can_direct_attack:
            ChangeState("Hunt")
        elif decision_close == 4 and engagement_visible and can_direct_attack and (weaponData.weaponAction != "Manual"):
            ChangeState("Attack")
        else:
            ChangeState("Combat")

func Shift(delta):
    shiftTimer += delta

    if _engagement_visible():
        Fire(delta)

    if shiftTimer > shiftCycle:
        shiftCount -= 1
        shiftTimer = 0.0

        if !GetShiftWaypoint():
            ChangeState("Combat")

    if shiftCount == 0:
        ChangeState("Combat")

    if _get_engagement_distance() < 10 or agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

func Hunt(delta):
    huntTimer += delta

    if _engagement_visible():
        Fire(delta)

    if huntTimer > huntCycle:
        GetHuntWaypoint()
        huntTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished() or _player_only_combat_blocked():
        ChangeState("Combat")

func Attack(delta):
    attackTimer += delta

    if _engagement_visible():
        Fire(delta)

    if attackTimer > attackCycle:
        GetAttackWaypoint()
        attackTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished() or _player_only_combat_blocked():
        if attackReturn and !_engagement_visible():
            ChangeState("Return")
        else:
            ChangeState("Combat")

func Return():
    if global_transform.origin.distance_to(agent.target_position) < 2.0:
        speed = 1.0
        turnSpeed = 2.0
    elif global_transform.origin.distance_to(agent.target_position) < 4.0:
        speed = 3.0
        turnSpeed = 5.0

    if agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

    if _get_engagement_distance() < 10:
        ChangeState("Combat")

func Flank(delta):
    flankTimer += delta

    if _engagement_visible():
        Fire(delta)

    if flankTimer > flankCycle:
        flankTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

    if _get_engagement_distance() < 8:
        ChangeState("Combat")

func CoverAlly(delta):
    coverTimer += delta

    if _engagement_visible():
        Fire(delta)

    if coverTimer > coverCycle:
        coverTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

func Rally(delta):
    rallyTimer += delta

    if rallyTimer > rallyCycle:
        rallyTimer = 0.0

    if agent.is_target_reached() or agent.is_navigation_finished():
        ChangeState("Combat")

    if _get_engagement_distance() < 15:
        ChangeState("Combat")

func CornerHide(delta):
    cornerHideTimer += delta

    if _engagement_visible():
        Fire(delta)

    if cornerHideTimer > cornerHideCycle:
        cornerHideTimer = 0.0
        if !GetCornerHidePoint():
            ChangeState("Combat")

    if agent.is_target_reached() or agent.is_navigation_finished():
        # Stay at corner position persistently
        pass

    if _get_engagement_distance() < 8:
        ChangeState("Combat")

func Fire(delta):
    if impact or _player_only_combat_blocked():
        return

    if LKL.distance_to(_get_engagement_position()) > 4.0:
        return

    if weaponData.weaponAction == "Semi-Auto":
        Selector(delta)

    fireTime -= delta

    if fireTime <= 0:
        _mark_ai_gunshot()
        Raycast()
        PlayFire()
        PlayTail()
        MuzzleVFX()

        impulseTime = spineData.impulse / 2
        impulseTimer = 0.0

        recoveryTime = spineData.impulse
        recoveryTimer = 0.0

        if fullAuto:
            var impulseX = spineTarget.x - spineData.recoil / 10.0
            var impulseY = spineTarget.y
            var impulseZ = spineTarget.z
            impulseTarget = Vector3(impulseX, impulseY, impulseZ)
        else:
            var impulseX2 = spineTarget.x - spineData.recoil
            var impulseY2 = spineTarget.y
            var impulseZ2 = spineTarget.z
            impulseTarget = Vector3(impulseX2, impulseY2, impulseZ2)

        flash.global_position = muzzle.global_position
        flash.Activate()

        FireFrequency()

        if _should_play_player_bullet_audio() and _get_engagement_distance() > 50:
            await get_tree().create_timer(0.1, false).timeout
            PlayCrack()

func FireFrequency():
    var engagement_distance = _get_engagement_distance()

    if weaponData.weaponAction == "Semi-Auto" and fullAuto:
        fireTime = weaponData.fireRate
    elif (weaponData.weaponAction == "Semi-Auto" or weaponData.weaponAction == "Semi") and !fullAuto:
        if engagement_distance < 10:
            fireTime = randf_range(0.1, 0.5)
        elif engagement_distance > 10 and engagement_distance < 50:
            fireTime = randf_range(0.1, 1.0)
        else:
            fireTime = randf_range(0.1, 4.0)
    elif weaponData.weaponAction == "Pump" or weaponData.weaponAction == "Bolt":
        if engagement_distance < 10:
            fireTime = randf_range(1.0, 2.0)
        elif engagement_distance > 10 and engagement_distance < 50:
            fireTime = randf_range(1.0, 2.0)
        else:
            fireTime = randf_range(1.0, 4.0)
    else:
        fireTime = randf_range(1.0, 4.0)

    fireTime = max(0.05, fireTime / max(0.1, EnemyAISettings.ai_fire_rate_multiplier))

func FireAccuracy() -> Vector3:
    var fireDirection = _get_fire_target_position()
    var spreadMultiplier = 1.0
    var accuracy_multiplier = max(0.1, EnemyAISettings.ai_accuracy_multiplier)
    var engagement_distance = _get_engagement_distance()
    var ai_target = _has_valid_ai_target()

    if fullAuto and !boss:
        spreadMultiplier = 2.0

    if ai_target:
        var horizontalSpread = 0.0
        var verticalSpread = 0.0

        if engagement_distance < 10 or boss:
            horizontalSpread = 0.05
            verticalSpread = 0.02
        elif engagement_distance > 10 and engagement_distance < 50:
            horizontalSpread = 0.25
            verticalSpread = 0.08
        else:
            horizontalSpread = 0.5
            verticalSpread = 0.15

        fireDirection.x += randf_range(-horizontalSpread, horizontalSpread) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-verticalSpread, verticalSpread) * spreadMultiplier / accuracy_multiplier
    elif engagement_distance < 10 or boss:
        fireDirection.x += randf_range(-0.1, 0.1) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-0.1, 0.1) * spreadMultiplier / accuracy_multiplier
    elif engagement_distance > 10 and engagement_distance < 50:
        fireDirection.x += randf_range(-1.0, 1.0) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-1.0, 1.0) * spreadMultiplier / accuracy_multiplier
    else:
        fireDirection.x += randf_range(-2.0, 2.0) * spreadMultiplier / accuracy_multiplier
        fireDirection.y += randf_range(-2.0, 2.0) * spreadMultiplier / accuracy_multiplier

    return fireDirection

func Raycast():
    fire.look_at(FireAccuracy(), Vector3.UP, true)
    fire.force_raycast_update()

    if fire.is_colliding():
        var hitCollider = fire.get_collider()

        if hitCollider is Hitbox:
            _apply_damage_to_hitbox(hitCollider, _shot_damage())
        elif _is_ai_root_hit(hitCollider):
            if !_try_apply_targeted_hitbox_damage(hitCollider):
                var rootDamage = _shot_damage()
                _debug_log("Shot landed via AI root collider=%s treating as torso damage=%.1f target=%s" % [hitCollider.name, rootDamage, targetLabel])
                hitCollider.WeaponDamage("Torso", rootDamage)
                var debug_main = get_node_or_null("/root/EnemyAIMain")
                if debug_main:
                    debug_main.record_hit("Torso", true)
        elif hitCollider.is_in_group("Player"):
            if boss:
                hitCollider.get_child(0).WeaponDamage(weaponData.damage * 2.0, weaponData.penetration)
            else:
                hitCollider.get_child(0).WeaponDamage(weaponData.damage, weaponData.penetration)
        else:
            var hitPoint = fire.get_collision_point()
            var hitNormal = fire.get_collision_normal()
            var hitSurface = hitCollider.get("surface")
            BulletDecal(hitCollider, hitPoint, hitNormal, hitSurface)
    elif _should_play_player_bullet_audio() and _get_engagement_distance() > 50:
        await get_tree().create_timer(0.1, false).timeout
        PlayFlyby()

func GetHidePoint() -> bool:
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_HP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    if point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var hidePoint = validPoints.pick_random()
        currentPoint = hidePoint
        MoveToPoint(hidePoint.global_position)
        return true

    return false

func GetVantagePoint() -> bool:
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_PP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    var direction = (engagement_position - point.global_position).normalized()
                    var vector = direction.dot(point.global_transform.basis.z)

                    if vector > 0.9 and point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var vantage = validPoints.pick_random()
        currentPoint = vantage
        MoveToPoint(vantage.global_position)
        return true

    return false

func GetCoverPoint() -> bool:
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    # First try dynamic cover detection
    if EnemyAISettings.enable_dynamic_cover:
        var dynamic_cover = _find_dynamic_cover()
        if dynamic_cover != Vector3.ZERO:
            MoveToPoint(dynamic_cover)
            return true

    # Fallback to static cover points
    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_CP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    var direction = (engagement_position - point.global_position).normalized()
                    var vector = direction.dot(point.global_transform.basis.z)

                    if vector < -0.8 and point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var cover = validPoints.pick_random()
        currentPoint = cover
        MoveToPoint(cover.global_position)
        return true

    return false

func GetCornerHidePoint() -> bool:
    # First try to find dynamic corners
    if EnemyAISettings.enable_corner_hiding:
        var corner_position = _find_dynamic_corner()
        if corner_position != Vector3.ZERO:
            MoveToPoint(corner_position)
            return true

    # Fallback to static corner points if available
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_CH"):  # Corner Hide points
                var distanceToAI = global_position.distance_to(point.global_position)
                var distanceToTarget = point.global_position.distance_to(engagement_position)

                if distanceToAI < 40 and distanceToAI < distanceToTarget:
                    if point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var corner = validPoints.pick_random()
        currentPoint = corner
        MoveToPoint(corner.global_position)
        return true

    return false

func _find_dynamic_corner() -> Vector3:
    var space_state = get_world_3d().direct_space_state
    var engagement_position = _get_engagement_position()
    var ai_position = global_position
    var direction_to_target = (engagement_position - ai_position).normalized()

    # Cast rays in perpendicular directions to find walls
    var perpendicular_left = direction_to_target.cross(Vector3.UP).normalized()
    var perpendicular_right = -perpendicular_left

    var ray_length = 5.0
    var corner_candidates = []

    # Check for L-shaped corners by casting rays in different directions
    for angle_offset in [-45, 0, 45]:  # Check multiple angles
        var base_direction = direction_to_target.rotated(Vector3.UP, deg_to_rad(angle_offset))

        # Cast forward ray to find wall
        var forward_query = PhysicsRayQueryParameters3D.create(ai_position, ai_position + base_direction * ray_length)
        forward_query.exclude = [self]
        var forward_result = space_state.intersect_ray(forward_query)

        if forward_result and forward_result["collider"].is_in_group("Wall"):
            var wall_hit_point = forward_result["position"]
            var wall_normal = forward_result["normal"]

            # Cast perpendicular rays from the wall hit point
            for perp_dir in [perpendicular_left, perpendicular_right]:
                var perp_query = PhysicsRayQueryParameters3D.create(wall_hit_point + wall_normal * 0.1, wall_hit_point + wall_normal * 0.1 + perp_dir * ray_length)
                perp_query.exclude = [self]
                var perp_result = space_state.intersect_ray(perp_query)

                if perp_result and perp_result["collider"].is_in_group("Wall"):
                    # Found potential L-shaped corner
                    var corner_position = wall_hit_point + (perp_result["position"] - wall_hit_point) * 0.5
                    corner_position.y = ai_position.y  # Keep at AI height

                    # Check if this is an exterior corner using sky raycast
                    if !EnemyAISettings.prefer_exterior_corners or _is_exterior_corner(corner_position):
                        var distance_to_corner = ai_position.distance_to(corner_position)
                        var distance_to_target = corner_position.distance_to(engagement_position)

                        # Ensure corner is between AI and target, and not too far
                        if distance_to_corner < EnemyAISettings.corner_detection_range and distance_to_corner < distance_to_target:
                            corner_candidates.append({
                                "position": corner_position,
                                "distance": distance_to_corner
                            })

    # Return closest valid corner
    if corner_candidates.size() > 0:
        corner_candidates.sort_custom(func(a, b): return a.distance < b.distance)
        return corner_candidates[0].position

    return Vector3.ZERO

func _is_exterior_corner(corner_position: Vector3) -> bool:
    var space_state = get_world_3d().direct_space_state

    # Cast ray upward to check if position is open to sky
    var sky_query = PhysicsRayQueryParameters3D.create(corner_position + Vector3(0, 1, 0), corner_position + Vector3(0, 50, 0))
    sky_query.exclude = [self]
    var sky_result = space_state.intersect_ray(sky_query)

    # If no collision (open to sky), it's exterior
    return !sky_result

func _calculate_peek_offset() -> Vector3:
    # Simple peek logic: alternate between left and right leans
    var peek_timer = Time.get_ticks_msec() / 1000.0
    var peek_direction = sin(peek_timer * 2.0)  # Oscillates between -1 and 1

    # Lean left or right based on peek direction
    var lean_amount = EnemyAISettings.peek_lean_intensity
    if peek_direction > 0:
        return Vector3(lean_amount, 0, 0)  # Lean right
    else:
        return Vector3(-lean_amount, 0, 0)  # Lean left

func _find_dynamic_cover() -> Vector3:
    var space_state = get_world_3d().direct_space_state
    var engagement_position = _get_engagement_position()
    var ai_position = global_position
    var direction_to_target = (engagement_position - ai_position).normalized()

    var cover_candidates = []
    var search_radius = 15.0
    var ray_length = 8.0

    # Cast rays in a fan pattern to find potential cover
    for angle in range(-90, 91, 30):  # Check every 30 degrees
        var ray_direction = direction_to_target.rotated(Vector3.UP, deg_to_rad(angle)).normalized()
        var ray_end = ai_position + ray_direction * ray_length

        var query = PhysicsRayQueryParameters3D.create(ai_position, ray_end)
        query.exclude = [self]
        var result = space_state.intersect_ray(query)

        if result and result["collider"].is_in_group("Wall"):
            var hit_point = result["position"]
            var hit_normal = result["normal"]

            # Check if this provides cover from the target
            var cover_position = hit_point - hit_normal * 1.5  # Position behind the cover
            cover_position.y = ai_position.y

            # Verify the cover actually blocks line of sight to target
            var los_query = PhysicsRayQueryParameters3D.create(cover_position + Vector3(0, 1, 0), engagement_position + Vector3(0, 1, 0))
            los_query.exclude = [self]
            var los_result = space_state.intersect_ray(los_query)

            if los_result and los_result["collider"].is_in_group("Wall"):
                # This position has cover
                var distance_to_cover = ai_position.distance_to(cover_position)
                var distance_to_target = cover_position.distance_to(engagement_position)

                if distance_to_cover < search_radius and distance_to_cover < distance_to_target:
                    cover_candidates.append({
                        "position": cover_position,
                        "distance": distance_to_cover
                    })

    # Return closest valid cover position
    if cover_candidates.size() > 0:
        cover_candidates.sort_custom(func(a, b): return a.distance < b.distance)
        return cover_candidates[0].position

    return Vector3.ZERO

# Environmental awareness variables
var environmental_update_timer = 0.0
var environmental_update_cycle = 2.0  # Check every 2 seconds, can be overridden by settings
var last_known_cover_positions = []
var last_known_corner_positions = []

func _update_environmental_awareness(delta):
    environmental_update_timer += delta

    if environmental_update_timer >= EnemyAISettings.environmental_update_frequency:
        environmental_update_timer = 0.0
        environmental_update_cycle = EnemyAISettings.environmental_update_frequency

        # Check for changes in cover positions
        var current_cover = _find_dynamic_cover()
        if current_cover != Vector3.ZERO and not last_known_cover_positions.has(current_cover):
            last_known_cover_positions.append(current_cover)
            # Could trigger behavior change if current cover becomes invalid
            if currentState == State.Cover and agent.is_target_reached():
                var distance_to_current_cover = global_position.distance_to(agent.target_position)
                if distance_to_current_cover > 2.0:  # Cover position changed
                    ChangeState("Combat")  # Re-evaluate

        # Check for changes in corner positions
        var current_corner = _find_dynamic_corner()
        if current_corner != Vector3.ZERO and not last_known_corner_positions.has(current_corner):
            last_known_corner_positions.append(current_corner)

        # Weather and time effects
        _apply_weather_time_effects()

func _notify_debug_state_change(old_state, new_state):
    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if !debug_main:
        return

    var old_decision = _state_to_decision(old_state)
    var new_decision = _state_to_decision(new_state)

    if old_decision != new_decision:
        debug_main.update_decision_count(old_decision, -1)
        debug_main.update_decision_count(new_decision, 1)

func _state_to_decision(state):
    if state == "":
        return ""
    match state:
        State.Combat:
            return "Combat"
        State.Hunt:
            return "Hunt"
        State.Attack:
            return "Attack"
        State.Shift:
            return "Shift"
        State.Hide:
            return "Hide"
        State.Cover:
            return "Cover"
        State.Vantage:
            return "Vantage"
        State.Guard:
            return "Guard"
        State.Patrol:
            return "Patrol"
        State.Ambush:
            return "Ambush"
        State.Return:
            return "Return"
        State_Flank:
            return "Flank"
        State_CoverAlly:
            return "CoverAlly"
        State_Rally:
            return "Rally"
        State_CornerHide:
            return "CornerHide"
        _:
            return "Other"

func _apply_weather_time_effects():
    if !EnemyAISettings.weather_effects_enabled and !EnemyAISettings.time_of_day_effects_enabled:
        return

    # Adjust behavior based on weather and time
    var baseSpeed = speed
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)
    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)

    # Weather effects
    if EnemyAISettings.weather_effects_enabled and gameData.has_method("get_weather_state"):
        var weather = gameData.get_weather_state()
        if weather == "rain" or weather == "storm":
            # Reduced visibility in rain
            sight_multiplier *= 0.6
            hearing_multiplier *= 0.8  # Rain noise can mask sounds
        elif weather == "fog":
            sight_multiplier *= 0.4

    # Time of day effects
    if EnemyAISettings.time_of_day_effects_enabled and gameData.has_method("get_time_of_day"):
        var tod = gameData.get_time_of_day()
        if tod >= 22 or tod <= 4:  # Night time
            # Night patrols - more aggressive at night
            if currentState == State.Patrol:
                speed = baseSpeed * 1.2
            # Reduced visibility at night (unless flashlight)
            if !gameData.flashlight:
                sight_multiplier *= 0.7

    # Apply adjusted multipliers to current LOS check
    # This affects the next LOSCheck call
    extraVisibility = 0.0
    if gameData.fog or (gameData.has_method("get_weather_state") and gameData.get_weather_state() == "fog"):
        extraVisibility = -50.0 * (1.0 - sight_multiplier)

func GetShiftWaypoint():
    var validPoints: Array[Node3D]
    var engagement_position = _get_engagement_position()

    if nearbyPoints.size() != 0:
        for point in nearbyPoints:
            if point.is_in_group("AI_WP"):
                var distanceToAI = global_position.distance_to(point.global_position)
                var directionToTarget = (engagement_position - global_position).normalized()
                var directionToPoint = (point.global_position - global_position).normalized()

                if directionToPoint.dot(directionToTarget) > 0 and distanceToAI < global_position.distance_to(engagement_position):
                    if point != currentPoint:
                        validPoints.append(point)

    if validPoints.size() != 0:
        var shift = validPoints.pick_random()
        currentPoint = shift
        MoveToPoint(shift.global_position)
        return true

    return false

func GetHuntWaypoint():
    MoveToPoint(lastKnownLocation)

func GetAttackWaypoint():
    MoveToPoint(lastKnownLocation)

func ChangeState(state):
    var old_state = currentState
    super(state)
    var new_state = currentState
    _notify_debug_state_change(old_state, new_state)

    var cycle_scale = _get_tactics_cycle_scale()

    if currentState == State.Guard:
        guardCycle *= cycle_scale
    elif currentState == State.Defend:
        defendCycle *= cycle_scale
    elif currentState == State.Combat:
        combatCycle *= cycle_scale
    elif currentState == State.Shift:
        shiftCycle *= cycle_scale
    elif currentState == State.Hunt:
        huntCycle *= cycle_scale
    elif currentState == State.Attack:
        attackCycle *= cycle_scale
    elif currentState == State.Ambush:
        ambushCycle *= cycle_scale
    elif state == "Flank":
        flankCycle = 2.0 * cycle_scale
        flankTimer = 0.0
    elif state == "CoverAlly":
        coverCycle = 3.0 * cycle_scale
        coverTimer = 0.0
    elif state == "Rally":
        rallyCycle = 1.5 * cycle_scale
        rallyTimer = 0.0
    elif state == "CornerHide":
        cornerHideCycle = 4.0 * cycle_scale
        cornerHideTimer = 0.0

func Spine(delta):
    if currentState == State.Defend or currentState == State.Combat or currentState == State.Hunt or currentState == State.Attack or currentState == State.Shift or currentState == State_Flank or currentState == State_CoverAlly or currentState == State_CornerHide:
        spineWeight = move_toward(spineWeight, spineData.weight, delta)
    else:
        spineWeight = move_toward(spineWeight, 0.0, delta * 10.0)

    var spinePose: Transform3D = skeleton.get_bone_global_pose_no_override(spineData.bone)
    var aimTarget: Vector3

    if _has_valid_ai_target() or _player_priority_active():
        aimTarget = -skeleton.to_local(_get_spine_target_position()) + Vector3(0, 1, 0)
    else:
        aimTarget = -skeleton.to_local(LKL)
        aimTarget += Vector3(0, 1, 0)

    # Add peek lean offsets for CornerHide state
    if currentState == State_CornerHide and _engagement_visible():
        var peek_offset = _calculate_peek_offset()
        aimTarget += peek_offset

    var spineAimPose = spinePose.looking_at(aimTarget, Vector3.UP)
    spineAimPose.basis = spineAimPose.basis.rotated(spineAimPose.basis.x, deg_to_rad(spineTarget.x))
    spineAimPose.basis = spineAimPose.basis.rotated(spineAimPose.basis.y, deg_to_rad(spineTarget.y))
    spineAimPose.basis = spineAimPose.basis.rotated(spineAimPose.basis.z, deg_to_rad(spineTarget.z))

    skeleton.set_bone_global_pose_override(spineData.bone, spineAimPose, spineWeight, true)

func _get_tactics_cycle_scale() -> float:
    match EnemyAISettings.ai_tactics_preset:
        0:
            return 1.5
        2:
            return 0.75
        3:
            return 0.5
        _:
            return 1.0

func Death(direction, force):
    _debug_log("Death faction=%s target=%s" % [_self_faction(), targetLabel])
    super(direction, force)
    if is_instance_valid(AISpawner) and AISpawner.has_method("replenish_regular_pool") and !boss:
        AISpawner.replenish_regular_pool(_self_faction())
    _clear_ai_target()

    # Remove from squad
    if is_instance_valid(squad_manager):
        squad_manager.remove_from_squad(self)

    _notify_debug_state_change(currentState, "")

    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        debug_main.record_death(AISpawner.activeAgents, {
            "last_event": "AI died",
            "current_target": "None"
        })
        debug_main.register_corpse(self, {
            "label": name,
            "faction": _self_faction()
        })

func _custom_ai_targeting_active() -> bool:
    if boss:
        return false

    return _same_faction_infighting_active() or _faction_warfare_active()

func _same_faction_infighting_active() -> bool:
    return _same_faction_targeting_allowed(_self_faction())

func _faction_warfare_active() -> bool:
    var faction = _self_faction()
    return EnemyAISettings.warfare_enabled and _is_supported_warfare_faction(faction)

func _sense_player_los() -> bool:
    if !_can_target_player():
        playerVisible = false
        return false

    if playerDistance3D <= 200.0:
        var directionToPlayer = (eyes.global_position - gameData.cameraPosition).normalized()
        var viewDirection = -eyes.global_transform.basis.z.normalized()
        var viewRadius = viewDirection.dot(directionToPlayer)

        if viewRadius > 0.5:
            LOSCheck(gameData.cameraPosition)
            return playerVisible

    playerVisible = false
    return false

func _player_priority_active() -> bool:
    return playerPriorityTimer > 0.0

func _can_target_player() -> bool:
    var aligned_faction = _player_aligned_faction()
    return aligned_faction == "" or aligned_faction != _self_faction()

func _player_aligned_faction() -> String:
    match EnemyAISettings.player_faction_alignment:
        1:
            return "Bandit"
        2:
            return "Guard"
        3:
            return "Military"
        _:
            return ""

func _refresh_player_alignment_state():
    if _can_target_player():
        return

    if _player_priority_active():
        playerPriorityTimer = 0.0
        playerPriorityReason = ""
        playerVisible = false

        if !_has_valid_ai_target():
            targetLabel = "None"

        _debug_log("Player alignment cleared hostility for faction=%s" % _self_faction())

func _activate_player_priority(reason: String, duration: float):
    var was_active = _player_priority_active()

    playerPriorityTimer = max(playerPriorityTimer, duration)
    playerPriorityReason = reason
    lastKnownLocation = playerPosition
    LKL = playerPosition

    if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
        Decision()
    elif currentState == State.Ambush or currentState == State.Hide or currentState == State.Cover or currentState == State.Vantage or currentState == State.Return or currentState == State.Defend:
        ChangeState("Combat")
    elif !was_active and currentState != State.Combat:
        ChangeState("Combat")

    _debug_log("Player priority activated (%s) distance=%.1f state=%s" % [reason, playerDistance3D, str(currentState)])

func _self_faction() -> String:
    if has_meta("enemy_ai_faction"):
        return str(get_meta("enemy_ai_faction"))
    return "Unknown"

func _update_hostile_ai_targeting(delta):
    if !_custom_ai_targeting_active():
        _clear_ai_target(false)
        return

    var current_refresh_cycle = _current_target_refresh_cycle()
    if targetRefreshTimer > current_refresh_cycle:
        targetRefreshTimer = current_refresh_cycle

    var current_visibility_cycle = _current_target_visibility_cycle()
    if targetVisibilityTimer > current_visibility_cycle:
        targetVisibilityTimer = current_visibility_cycle

    targetRefreshTimer -= delta
    targetVisibilityTimer -= delta

    if !_has_valid_ai_target() or targetRefreshTimer <= 0.0:
        var previousTarget = currentAITarget
        currentAITarget = _acquire_hostile_ai_target()
        targetRefreshTimer = current_refresh_cycle
        targetVisibilityTimer = 0.0

        if currentAITarget != previousTarget:
            if is_instance_valid(currentAITarget):
                _update_target_visibility()
                targetVisibilityTimer = current_visibility_cycle
                _debug_log("Hostile target acquired: %s" % targetLabel)
                _push_debug_status("Hostile target acquired")
                # Alert squad to threat
                if is_instance_valid(squad_manager):
                    squad_manager.send_squad_message(self, {
                        "type": "threat_spotted",
                        "position": _get_ai_target_position(currentAITarget),
                        "sender": self
                    })

    if !_has_valid_ai_target():
        _update_target_visibility()
    else:
        currentAITargetDistance = global_position.distance_to(currentAITarget.global_position)
        _set_target_label()

        if targetVisibilityTimer <= 0.0:
            _update_target_visibility()
            targetVisibilityTimer = current_visibility_cycle

func _current_target_refresh_cycle() -> float:
    var active_count = _active_ai_count()
    var base_cycle = targetRefreshCycle + targetRefreshJitter

    if active_count >= 64:
        base_cycle = 1.45 + targetRefreshJitter
    elif active_count >= 60:
        base_cycle = 1.36 + targetRefreshJitter
    elif active_count >= 56:
        base_cycle = 1.3 + targetRefreshJitter
    elif active_count >= 52:
        base_cycle = 1.22 + targetRefreshJitter
    elif active_count >= 48:
        base_cycle = 1.15 + targetRefreshJitter
    elif active_count >= 45:
        base_cycle = 1.08 + targetRefreshJitter
    elif active_count >= 40:
        base_cycle = 1.0 + targetRefreshJitter
    elif active_count >= 32:
        base_cycle = 0.82 + targetRefreshJitter
    elif active_count >= 24:
        base_cycle = 0.58 + targetRefreshJitter

    if _has_stable_visible_ai_target():
        return max(0.25, base_cycle * 0.72)
    if !_has_valid_ai_target():
        return base_cycle * 1.25

    return base_cycle

func _current_target_visibility_cycle() -> float:
    var active_count = _active_ai_count()
    var base_cycle = 0.08 + targetVisibilityJitter

    if active_count >= 64:
        base_cycle = 0.42 + targetVisibilityJitter
    elif active_count >= 60:
        base_cycle = 0.38 + targetVisibilityJitter
    elif active_count >= 56:
        base_cycle = 0.35 + targetVisibilityJitter
    elif active_count >= 52:
        base_cycle = 0.32 + targetVisibilityJitter
    elif active_count >= 48:
        base_cycle = 0.29 + targetVisibilityJitter
    elif active_count >= 45:
        base_cycle = 0.265 + targetVisibilityJitter
    elif active_count >= 40:
        base_cycle = 0.24 + targetVisibilityJitter
    elif active_count >= 32:
        base_cycle = 0.18 + targetVisibilityJitter
    elif active_count >= 24:
        base_cycle = 0.12 + targetVisibilityJitter

    if _has_valid_ai_target():
        if currentAITargetDistance > 90.0:
            return base_cycle * 1.6
        if currentAITargetDistance > 50.0:
            return base_cycle * 1.35
        if currentAITargetDistance < 20.0:
            return max(0.05, base_cycle * 0.8)

    return base_cycle

func _current_ai_audio_cycle() -> float:
    var active_count = _active_ai_count()

    if active_count >= 64:
        return 1.35 + aiAudioSenseJitter
    if active_count >= 60:
        return 1.25 + aiAudioSenseJitter
    if active_count >= 56:
        return 1.15 + aiAudioSenseJitter
    if active_count >= 52:
        return 1.05 + aiAudioSenseJitter
    if active_count >= 48:
        return 0.95 + aiAudioSenseJitter
    if active_count >= 45:
        return 0.9 + aiAudioSenseJitter
    if active_count >= 40:
        return 0.85 + aiAudioSenseJitter
    if active_count >= 32:
        return 0.65 + aiAudioSenseJitter
    if active_count >= 24:
        return 0.45 + aiAudioSenseJitter

    return 0.25 + aiAudioSenseJitter

func _active_ai_count() -> int:
    if is_instance_valid(AISpawner):
        return int(AISpawner.activeAgents)
    return 0

func _sense_ai_audio():
    var audible_target = _find_audible_hostile_target()
    if !is_instance_valid(audible_target):
        return

    currentAITarget = audible_target
    currentAITargetDistance = global_position.distance_to(audible_target.global_position)
    currentAITargetVisible = false
    lastKnownLocation = _get_ai_target_position(audible_target)

    var reason = _get_audible_target_reason(audible_target)
    if reason == "":
        reason = "AI sound"

    targetLabel = "%s %.1fm" % [_self_or_target_faction_name(audible_target), currentAITargetDistance]

    if currentState == State.Wander or currentState == State.Guard or currentState == State.Patrol:
        Decision()
    elif currentState == State.Ambush or currentState == State.Return:
        ChangeState("Combat")

    if lastAISoundTarget != audible_target or lastAISoundReason != reason:
        _debug_log_ai_audio("ai_audio_%s" % reason.to_lower().replace(" ", "_"), "AI audio tracked target=%s reason=%s distance=%.1f" % [targetLabel, reason, currentAITargetDistance])

    lastAISoundTarget = audible_target
    lastAISoundReason = reason

func _find_audible_hostile_target() -> Node3D:
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return null

    var nearest_target: Node3D = null
    var nearest_distance = 9999.0

    for child in AISpawner.agents.get_children():
        if !_is_valid_hostile_ai_target(child):
            continue

        var distance_to_target = global_position.distance_to(child.global_position)
        if !_target_is_audible(child, distance_to_target):
            continue

        if distance_to_target < nearest_distance:
            nearest_distance = distance_to_target
            nearest_target = child

    return nearest_target

func _target_is_audible(target_node: Node3D, distance_to_target: float) -> bool:
    var hearing_multiplier = max(0.1, EnemyAISettings.ai_hearing_multiplier)
    var movement_speed = float(target_node.get("movementSpeed"))
    var running_distance = AI_HEARING_RUN_DISTANCE * hearing_multiplier
    var walking_distance = AI_HEARING_WALK_DISTANCE * hearing_multiplier
    var gunshot_distance = AI_HEARING_GUNSHOT_DISTANCE * hearing_multiplier

    if _target_fired_recently(target_node) and distance_to_target <= gunshot_distance:
        return true

    if movement_speed >= 2.0 and distance_to_target <= running_distance:
        return true

    if movement_speed > 0.15 and distance_to_target <= walking_distance:
        return true

    return false

func _get_audible_target_reason(target_node: Node3D) -> String:
    if _target_fired_recently(target_node):
        return "Gunshot"

    var movement_speed = float(target_node.get("movementSpeed"))
    if movement_speed >= 2.0:
        return "Running"
    if movement_speed > 0.15:
        return "Walking"

    return ""

func _target_fired_recently(target_node: Node3D) -> bool:
    if !is_instance_valid(target_node):
        return false
    if !target_node.has_meta("enemy_ai_last_shot_time"):
        return false

    var shot_time = float(target_node.get_meta("enemy_ai_last_shot_time"))
    var now = float(Time.get_ticks_msec()) / 1000.0
    return now - shot_time <= AI_GUNSHOT_MEMORY_TIME

func _mark_ai_gunshot():
    set_meta("enemy_ai_last_shot_time", float(Time.get_ticks_msec()) / 1000.0)

func _acquire_hostile_ai_target() -> Node3D:
    if !is_instance_valid(AISpawner) or !is_instance_valid(AISpawner.agents):
        return null

    var nearestTarget: Node3D = null
    var nearestDistance = 9999.0

    for child in AISpawner.agents.get_children():
        if !_is_valid_hostile_ai_target(child):
            continue

        var distanceToTarget = global_position.distance_to(child.global_position)
        if distanceToTarget < nearestDistance and distanceToTarget <= 120.0:
            nearestDistance = distanceToTarget
            nearestTarget = child

    var selectedTarget = _choose_hostile_target_with_hysteresis(nearestTarget, nearestDistance)
    return selectedTarget

func _choose_hostile_target_with_hysteresis(best_candidate: Node3D, best_distance: float) -> Node3D:
    if !_has_valid_ai_target():
        return best_candidate

    if !is_instance_valid(best_candidate):
        return currentAITarget

    if best_candidate == currentAITarget:
        return currentAITarget

    var current_distance = global_position.distance_to(currentAITarget.global_position)

    if currentAITargetVisible:
        if best_distance < current_distance * 0.75:
            return best_candidate
        return currentAITarget

    if best_distance < current_distance * 0.9:
        return best_candidate

    return currentAITarget

func _is_valid_hostile_ai_target(node) -> bool:
    if !is_instance_valid(node):
        return false
    if node == self:
        return false
    if !node.has_method("WeaponDamage"):
        return false
    if bool(node.get("dead")):
        return false
    if bool(node.get("pause")):
        return false
    if !node.has_meta("enemy_ai_faction"):
        return false

    # Don't target squad mates
    if is_instance_valid(squad_manager) and squad_manager.are_squad_mates(self, node):
        return false

    return _is_hostile_faction(_self_faction(), str(node.get_meta("enemy_ai_faction")))

func _is_hostile_faction(self_faction: String, other_faction: String) -> bool:
    if other_faction == "" or other_faction == "Unknown":
        return false

    if self_faction == other_faction:
        return _same_faction_targeting_allowed(self_faction)

    if !_faction_warfare_active():
        return false

    return _is_supported_warfare_faction(self_faction) and _is_supported_warfare_faction(other_faction)

func _same_faction_targeting_allowed(faction: String) -> bool:
    match faction:
        "Bandit":
            return EnemyAISettings.bandit_infighting_enabled
        "Guard":
            return EnemyAISettings.guard_infighting_enabled
        "Military":
            return EnemyAISettings.military_infighting_enabled
        _:
            return false

func _is_supported_warfare_faction(faction: String) -> bool:
    return faction == "Bandit" or faction == "Guard" or faction == "Military"

func _update_target_visibility():
    if _has_valid_ai_target():
        currentAITargetDistance = global_position.distance_to(currentAITarget.global_position)
        currentAITargetVisible = _can_see_ai_target(currentAITarget)
        _set_target_label()
        previousAITargetVisible = currentAITargetVisible

        if currentAITargetVisible:
            lastKnownLocation = _get_ai_target_position()
    else:
        currentAITargetVisible = false
        currentAITargetDistance = 9999.0
        if _player_priority_active():
            targetLabel = "Player %.1fm" % playerDistance3D
        else:
            targetLabel = "None"
        previousAITargetVisible = false

func _can_see_ai_target(target_node: Node3D) -> bool:
    if !is_instance_valid(target_node):
        return false

    var target_position = _get_ai_target_position(target_node)
    var sight_multiplier = max(0.1, EnemyAISettings.ai_sight_multiplier)

    if gameData.TOD == 4 and !gameData.flashlight and !boss:
        LOS.target_position = Vector3(0, 0, (25 + extraVisibility) * sight_multiplier)
    elif gameData.fog and !boss:
        LOS.target_position = Vector3(0, 0, (100 + extraVisibility) * sight_multiplier)
    else:
        LOS.target_position = Vector3(0, 0, 200 * sight_multiplier)

    LOS.look_at(target_position, Vector3.UP, true)
    LOS.force_raycast_update()

    if !LOS.is_colliding():
        return false

    var collider = LOS.get_collider()
    if collider == target_node:
        return true
    if collider is Hitbox and collider.owner == target_node:
        return true

    return false

func _has_valid_ai_target() -> bool:
    return _is_valid_hostile_ai_target(currentAITarget)

func _has_stable_visible_ai_target() -> bool:
    return _has_valid_ai_target() and currentAITargetVisible

func _get_ai_target_position(target_node = null) -> Vector3:
    if target_node == null:
        target_node = currentAITarget

    if !is_instance_valid(target_node):
        return playerPosition

    var torsoPosition = _get_ai_torso_position(target_node)
    if torsoPosition != Vector3.ZERO:
        return torsoPosition

    var targetHead = target_node.get("head")
    if targetHead is Node3D:
        return targetHead.global_position + Vector3(0, -0.35, 0)

    var targetEyes = target_node.get("eyes")
    if targetEyes is Node3D:
        return targetEyes.global_position + Vector3(0, -0.6, 0)

    return target_node.global_position + Vector3(0, 0.8, 0)

func _get_fire_target_position() -> Vector3:
    if _player_priority_active():
        return playerPosition + Vector3(0, 1.0, 0)

    if _has_valid_ai_target():
        var torsoPosition = _get_ai_torso_position()
        if torsoPosition != Vector3.ZERO:
            return torsoPosition

    return playerPosition + Vector3(0, 1.0, 0)

func _get_spine_target_position() -> Vector3:
    if _player_priority_active():
        return playerPosition

    if _has_valid_ai_target():
        var spineTorsoPosition = _get_ai_spine_torso_position()
        if spineTorsoPosition != Vector3.ZERO:
            return spineTorsoPosition

        return currentAITarget.global_position + Vector3(0, 1.0, 0)

    return LKL

func _get_ai_torso_position(target_node = null) -> Vector3:
    if target_node == null:
        target_node = currentAITarget

    if !is_instance_valid(target_node):
        return Vector3.ZERO

    var targetChest = target_node.get("chest")
    if targetChest is Node3D:
        return targetChest.global_position + Vector3(0, -0.25, 0)

    return Vector3.ZERO

func _get_ai_spine_torso_position(target_node = null) -> Vector3:
    if target_node == null:
        target_node = currentAITarget

    if !is_instance_valid(target_node):
        return Vector3.ZERO

    var targetChest = target_node.get("chest")
    if targetChest is Node3D:
        return targetChest.global_position

    var targetHead = target_node.get("head")
    if targetHead is Node3D:
        return targetHead.global_position + Vector3(0, -0.6, 0)

    return target_node.global_position + Vector3(0, 1.0, 0)

func _is_ai_root_hit(hitCollider) -> bool:
    if !is_instance_valid(hitCollider):
        return false
    if hitCollider == self:
        return false
    if !hitCollider.has_method("WeaponDamage"):
        return false
    if !hitCollider.has_meta("enemy_ai_faction"):
        return false
    return _is_valid_hostile_ai_target(hitCollider)

func _get_engagement_position() -> Vector3:
    if _player_priority_active():
        return playerPosition

    if _has_valid_ai_target():
        return _get_ai_target_position()
    return playerPosition

func _get_engagement_distance() -> float:
    if _player_priority_active():
        return playerDistance3D

    if _has_valid_ai_target():
        return currentAITargetDistance
    return playerDistance3D

func _engagement_visible() -> bool:
    if _player_priority_active():
        return playerVisible

    if _has_valid_ai_target():
        return currentAITargetVisible
    return playerVisible

func _can_direct_attack_target() -> bool:
    if _player_priority_active():
        return true

    if _has_valid_ai_target():
        return true
    return !gameData.isTrading

func _player_only_combat_blocked() -> bool:
    if _player_priority_active():
        return false

    if _has_valid_ai_target():
        return false
    return gameData.isTrading

func _should_play_player_bullet_audio() -> bool:
    return _player_priority_active() and _can_target_player()

func _clear_ai_target(push_status: bool = true):
    currentAITarget = null
    currentAITargetVisible = false
    currentAITargetDistance = 9999.0
    targetLabel = "None"
    previousAITargetVisible = false

    if push_status:
        _push_debug_status("No active hostile target")

func _set_target_label():
    if _player_priority_active():
        targetLabel = "Player %.1fm" % playerDistance3D
        return

    if !_has_valid_ai_target():
        targetLabel = "None"
        return

    targetLabel = "%s %.1fm" % [_self_or_target_faction_name(currentAITarget), currentAITargetDistance]

func _self_or_target_faction_name(target_node: Node3D) -> String:
    if is_instance_valid(target_node) and target_node.has_meta("enemy_ai_faction"):
        return str(target_node.get_meta("enemy_ai_faction"))
    return "Unknown"

func _push_debug_status(event_text: String):
    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        debug_main.update_status(AISpawner.activeAgents, {
            "last_event": event_text,
            "current_target": targetLabel
        })

func _debug_log(message: String):
    pass

func _debug_log_ai_audio(key: String, message: String):
    var now = float(Time.get_ticks_msec()) / 1000.0
    var next_allowed = 0.0
    if aiAudioLogCooldowns.has(key):
        next_allowed = float(aiAudioLogCooldowns[key])

    if now < next_allowed:
        return

    aiAudioLogCooldowns[key] = now + AI_AUDIO_LOG_COOLDOWN
    _debug_log(message)

func _shot_damage() -> float:
    var damage = weaponData.damage
    if boss:
        damage *= 2.0
    return damage

func _apply_damage_to_hitbox(hitbox: Hitbox, damage: float):
    var hitOwner = hitbox.owner
    var ownerLabel = "Unknown"
    if is_instance_valid(hitOwner):
        if hitOwner.has_meta("enemy_ai_faction"):
            ownerLabel = str(hitOwner.get_meta("enemy_ai_faction"))
        else:
            ownerLabel = hitOwner.name
    _debug_log("Shot landed on Hitbox type=%s owner=%s damage=%.1f target=%s" % [str(hitbox.type), ownerLabel, damage, targetLabel])
    hitbox.ApplyDamage(damage)
    var debug_main = get_node_or_null("/root/EnemyAIMain")
    if debug_main:
        debug_main.record_hit(str(hitbox.type), false)

func _try_apply_targeted_hitbox_damage(hitCollider) -> bool:
    var space_state = get_world_3d().direct_space_state
    var shot_origin = muzzle.global_position
    var preferred_targets = _get_preferred_hit_targets(hitCollider)
    var fallbackHitbox: Hitbox = null

    for preferred_target in preferred_targets:
        var query = PhysicsRayQueryParameters3D.create(shot_origin, preferred_target)
        query.exclude = [self, hitCollider]
        var result = space_state.intersect_ray(query)

        if result.is_empty():
            continue

        var secondaryCollider = result["collider"]
        if secondaryCollider is Hitbox:
            if str(secondaryCollider.type) == "Torso":
                _apply_damage_to_hitbox(secondaryCollider, _shot_damage())
                return true
            if fallbackHitbox == null:
                fallbackHitbox = secondaryCollider

    if fallbackHitbox != null:
        _apply_damage_to_hitbox(fallbackHitbox, _shot_damage())
        return true

    return false

func _get_preferred_hit_targets(hitCollider) -> Array:
    var targets: Array = []

    if is_instance_valid(hitCollider) and hitCollider == currentAITarget:
        var directTorso = _get_ai_torso_position(hitCollider)
        if directTorso != Vector3.ZERO:
            targets.append(directTorso)
        else:
            targets.append(_get_ai_target_position(hitCollider))

    if is_instance_valid(currentAITarget):
        var torso = _get_ai_torso_position(currentAITarget)
        if torso != Vector3.ZERO:
            targets.append(torso)

        var head = currentAITarget.get("head")
        if head is Node3D:
            targets.append(head.global_position + Vector3(0, -0.4, 0))

        var eyesNode = currentAITarget.get("eyes")
        if eyesNode is Node3D:
            targets.append(eyesNode.global_position + Vector3(0, -0.8, 0))

    targets.append(_get_fire_target_position())
    return targets

# Squad communication
func receive_squad_message(message: Dictionary):
    var msg_type = message.get("type", "")
    var position = message.get("position", Vector3.ZERO)
    var sender = message.get("sender")

    match msg_type:
        "threat_spotted":
            # If not already engaged, move towards threat
            if currentState in [State.Wander, State.Guard, State.Patrol] and !_has_valid_ai_target():
                lastKnownLocation = position
                Decision()
        "need_cover":
            # If leader, assign cover position
            if is_squad_leader:
                _assign_cover_position(sender)
        "rally":
            # Move to rally point
            if currentState != State.Combat:
                ChangeState("Rally")
                rally_target = position
        "flank_target":
            # Attempt flanking maneuver
            if is_squad_leader or randf() < 0.5:
                _attempt_flank(position)

var rally_target = Vector3.ZERO

func _assign_cover_position(ally):
    # Simple cover assignment - move to position behind ally
    if is_instance_valid(ally):
        var cover_pos = ally.global_position + (global_position - ally.global_position).normalized() * 5.0
        MoveToPoint(cover_pos)
        ChangeState("CoverAlly")

func _attempt_flank(target_pos: Vector3):
    # Calculate flank position
    var flank_dir = (target_pos - global_position).rotated(Vector3.UP, PI/2).normalized()
    var flank_pos = target_pos + flank_dir * 10.0
    MoveToPoint(flank_pos)
    ChangeState("Flank")
