class_name ChatBridge
extends CanvasLayer

## In-game chat + command bridge for Bob (MindShaft 0.2.2).
##
## Enter = open the input, type a message, Enter = send.
## Bob parses simple commands: "follow", "stay", "come", "mine that",
## "mine <x> <z>", "hello" ... and replies in the chat with a friendly
## tone. This is the local layer; hooking up a real Hermes relay later
## replaces the scripted responses with a live conversation.

const BOOT_MSGS: Array[String] = [
	"Bob: Hi Boo! I'm here to help you dig. :)",
	"Bob: Try: 'follow', 'stay', 'mine that', or 'hello'.",
]

@onready var log_holder: VBoxContainer = null
@onready var input: LineEdit = null
@onready var dim: ColorRect = null

var _open := false

# Bob command targets (consumed by help_bot.gd)
var bob_command := "follow"
var bob_target: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("chat_bridge")
	# Build the chat UI in code (kept simple, no extra scene file).
	# Backdrop dim + top-left log + bottom input.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE so the overlay never swallows mouse-look or clicks from the player.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	log_holder = VBoxContainer.new()
	log_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	log_holder.offset_left = 16
	log_holder.offset_top = 16
	log_holder.offset_right = -300
	log_holder.offset_bottom = 160
	log_holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	# CRITICAL: never swallow mouse input — otherwise it blocks mining clicks.
	log_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(log_holder)

	for msg: String in BOOT_MSGS:
		_add_log(msg)

	input = LineEdit.new()
	input.placeholder_text = "Chat with Bob... (Enter to send, Esc to close)"
	input.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	input.offset_left = 16
	input.offset_right = -16
	input.offset_top = -56
	input.offset_bottom = -16
	input.visible = false
	input.text_submitted.connect(_on_submit)
	input.visibility_changed.connect(_on_input_visibility)
	root.add_child(input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not _open:
		_open = true
		dim.color = Color(0, 0, 0, 0.25)
		input.visible = true
		input.grab_focus()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _open:
		_close()

func _on_input_visibility() -> void:
	if not input.visible:
		_close()

func _on_submit(text_t: String) -> void:
	var trimmed := text_t.strip_edges()
	_add_log("You: " + trimmed)
	_process_command(trimmed)
	input.clear()
	_close()
	# release mouse so controls resume
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _close() -> void:
	_open = false
	dim.color = Color(0, 0, 0, 0.0)
	input.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _add_log(line: String) -> void:
	var label := Label.new()
	label.text = line
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	log_holder.add_child(label)
	# Trim old lines
	while log_holder.get_child_count() > 30:
		var first: Node = log_holder.get_child(0)
		log_holder.remove_child(first)
		first.queue_free()

# ---- command parsing ----
func _process_command(msg: String) -> void:
	var lower := msg.to_lower()
	var resp := ""

	if lower.contains("hello") or lower.contains("hi ") or lower == "hi" or lower.contains("hey"):
		resp = "Bob: Hey Boo! Ready to dig with you. :)"
	elif lower.contains("follow"):
		bob_command = "follow"
		resp = "Bob: On your heels, Boss!"
	elif lower.contains("guard"):
		bob_command = "guard"
		resp = "Bob: Guarding you — patrolling your perimeter."
	elif lower.contains("stay") or lower.contains("stop") or lower.contains("wait"):
		bob_command = "stay"
		resp = "Bob: Standing by right here."
	elif lower.contains("come") or lower.contains("come here"):
		bob_command = "follow"
		resp = "Bob: Coming!"
	elif lower.contains("mine that") or lower.contains("dig that"):
		bob_command = "mine"
		resp = "Bob: I'll help you break it. Hold it in your crosshair & I'll swing alongside."
	elif lower.contains("mine") or lower.contains("dig") or lower.contains("go to"):
		resp = "Bob: Point at a block and I'll mine it with you. Or tell me a spot."
	elif lower.contains("help"):
		resp = "Bob: I follow your footsteps, help mine, and hang out. Try 'follow', 'guard', 'stay', 'mine that'."
	elif lower.contains("sword") or lower.contains("fight") or lower.contains("zombie") or lower.contains("monster"):
		resp = "Bob: I'm a mining buddy, not a fighter yet. If monsters show up I'll keep close to you."
	elif lower.contains("thank"):
		resp = "Bob: Anytime! That's what I'm here for."
	elif lower.contains("who are you"):
		resp = "Bob: I'm Bob — your MindShaft mining companion."
	else:
		resp = "Bob: Hmm, I didn't catch that. Try 'follow', 'stay', 'mine that', 'hello'."

	_add_log(resp)
