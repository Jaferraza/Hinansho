extends Button



func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/1stmap.tscn")





func _on_button_4_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/2ndmap.tscn")





func _on_button_5_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/QingMAP.tscn")





func _on_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
