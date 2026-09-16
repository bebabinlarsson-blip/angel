class_name AdminDebugPanel
extends Control

## Password-gated in-game developer console. The console is intentionally
## runtime-only and does not write its toggles into normal save data.

signal close_requested

const PASSCODE := "Angel Oath"
const SLIME_SCENE = preload("res://scenes/monsters/slime.tscn")
const DEBUG_ANIMAL_SCRIPT = preload("res://scripts/world/debug_animal.gd")

const ITEM_CATALOG := {
	"Materials": [
		{"id": "wood", "name": "Wood", "type": 0, "stackable": true},
		{"id": "stone", "name": "Stone", "type": 0, "stackable": true},
		{"id": "fiber", "name": "Fiber", "type": 0, "stackable": true},
		{"id": "herb", "name": "Herb", "type": 0, "stackable": true},
		{"id": "mushroom", "name": "Mushroom", "type": 0, "stackable": true},
		{"id": "iron_ore", "name": "Iron Ore", "type": 0, "stackable": true},
		{"id": "coal", "name": "Coal", "type": 0, "stackable": true},
		{"id": "gold_ore", "name": "Gold Ore", "type": 0, "stackable": true},
		{"id": "crystal", "name": "Blue Crystal", "type": 6, "stackable": true},
		{"id": "sunstone", "name": "Sunstone", "type": 6, "stackable": true},
		{"id": "flower", "name": "Wildflower", "type": 0, "stackable": true},
		{"id": "clover", "name": "Clover", "type": 0, "stackable": true},
		{"id": "berry", "name": "Wild Berries", "type": 0, "stackable": true},
		{"id": "apple", "name": "Apple", "type": 0, "stackable": true},
		{"id": "orange", "name": "Orange", "type": 0, "stackable": true},
		{"id": "pear", "name": "Pear", "type": 0, "stackable": true},
		{"id": "banana", "name": "Banana", "type": 0, "stackable": true},
		{"id": "grapes", "name": "Grapes", "type": 0, "stackable": true},
		{"id": "tomato", "name": "Tomato", "type": 0, "stackable": true},
		{"id": "carrot", "name": "Carrot", "type": 0, "stackable": true},
		{"id": "wheat", "name": "Wheat", "type": 0, "stackable": true},
		{"id": "mint", "name": "Mint", "type": 0, "stackable": true},
		{"id": "lavender", "name": "Lavender", "type": 0, "stackable": true},
		{"id": "rose", "name": "Rose", "type": 0, "stackable": true},
	],
	"Equipment": [
		{"id": "wooden_sword", "name": "Wooden Sword", "type": 1, "stackable": false, "attack_bonus": 15.0},
		{"id": "iron_sword", "name": "Iron Sword", "type": 1, "stackable": false, "attack_bonus": 35.0},
		{"id": "hunter_blade", "name": "Hunter Blade", "type": 1, "stackable": false, "attack_bonus": 60.0},
		{"id": "leather_armor", "name": "Leather Armor", "type": 2, "stackable": false, "defense": 8.0},
		{"id": "iron_armor", "name": "Iron Armor", "type": 2, "stackable": false, "defense": 24.0},
	],
	"Food / Dishes": [
		{"id": "mushroom_stew", "name": "Mushroom Stew", "type": 3, "stackable": true, "heal": 35.0, "stamina_restore": 10.0},
		{"id": "herb_salad", "name": "Herb Salad", "type": 3, "stackable": true, "heal": 20.0, "stamina_restore": 5.0},
		{"id": "berry_compote", "name": "Berry Compote", "type": 3, "stackable": true, "heal": 25.0, "stamina_restore": 10.0},
		{"id": "foragers_salad", "name": "Forager's Salad", "type": 3, "stackable": true, "heal": 30.0, "stamina_restore": 12.0},
		{"id": "orchard_pie", "name": "Orchard Pie", "type": 3, "stackable": true, "heal": 40.0, "stamina_restore": 15.0},
		{"id": "tropical_fruit_bowl", "name": "Tropical Fruit Bowl", "type": 3, "stackable": true, "heal": 20.0, "stamina_restore": 35.0},
		{"id": "herbalist_broth", "name": "Herbalist's Broth", "type": 3, "stackable": true, "heal": 45.0, "stamina_restore": 20.0},
		{"id": "garden_soup", "name": "Garden Soup", "type": 3, "stackable": true, "heal": 40.0, "stamina_restore": 15.0},
		{"id": "fruit_punch", "name": "Fruit Punch", "type": 3, "stackable": true, "heal": 18.0, "stamina_restore": 50.0},
		{"id": "root_roast", "name": "Root Roast", "type": 3, "stackable": true, "heal": 55.0, "stamina_restore": 10.0},
		{"id": "lavender_tea", "name": "Lavender Tea", "type": 3, "stackable": true, "heal": 12.0, "stamina_restore": 35.0},
	],
	"Potions": [
		{"id": "stamina_tonic", "name": "Stamina Tonic", "type": 4, "stackable": true, "heal": 15.0, "stamina_restore": 25.0},
		{"id": "iron_brew", "name": "Iron Vitality Brew", "type": 4, "stackable": true, "heal": 50.0, "stamina_restore": 30.0},
		{"id": "greater_health_potion", "name": "Greater Health Potion", "type": 4, "stackable": true, "heal": 100.0},
		{"id": "swift elixir", "name": "Swift Elixir", "type": 4, "stackable": true, "stamina_restore": 100.0},
	],
}

