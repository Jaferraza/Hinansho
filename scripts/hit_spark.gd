extends Node2D
# A short-lived starburst drawn in code. fight.gd spawns one where a hit lands.
# Set `big` before adding it to the tree for the special-attack version.

var big := false

var _outer := PackedVector2Array()
var _inner := PackedVector2Array()


func _ready() -> void:
	var spikes := 12 if big else 8
	var radius := 62.0 if big else 34.0
	for i in range(spikes * 2):
		var r := radius if i % 2 == 0 else radius * 0.4
		var angle := TAU * i / float(spikes * 2)
		var p := Vector2(cos(angle), sin(angle))
		_outer.append(p * r)
		_inner.append(p * r * 0.45)
	rotation = randf() * TAU
	scale = Vector2(0.4, 0.4)
	z_index = 50

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.16).set_delay(0.06)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_colored_polygon(_outer, Color(1.0, 0.55, 0.15) if big else Color(1.0, 0.92, 0.55))
	draw_colored_polygon(_inner, Color.WHITE)
