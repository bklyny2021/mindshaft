extends Node

## Simple sound manager: plays one-shot sound effects from assets/audio/.
## Autoloaded as "SoundManager" so any script can call SoundManager.play("hurt").
## Also plays looping background music.

var _streams: Dictionary = {}
var _music_player: AudioStreamPlayer


func _ready() -> void:
	# Preload the sounds we have.
	_load("hurt", "res://assets/audio/hurt.ogg")
	_load("block_break", "res://assets/audio/block_break.ogg")
	_load("water_splash", "res://assets/audio/water_splash.ogg")
	# Start the looping background music.
	_start_music("res://assets/audio/ambient_heavenly_loop.ogg")


func _load(key: String, path: String) -> void:
	if ResourceLoader.exists(path):
		_streams[key] = load(path)


## Play a one-shot sound by key (e.g. "hurt", "block_break", "water_splash").
func play(key: String, volume_db: float = 0.0) -> void:
	if not _streams.has(key):
		return
	var player := AudioStreamPlayer.new()
	player.stream = _streams[key]
	player.volume_db = volume_db
	add_child(player)
	player.play()
	# Free the player when the sound finishes.
	player.finished.connect(player.queue_free)


## Start looping background music (quiet so it doesn't overpower effects).
func _start_music(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load(path)
	_music_player.volume_db = -14.0
	_music_player.autoplay = true
	_music_player.finished.connect(_restart_music)
	add_child(_music_player)


func _restart_music() -> void:
	if _music_player != null:
		_music_player.play()
