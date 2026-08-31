class_name HostileMob
extends CharacterBody3D

## A hostile mob (zombie-like) that chases the player, faces them, and attacks
## on contact. Uses the same obstacle-avoidance pattern as Bob so it steers
## around walls instead of walking into them.

const GRAVITY: float = 25.0
const CHASE_SPEED: float = 3.2
const ATTACK_RANGE: float = 1.0
const ATTACK_DAMAGE: int = 2
const ATTACK_COOLDOWN: float = 1.0
const HIT_FLASH_SEC: float = 0.15
const KNOCKBACK_SPEED: float = 3.0
const MAX_HEALTH: int = 10

var _player: Node3D
var _world: Node
var _health: int = MAX_HEALTH
var _attack_cooldown: float = 0.0
var _hit_flash_time: float = 0.0
var _walk_phase: float = 0.0
var _dead: bool = false
var _materials: Array[StandardMaterial3D] = []
var _material_base_colors: Dictionary = {}

@onready var _model: Node3D = $Model
@onready var _left_arm: MeshInstance3D = $Model/LeftArm
@onready var _right_arm: MeshInstance3D = $Model/RightArm
@onready var _left_leg: MeshInstance3D = $Model/LeftLeg
@onready var _right_leg: MeshInstance3D = $Model/RightLeg
@onready var _health_fill: MeshInstance3D = $HealthBar/Fill


func _ready() -> void:
	add_to_group(&"hostile_mob")
	add_to_group(&"mob")
	collision_layer = 1
	collision_mask = 1
	_health = MAX_HEALTH
	_cache_model_materials()
	_update_health_bar()


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# Safety net: keep the mob on the surface. If it's inside a solid block OR
	# below the surface (fell into a hole / the void), teleport it up so it's
	# always visible and can never chase you from under the map.
	if _world == null:
		_world = get_tree().get_first_node_in_group("world")
	if _world != null and _world.has_method("get_surface_y"):
		var feet: Vector3i = Vector3i(floori(global_position.x), floori(global_position.y), floori(global_position.z))
		var surface_y: int = _world.get_surface_y(feet.x, feet.z)
		var buried: bool = _world.has_method("has_block") and _world.has_block(feet)
		if buried or global_position.y < float(surface_y):
			global_position = Vector3(global_position.x, float(surface_y) + 1.0, global_position.z)
			velocity = Vector3.ZERO
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Find the player.
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _player == null:
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()

	var move_dir: Vector3 = Vector3.ZERO
	if dist > ATTACK_RANGE:
		# Chase the player.
		move_dir = to_player / maxf(dist, 0.001)
		# Obstacle avoidance: steer around walls in the way.
		if _obstacle_ahead(1.2):
			move_dir = Vector3(move_dir.z, 0.0, -move_dir.x)
		velocity.x = move_dir.x * CHASE_SPEED
		velocity.z = move_dir.z * CHASE_SPEED
		# Face the player.
		look_at(global_position + move_dir, Vector3.UP)
		_walk_phase += delta * 6.0
	else:
		# In attack range — stop and attack.
		velocity.x = 0.0
		velocity.z = 0.0
		# Face the player (flattened so the up vector is never colinear).
		var face_dir: Vector3 = to_player
		face_dir.y = 0.0
		if face_dir.length() > 0.01:
			look_at(global_position + face_dir, Vector3.UP)
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_attack_cooldown = ATTACK_COOLDOWN
			_attack_player()

	move_and_slide()
	_animate_model(delta)

	if _hit_flash_time > 0.0:
		_hit_flash_time = max(0.0, _hit_flash_time - delta)
		if _hit_flash_time == 0.0:
			_restore_material_colors()


func _attack_player() -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		_player.take_damage(ATTACK_DAMAGE, "a hostile mob")


## True if a solid block is directly in front at chest height (a wall to avoid).
func _obstacle_ahead(dist: float) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.0
	var to := from + (-global_transform.basis.z * dist)
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	return not hit.is_empty()


func take_damage(amount: int = 1) -> void:
	if _dead:
		return
	_health -= amount
	_hit_flash_time = HIT_FLASH_SEC
	_flash_materials()
	_update_health_bar()
	# Knockback away from the player.
	if _player != null and is_instance_valid(_player):
		var away: Vector3 = (global_position - _player.global_position).normalized()
		away.y = 0.0
		velocity.x = away.x * KNOCKBACK_SPEED
		velocity.z = away.z * KNOCKBACK_SPEED
	if _health <= 0:
		_die()


## Scale the health bar fill down as the mob takes damage.
func _update_health_bar() -> void:
	if _health_fill == null:
		return
	var ratio: float = clampf(float(_health) / float(MAX_HEALTH), 0.0, 1.0)
	_health_fill.scale.x = ratio
	# Shift the fill so it shrinks from the right (pivot at left edge).
	_health_fill.position.x = -0.35 + 0.35 * ratio


func _die() -> void:
	if _dead:
		return
	_dead = true
	queue_free()


func _cache_model_materials() -> void:
	# The mob has few parts and doesn't need mesh batching — batching can cause
	# see-through faces (bad normals/winding). Just collect the materials from
	# the existing box meshes so hit-flash works.
	_materials.clear()
	_material_base_colors.clear()
	for part: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		if part.mesh == null:
			continue
		for surface_index: int in part.mesh.get_surface_count():
			var material: Material = part.mesh.surface_get_material(surface_index)
			if material is StandardMaterial3D:
				var sm: StandardMaterial3D = material as StandardMaterial3D
				if not _materials.has(sm):
					_materials.append(sm)
					_material_base_colors[sm] = sm.albedo_color


func _animate_model(delta: float) -> void:
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.1 and is_on_floor()
	var swing: float = 0.0
	if moving:
		swing = sin(_walk_phase) * 0.4
	_left_arm.rotation.x = lerp_angle(_left_arm.rotation.x, swing, min(1.0, delta * 10.0))
	_right_arm.rotation.x = lerp_angle(_right_arm.rotation.x, -swing, min(1.0, delta * 10.0))
	_left_leg.rotation.x = lerp_angle(_left_leg.rotation.x, -swing, min(1.0, delta * 10.0))
	_right_leg.rotation.x = lerp_angle(_right_leg.rotation.x, swing, min(1.0, delta * 10.0))


func _flash_materials() -> void:
	for material: StandardMaterial3D in _materials:
		var base_color: Color = _material_base_colors.get(material, Color.WHITE)
		material.albedo_color = base_color.lerp(Color(1.0, 0.12, 0.1), 0.7)


func _restore_material_colors() -> void:
	for material: StandardMaterial3D in _materials:
		material.albedo_color = _material_base_colors.get(material, Color.WHITE)