const ENTITY_CATALOG := [
	{"id": "slime", "name": "Slime (Monster)"},
	{"id": "moss", "name": "Moss Slime (Monster)"},
	{"id": "ember", "name": "Ember Slime (Monster)"},
	{"id": "crystal", "name": "Crystal Slime (Monster)"},
	{"id": "chicken", "name": "Chicken (Animal)"},
	{"id": "cow", "name": "Cow (Animal)"},
	{"id": "rabbit", "name": "Rabbit (Animal)"},
]

var unlocked := false
var gate: Control
var console: Control
var code_input: LineEdit
var gate_status: Label
var tab_container: TabContainer
var debug_overlay: Label
var debug_overlay_enabled := false
var item_category: OptionButton
var item_option: OptionButton
var item_quantity: SpinBox
var entity_option: OptionButton
var entity_quantity: SpinBox
var time_slider: HSlider
var time_value_label: Label
var coord_x: SpinBox
var coord_y: SpinBox
var preset_option: OptionButton
var quest_status: Label
var quest_force_button: Button
var quest_skip_button: Button
var player: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_shell()

func show_from_pause() -> void:
	player = GameManager.player
	visible = true
	if unlocked:
		_show_console()
	else:
		_show_gate()

func close_panel() -> void:
	visible = false
	gate.visible = false
	console.visible = false
	close_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close_panel()
		get_viewport().set_input_as_handled()

func _build_shell() -> void:
	_build_gate()
	_build_console()
	_show_gate()

func _build_gate() -> void:
	gate = Control.new()
	gate.name = "PasscodeGate"
	gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(gate)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gate.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 280)
	card.add_theme_stylebox_override("panel", _panel_style(UITheme.GOLD, UITheme.INK))
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := _title_label("ADMIN / DEBUG ACCESS")
	layout.add_child(title)
	var description := _muted_label("Enter the developer passcode to unlock session tools.")
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(description)

	code_input = LineEdit.new()
	code_input.name = "PasscodeInput"
	code_input.placeholder_text = "Passcode"
	code_input.secret = true
	code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	code_input.custom_minimum_size.y = 42
	code_input.text_submitted.connect(func(_text: String): _try_unlock())
	layout.add_child(code_input)

	var unlock_button := Button.new()
	unlock_button.text = "Unlock Admin Panel"
	unlock_button.custom_minimum_size.y = 42
	unlock_button.pressed.connect(_try_unlock)
	_apply_button(unlock_button)
	layout.add_child(unlock_button)

	gate_status = _muted_label("")
	gate_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(gate_status)

	var cancel := Button.new()
	cancel.text = "Back to Pause Menu"
	cancel.pressed.connect(close_panel)
	_apply_button(cancel)
	layout.add_child(cancel)

