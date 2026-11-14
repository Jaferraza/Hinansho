extends Node2D
# Attach to the root of a map. Ends the round when a fighter dies; Esc goes back to map selection.

var _over := false

func _ready() -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	fighters.sort_custom(func(a, b): return a.player_id < b.player_id)
	for fighter in fighters:
		fighter.died.connect(_on_fighter_died.bind(fighter))
	var hud = load("res://scripts/hud.gd").new()
	add_child(hud)
	hud.setup(fighters)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/map_selection.tscn")

func _on_fighter_died(dead: Node) -> void:
	if _over:
		return
	_over = true
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "PLAYER %s WINS" % ("ONE" if dead.player_id == 2 else "TWO")
	label.add_theme_font_override("font", load("res://Sukajan Brush Demo.otf"))
	label.add_theme_font_size_override("font_size", 120)
	layer.add_child(label)
	add_child(layer)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		get_tree().change_scene_to_file("res://scenes/map_selection.tscn")
