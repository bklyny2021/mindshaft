class_name CowSpawner
extends Node3D

## Spawns a small herd of wandering cows around world spawn on ready.

@export var world_path: NodePath
@export var cow_scene: PackedScene = preload("res://scenes/cow.tscn")
@export var spawn_count: int = 3
@export var spawn_min_radius: int = 10
@export var spawn_max_radius: int = 20

var _world: Node


func _ready() -> void:
	if world_path != NodePath(""):
		_world = get_node_or_null(world_path)
	if _world == null or cow_scene == null:
		return
	for index: int in spawn_count:
		call_deferred("_spawn_one")


func _spawn_one() -> void:
	var spawn: Dictionary = _world.find_safe_animal_spawn(spawn_min_radius, spawn_max_radius)
	if spawn.is_empty():
		return
	var cow: Node3D = cow_scene.instantiate()
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(cow)
	cow.global_position = spawn["position"] as Vector3
