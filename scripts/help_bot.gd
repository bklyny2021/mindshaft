class_name HelpBot
extends CharacterBody3D

## Bob — MindShaft's helper bot. Follows the player and helps mine the
## block you're aiming at, like the browser game's companion.
## Built on the Godotcraft-style entity pattern (CharacterBody3D + world API).

const GRAVITY: float = 25.0
const MOVE_ACCEL: float = 12.0       # snappier so Bob actually keeps up
const FOLLOW_MIN_DIST: float = 2.0
const FOLLOW_MAX_DIST: float = 3.0
const MINE_REACH: float = 4.5
const MINE_INTERVAL: float = 0.6   # seconds between mine swings
const JUMP_VELOCITY: float = 7.0   # to hop a 1-block ledge
const MAX_HEALTH: int = 10
const FALL_SAFE: float = 3.0       # blocks of fall before taking damage
const FALL_DMG_SCALE: float = 2.0  # damage per extra block
# Sentinel: "no mining target" — matches player.get_mine_target() when idle.
const NO_TARGET: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)

var _world: Node
var _player: Node3D
var _bridge: Node
var _mine_timer: float = 0.0
var _walk_phase: float = 0.0
var _stuck_time: float = 0.0
var _health: int = MAX_HEALTH
var _fall_start_y: float = 0.0
var _was_airborne: bool = false
var _dead: bool = false

# Footstep trail: Bob retraces where the player walked instead of cutting
# straight across, so he follows your actual path and can't overtake you.
var _foot_steps: Array[Vector3] = []
const FOR_INF: float = INF  # no Vector3.INF constant in GDScript
var _last_record_pos: Vector3 = Vector3(FOR_INF, FOR_INF, FOR_INF)
const FOOT_RECORD_GAP: float = 0.8   # record a step every ~0.8 blocks apart
const FOOT_KEEP: int = 40            # keep the last 40 footsteps

@onready var _model: Node3D = $Model
@onready var _front_left_leg: MeshInstance3D = $Model/FrontLeftLeg
@onready var _front_right_leg: MeshInstance3D = $Model/FrontRightLeg
@onready var _back_left_leg: MeshInstance3D = $Model/BackLeftLeg
@onready var _back_right_leg: MeshInstance3D = $Model/BackRightLeg
@onready var _arm: MeshInstance3D = $Model/MiningArm

