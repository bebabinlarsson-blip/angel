class_name PauseMenu
extends Control

@onready var resume_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ResumeButton")
@onready var save_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SaveButton")
@onready var quest_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/QuestButton")
@onready var settings_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SettingsButton")
@onready var main_menu_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MainMenuButton")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")
@onready var settings_panel: Control = get_node_or_null("SettingsPanel")

func _ready() -> void:
	EventBus.pause_toggled.connect(_toggle)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if resume_btn:
		resume_btn.pressed.connect(_on_resume)
	if save_btn:
		save_btn.pressed.connect(_on_save)
	if quest_btn:
		quest_btn.pressed.connect(_on_quest)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu)
	if dimmer:
		dimmer.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_toggle()
		)
	
	_create_settings_panel()
	for b in [resume_btn, save_btn, quest_btn, settings_btn, main_menu_btn]:
		if b is Button:
			UIAnim.hook_button_sounds(b)
	UITheme.style_recursive(self)

func _create_settings_panel() -> void:
	if settings_panel == null:
		return
	
	for child in settings_panel.get_children():
		child.queue_free()
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	style.border_color = Color(0.35, 0.80, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)
	
	var vol_label := Label.new()
	vol_label.text = "Master Audio Volume"
	vbox.add_child(vol_label)
	
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 85.0
	slider.value_changed.connect(func(v: float):
		var bus_idx := AudioServer.get_bus_index("Master")
		if bus_idx >= 0:
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v / 100.0))
	)
	vbox.add_child(slider)
	
	var fs_check := CheckButton.new()
	fs_check.text = "Fullscreen Mode"
	fs_check.toggled.connect(func(toggled: bool):
		if toggled:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	)
	vbox.add_child(fs_check)
	
	var back_btn := Button.new()
	back_btn.text = "Close"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(func(): settings_panel.visible = false)
	vbox.add_child(back_btn)
	
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)
	settings_panel.add_child(center)

func _toggle() -> void:
	if GameManager.current_state == GameManager.GameState.MAIN_MENU:
		return
	visible = !visible
	if visible:
		var inv := get_tree().root.find_child("InventoryUI", true, false)
		if inv and inv.visible:
			inv.visible = false
		var q_menu := get_tree().root.find_child("QuestMenu", true, false)
		if q_menu and q_menu.visible:
			q_menu.visible = false
		
		GameManager.set_state(GameManager.GameState.PAUSED)
		var card := get_node_or_null("CenterContainer/PanelContainer")
		if card is Control:
			UIAnim.pop_in(card as Control, 0.2)
	else:
		GameManager.set_state(GameManager.GameState.PLAYING)
		if settings_panel:
			settings_panel.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and visible and settings_panel and settings_panel.visible:
		settings_panel.visible = false
		get_viewport().set_input_as_handled()

func _on_resume() -> void:
	_toggle()

func _on_save() -> void:
	SaveManager.save_game(0)
	EventBus.show_notification.emit("Game Progress Saved!")

func _on_settings() -> void:
	if settings_panel:
		settings_panel.visible = !settings_panel.visible


func _on_quest() -> void:
	_toggle()
	EventBus.quest_menu_toggled.emit()

func _on_main_menu() -> void:
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
