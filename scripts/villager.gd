class_name Villager
extends CharacterBody3D

## A Minecraft-style villager NPC. Wanders idly like the passive animals, has
## a blocky body (robe + skin + robe-colored head), and can say a line through
## the chat bridge when you talk to it. Reuses the game's wander pattern.

const GRAVITY: float = 25.0
const WALK_SPEED: float = 0.7
const WANDER_MIN_SEC: float = 3.0
const WANDER_MAX_SEC: float = 7.0

var _wander_dir: Vector3 = Vector3.ZERO
var _wander_time_left: float = 0.0
var _world: Node
var _player: Node3D
var _walk_phase: float = 0.0

# Home / job behavior
var home_pos: Vector3 = Vector3.ZERO      # where inside the house
var door_pos: Vector3 = Vector3.ZERO      # the door block to lock at night
var _at_home: bool = false
var job: String = "farmer"

@onready var _model: Node3D = $Model
@onready var _front_left_leg: MeshInstance3D = $Model/FrontLeftLeg
@onready var _front_right_leg: MeshInstance3D = $Model/FrontRightLeg
@onready var _back_left_leg: MeshInstance3D = $Model/BackLeftLeg
@onready var _back_right_leg: MeshInstance3D = $Model/BackRightLeg

const VILLAGER_LINES: Array[String] = [
	"Villager: Hrm... good day to you!",
	"Villager: Would you trade? I've got some fine goods.",
	"Villager: Mind the mobs at night, traveler.",
	"Villager: Hohoho! Welcome to the village.",
]

func _ready() -> void:
	add_to_group("villager")
	collision_layer = 1
	collision_mask = 1
	_world = get_tree().get_first_node_in_group("world")
	_player = get_tree().get_first_node_in_group("player")
	_pick_new_wander_dir()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	var dnc: Node = get_tree().get_first_node_in_group("day_night_cycle")
	var is_night: bool = dnc != null and dnc.has_method("is_night") and dnc.is_night()

	_wander_time_left -= delta
	if _wander_time_left <= 0.0:
		_pick_new_wander_dir()

	var move_dir: Vector3 = _wander_dir
	if is_night:
		# Night: head home, then lock the door behind us.
		var home_dir: Vector3 = home_pos - global_position
		home_dir.y = 0.0
		if home_dir.length() > 1.0:
			move_dir = home_dir.normalized()
		else:
			# Arrived home — lock the door (place a block over the gap).
			if not _at_home and _world != null:
				_at_home = true
				if not _world.has_block(door_pos):
					_world.add_block(door_pos, "wood")
	velocity.x = move_dir.x * WALK_SPEED
	velocity.z = move_dir.z * WALK_SPEED
	if move_dir.length() > 0.01:
		look_at(global_position + move_dir, Vector3.UP)
	move_and_slide()

	# leg animation
	var moving: bool = Vector2(velocity.x, velocity.z).length() > 0.1 and is_on_floor()
	if moving:
		_walk_phase += delta * 5.0
		var swing: float = sin(_walk_phase) * 0.35
		_front_left_leg.rotation.x = swing
		_back_right_leg.rotation.x = swing
		_front_right_leg.rotation.x = -swing
		_back_left_leg.rotation.x = -swing

func _pick_new_wander_dir() -> void:
	_wander_time_left = randf_range(WANDER_MIN_SEC, WANDER_MAX_SEC)
	var angle: float = randf_range(0.0, TAU)
	if randf() < 0.35:
		_wander_dir = Vector3.ZERO
	else:
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle))

## Say a random line through the chat bridge (used when the player talks at you).
func greet() -> void:
	var bridges: Array = get_tree().get_nodes_in_group("chat_bridge")
	if bridges.is_empty():
		return
	var bridge: Node = bridges[0]
	if bridge.has_method("_add_log"):
		bridge._add_log(VILLAGER_LINES[randi() % VILLAGER_LINES.size()])
