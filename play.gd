extends Panel

signal pause

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.is_pressed():
			emit_signal("pause")