func _ready() -> void:
	add_to_group("help_bot")
	collision_layer = 1
	collision_mask = 1
	_world = get_tree().get_first_node_in_group("world")
	_player = get_tree().get_first_node_in_group("player")
	_bridge = get_tree().get_first_node_in_group("chat_bridge")
	_health = MAX_HEALTH
	_fall_start_y = global_position.y
	# Spawn next to the player on the surface, not at the world origin (which
	# is underground and would leave Bob hidden).
	if _player != null and is_instance_valid(_player):
		global_position = _player.global_position + Vector3(2.0, 0.0, 0.0)
		# If that's inside solid ground for some reason, nudge up so gravity settles him.
		global_position.y += 2.0
		_fall_start_y = global_position.y

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return

	if _world == null or not is_instance_valid(_world):
		_world = get_tree().get_first_node_in_group("world")

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Record the player's footsteps so Bob can retrace your exact path.
	var player_feet: Vector3 = _player.global_position
	player_feet.y = 0.0
	if _last_record_pos.x > 1.0e18 or player_feet.distance_to(_last_record_pos) >= FOOT_RECORD_GAP:
		_last_record_pos = player_feet
		_foot_steps.push_back(player_feet)
		if _foot_steps.size() > FOOT_KEEP:
			_foot_steps.pop_front()

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()

	var move_dir: Vector3 = Vector3.ZERO
	_mining_arm_swing(delta)

	# Current command from the chat bridge ("follow" / "stay" / "mine")
	var command: String = ""
	if _bridge != null and "bob_command" in _bridge:
		command = _bridge.bob_command

	if command == "stay":
		# Hold position; do nothing (gravity still applies above).
		move_dir = Vector3.ZERO
	elif command == "guard":
		# Patrol: orbit the player in a ring ~2.5 blocks out, so Bob circles you.
		move_dir = _guard_patrol_dir()
	else:
		# Mine the player's target if commanded (or follow keeps helping).
		var mine_target := _get_player_mine_target()
		var should_mine: bool = (command == "mine") or (mine_target != NO_TARGET and _world != null)
		if should_mine and mine_target != NO_TARGET and _world != null:
			var target_pos: Vector3 = Vector3(mine_target.x + 0.5, mine_target.y + 0.5, mine_target.z + 0.5)
			var to_target: Vector3 = target_pos - global_position
			to_target.y = 0.0
			var t_dist: float = to_target.length()
			if t_dist > 1.5:
				move_dir = to_target / maxf(t_dist, 0.001)
			else:
				# In range — mine it
				_mine_timer -= delta
				if _mine_timer <= 0.0:
					_mine_timer = MINE_INTERVAL
					_try_mine_block(mine_target)
		elif command != "mine":
			# Follow ALONG the player's footprint trail so Bob retraces your
			# actual steps, stays behind you, and never cuts across/passes you.
			if dist > FOLLOW_MAX_DIST:
				# Head toward the nearest recorded footprint that lies behind Bob.
				move_dir = _dir_to_trail_step()
				if move_dir == Vector3.ZERO:
					move_dir = to_player / maxf(dist, 0.001)
			elif dist < FOLLOW_MIN_DIST:
				move_dir = -to_player / maxf(dist, 0.001) * 0.5  # gentle back-off

	# Match the PLAYER's current horizontal speed so Bob keeps up whether you
	# walk or sprint — he copies your pace instead of using a fixed constant.
	var player_speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
	if player_speed < 0.5:
		player_speed = 4.5   # player idle/walking baseline; keeps Bob gently moving
	var target_vel: Vector3 = move_dir * (player_speed if move_dir != Vector3.ZERO else 0.0)
	velocity.x = lerp(velocity.x, target_vel.x, clamp(MOVE_ACCEL * delta, 0.0, 1.0))
	velocity.z = lerp(velocity.z, target_vel.z, clamp(MOVE_ACCEL * delta, 0.0, 1.0))

	# --- Stuck detection: wants to move but isn't getting anywhere. ---
	var wants_to_move: bool = move_dir.length() > 0.1
	var actually_moving: bool = Vector2(velocity.x, velocity.z).length() > 0.3
	if wants_to_move and not actually_moving and is_on_floor():
		_stuck_time += delta
		if _stuck_time > 2.0 and _stuck_time - delta <= 2.0:
			# Just crossed the threshold — tell the player once.
			if _bridge != null and _bridge.has_method("post_bob_message"):
				_bridge.post_bob_message("I'm stuck! Can you help me? (coords %.1f, %.1f, %.1f)" % [global_position.x, global_position.y, global_position.z])
	else:
		_stuck_time = 0.0

	# --- Jump to clear a wall/block (and clear 1-high ledges) ---
	if is_on_wall() and is_on_floor() and velocity.length() > 0.5:
		velocity.y = JUMP_VELOCITY

	# --- Cliff avoidance: if there's no ground just ahead, don't walk off
	#     (Bob knows he can fall and take damage). ---
	if is_on_floor() and move_dir.length() > 0.1 and _world != null:
		if not _ground_ahead(global_position, 1.4, 3.0):
			# Ground is missing just ahead — steer sideways instead of falling.
			move_dir = Vector3(move_dir.z, 0.0, -move_dir.x)

	# --- Obstacle avoidance: steer around walls/blocks in the way. ---
	if is_on_floor() and move_dir.length() > 0.1 and _obstacle_ahead(1.2):
		# Something solid is in front — turn sideways to go around it.
		move_dir = Vector3(move_dir.z, 0.0, -move_dir.x)

	# --- Fall damage: record start, and damage on landing past a safe height. ---
	if not is_on_floor():
		if not _was_airborne:
			_fall_start_y = global_position.y
		_was_airborne = true
	else:
		if _was_airborne:
			var fell: float = _fall_start_y - global_position.y
			if fell > FALL_SAFE:
				var dmg: int = int(ceil((fell - FALL_SAFE) * FALL_DMG_SCALE))
				take_damage(dmg)
		_was_airborne = false
		_fall_start_y = global_position.y

	# Face movement direction
	if move_dir.length() > 0.1:
		look_at(global_position + move_dir, Vector3.UP)
		_walk_phase += delta * 6.0
	else:
		_walk_phase += delta * 4.0

	move_and_slide()
	_animate_legs()

