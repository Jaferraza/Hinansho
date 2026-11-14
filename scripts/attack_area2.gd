extends Area2D
# Hitbox on the player. The player turns `monitoring` on only while an attack animation is playing.

func _ready() -> void:
	monitoring = false
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	var attacker := get_parent()
	if body == attacker or not body.has_method("take_damage"):
		return
	body.take_damage(attacker.current_damage, attacker)
