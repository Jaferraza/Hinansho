extends Node
# Autoload "Sfx": one-line sound effects. Sfx.play("hit") plays res://assets/sfx/hit.wav.
# Every Button in the game clicks automatically (hooked via node_added).
# Replace any .wav in assets/sfx with a better one; the name is all that matters.

const DIR := "res://assets/sfx/"
const VOLUME_DB := -6.0
const VOICES := 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)
	get_tree().node_added.connect(_on_node_added)


func play(sound: String, pitch_jitter: float = 0.08) -> void:
	if not _streams.has(sound):
		var path := DIR + sound + ".wav"
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = _streams[sound]
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(play.bind("click"), CONNECT_DEFERRED)
