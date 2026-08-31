class_name SaveManager
extends Node

## MindShaft save system. Persists the world state to a JSON file so the
## player can quit and come back to the same world.
##
## Saves: block edits (everything the player mined/placed), the world seed,
## player position, and player health. The world terrain is deterministic
## from its seed, so we only need to store the EDITS, not the whole world —
## this keeps the save small and fast.

const SAVE_PATH := "user://mindshaft_save.json"
const AUTOSAVE_INTERVAL := 15.0   # seconds between autosaves

var _autosave_timer := 0.0

func _ready() -> void:
	add_to_group("save_manager")
	# Load the persisted world shortly after the scene starts (once the world
	# has streamed its initial chunks in).
	_autosave_timer = 0.0
	call_deferred("_deferred_load")

func _deferred_load() -> void:
	var world: Node = _get_world()
	if world == null:
		# World not ready yet; retry next frame.
		call_deferred("_deferred_load")
		return
	load_game()

## The scene nodes we read/write. Resolved lazily from groups.
func _get_world() -> Node:
	return get_tree().get_first_node_in_group("world")

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _process(delta: float) -> void:
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save_game()


func save_game() -> void:
	var world: Node = _get_world()
	var player: Node = _get_player()
	if world == null:
		return

	var data := {}
	if world.has_method("get_world_seed"):
		data["seed"] = world.get_world_seed()
	if world.has_method("get_block_snapshot"):
		data["edits"] = world.get_block_snapshot()
	if player != null and player.has_method("get_position"):
		var p: Vector3 = player.global_position
		data["player_pos"] = {"x": p.x, "y": p.y, "z": p.z}
	if player != null and player.has_method("get_health"):
		data["player_health"] = player.get_health()

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: could not open save file: " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	var world: Node = _get_world()
	if not has_save() or world == null:
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed

	# Restore block edits so the player's changes persist.
	if world.has_method("apply_block_snapshot") and data.has("edits"):
		world.apply_block_snapshot(data["edits"])

	# Restore player position and health.
	var player: Node = _get_player()
	if player != null:
		if data.has("player_pos"):
			var pp: Dictionary = data["player_pos"]
			player.global_position = Vector3(
				float(pp.get("x", 0.0)),
				float(pp.get("y", 64.0)),
				float(pp.get("z", 0.0))
			)
		if data.has("player_health") and player.has_method("set_health"):
			player.set_health(int(data["player_health"]))
	return true
