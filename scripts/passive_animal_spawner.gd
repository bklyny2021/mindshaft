class_name PassiveAnimalSpawner
extends Node3D

## Spawns one species of passive animal around world spawn on ready, spaced
## apart so they don't cluster into one spot.

@export var world_path: NodePath
@export var animal_scene: PackedScene
@export var spawn_count: int = 2
@export var spawn_min_radius: int = 10
@export var spawn_max_radius: int = 28
@export var min_spacing: float = 6.0  # min blocks between animals of this species

var _world: Node
var _spawned_positions: Array[Vector3] = []


func _ready() -> void:
	if world_path != NodePath(""):
		_world = get_node_or_null(world_path)
	if _world == null or animal_scene == null:
		return
	for index: int in spawn_count:
		call_deferred("_spawn_one")


func _spawn_one() -> void:
	var spawn: Dictionary = _world.find_safe_animal_spawn(spawn_min_radius, spawn_max_radius)
	if spawn.is_empty():
		return
	var pos: Vector3 = spawn["position"] as Vector3
	# Keep animals apart so they don't pile in one spot.
	for i: int in 8:
		if _is_far_enough(pos):
			break
		spawn = _world.find_safe_animal_spawn(spawn_min_radius, spawn_max_radius)
		if spawn.is_empty():
			return
		pos = spawn["position"] as Vector3
	if not _is_far_enough(pos):
		return  # couldn't find a clear spot; skip rather than cluster
	_spawned_positions.append(pos)
	var animal: Node3D = animal_scene.instantiate()
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(animal)
	animal.global_position = pos


func _is_far_enough(pos: Vector3) -> bool:
	for p: Vector3 in _spawned_positions:
		if p.distance_to(pos) < min_spacing:
			return false
	return true
