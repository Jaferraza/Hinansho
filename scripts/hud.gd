extends CanvasLayer
# Fixed health bars at the top of the screen: Player 1 top-left, Player 2 top-right.
# Built in code; fight.gd adds it and calls setup() with the two fighters.

const BAR_W := 420.0
const BAR_H := 28.0
const MARGIN := 20.0
const THRESHOLD := 0.25

const FILL_NORMAL := Color(0.75, 0.1, 0.15)
const FILL_BOOST := Color(1.0, 0.5, 0.1)
const SPECIAL_ON := Color(1.0, 0.85, 0.2)
const SPECIAL_OFF := Color(0.45, 0.45, 0.45)

var _panels: Array = []


func setup(fighters: Array) -> void:
	for fighter in fighters:
		_panels.append(_build_panel(fighter))


func _build_panel(fighter) -> Dictionary:
	var left: bool = fighter.player_id == 1
	var align := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT

	var root := Control.new()
	root.size = Vector2(BAR_W, 130)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var name_label := _label(root, "PLAYER %d" % fighter.player_id, 22, Vector2(0, 0), BAR_W, align)
	name_label.add_theme_color_override("font_color", Color.WHITE)

	var bar := ProgressBar.new()
	bar.position = Vector2(0, 28)
	bar.size = Vector2(BAR_W, BAR_H)
	bar.show_percentage = false
	bar.step = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill is anchored on the inside edge, so both bars drain toward their screen edge.
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if left else ProgressBar.FILL_BEGIN_TO_END
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	bg.border_color = Color.WHITE
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_NORMAL
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	root.add_child(bar)

	var hp_label := _label(bar, "", 20, Vector2(0, 0), BAR_W, HORIZONTAL_ALIGNMENT_CENTER)
	hp_label.size.y = BAR_H
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 4)

	# Tick at the 25% point (the bar is filled from the inside edge).
	var tick := ColorRect.new()
	tick.color = SPECIAL_ON
	tick.size = Vector2(3, BAR_H + 8)
	tick.position = Vector2((BAR_W * (1.0 - THRESHOLD) if left else BAR_W * THRESHOLD) - 1.5, 24)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tick)

	var special_label := _label(root, "SPECIAL", 18, Vector2(0, 28 + BAR_H + 4), BAR_W, align)
	var banner := _label(root, "BOUNCE BACK!", 30, Vector2(0, 28 + BAR_H + 28), BAR_W, align)
	banner.add_theme_color_override("font_color", FILL_BOOST)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 6)
	banner.visible = false

	return {"fighter": fighter, "left": left, "root": root, "bar": bar, "fill": fill,
			"hp": hp_label, "special": special_label, "banner": banner}


func _label(parent: Node, text: String, font_size: int, pos: Vector2, width: float, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(width, font_size + 8)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	for panel in _panels:
		var fighter = panel["fighter"]
		if not is_instance_valid(fighter):
			continue
		panel["root"].position = Vector2(MARGIN if panel["left"] else view_w - MARGIN - BAR_W, MARGIN)
		panel["bar"].max_value = fighter.max_health
		panel["bar"].value = fighter.health
		panel["hp"].text = str(fighter.health)
		panel["fill"].bg_color = FILL_BOOST if fighter.is_boosted() else FILL_NORMAL
		panel["special"].add_theme_color_override("font_color", SPECIAL_ON if fighter.can_use_special() else SPECIAL_OFF)
		panel["banner"].visible = fighter.is_boosted()
