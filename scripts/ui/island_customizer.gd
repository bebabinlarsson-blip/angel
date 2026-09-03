class_name IslandCustomizer
extends Control

@onready var slider_radius: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/ScaleGrid/SliderRadius")
@onready var val_radius: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/ScaleGrid/ValRadius")

@onready var slider_trees: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/NatureGrid/SliderTrees")
@onready var val_trees: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/NatureGrid/ValTrees")

@onready var slider_flowers: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/NatureGrid/SliderFlowers")
@onready var val_flowers: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/NatureGrid/ValFlowers")

@onready var slider_rocks: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/NatureGrid/SliderRocks")
@onready var val_rocks: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/NatureGrid/ValRocks")

@onready var slider_rabbits: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/WildGrid/SliderRabbits")
@onready var val_rabbits: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/WildGrid/ValRabbits")

@onready var slider_deer: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/WildGrid/SliderDeer")
@onready var val_deer: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/WildGrid/ValDeer")

@onready var slider_birds: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/WildGrid/SliderBirds")
@onready var val_birds: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/WildGrid/ValBirds")

@onready var slider_mining: HSlider = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/ResGrid/SliderMining")
@onready var val_mining: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/ContentVBox/ResGrid/ValMining")

@onready var apply_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBar/ApplyButton")
@onready var reset_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonBar/ResetButton")
@onready var close_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")

const CONFIG_PATH: String = "res://data/island_layout.json"
const USER_CONFIG_PATH: String = "user://island_layout.json"

static func load_layout() -> Dictionary:
	# user:// override wins (exported builds can't write res://).
	for path in [USER_CONFIG_PATH, CONFIG_PATH]:
		if FileAccess.file_exists(path):
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json = JSON.parse_string(file.get_as_text())
				if json and typeof(json) == TYPE_DICTIONARY:
					return json
	return {}

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if close_btn:
		close_btn.pressed.connect(close)
	if dimmer:
		dimmer.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				close()
		)
	
	if apply_btn:
		apply_btn.pressed.connect(_on_apply)
	if reset_btn:
		reset_btn.pressed.connect(_on_reset)
	
	_connect_slider(slider_radius, val_radius)
	_connect_slider(slider_trees, val_trees)
	_connect_slider(slider_flowers, val_flowers)
	_connect_slider(slider_rocks, val_rocks)
	_connect_slider(slider_rabbits, val_rabbits)
	_connect_slider(slider_deer, val_deer)
	_connect_slider(slider_birds, val_birds)
	_connect_slider(slider_mining, val_mining)
	UITheme.style_recursive(self)
	
	_load_current_values()

func _connect_slider(slider: HSlider, label: Label) -> void:
	if slider and label:
		slider.value_changed.connect(func(val: float):
			label.text = str(int(val))
		)

func open() -> void:
	visible = true
	_load_current_values()
	get_tree().paused = true

