extends CanvasLayer
# Fixed health bars at the top of the screen: Player 1 top-left, Player 2 top-right.
# Built in code; fight.gd adds it and calls setup() with the two fighters.
# The red bar snaps to the current health; a yellow "ghost" bar behind it drains slowly to show
# how much the last hit took. Healing flashes the bar white; a ready special pulses gold.

const BAR_W := 420.0
const BAR_H := 28.0
const MARGIN := 20.0
const THRESHOLD := 0.25
const GHOST_DELAY := 0.35          # seconds the ghost bar waits before draining
const GHOST_SPEED := 90.0          # health points per second
const PLAYER_NAMES := {1: "PLAYER ONE", 2: "PLAYER TWO"}
# The demo brush font has blank digits, so it is used for letters only; HP numbers use the default font.
const BRUSH_FONT := preload("res://Sukajan Brush Demo.otf")

const FILL_NORMAL := Color(0.75, 0.1, 0.15)
const FILL_BOOST := Color(1.0, 0.5, 0.1)
const GHOST_COLOR := Color(1.0, 0.85, 0.35)
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
	root.size = Vector2(BAR_W, 170)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var name_label := _label(root, PLAYER_NAMES[fighter.player_id], 34, Vector2(0, 0), BAR_W, align, true)
	name_label.add_theme_color_override("font_color", Color.WHITE)

	# Background + border as its own panel, so the ghost bar can sit between it and the red fill.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	bg.border_color = Color.WHITE
	bg.set_border_width_all(2)
	var frame := Panel.new()
	frame.position = Vector2(0, 42)
	frame.size = Vector2(BAR_W, BAR_H)
	frame.add_theme_stylebox_override("panel", bg)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)

	var ghost_fill := StyleBoxFlat.new()
	ghost_fill.bg_color = GHOST_COLOR
	var ghost := _bar(root, left, ghost_fill)
	ghost.value = fighter.max_health

	var fill := StyleBoxFlat.new()
	fill.bg_color = FILL_NORMAL
	var bar := _bar(root, left, fill)
	bar.value = fighter.max_health

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
	tick.position = Vector2((BAR_W * (1.0 - THRESHOLD) if left else BAR_W * THRESHOLD) - 1.5, 38)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tick)

	var special_label := _label(root, "SPECIAL", 28, Vector2(0, 42 + BAR_H + 4), BAR_W, align, true)
	var banner := _label(root, "BOUNCE BACK!", 46, Vector2(0, 42 + BAR_H + 40), BAR_W, align, true)
	banner.add_theme_color_override("font_color", FILL_BOOST)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 6)
	banner.visible = false
	banner.pivot_offset = Vector2(0 if left else BAR_W, banner.size.y / 2.0)

	return {"fighter": fighter, "left": left, "root": root, "bar": bar, "ghost": ghost, "fill": fill,
			"hp": hp_label, "special": special_label, "banner": banner,
			"last_health": fighter.max_health, "ghost_wait": 0.0, "banner_shown": false}


func _bar(parent: Node, left: bool, fill: StyleBoxFlat) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = Vector2(0, 42)
	bar.size = Vector2(BAR_W, BAR_H)
	bar.show_percentage = false
	bar.step = 0.01
	bar.max_value = 100
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill is anchored on the inside edge, so both bars drain toward their screen edge.
	bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN if left else ProgressBar.FILL_BEGIN_TO_END
	var empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("background", empty)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _label(parent: Node, text: String, font_size: int, pos: Vector2, width: float, align: HorizontalAlignment, brush: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = Vector2(width, font_size + 8)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	if brush:
		label.add_theme_font_override("font", BRUSH_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _process(delta: float) -> void:
	var view_w := get_viewport().get_visible_rect().size.x
	var t := Time.get_ticks_msec() / 1000.0
	for panel in _panels:
		var fighter = panel["fighter"]
		if not is_instance_valid(fighter):
			continue
		panel["root"].position = Vector2(MARGIN if panel["left"] else view_w - MARGIN - BAR_W, MARGIN)

		var health: int = fighter.health
		var bar: ProgressBar = panel["bar"]
		var ghost: ProgressBar = panel["ghost"]
		bar.max_value = fighter.max_health
		ghost.max_value = fighter.max_health

		if health < panel["last_health"]:
			# Took damage: red bar snaps down, ghost waits, then drains.
			panel["ghost_wait"] = GHOST_DELAY
			_punch(panel["hp"])
		elif health > panel["last_health"]:
			# Healed (bounce back): everything snaps up and the bar flashes white.
			ghost.value = health
			_flash(panel["fill"], FILL_BOOST if fighter.is_boosted() else FILL_NORMAL)
		panel["last_health"] = health

		bar.value = health
		if panel["ghost_wait"] > 0.0:
			panel["ghost_wait"] -= delta
		elif ghost.value > health:
			ghost.value = maxf(ghost.value - GHOST_SPEED * delta, health)
		if ghost.value < health:
			ghost.value = health

		panel["hp"].text = str(health)
		if not panel["fill"].has_meta("flashing"):
			panel["fill"].bg_color = FILL_BOOST if fighter.is_boosted() else FILL_NORMAL

		var special: Label = panel["special"]
		if fighter.can_use_special():
			special.add_theme_color_override("font_color", SPECIAL_ON)
			special.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 8.0))
		else:
			special.add_theme_color_override("font_color", SPECIAL_OFF)
			special.modulate.a = 1.0

		var boosted: bool = fighter.is_boosted()
		if boosted and not panel["banner_shown"]:
			_show_banner(panel["banner"])
		panel["banner_shown"] = boosted
		panel["banner"].visible = boosted


# Little scale punch on the HP number when it drops.
func _punch(label: Label) -> void:
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2(1.5, 1.5)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(fill: StyleBoxFlat, back_to: Color) -> void:
	fill.set_meta("flashing", true)
	fill.bg_color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(fill, "bg_color", back_to, 0.45)
	tween.tween_callback(func(): fill.remove_meta("flashing"))


func _show_banner(banner: Label) -> void:
	banner.scale = Vector2(2.0, 2.0)
	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
