class_name HostileMobSpawner
extends Node3D

## Spawns hostile mobs around the player as they explore, spaced apart so they
## don't cluster. Mobs chase the player and attack on contact.

@export var world_path: NodePath
@export var mob_scene: PackedScene = preload("res://scenes/hostile_mob.tscn")
@export var spawn_count: int = 3
@export var spawn_min_radius: int = 8
@export var spawn_max_radius: int = 16
@export var min_spacing: float = 8.0

var _world: Node
var _spawned_positions: Array[Vector3] = []
var _spawned_mobs: Array[Node3D] = []


func _ready() -> void:
	if world_path != NodePath(""):
		_world = get_node_or_null(world_path)
	if _world == null or mob_scene == null:
		return
	# Check the day/night cycle every second: spawn mobs at night, despawn at day.
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_cycle_tick)
	add_child(timer)


func _on_cycle_tick() -> void:
	var dnc: Node = get_tree().get_first_node_in_group("day_night_cycle")
	var is_night: bool = dnc != null and dnc.has_method("is_night") and dnc.is_night()
	if is_night:
		# Spawn up to the target count at night.
		while _spawned_mobs.size() < spawn_count:
			_spawn_one()
	else:
		# Day: despawn all mobs.
		_despawn_all()


func _spawn_one() -> void:
	var spawn: Dictionary = _world.find_safe_animal_spawn(spawn_min_radius, spawn_max_radius)
	if spawn.is_empty():
		return
	var pos: Vector3 = spawn["position"] as Vector3
	for i: int in 8:
		if _is_far_enough(pos):
			break
		spawn = _world.find_safe_animal_spawn(spawn_min_radius, spawn_max_radius)
		if spawn.is_empty():
			return
		pos = spawn["position"] as Vector3
	if not _is_far_enough(pos):
		return
	_spawned_positions.append(pos)
	var mob: Node3D = mob_scene.instantiate()
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(mob)
	# Safety: never let a mob spawn inside a solid block. If the chosen spot is
	# buried, lift it to the surface so it's actually visible.
	if _world.has_method("get_surface_y"):
		var feet: Vector3i = Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))
		if _world.has_method("has_block") and _world.has_block(feet):
			var surface_y: int = _world.get_surface_y(feet.x, feet.z)
			pos.y = float(surface_y) + 1.0
	mob.global_position = pos
	_spawned_mobs.append(mob)


func _despawn_all() -> void:
	for mob: Node3D in _spawned_mobs:
		if mob != null and is_instance_valid(mob):
			mob.queue_free()
	_spawned_mobs.clear()
	_spawned_positions.clear()


func _is_far_enough(pos: Vector3) -> bool:
	for p: Vector3 in _spawned_positions:
		if p.distance_to(pos) < min_spacing:
			return false
	return true
