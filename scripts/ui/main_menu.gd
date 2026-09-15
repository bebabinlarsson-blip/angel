class_name MainMenu
extends Control

@onready var new_game_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/NewGameButton")
@onready var continue_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/ContinueButton")
@onready var controls_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/ControlsButton")
@onready var settings_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/SettingsButton")
@onready var quit_btn: Button = get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer/QuitButton")

var settings_panel: Control = null
var controls_panel: Control = null
var _transitioning: bool = false

func _ready() -> void:
	_ensure_audio_manager()
	if new_game_btn:
		new_game_btn.pressed.connect(_on_new_game)
	if continue_btn:
		continue_btn.pressed.connect(_on_continue)
		var has_save: bool = SaveManager.has_save(0)
		continue_btn.disabled = not has_save
	if controls_btn:
		controls_btn.pressed.connect(_on_controls)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings)
	if quit_btn:
		if OS.has_feature("web"):
			quit_btn.visible = false
		else:
			quit_btn.pressed.connect(_on_quit)
	
	_create_settings_modal()
	_create_controls_modal()
	UITheme.style_recursive(self)
	_play_entrance()

func _input(event: InputEvent) -> void:
	# Settings and controls are independent main-menu modals. Close the active
	# one on Escape before a focused slider/button can consume the event.
	if not event.is_action_pressed("pause"):
		return
	if controls_panel != null and controls_panel.visible:
		controls_panel.visible = false
		get_viewport().set_input_as_handled()
		return
	if settings_panel != null and settings_panel.visible:
		settings_panel.visible = false
		get_viewport().set_input_as_handled()

func _ensure_audio_manager() -> void:
	if get_tree().root.get_node_or_null("AudioManager") == null:
		var mgr := AudioManager.new()
		mgr.name = "AudioManager"
		get_tree().root.add_child.call_deferred(mgr)

func _play_entrance() -> void:
	var card := get_node_or_null("CenterContainer/MenuCard")
	if card is Control:
		UIAnim.pop_in(card as Control, 0.35)
	var vbox := get_node_or_null("CenterContainer/MenuCard/MarginContainer/VBoxContainer")
	if vbox:
		UIAnim.stagger_children(vbox, 0.06, 0.3)
	for b in [new_game_btn, continue_btn, controls_btn, settings_btn, quit_btn]:
		if b is Button:
			UIAnim.hook_button_sounds(b)

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
	card.add_theme_stylebox_override("panel", UITheme.panel_style())
	
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
	card.add_theme_stylebox_override("panel", UITheme.panel_style())
	
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
		["[E] or [Tab]", "Open Inventory & Equipment"],
		["[Q]", "Open Quest Journal"],
		["[M] or Click Map", "Toggle Big Map"],
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
	if _transitioning:
		return
	_set_transitioning(true)
	var scene_tree := get_tree()
	if scene_tree == null:
		_set_transitioning(false)
		return
	GameManager.opened_caches.clear()
	GameManager.unlocked_waystones.clear()
	GameManager.pending_waystone_ids.clear()
	GameManager.pending_player_data.clear()
	GameManager.pending_quest_data.clear()
	GameManager.pending_world_data.clear()
	GameManager.is_interior = false
	GameManager.current_interior_id = ""
	GameManager.current_location_name = "Angel Village"
	GameManager.return_scene_path = "res://scenes/game.tscn"
	GameManager.return_position = Vector2.ZERO
	GameManager.game_time_hours = 8.0
	GameManager.day_count = 1
	GameManager.is_night = false
	GameManager._last_emit_hour = -1
	GameManager._last_emit_minute = -1
	GameManager.set_state(GameManager.GameState.LOADING)
	var change_error := scene_tree.change_scene_to_file("res://scenes/game.tscn")
	if change_error != OK:
		GameManager.set_state(GameManager.GameState.MAIN_MENU)
		_set_transitioning(false)
		push_error("MainMenu: failed to start a new game (%s)" % error_string(change_error))

func _on_continue() -> void:
	if _transitioning:
		return
	_set_transitioning(true)
	var scene_tree := get_tree()
	if scene_tree == null:
		_set_transitioning(false)
		return
	GameManager.set_state(GameManager.GameState.LOADING)
	var change_error := scene_tree.change_scene_to_file("res://scenes/game.tscn")
	if change_error != OK:
		GameManager.set_state(GameManager.GameState.MAIN_MENU)
		_set_transitioning(false)
		push_error("MainMenu: failed to continue into the game (%s)" % error_string(change_error))
		return
	# Wait for the new scene's gameplay systems, not just the player. This keeps
	# the quest/world snapshots from a save from racing scene initialization.
	for i in range(120):
		await scene_tree.process_frame
		var p := scene_tree.root.find_child("Player", true, false)
		var q := scene_tree.root.find_child("QuestSystem", true, false)
		var director := scene_tree.root.find_child("WorldDirector", true, false)
		if p and q and director:
			break
	SaveManager.load_game(0)

func _set_transitioning(value: bool) -> void:
	_transitioning = value
	for button in [new_game_btn, continue_btn, controls_btn, settings_btn, quit_btn]:
		if button is Button:
			button.disabled = value
	if not value and continue_btn:
		continue_btn.disabled = not SaveManager.has_save(0)

func _on_controls() -> void:
	if controls_panel:
		if settings_panel:
			settings_panel.visible = false
		controls_panel.visible = true
		var card := controls_panel.get_node_or_null("CenterContainer/PanelContainer")
		if card == null:
			card = _find_card(controls_panel)
		if card is Control:
			UIAnim.pop_in(card as Control)

func _on_settings() -> void:
	if settings_panel:
		if controls_panel:
			controls_panel.visible = false
		settings_panel.visible = true
		var card := settings_panel.get_node_or_null("CenterContainer/PanelContainer")
		if card == null:
			card = _find_card(settings_panel)
		if card is Control:
			UIAnim.pop_in(card as Control)

func _find_card(node: Node) -> Control:
	if node is PanelContainer:
		return node as Control
	for c in node.get_children():
		var found := _find_card(c)
		if found:
			return found
	return null

func _on_quit() -> void:
	get_tree().quit()
