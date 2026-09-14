class_name InteriorManager
extends Node

const INTERIOR_ENTRANCE_SCRIPT = preload("res://scripts/world/interior_entrance.gd")
const INTERIOR_VIEW_SCRIPT = preload("res://scripts/world/interior_view.gd")

var world_node: Node2D = null
var entrance_parent: Node2D = null
var definitions: Array[Dictionary] = []
var interior_layer: CanvasLayer = null
var interior_panel: PanelContainer = null
var interior_view: Control = null
var title_label: Label = null
var description_label: Label = null
var exit_button: Button = null
var active_interior_id: String = ""
var return_position: Vector2 = Vector2.ZERO
var inside_interior: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(new_world_node: Node2D, config: Dictionary) -> void:
	world_node = new_world_node
	definitions = _normalise_definitions(config)
	_ensure_entrances()
	_create_ui()

func _normalise_definitions(config: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = config.get("interiors", [])
	if value is Array:
		for raw_definition in value:
			if not (raw_definition is Dictionary):
				continue
			var raw: Dictionary = raw_definition
			var id := str(raw.get("id", ""))
			if id.is_empty():
				continue
			var position_value: Variant = raw.get("pos", raw.get("position", {}))
			var position := _point_from_data(position_value)
			result.append({
				"id": id,
				"name": str(raw.get("name", id.replace("_", " ").capitalize())),
				"kind": str(raw.get("kind", "house")),
				"pos": position,
				"description": str(raw.get("description", "A quiet place in Angel Village."))
			})
	if result.is_empty():
		result = _fallback_definitions()
	return result

func _fallback_definitions() -> Array[Dictionary]:
	return [
		{"id": "elder_house", "name": "Elder's House", "kind": "house", "pos": Vector2(-384.0, -128.0), "description": "A warm room of maps, stories and village records."},
		{"id": "chef_house", "name": "Chef Maria's Bakery", "kind": "cook", "pos": Vector2(256.0, -128.0), "description": "Fresh bread, preserves and the best recipes on the island."},
		{"id": "smith_cottage", "name": "Blacksmith Cottage", "kind": "smith", "pos": Vector2(-384.0, 96.0), "description": "A forge where tools are sharpened and repaired."},
		{"id": "carpenter_workshop", "name": "Carpenter Workshop", "kind": "market", "pos": Vector2(256.0, 96.0), "description": "A busy workshop full of timber, plans and spare parts."},
		{"id": "highland_mine", "name": "Highland Mine", "kind": "mine", "pos": Vector2(-2176.0, -2368.0), "description": "A harvestable mine with ore veins and old rail tracks."},
		{"id": "abandoned_church", "name": "Abandoned Church", "kind": "church", "pos": Vector2(160.0, 2304.0), "description": "A silent sanctuary overlooking the southern ruins."}
	]

func _point_from_data(value: Variant) -> Vector2:
	if value is Dictionary:
		var point: Dictionary = value
		return Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))
	if value is Vector2:
		return value
	return Vector2.ZERO

func _ensure_entrances() -> void:
	if world_node == null:
		return
	entrance_parent = world_node.get_node_or_null("InteriorEntrances") as Node2D
	if entrance_parent == null:
		entrance_parent = Node2D.new()
		entrance_parent.name = "InteriorEntrances"
		world_node.add_child(entrance_parent)
	for definition: Dictionary in definitions:
		var id := str(definition.get("id", ""))
		if id.is_empty():
			continue
		var node_name := "Entrance_" + id.replace(" ", "_")
		var entrance := entrance_parent.get_node_or_null(node_name) as Node
		if entrance == null:
			entrance = INTERIOR_ENTRANCE_SCRIPT.new() as Node
			entrance.name = node_name
			entrance_parent.add_child(entrance)
		entrance.set("manager", self)
		entrance.call("configure", id, str(definition.get("name", id)), str(definition.get("kind", "house")), str(definition.get("description", "")))
		var position_value: Variant = definition.get("pos", Vector2.ZERO)
		if position_value is Vector2:
			(entrance as Node2D).position = position_value

