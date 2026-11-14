extends Node2D


const BRUSH_FONT := preload("res://Sukajan Brush Demo.otf")
const HIT_SPARK := preload("res://scripts/hit_spark.gd")

const HIT_STOP := 0.07          # real seconds the game freezes on a normal hit
const SPECIAL_HIT_STOP := 0.16
const KO_SLOWMO := 0.2
const KO_SLOWMO_TIME := 1.1     # real seconds

var _over := false
var _layer: CanvasLayer
var _camera: Camera2D
var _shake_strength := 0.0
var _freeze_id := 0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 10
	add_child(_layer)
	_camera = get_viewport().get_camera_2d()

	var fighters := get_tree().get_nodes_in_group("fighters")
	fighters.sort_custom(func(a, b): return a.player_id < b.player_id)
	for fighter in fighters:
		fighter.died.connect(_on_fighter_died.bind(fighter))
		fighter.hit_taken.connect(_on_hit_taken)
		fighter.controls_enabled = false
	var hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(fighters)

	await _announce("ROUND ONE", 0.8, 130)
	await _announce("FIGHT!", 0.5, 170, Color(1.0, 0.25, 0.2))
	for fighter in fighters:
		if is_instance_valid(fighter):
			fighter.controls_enabled = true


func _process(delta: float) -> void:
	if _camera == null:
		return
	if _shake_strength > 0.0:
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = maxf(_shake_strength - delta * 40.0, 0.0)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Engine.time_scale = 1.0
		Transition.change_scene("res://scenes/map_selection.tscn")


# --- hit effects -------------------------------------------------------------

func _on_hit_taken(pos: Vector2, amount: int, special: bool) -> void:
	var spark := HIT_SPARK.new()
	spark.big = special
	spark.position = pos
	add_child(spark)
	_spawn_damage_number(pos, amount, special)
	_shake_strength = 14.0 if special else 6.0
	_hit_stop(SPECIAL_HIT_STOP if special else HIT_STOP)


func _spawn_damage_number(pos: Vector2, amount: int, special: bool) -> void:
	var label := Label.new()
	label.text = "-%d" % amount
	label.add_theme_font_size_override("font_size", 40 if special else 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2) if special else Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 51
	# Counter the camera's (non-uniform) zoom so the text keeps its proportions.
	if _camera:
		label.scale = Vector2(1.0 / _camera.zoom.x, 1.0 / _camera.zoom.y)
	add_child(label)
	label.position = pos + Vector2(-20, -70)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 45.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _hit_stop(real_seconds: float) -> void:
	if _over:
		return
	_freeze_id += 1
	var my_id := _freeze_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(real_seconds, true, false, true).timeout
	if my_id == _freeze_id and not _over:
		Engine.time_scale = 1.0


# --- announcements -----------------------------------------------------------

func _make_banner(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BRUSH_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.pivot_offset = get_viewport().get_visible_rect().size / 2.0
	return label


# Pops the text in, holds it, fades it out. Runs on real time so it also works in slow motion.
func _announce(text: String, hold: float, size: int, color: Color = Color.WHITE) -> void:
	var label := _make_banner(text, size, color)
	label.scale = Vector2(2.2, 2.2)
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.2).set_delay(hold)
	await tween.finished
	label.queue_free()


# --- end of round ------------------------------------------------------------

func _on_fighter_died(dead: Node) -> void:
	if _over:
		return
	_over = true
	_shake_strength = 22.0

	# Slow-motion K.O. with a camera push-in.
	Engine.time_scale = KO_SLOWMO
	var zoom_before := Vector2.ONE
	if _camera:
		zoom_before = _camera.zoom
		var zoom_in := create_tween()
		zoom_in.set_ignore_time_scale(true)
		zoom_in.tween_property(_camera, "zoom", zoom_before * 1.25, KO_SLOWMO_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _announce("K.O.", KO_SLOWMO_TIME - 0.5, 200, Color(1.0, 0.2, 0.15))
	if not is_inside_tree():
		return
	Engine.time_scale = 1.0
	if _camera:
		var zoom_out := create_tween()
		zoom_out.tween_property(_camera, "zoom", zoom_before, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var winner := _make_banner("PLAYER %s WINS" % ("ONE" if dead.player_id == 2 else "TWO"), 120, Color.WHITE)
	winner.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(winner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		Transition.change_scene("res://scenes/map_selection.tscn")
