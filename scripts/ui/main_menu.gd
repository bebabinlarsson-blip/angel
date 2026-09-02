class_name MainMenu
extends Control

@onready var new_game_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/NewGameButton")
@onready var continue_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/ContinueButton")
@onready var customizer_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/CustomizerButton")
@onready var controls_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/ControlsButton")
@onready var settings_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/SettingsButton")
@onready var quit_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/QuitButton")

var settings_panel: Control = null
var controls_panel: Control = null
var customizer_panel: Control = null

func _ready() -> void:
	if new_game_btn:
		new_game_btn.pressed.connect(_on_new_game)
	if continue_btn:
		continue_btn.pressed.connect(_on_continue)
		var has_save: bool = SaveManager.has_save(0)
		continue_btn.disabled = not has_save
	if customizer_btn:
		customizer_btn.pressed.connect(_on_customizer)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)
	
	_create_settings_modal()
	_create_controls_modal()

func _create_settings_modal() -> void:
	settings_panel = Control.new()
	settings_panel.name = "SettingsModal"
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	
	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			settings_panel.visible = false
	)
	settings_panel.add_child(dimmer)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(400, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	style.border_color = Color(0.35, 0.80, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
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
	add_child(settings_panel)

func _create_controls_modal() -> void:
	controls_panel = Control.new()
	controls_panel.name = "ControlsModal"
	controls_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_panel.visible = false
	
	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			controls_panel.visible = false
	)
	controls_panel.add_child(dimmer)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 480)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.98)
	style.border_color = Color(0.35, 0.80, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	var title := Label.new()
	title.text = "HOW TO PLAY & CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vbox.add_child(title)
	
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	
	var controls_info := [
		["[W][A][S][D] / Arrows", "Move Character"],
		["[Shift]", "Dash / Dodge (Costs 10 Stamina)"],
		["[Space] / Left Click", "Normal Attack (Tap)"],
		["Hold [Space] / Click", "Power Whirlwind Nova (Hold & Release)"],
		["Mouse Cursor", "Aim Direction"],
		["[F]", "Interact / Talk to NPCs / Campfire"],
		["[I] or [Tab]", "Open Inventory & Equipment"],
		["[B]", "Open Island Customizer"],
		["[Esc]", "Pause Menu & Save Game"]
	]
	
	for entry in controls_info:
		var k_lbl := Label.new()
		k_lbl.text = entry[0]
		k_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		grid.add_child(k_lbl)
		
		var d_lbl := Label.new()
		d_lbl.text = entry[1]
		d_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
		grid.add_child(d_lbl)
	
	vbox.add_child(grid)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func(): controls_panel.visible = false)
	vbox.add_child(close_btn)
	
	margin.add_child(vbox)
	card.add_child(margin)
	center.add_child(card)
	controls_panel.add_child(center)
	add_child(controls_panel)

func _on_new_game() -> void:
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_continue() -> void:
	GameManager.current_state = GameManager.GameState.PLAYING
	get_tree().change_scene_to_file("res://scenes/game.tscn")
	await get_tree().create_timer(0.2).timeout
	SaveManager.load_game(0)

func _on_customizer() -> void:
	if customizer_panel == null:
		var cust_scene = load("res://scenes/ui/island_customizer.tscn")
		if cust_scene:
			customizer_panel = cust_scene.instantiate()
			add_child(customizer_panel)
	if customizer_panel:
		if customizer_panel.has_method("open"):
			customizer_panel.open()
		else:
			customizer_panel.visible = true

func _on_controls() -> void:
	if controls_panel:
		controls_panel.visible = true

func _on_settings() -> void:
	if settings_panel:
		settings_panel.visible = true

func _on_quit() -> void:
	get_tree().quit()
