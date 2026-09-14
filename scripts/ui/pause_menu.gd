	if settings_panel:
		settings_panel.visible = !settings_panel.visible
		if settings_panel.visible:
			_on_viewport_resized()


func _on_quest() -> void:
	_toggle()
	EventBus.quest_menu_toggled.emit()

func _on_main_menu() -> void:
	GameManager.set_state(GameManager.GameState.LOADING)
	var result := get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	if result != OK:
		GameManager.set_state(GameManager.GameState.PAUSED)
		EventBus.show_notification.emit("Could not return to the main menu.")