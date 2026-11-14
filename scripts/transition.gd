extends CanvasLayer
# Autoload "Transition" (registered in project.godot).
# Fades to black between scenes: call Transition.change_scene("res://scenes/x.tscn")
# instead of get_tree().change_scene_to_file(). Also fades in when the game starts.

const FADE_TIME := 0.25

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.modulate.a = 1.0
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # after add_child so it covers the viewport
	_fade_to(0.0)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	Engine.time_scale = 1.0   # a fight may have left slow motion on
	get_tree().change_scene_to_file(path)
	await _fade_to(0.0)
	_busy = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.tween_property(_rect, "modulate:a", alpha, FADE_TIME)
	await tween.finished
