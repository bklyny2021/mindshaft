class_name Village
extends Node3D

## Builds a small Minecraft-style village on load: a few villagers, each with a
## little cobble+wood house as their home. Reuses the world's add_block so the
## houses are real, durable blocks (persisted via _edits).

@export var world_path: NodePath
@export var villager_scene: PackedScene
@export var villagers_to_spawn: int = 3
@export var spawn_center: Vector3i = Vector3i(6, 0, 6)

var _world: Node


func _ready() -> void:
	if world_path != NodePath(""):
		_world = get_node_or_null(world_path)
	if _world == null or villager_scene == null:
		return
	call_deferred("_build_village")


func _build_village() -> void:
	# Lay out 3 houses in a small row, each ~5 blocks apart.
	var offsets: Array = [0, 5, -5]
	for i: int in villagers_to_spawn:
		var hx: int = spawn_center.x + offsets[i % offsets.size()]
		var hz: int = spawn_center.z
		var ground_y: int = _world.get_surface_y(hx, hz)
		_build_house(hx, ground_y, hz)
		_spawn_villager(hx, ground_y, hz)


func _build_house(hx: int, gy: int, hz: int) -> void:
	# A 4x3x4 cobble box with a wood roof and leaves trim, front door gap.
	for x: int in range(4):
		for z: int in range(4):
			var is_wall: bool = (x == 0 or x == 3 or z == 0 or z == 3)
			for y: int in range(3):
				if is_wall:
					var front_door: bool = (x == 1 or x == 2) and z == 3 and y == 0
					_add_block(Vector3i(hx + x, gy + y, hz + z), "grass" if y == 2 else "cobble", front_door)
	# wood roof
	for x: int in range(4):
		for z: int in range(4):
			_add_block(Vector3i(hx + x, gy + 3, hz + z), "wood", false)
	# leaves trim on top corners
	_add_block(Vector3i(hx + 4, gy + 3, hz + 1), "leaves", false)


func _add_block(pos: Vector3i, type: String, skip: bool) -> void:
	if skip or _world == null:
		return
	if not _world.has_block(pos):
		_world.add_block(pos, type)


func _spawn_villager(hx: int, gy: int, hz: int) -> void:
	var v: Node3D = villager_scene.instantiate()
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	parent.add_child(v)
	# Spawn just in front of the house door.
	v.global_position = Vector3(hx + 1.5, float(gy) + 1.0, float(hz + 2))
	# Give the villager its home (inside the house) and its door (to lock at night).
	if "home_pos" in v:
		v.home_pos = Vector3(hx + 2.0, float(gy) + 1.0, float(hz + 2))
	if "door_pos" in v:
		v.door_pos = Vector3i(hx + 1, gy, hz + 3)
	# Assign a job so they each have a role (wander their home area by day).
	const JOBS: Array[String] = ["farmer", "lumberjack", "fisher"]
	if "job" in v:
		v.job = JOBS[_villager_index % JOBS.size()]
	_villager_index += 1

var _villager_index: int = 0
