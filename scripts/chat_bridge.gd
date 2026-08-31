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
	# Fully integrate Bob: auto-launch his LLM brain server (windowless) if it
	# isn't already running, and auto-kill it when the game closes.
	_ensure_bob_server()
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
	# Show the chat window and schedule it to fade out after a few seconds.
	_show_chat_then_fade()


## Public: let Bob speak proactively (e.g. when under attack or stuck).
func post_bob_message(text: String) -> void:
	_add_log("Bob: " + text)


## Show the chat log, then fade it out after a few seconds so it doesn't stay
## on screen forever. A new message re-shows it.
func _show_chat_then_fade() -> void:
	log_holder.modulate.a = 1.0
	log_holder.visible = true
	# Kill any existing fade tween so a new message keeps it visible.
	if log_holder.has_meta("fade_tween"):
		var old: Tween = log_holder.get_meta("fade_tween")
		if old != null and old.is_valid():
			old.kill()
	var tween: Tween = create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(log_holder, "modulate:a", 0.0, 1.5)
	log_holder.set_meta("fade_tween", tween)

# ---- command parsing ----
func _process_command(msg: String) -> void:
	var lower := msg.to_lower()
	var resp := ""

	# Commands Bob understands locally (fast, no LLM needed).
	if lower.contains("follow"):
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
	elif lower.contains("bob"):
		# Free-form chat: only reply when the player says Bob's name.
		_ask_bob_llm(msg)
		return
	else:
		# Not addressed to Bob — stay quiet.
		return

	_add_log(resp)


## Ask Bob's LLM brain (bob_server.py /chat) for a free-form reply, passing his
## current state AND a screenshot of what his camera sees, so he can talk about
## the actual game in front of him.
func _ask_bob_llm(msg: String) -> void:
	var state: String = "unknown"
	var screenshot_b64: String = ""
	var bots: Array = get_tree().get_nodes_in_group("help_bot")
	if not bots.is_empty():
		var bot: Node = bots[0]
		if bot.has_method("get_state_string"):
			state = bot.get_state_string()
		# Capture Bob's real view and send it as base64 so the vision LLM sees it.
		if bot.has_method("capture_view"):
			var shot_path: String = "user://bob_chat_view.png"
			var ok: bool = await bot.capture_view(shot_path)
			if ok:
				var f := FileAccess.open(shot_path, FileAccess.READ)
				if f != null:
					screenshot_b64 = Marshalls.raw_to_base64(f.get_buffer(f.get_length()))
					f.close()
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 30.0
	var body := JSON.stringify({"message": msg, "state": state, "screenshot": screenshot_b64})
	var err := http.request(
		"http://127.0.0.1:8642/chat",
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		http.queue_free()
		_add_log("Bob: (can't reach my brain) I'm still here though!")
		return
	http.request_completed.connect(func(_r, _c, _h, b) -> void:
		var parsed = JSON.parse_string(b.get_string_from_utf8())
		if parsed is Dictionary and parsed.has("reply"):
			_add_log(parsed["reply"])
		else:
			_add_log("Bob: ...")
		http.queue_free()
	)


## Auto-launch Bob's LLM brain server (bob_server.py) windowless if it isn't
## already running, so Bob is always available without starting it manually.
func _ensure_bob_server() -> void:
	# If the server is already up, nothing to do.
	var probe := HTTPRequest.new()
	add_child(probe)
	probe.timeout = 2.0
	var err := probe.request("http://127.0.0.1:8642/")
	if err == OK:
		probe.request_completed.connect(func(_r, _c, _h, _b) -> void:
			probe.queue_free()
		)
		return
	# Not running — launch it windowless (pythonw, no console window).
	var script_path := ProjectSettings.globalize_path("res://bob_server.py")
	var cmd := "pythonw \"" + script_path + "\""
	OS.create_process("cmd.exe", ["/c", "start", "", "/b", cmd])
	probe.queue_free()