func _create_ui() -> void:
	if interior_layer != null:
		return
	interior_layer = CanvasLayer.new()
	interior_layer.name = "InteriorLayer"
	interior_layer.layer = 58
	interior_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(interior_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	interior_layer.add_child(root)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.02, 0.04, 0.82)
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_exit_interior()
	)
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	interior_panel = PanelContainer.new()
	interior_panel.name = "InteriorPanel"
	interior_panel.custom_minimum_size = Vector2(720.0, 520.0)
	interior_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#e7b85d"), Color("#111b29")))
	center.add_child(interior_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 18)
	interior_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	title_label = Label.new()
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", Color("#ffe08a"))
	header.add_child(title_label)

	var tag := Label.new()
	tag.text = "INTERIOR"
	tag.add_theme_color_override("font_color", Color("#8dd7dd"))
	header.add_child(tag)
	vbox.add_child(header)

	interior_view = INTERIOR_VIEW_SCRIPT.new() as Control
	interior_view.name = "InteriorView"
	interior_view.custom_minimum_size = Vector2(672.0, 300.0)
	interior_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interior_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(interior_view)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.add_theme_color_override("font_color", Color("#cad8e3"))
	vbox.add_child(description_label)

	exit_button = Button.new()
	exit_button.text = "Return to the village [F / Esc]"
	exit_button.custom_minimum_size = Vector2(0.0, 40.0)
	exit_button.pressed.connect(_exit_interior)
	UITheme.style_button(exit_button)
	vbox.add_child(exit_button)

	_create_ui_theme()
	interior_layer.visible = false

func _create_ui_theme() -> void:
	if interior_panel:
		UITheme.style_recursive(interior_panel)

func _fit_modal() -> void:
	if interior_panel:
		UITheme.fit_modal(interior_panel, Vector2(720.0, 520.0))

func _definition_for(id: String) -> Dictionary:
	for definition: Dictionary in definitions:
		if str(definition.get("id", "")) == id:
			return definition
	return {}

func enter_interior(interior_id: String, entrance_position: Vector2) -> void:
	if inside_interior or GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var player_value: Variant = GameManager.player
	if not (player_value is Node2D) or not is_instance_valid(player_value):
		return
	var definition := _definition_for(interior_id)
	if definition.is_empty():
		return
	var player := player_value as Node2D
	var outward := player.global_position - entrance_position
	if outward.length_squared() <= 0.001:
		outward = Vector2.DOWN
	return_position = entrance_position + outward.normalized() * 88.0
	var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain:
		return_position = terrain.clamp_to_playable_area(return_position)
	active_interior_id = interior_id
	inside_interior = true
	if title_label:
		title_label.text = str(definition.get("name", "Interior"))
	if description_label:
		description_label.text = str(definition.get("description", "A quiet place to rest."))
	if interior_view:
		interior_view.call("configure", interior_id, str(definition.get("name", "Interior")), str(definition.get("kind", "house")))
	if interior_layer:
		interior_layer.visible = true
		_fit_modal()
		UIAnim.pop_in(interior_panel, 0.22)
	GameManager.set_state(GameManager.GameState.PAUSED)

func _exit_interior() -> void:
	if not inside_interior:
		return
	var player_value: Variant = GameManager.player
	if player_value is Node2D and is_instance_valid(player_value):
		var player := player_value as Node2D
		player.global_position = return_position
		player.set("velocity", Vector2.ZERO)
	inside_interior = false
	active_interior_id = ""
	if interior_layer:
		interior_layer.visible = false
	if GameManager.current_state != GameManager.GameState.GAME_OVER and GameManager.current_state != GameManager.GameState.MAIN_MENU:
		GameManager.set_state(GameManager.GameState.PLAYING)

func _input(event: InputEvent) -> void:
	if not inside_interior:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_exit_interior()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") or event.is_action_pressed("quest") or event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