func _build_console() -> void:
	console = Control.new()
	console.name = "AdminConsole"
	console.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	console.visible = false
	add_child(console)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	console.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(1080, 660)
	card.add_theme_stylebox_override("panel", _panel_style(UITheme.EDGE_GOLD, UITheme.INK))
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 16)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	layout.add_child(header)
	var title := _title_label("ANGEL  //  ADMIN & DEBUG")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close  [Esc]"
	close_button.custom_minimum_size = Vector2(130, 34)
	close_button.pressed.connect(close_panel)
	_apply_button(close_button)
	header.add_child(close_button)

	var subtitle := _muted_label("Session-only developer tools. Use carefully while testing.")
	layout.add_child(subtitle)

	tab_container = TabContainer.new()
	tab_container.name = "AdminTabs"
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(tab_container)

	_build_player_tab(_new_tab("Player Cheats & Stats"))
	_build_spawner_tab(_new_tab("Spawners"))
	_build_world_tab(_new_tab("World Controls"))
	_build_developer_tab(_new_tab("Developer Tools"))

	var footer := _muted_label("Passcode accepted: Angel Oath  •  Changes are active immediately")
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(footer)

func _new_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title.replace(" ", "_").replace("/", "")
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, title)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(950, 0)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	return content

func _build_player_tab(content: VBoxContainer) -> void:
	_add_section(content, "PLAYER CHEATS & STATS", "Change the live player state without editing a save file.")
	var god_mode := CheckButton.new()
	god_mode.text = "God Mode  —  invulnerable"
	god_mode.button_pressed = _player_bool("admin_god_mode", false)
	god_mode.toggled.connect(func(value: bool):
		GameManager.admin_god_mode = value
		if player and player.has_method("set_admin_god_mode"):
			player.call("set_admin_god_mode", value)
	)
	_apply_button(god_mode)
	content.add_child(god_mode)

	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 12)
	content.add_child(money_row)
	var money_label := _field_label("Currency")
	money_row.add_child(money_label)
	var money := _spinbox(0.0, 999999999.0, 1.0, _player_money())
	money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money.value_changed.connect(func(value: float):
		var stats := _player_stats()
		if stats:
			stats.money = maxi(0, int(value))
			EventBus.player_money_changed.emit(stats.money)
	)
	money_row.add_child(money)

	_add_slider_row(content, "Health / Max Health", 1.0, 5000.0, 1.0, _stat_health(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_max_hp(value)
			stats.current_hp = value
			EventBus.player_health_changed.emit(stats.current_hp, stats.get_max_hp())
	)
	_add_slider_row(content, "Attack", 0.0, 1000.0, 1.0, _stat_attack(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_attack(value)
	)
	_add_slider_row(content, "Speed Multiplier", 0.25, 8.0, 0.05, _stat_speed(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_speed_multiplier(value)
	)
	_add_slider_row(content, "Stamina / Max Stamina", 1.0, 2000.0, 1.0, _stat_stamina(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_max_stamina(value)
			stats.current_stamina = value
			EventBus.player_stamina_changed.emit(stats.current_stamina, stats.get_max_stamina())
	)
	_add_slider_row(content, "Character Level", 0.0, 1000.0, 1.0, _stat_level(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_level(int(value))
			EventBus.player_health_changed.emit(stats.current_hp, stats.get_max_hp())
			EventBus.player_stamina_changed.emit(stats.current_stamina, stats.get_max_stamina())
	)
	_add_slider_row(content, "Weapon Upgrade Level", 0.0, 100.0, 1.0, _stat_weapon_upgrade(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_weapon_upgrade_level(int(value))
	)
	_add_slider_row(content, "Armor Upgrade Level", 0.0, 100.0, 1.0, _stat_armor_upgrade(), func(value: float):
		var stats := _player_stats()
		if stats:
			stats.set_admin_armor_upgrade_level(int(value))
	)

	var reset := Button.new()
	reset.text = "Reset Stat Overrides"
	reset.pressed.connect(func():
		var stats := _player_stats()
		if stats:
			stats.clear_admin_overrides()
			stats.current_hp = stats.get_max_hp()
			stats.current_stamina = stats.get_max_stamina()
			EventBus.player_health_changed.emit(stats.current_hp, stats.get_max_hp())
			EventBus.player_stamina_changed.emit(stats.current_stamina, stats.get_max_stamina())
			EventBus.show_notification.emit("Admin stat overrides reset.")
	)
	_apply_button(reset)
	content.add_child(reset)

func _build_spawner_tab(content: VBoxContainer) -> void:
	_add_section(content, "ITEM SPAWNER", "Add materials, equipment, dishes and potions directly to the backpack.")
	item_category = OptionButton.new()
	item_category.name = "ItemCategory"
	for category in ITEM_CATALOG.keys():
		item_category.add_item(str(category))
	item_category.item_selected.connect(func(_index: int): _refresh_item_options())
	item_category.select(0)
	content.add_child(_labeled_control("Category", item_category))

	item_option = OptionButton.new()
	item_option.name = "Item"
	content.add_child(_labeled_control("Item", item_option))

	item_quantity = _spinbox(1.0, 999999999.0, 1.0, 10.0)
	content.add_child(_labeled_control("Quantity", item_quantity))

	var spawn_item := Button.new()
	spawn_item.text = "Spawn Item into Inventory"
	spawn_item.pressed.connect(_spawn_selected_item)
	_apply_button(spawn_item)
	content.add_child(spawn_item)
	_refresh_item_options()

	_add_section(content, "ENTITY SPAWNER", "Spawn monsters or harmless wandering animals at the player's current position.")
	entity_option = OptionButton.new()
	for entry: Dictionary in ENTITY_CATALOG:
		entity_option.add_item(str(entry["name"]))
		entity_option.set_item_metadata(entity_option.item_count - 1, str(entry["id"]))
	content.add_child(_labeled_control("Entity", entity_option))

	entity_quantity = _spinbox(1.0, 20.0, 1.0, 1.0)
	content.add_child(_labeled_control("Count", entity_quantity))
	var spawn_entity := Button.new()
	spawn_entity.text = "Spawn at Player"
	spawn_entity.pressed.connect(_spawn_selected_entity)
	_apply_button(spawn_entity)
	content.add_child(spawn_entity)

func _build_world_tab(content: VBoxContainer) -> void:
	_add_section(content, "WORLD CONTROLS", "Adjust time and jump to authored locations or exact coordinates.")
	_add_slider_row(content, "Time of Day", 0.0, 24.0, 0.25, GameManager.game_time_hours, func(value: float):
		GameManager.set_admin_time(value)
	)
	var freeze := CheckButton.new()
	freeze.text = "Freeze Time"
	freeze.button_pressed = GameManager.admin_freeze_time
	freeze.toggled.connect(func(value: bool): GameManager.admin_freeze_time = value)
	_apply_button(freeze)
	content.add_child(freeze)

	_add_section(content, "TELEPORT", "Coordinates use the current world-space map coordinate system.")
	coord_x = _spinbox(-20000.0, 20000.0, 1.0, _player_position().x)
	coord_y = _spinbox(-20000.0, 20000.0, 1.0, _player_position().y)
	content.add_child(_labeled_control("Map X", coord_x))
	content.add_child(_labeled_control("Map Y", coord_y))

	var teleport := Button.new()
	teleport.text = "Teleport to Coordinates"
	teleport.pressed.connect(_teleport_to_coordinates)
	_apply_button(teleport)
	content.add_child(teleport)

	preset_option = OptionButton.new()
	content.add_child(_labeled_control("Preset Location", preset_option))
	_build_teleport_presets()
	preset_option.item_selected.connect(func(index: int):
		var value: Variant = preset_option.get_item_metadata(index)
		if value is Vector2:
			coord_x.value = value.x
			coord_y.value = value.y
	)
	var preset_teleport := Button.new()
	preset_teleport.text = "Teleport to Preset"
	preset_teleport.pressed.connect(func():
		var value: Variant = preset_option.get_selected_metadata()
		if value is Vector2:
			_teleport(value as Vector2)
	)
	_apply_button(preset_teleport)
	content.add_child(preset_teleport)

func _build_developer_tab(content: VBoxContainer) -> void:
	_add_section(content, "DEVELOPER TOOLS", "Diagnostics and movement tools for testing the world.")
	var free_camera := CheckButton.new()
	free_camera.text = "Free Camera  —  move camera with WASD"
	free_camera.button_pressed = _player_bool("admin_free_camera", GameManager.admin_free_camera)
	free_camera.toggled.connect(func(value: bool):
		GameManager.admin_free_camera = value
		if player and player.has_method("set_admin_free_camera"):
			player.call("set_admin_free_camera", value)
	)
	_apply_button(free_camera)
	content.add_child(free_camera)

	var no_clip := CheckButton.new()
	no_clip.text = "No-Clip  —  pass through collision"
	no_clip.button_pressed = _player_bool("admin_no_clip", GameManager.admin_no_clip)
	no_clip.toggled.connect(func(value: bool):
		GameManager.admin_no_clip = value
		if player and player.has_method("set_admin_no_clip"):
			player.call("set_admin_no_clip", value)
	)
	_apply_button(no_clip)
	content.add_child(no_clip)

	var overlay_toggle := CheckButton.new()
	overlay_toggle.text = "Debug Overlay  —  FPS, coordinates, time"
	overlay_toggle.toggled.connect(func(value: bool): _set_debug_overlay(value))
	_apply_button(overlay_toggle)
	content.add_child(overlay_toggle)

	_add_section(content, "QUEST MANAGER", "Force-complete the active quest for rewards or skip it without rewards.")
	quest_status = _muted_label("")
	quest_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(quest_status)
	var quest_buttons := HBoxContainer.new()
	quest_buttons.add_theme_constant_override("separation", 10)
	content.add_child(quest_buttons)
	quest_force_button = Button.new()
	quest_force_button.text = "Force Complete Active"
	quest_force_button.pressed.connect(_force_complete_quest)
	_apply_button(quest_force_button)
	quest_buttons.add_child(quest_force_button)
	quest_skip_button = Button.new()
	quest_skip_button.text = "Skip Active Objective"
	quest_skip_button.pressed.connect(_skip_quest)
	_apply_button(quest_skip_button)
	quest_buttons.add_child(quest_skip_button)
	var refresh_quest := Button.new()
	refresh_quest.text = "Refresh Quest State"
	refresh_quest.pressed.connect(_refresh_quest_state)
	_apply_button(refresh_quest)
	quest_buttons.add_child(refresh_quest)
	_refresh_quest_state()

	debug_overlay = Label.new()
	debug_overlay.name = "AdminDebugOverlay"
	debug_overlay.position = Vector2(16, 16)
	debug_overlay.custom_minimum_size = Vector2(250, 100)
	debug_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_overlay.add_theme_color_override("font_color", Color("#d7f4ff"))
	debug_overlay.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
	debug_overlay.add_theme_constant_override("outline_size", 4)
	debug_overlay.add_theme_font_size_override("font_size", 14)
	debug_overlay.visible = false
	add_child(debug_overlay)

func _show_gate() -> void:
	if gate:
		gate.visible = true
	if console:
		console.visible = false
	if code_input:
		code_input.grab_focus.call_deferred()

func _show_console() -> void:
	if gate:
		gate.visible = false
	if console:
		console.visible = true
	_refresh_quest_state()
	_refresh_teleport_coordinates()

func _try_unlock() -> void:
	if code_input and code_input.text == PASSCODE:
		unlocked = true
		if gate_status:
			gate_status.text = "Access granted."
			gate_status.add_theme_color_override("font_color", Color("#9fe6a0"))
		_show_console()
	else:
		if gate_status:
			gate_status.text = "Incorrect passcode."
			gate_status.add_theme_color_override("font_color", Color("#ff8b8b"))
		if code_input:
			code_input.select_all()

func _player_stats() -> PlayerStats:
	if player == null or not is_instance_valid(player):
		player = GameManager.player
	if player == null or not is_instance_valid(player):
		return null
	return player.get("stats") as PlayerStats

func _player_bool(property_name: String, fallback: bool) -> bool:
	if player == null or not is_instance_valid(player):
		player = GameManager.player
	if player == null or not is_instance_valid(player):
		return fallback
	var value: Variant = player.get(property_name)
	return bool(value) if value != null else fallback

func _player_money() -> float:
	var stats := _player_stats()
	return float(stats.money) if stats else 0.0

func _stat_health() -> float:
	var stats := _player_stats()
	return stats.admin_max_hp_override if stats and stats.admin_max_hp_override > 0.0 else (stats.get_max_hp() if stats else 100.0)

func _stat_attack() -> float:
	var stats := _player_stats()
	return stats.admin_attack_override if stats and stats.admin_attack_override >= 0.0 else (stats.get_attack() if stats else 50.0)

func _stat_speed() -> float:
	var stats := _player_stats()
	return stats.admin_speed_multiplier if stats else 1.0

func _stat_stamina() -> float:
	var stats := _player_stats()
	return stats.admin_max_stamina_override if stats and stats.admin_max_stamina_override > 0.0 else (stats.get_max_stamina() if stats else 30.0)

func _stat_level() -> float:
	var stats := _player_stats()
	return float(stats.level) if stats else 0.0

func _stat_weapon_upgrade() -> float:
	var stats := _player_stats()
	return float(stats.admin_weapon_upgrade_level) if stats else 0.0

func _stat_armor_upgrade() -> float:
	var stats := _player_stats()
	return float(stats.admin_armor_upgrade_level) if stats else 0.0

func _player_position() -> Vector2:
	if player == null or not is_instance_valid(player):
		player = GameManager.player
	return (player as Node2D).global_position if player is Node2D else Vector2.ZERO

func _refresh_item_options() -> void:
	if item_category == null or item_option == null:
		return
	item_option.clear()
	var category_index := item_category.selected
	if category_index < 0:
		category_index = 0
	var category := item_category.get_item_text(category_index)
	var entries: Array = ITEM_CATALOG.get(category, [])
	for item_value in entries:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			item_option.add_item(str(item.get("name", item.get("id", "Item"))))
			item_option.set_item_metadata(item_option.item_count - 1, item.duplicate(true))

func _spawn_selected_item() -> void:
	var stats := _player_stats()
	if stats == null or player == null:
		return
	var inventory := player.get("inventory") as PlayerInventory
	if inventory == null:
		return
	var item_value: Variant = item_option.get_selected_metadata()
	if not (item_value is Dictionary):
		return
	var item: Dictionary = item_value.duplicate(true)
	var amount := maxi(1, int(item_quantity.value))
	item["quantity"] = 1 if not bool(item.get("stackable", true)) else amount
	var added := 0
	for i in range(amount if not bool(item.get("stackable", true)) else 1):
		if inventory.add_item(item):
			added += 1 if not bool(item.get("stackable", true)) else amount
		else:
			break
	EventBus.show_notification.emit("Admin spawned %s x%d" % [str(item.get("name", "Item")), added])

func _spawn_selected_entity() -> void:
	var index := entity_option.selected
	if index < 0:
		return
	var entity_id := str(entity_option.get_item_metadata(index))
	var count := maxi(1, int(entity_quantity.value))
	var origin := _player_position()
	for i in range(count):
		var offset := Vector2.ZERO if count == 1 else Vector2.RIGHT.rotated(float(i) * TAU / float(count)) * 42.0
		_spawn_entity(entity_id, origin + offset)
	EventBus.show_notification.emit("Admin spawned %d %s" % [count, entity_id.replace("_", " ").capitalize()])

func _spawn_entity(entity_id: String, position: Vector2) -> void:
	if entity_id in ["slime", "moss", "ember", "crystal"]:
		var director := get_tree().root.find_child("WorldDirector", true, false)
		if director and director.has_method("debug_spawn_enemy_at"):
			director.call("debug_spawn_enemy_at", position, entity_id)
			return
		var enemy := SLIME_SCENE.instantiate() as Node2D
		if enemy:
			enemy.set_meta("variant", entity_id)
			_find_spawn_parent().add_child(enemy)
			enemy.global_position = position
		return
	var animal := DEBUG_ANIMAL_SCRIPT.new() as DebugAnimal
	if animal:
		animal.species = entity_id
		_find_spawn_parent().add_child(animal)
		animal.global_position = position

func _find_spawn_parent() -> Node:
	if player and is_instance_valid(player) and player.get_parent() != null:
		return player.get_parent()
	return get_tree().current_scene

func _build_teleport_presets() -> void:
	preset_option.clear()
	_add_preset("Angel Village", Vector2(0.0, 90.0))
	_add_preset("Northern Mine", Vector2(-2160.0, -2344.0))
	_add_preset("Abandoned Church", Vector2(528.0, -616.0))
	_add_preset("Guest House", Vector2(256.0, -72.0))
	for entry in get_tree().get_nodes_in_group("interior_entries"):
		if entry is Node2D:
			_add_preset(str(entry.get("display_name")) + " Entrance", (entry as Node2D).global_position + Vector2(0, 70))
	for stone in get_tree().get_nodes_in_group("waystones"):
		if stone is Node2D:
			_add_preset(str(stone.get("display_name")), (stone as Node2D).global_position + Vector2(0, 44))

func _add_preset(label: String, position: Vector2) -> void:
	for i in range(preset_option.item_count):
		if preset_option.get_item_text(i) == label:
			return
	preset_option.add_item(label)
	preset_option.set_item_metadata(preset_option.item_count - 1, position)

func _refresh_teleport_coordinates() -> void:
	if coord_x == null or coord_y == null:
		return
	var position := _player_position()
	coord_x.value = position.x
	coord_y.value = position.y

func _teleport_to_coordinates() -> void:
	_teleport(Vector2(coord_x.value, coord_y.value))

func _teleport(destination: Vector2) -> void:
	if player == null or not is_instance_valid(player) or not (player is Node2D):
		return
	var target := destination
	var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain and not GameManager.is_interior:
		target = terrain.clamp_to_playable_area(target)
	(player as Node2D).global_position = target
	if player.get("velocity") is Vector2:
		player.set("velocity", Vector2.ZERO)
	if player.get("camera") is Camera2D:
		(player.get("camera") as Camera2D).reset_smoothing()
	EventBus.show_notification.emit("Teleported to (%.0f, %.0f)" % [target.x, target.y])
	_refresh_teleport_coordinates()

func _set_debug_overlay(enabled: bool) -> void:
	debug_overlay_enabled = enabled
	if debug_overlay:
		debug_overlay.visible = enabled

func _process(_delta: float) -> void:
	if debug_overlay_enabled and debug_overlay:
		var position := _player_position()
		debug_overlay.text = "DEBUG OVERLAY\nFPS: %d\nPlayer: (%.0f, %.0f)\nTime: %s\nLocation: %s" % [Engine.get_frames_per_second(), position.x, position.y, GameManager.get_time_string(), GameManager.current_location_name]
	if console and console.visible:
		_refresh_quest_state()

func _refresh_quest_state() -> void:
	if quest_status == null:
		return
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system == null:
		quest_status.text = "Quest system unavailable in this scene."
		quest_force_button.disabled = true
		quest_skip_button.disabled = true
		return
	var quest := quest_system.get_active_quest()
	if quest.is_empty():
		quest_status.text = "No active quest."
		quest_force_button.disabled = true
		quest_skip_button.disabled = true
		return
	var current := int(quest.get("current_count", 0))
	var target := maxi(1, int(quest.get("target_count", 1)))
	quest_status.text = "%s\n%s\nProgress: %d / %d" % [str(quest.get("title", "Quest")), str(quest.get("objective", "Active objective")), current, target]
	quest_force_button.disabled = false
	quest_skip_button.disabled = false

func _force_complete_quest() -> void:
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system and quest_system.debug_force_complete_active():
		_refresh_quest_state()

func _skip_quest() -> void:
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system and quest_system.debug_skip_active_objective():
		_refresh_quest_state()

func _add_section(parent: VBoxContainer, title: String, description: String) -> void:
	var heading := _title_label(title)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(heading)
	var detail := _muted_label(description)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(detail)
	var separator := HSeparator.new()
	parent.add_child(separator)

func _add_slider_row(parent: VBoxContainer, title: String, minimum: float, maximum: float, step: float, value: float, changed: Callable) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	parent.add_child(row)
	var header := HBoxContainer.new()
	row.add_child(header)
	var name_label := _field_label(title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := _muted_label(_format_slider_value(value, step))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = clampf(value, minimum, maximum)
	slider.custom_minimum_size.y = 24
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(new_value: float):
		value_label.text = _format_slider_value(new_value, step)
		changed.call(new_value)
	)
	row.add_child(slider)
	return slider

func _format_slider_value(value: float, step: float) -> String:
	return "%.2f" % value if step < 0.1 else ("%.1f" % value if step < 1.0 else "%d" % int(value))

func _labeled_control(label_text: String, control: Control) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _field_label(label_text)
	label.custom_minimum_size.x = 190
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

func _spinbox(minimum: float, maximum: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = clampf(value, minimum, maximum)
	spin.allow_greater = false
	spin.allow_lesser = false
	return spin

func _title_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UITheme.GOLD)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	return label

func _field_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UITheme.TEXT)
	return label

func _muted_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return label

func _apply_button(button: Button) -> void:
	UITheme.style_button(button)
	UIAnim.hook_button_sounds(button)

func _panel_style(border: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	return style
