extends Button


func _on_pressed() -> void:
	Transition.change_scene("res://scenes/1stmap.tscn")


func _on_button_4_pressed() -> void:
	Transition.change_scene("res://scenes/2ndmap.tscn")


func _on_button_5_pressed() -> void:
	Transition.change_scene("res://scenes/QingMAP.tscn")


func _on_button_pressed() -> void:
	Transition.change_scene("res://scenes/main_menu.tscn")
