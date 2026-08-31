class_name VillagerSpawner
extends Node3D

## Spawns villagers around the player on ready, on safe terrain, reusing the
## world's safe-spawn finder (same as the animal spawners).

@export var world_path: NodePath
@export var villager_scene: PackedScene
@export var spawn_count: int = 3
@export var spawn_min_radius: int = 6
@export var spawn_max_radius: int = 16

var _world: Node

func _ready() -> void:
	if world_path != NodePath(""):
		_world = get_node_or_null(world_path)
	if _world == null or villager_scene == null:
		return
	for index: int in spawn_count:
		call_deferred("_spawn_one")

func _spawn_one() -> void:
	if _world == null or not _world.has_method("find_safe_animal_spawn"):
		return
	var spawn: Dictionary = _world.find_safe_animal_spawn(spawn_min_radius, spawn_max_radius)
	if spawn.is_empty():
		return
	var v: Node3D = villager_scene.instantiate()
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(v)
	v.global_position = spawn["position"] as Vector3