func _get_player_mine_target() -> Vector3i:
	# The player exposes its current mining target as a Vector3i, or NO_TARGET if none / not reachable
	if _player.has_method("get_mine_target"):
		return _player.get_mine_target()
	return NO_TARGET

## Direction to the trail step Bob should retrace next. Picks the oldest
## footprint ahead of him (walking the path the player laid down), so he
## follows your footsteps from behind and never overtakes you.
func _dir_to_trail_step() -> Vector3:
	if _foot_steps.is_empty():
		return Vector3.ZERO
	var best: Vector3 = Vector3.ZERO
	var best_d: float = INF
	var my_feet: Vector3 = global_position
	my_feet.y = 0.0
	for s in _foot_steps:
		var to_s: Vector3 = s - my_feet
		var d: float = to_s.length()
		# Only head toward footprints that are in FRONT of Bob (> ~1.5 blocks)
		# so he doesn't backtrack to steps he's already passed.
		if d > 1.5 and d < best_d:
			best_d = d
			best = to_s.normalized()
	if best_d >= INF:
		return Vector3.ZERO
	return best

## Guard patrol: orbit the player in a ring `GUARD_RADIUS` blocks out. Bob
## moves tangentially around you so he circles steadily without walking
## through you, holding a perimeter.
const GUARD_RADIUS: float = 2.5
func _guard_patrol_dir() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	var to_p: Vector3 = _player.global_position - global_position
	to_p.y = 0.0
	var d: float = to_p.length()
	if d < 0.001:
		return Vector3.RIGHT
	# Radial direction away/toward the ring + tangential for orbit.
	var radial: Vector3 = to_p / d
	var tangent: Vector3 = Vector3(-radial.z, 0.0, radial.x)  # orbit CCW
	var dir := tangent * 0.7
	if d < GUARD_RADIUS - 0.4:
		dir += radial            # move outward to reach the ring
	elif d > GUARD_RADIUS + 0.4:
		dir -= radial            # move inward to reach the ring
	return dir.normalized() if dir.length() > 0.001 else tangent

func _ground_ahead(pos: Vector3, dist: float, look_down: float) -> bool:
	# True if there is solid ground within `dist` ahead and `look_down` below.
	var space := get_world_3d().direct_space_state
	var origin := pos + Vector3.UP * 0.5
	var from := origin
	var to := origin + Vector3.DOWN * look_down
	from += -global_transform.basis.z * dist    # forward along facing
	to += -global_transform.basis.z * dist
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)  # layer 1 = blocks
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	return not hit.is_empty()


## True if a solid block is directly in front of Bob at chest height (a wall or
## obstacle he can't just walk through). Used to steer around things.
func _obstacle_ahead(dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.0
	var to := from + (-global_transform.basis.z * dist)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	return not hit.is_empty()

func take_damage(amount: int) -> void:
	if _dead:
		return
	_health = maxi(_health - amount, 0)
	# Play the hurt sound (same as the player).
	if has_node("/root/SoundManager"):
		get_node("/root/SoundManager").play("hurt")
	# Tell the player when under attack.
	if _bridge != null and _bridge.has_method("post_bob_message"):
		_bridge.post_bob_message("I'm under attack! Help me! (coords %.1f, %.1f, %.1f)" % [global_position.x, global_position.y, global_position.z])
	if _health <= 0:
		_die()

func _die() -> void:
	if _dead:
		return
	_dead = true
	# Drop a little loot (like a mob) before respawning — reusing the player's
	# ItemDrop pattern so the cubes pick up like normal drops.
	_drop_loot("dirt", 2)
	_drop_loot("wood", 1)
	# Respawn at the player's side with full health (survival loop).
	if _player != null and is_instance_valid(_player):
		global_position = _player.global_position + Vector3(2.0, 0.0, 0.0)
		global_position.y += 2.0
	_health = MAX_HEALTH
	velocity = Vector3.ZERO
	_fall_start_y = global_position.y
	_was_airborne = false
	_dead = false

func _drop_loot(type: String, count: int) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var tex: Texture2D = null
	if _player != null and _player.has_method("get_block_texture"):
		tex = _player.get_block_texture(type)
	for i in count:
		var drop: ItemDrop = ItemDrop.new()
		drop.block_type = type
		drop.block_texture = tex
		parent.add_child(drop)
		drop.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5))