func close() -> void:
	visible = false
	if GameManager.current_state == GameManager.GameState.PLAYING:
		get_tree().paused = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("customizer"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			if visible:
				close()
			else:
				open()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible:
			close()
			get_viewport().set_input_as_handled()

func _load_current_values() -> void:
	var json: Variant = IslandCustomizer.load_layout()
	if json.is_empty():
		return
	if typeof(json) == TYPE_DICTIONARY:
		var island_s: Dictionary = json.get("island_settings", {})
		if slider_radius:
			slider_radius.value = island_s.get("base_radius", 16800.0)
			if val_radius: val_radius.text = str(int(slider_radius.value))
		
		var dens_s: Dictionary = json.get("density_settings", {})
		if slider_trees:
			slider_trees.value = dens_s.get("tree_count", 350)
			if val_trees: val_trees.text = str(int(slider_trees.value))
		if slider_flowers:
			slider_flowers.value = dens_s.get("flower_count", 220)
			if val_flowers: val_flowers.text = str(int(slider_flowers.value))
		if slider_rocks:
			slider_rocks.value = dens_s.get("rock_clusters", 24)
			if val_rocks: val_rocks.text = str(int(slider_rocks.value))
		if slider_rabbits:
			slider_rabbits.value = dens_s.get("wildlife_rabbits", 28)
			if val_rabbits: val_rabbits.text = str(int(slider_rabbits.value))
		if slider_deer:
			slider_deer.value = dens_s.get("wildlife_deer", 20)
			if val_deer: val_deer.text = str(int(slider_deer.value))
		if slider_birds:
			slider_birds.value = dens_s.get("wildlife_birds", 30)
			if val_birds: val_birds.text = str(int(slider_birds.value))
		if slider_mining:
			slider_mining.value = dens_s.get("mining_nodes", 32)
			if val_mining: val_mining.text = str(int(slider_mining.value))

func _on_apply() -> void:
	var base_r: float = slider_radius.value if slider_radius else 16800.0
	var config := {
		"island_settings": {
			"base_radius": base_r,
			"beach_radius": base_r + 1700.0,
			"water_rim_radius": base_r + 3000.0,
			"ocean_boundary": base_r * 2.1,
			"village_radius": 800.0
		},
		"density_settings": {
			"tree_count": int(slider_trees.value if slider_trees else 350),
			"rock_clusters": int(slider_rocks.value if slider_rocks else 24),
			"flower_count": int(slider_flowers.value if slider_flowers else 220),
			"wildlife_rabbits": int(slider_rabbits.value if slider_rabbits else 28),
			"wildlife_deer": int(slider_deer.value if slider_deer else 20),
			"wildlife_birds": int(slider_birds.value if slider_birds else 30),
			"material_wood": 60,
			"material_herb": 60,
			"material_mushroom": 50,
			"mining_nodes": int(slider_mining.value if slider_mining else 32)
		},
		"village": {
			"campfire_pos": {"x": 0.0, "y": 0.0},
			"tree_ring_radius": 780.0,
			"tree_ring_count": 36,
			"houses": [
				{"id": "house1", "pos": {"x": -350.0, "y": -260.0}},
				{"id": "house2", "pos": {"x": 350.0, "y": -260.0}},
				{"id": "house3", "pos": {"x": -350.0, "y": 280.0}},
				{"id": "house4", "pos": {"x": 350.0, "y": 280.0}}
			],
			"npcs": [
				{"id": "elder", "name": "Village Elder", "quest_id": "slay_slimes", "pos": {"x": -140.0, "y": -100.0}, "type": 9},
				{"id": "carpenter", "name": "Carpenter", "quest_id": "gather_wood", "pos": {"x": 260.0, "y": -100.0}, "type": 10},
				{"id": "cook", "name": "Chef Maria", "quest_id": "first_meal", "pos": {"x": 100.0, "y": 50.0}, "type": 11},
				{"id": "miner", "name": "Miner Torvald", "quest_id": "explore_cave", "pos": {"x": -60.0, "y": -380.0}, "type": 12}
			]
		}
	}
	
	var file := FileAccess.open(USER_CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(config, "\t"))
		file.close()
	else:
		# Exported/web builds: res:// is read-only. Keep the in-memory
		# regenerate so the session still updates, and tell the player.
		EventBus.show_notification.emit("Island updated for this session (could not save file).")
	
	var world_gen := get_tree().root.find_child("WorldGenerator", true, false) as WorldGenerator
	if world_gen:
		world_gen.regenerate_world(config)
	
	EventBus.show_notification.emit("Island Layout Updated & Regenerated!")
	close()

func _on_reset() -> void:
	if slider_radius: slider_radius.value = 16800.0
	if slider_trees: slider_trees.value = 350.0
	if slider_flowers: slider_flowers.value = 220.0
	if slider_rocks: slider_rocks.value = 24.0
	if slider_rabbits: slider_rabbits.value = 28.0
	if slider_deer: slider_deer.value = 20.0
	if slider_birds: slider_birds.value = 30.0
	if slider_mining: slider_mining.value = 32.0