func _try_mine_block(pos: Vector3i) -> void:
	if _world == null or not _world.has_method("get_block_type"):
		return
	var type: String = _world.get_block_type(pos)
	if type.is_empty():
		return
	# Swing arm + remove the block
	_mining_arm_swing(0.3)
	if _world.has_method("remove_block"):
		var removed: String = _world.remove_block(pos)
		# Drop the cube like the player does, so the block is never lost and
		# flies to the PLAYER (item_drop homes to the "player" group).
		if removed != "":
			var drop: ItemDrop = ItemDrop.new()
			drop.block_type = removed
			if _player != null and _player.has_method("get_block_texture"):
				drop.block_texture = _player.get_block_texture(removed)
			var parent: Node = get_parent()
			if parent != null:
				parent.add_child(drop)
				drop.global_position = global_position + Vector3(0.0, 0.6, 0.0)

func _mining_arm_swing(delta: float) -> void:
	# Simple idle mining-arm bob so Bob looks alive
	if _arm != null:
		_arm.rotation.x = sin(Time.get_ticks_msec() * 0.006) * 0.3

func _animate_legs() -> void:
	var amp: float = 0.25 if velocity.length() > 0.5 else 0.02
	var swing: float = sin(_walk_phase) * amp
	_front_left_leg.rotation.x = swing
	_back_right_leg.rotation.x = swing
	_front_right_leg.rotation.x = -swing
	_back_left_leg.rotation.x = -swing


## Human-readable state string for the chat brain: what Bob is doing, his
## coordinates, and whether he's stuck.
func get_state_string() -> String:
	var doing: String = "following the player"
	if _bridge != null and "bob_command" in _bridge:
		match _bridge.bob_command:
			"stay":
				doing = "standing still (stay)"
			"guard":
				doing = "guarding you (patrolling)"
			"mine":
				doing = "mining"
	var stuck: String = "no"
	if _stuck_time > 2.0:
		stuck = "yes"
	return "doing=%s, coords=(%.1f, %.1f, %.1f), stuck=%s" % [doing, global_position.x, global_position.y, global_position.z, stuck]

## Bob's real vision: render what his OWN 90° camera sees to a PNG and return
## the path. Uses a dedicated SubViewport so Bob sees only his own camera's
## view (walls block him, he only sees the direction he faces — no x-ray, and
## NOT the player's screen). This is the feed the vision LLM looks at.
func capture_view(out_path: String) -> bool:
	var cam: Camera3D = get_node_or_null("CameraPivot/Camera3D") as Camera3D
	if cam == null:
		return false
	# Build a dedicated SubViewport that renders ONLY Bob's camera.
	var sub := SubViewport.new()
	sub.size = Vector2i(320, 180)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sub.own_world_3d = false  # share the main world so Bob sees the real scene
	sub.world_3d = get_viewport().world_3d
	# Reparent Bob's camera into the subviewport so it renders his view.
	var cam_parent: Node = cam.get_parent()
	cam_parent.remove_child(cam)
	sub.add_child(cam)
	cam.current = true
	# Render one frame and grab the image.
	await RenderingServer.frame_post_draw
	var image := sub.get_texture().get_image()
	# Put the camera back where it was.
	sub.remove_child(cam)
	cam_parent.add_child(cam)
	cam.current = false
	sub.queue_free()
	if image == null:
		return false
	image.resize(160, 90, Image.INTERPOLATE_LANCZOS)
	var err := image.save_png(out_path)
	return err == OK
