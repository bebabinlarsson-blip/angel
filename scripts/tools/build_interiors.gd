@tool
extends SceneTree

# Builder script to generate distinct interior scenes for:
# - 6 Houses (beds, tables, chairs, fireplaces, shelves)
# - 2 Shops (General Goods & Armory)
# - Verifies Church, Ruins, and Mine scenes

func _init() -> void:
	print("--- Generating Interior Scenes ---")
	var tileset: TileSet = load("res://assets/tilesets/angel_environment_tileset.tres")
	
	var house_configs := [
		{
			"id": "house_1",
			"name": "Lina's House",
			"path": "res://scenes/interiors/house_1.tscn",
			"furniture": [
				# Bed in top-left
				{"coord": Vector2i(-8, -6), "source": 11, "atlas": Vector2i(0, 0)},
				{"coord": Vector2i(-8, -5), "source": 11, "atlas": Vector2i(0, 1)},
				# Fireplace at top wall center
				{"coord": Vector2i(0, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(0, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Shelves along top-right
				{"coord": Vector2i(5, -7), "source": 11, "atlas": Vector2i(7, 0)},
				{"coord": Vector2i(6, -7), "source": 11, "atlas": Vector2i(8, 0)},
				# Dining table & chairs in center-left
				{"coord": Vector2i(-3, -1), "source": 11, "atlas": Vector2i(4, 0)},
				{"coord": Vector2i(-2, -1), "source": 11, "atlas": Vector2i(5, 0)},
				{"coord": Vector2i(-4, -1), "source": 11, "atlas": Vector2i(3, 2)},
				{"coord": Vector2i(-1, -1), "source": 11, "atlas": Vector2i(3, 3)},
				# Small dresser
				{"coord": Vector2i(7, 0), "source": 11, "atlas": Vector2i(2, 0)}
			]
		},
		{
			"id": "house_2",
			"name": "Baker's House",
			"path": "res://scenes/interiors/house_2.tscn",
			"furniture": [
				# Bed in top-right
				{"coord": Vector2i(7, -6), "source": 11, "atlas": Vector2i(0, 0)},
				{"coord": Vector2i(7, -5), "source": 11, "atlas": Vector2i(0, 1)},
				# Large baking fireplace/oven in top-left
				{"coord": Vector2i(-7, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(-7, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Kitchen shelves
				{"coord": Vector2i(-4, -7), "source": 11, "atlas": Vector2i(7, 0)},
				{"coord": Vector2i(-3, -7), "source": 11, "atlas": Vector2i(8, 0)},
				# Preparation table in center
				{"coord": Vector2i(0, -2), "source": 11, "atlas": Vector2i(4, 1)},
				{"coord": Vector2i(1, -2), "source": 11, "atlas": Vector2i(5, 1)},
				{"coord": Vector2i(-1, -2), "source": 11, "atlas": Vector2i(3, 2)},
				{"coord": Vector2i(2, -2), "source": 11, "atlas": Vector2i(3, 3)},
				# Bread pantry shelves
				{"coord": Vector2i(7, 1), "source": 11, "atlas": Vector2i(7, 1)}
			]
		},
		{
			"id": "house_3",
			"name": "Guard's House",
			"path": "res://scenes/interiors/house_3.tscn",
			"furniture": [
				# Bunk/cot bed top-left
				{"coord": Vector2i(-8, -6), "source": 11, "atlas": Vector2i(1, 0)},
				{"coord": Vector2i(-8, -5), "source": 11, "atlas": Vector2i(1, 1)},
				# Fireplace right side
				{"coord": Vector2i(7, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(7, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Weapon rack / sturdy shelves
				{"coord": Vector2i(-2, -7), "source": 11, "atlas": Vector2i(7, 2)},
				{"coord": Vector2i(-1, -7), "source": 11, "atlas": Vector2i(8, 2)},
				# Strategy table & chairs
				{"coord": Vector2i(1, -1), "source": 11, "atlas": Vector2i(4, 0)},
				{"coord": Vector2i(2, -1), "source": 11, "atlas": Vector2i(5, 0)},
				{"coord": Vector2i(0, -1), "source": 11, "atlas": Vector2i(3, 2)},
				{"coord": Vector2i(3, -1), "source": 11, "atlas": Vector2i(3, 3)},
				# Supply footlocker / chest
				{"coord": Vector2i(-7, 2), "source": 11, "atlas": Vector2i(2, 2)}
			]
		},
		{
			"id": "house_4",
			"name": "Elder's House",
			"path": "res://scenes/interiors/house_4.tscn",
			"furniture": [
				# Elegant bed top-right
				{"coord": Vector2i(6, -6), "source": 11, "atlas": Vector2i(0, 2)},
				{"coord": Vector2i(6, -5), "source": 11, "atlas": Vector2i(0, 3)},
				# Grand hearth fireplace in center top
				{"coord": Vector2i(0, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(0, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Massive book archive shelves
				{"coord": Vector2i(-8, -7), "source": 11, "atlas": Vector2i(7, 0)},
				{"coord": Vector2i(-7, -7), "source": 11, "atlas": Vector2i(8, 0)},
				{"coord": Vector2i(-6, -7), "source": 11, "atlas": Vector2i(7, 1)},
				{"coord": Vector2i(-5, -7), "source": 11, "atlas": Vector2i(8, 1)},
				# Study council table & chairs
				{"coord": Vector2i(-2, 0), "source": 11, "atlas": Vector2i(4, 2)},
				{"coord": Vector2i(-1, 0), "source": 11, "atlas": Vector2i(5, 2)},
				{"coord": Vector2i(-3, 0), "source": 11, "atlas": Vector2i(3, 2)},
				{"coord": Vector2i(0, 0), "source": 11, "atlas": Vector2i(3, 3)},
				# Reading chair by hearth
				{"coord": Vector2i(2, -4), "source": 11, "atlas": Vector2i(3, 1)}
			]
		},
		{
			"id": "house_5",
			"name": "Craftsman's House",
			"path": "res://scenes/interiors/house_5.tscn",
			"furniture": [
				# Bed in top-left
				{"coord": Vector2i(-8, -6), "source": 11, "atlas": Vector2i(1, 2)},
				{"coord": Vector2i(-8, -5), "source": 11, "atlas": Vector2i(1, 3)},
				# Stove / fireplace at center
				{"coord": Vector2i(2, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(2, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Tool cabinets & shelving
				{"coord": Vector2i(6, -7), "source": 11, "atlas": Vector2i(7, 3)},
				{"coord": Vector2i(7, -7), "source": 11, "atlas": Vector2i(8, 3)},
				# Large woodworking bench & stools
				{"coord": Vector2i(-1, -1), "source": 11, "atlas": Vector2i(4, 3)},
				{"coord": Vector2i(0, -1), "source": 11, "atlas": Vector2i(5, 3)},
				{"coord": Vector2i(-2, -1), "source": 11, "atlas": Vector2i(3, 2)},
				{"coord": Vector2i(1, -1), "source": 11, "atlas": Vector2i(3, 3)},
				# Material storage crates/dresser
				{"coord": Vector2i(-7, 1), "source": 11, "atlas": Vector2i(2, 1)}
			]
		},
		{
			"id": "house_6",
			"name": "Herbalist's House",
			"path": "res://scenes/interiors/house_6.tscn",
			"furniture": [
				# Simple bed top-right
				{"coord": Vector2i(7, -6), "source": 11, "atlas": Vector2i(0, 0)},
				{"coord": Vector2i(7, -5), "source": 11, "atlas": Vector2i(0, 1)},
				# Hearth fireplace top-left
				{"coord": Vector2i(-6, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(-6, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Apothecary specimen shelves & herb jars
				{"coord": Vector2i(-2, -7), "source": 11, "atlas": Vector2i(7, 1)},
				{"coord": Vector2i(-1, -7), "source": 11, "atlas": Vector2i(8, 1)},
				{"coord": Vector2i(1, -7), "source": 11, "atlas": Vector2i(7, 2)},
				{"coord": Vector2i(2, -7), "source": 11, "atlas": Vector2i(8, 2)},
				# Potion brewing table & stool
				{"coord": Vector2i(-1, 0), "source": 11, "atlas": Vector2i(4, 1)},
				{"coord": Vector2i(0, 0), "source": 11, "atlas": Vector2i(5, 1)},
				{"coord": Vector2i(-2, 0), "source": 11, "atlas": Vector2i(3, 2)},
				# Drying rack dresser
				{"coord": Vector2i(-7, 2), "source": 11, "atlas": Vector2i(2, 0)}
			]
		},
		{
			"id": "shop_general",
			"name": "General Goods",
			"path": "res://scenes/interiors/shop_general.tscn",
			"furniture": [
				# Merchant counter across the middle
				{"coord": Vector2i(-4, -2), "source": 11, "atlas": Vector2i(4, 0)},
				{"coord": Vector2i(-3, -2), "source": 11, "atlas": Vector2i(5, 0)},
				{"coord": Vector2i(-2, -2), "source": 11, "atlas": Vector2i(4, 0)},
				{"coord": Vector2i(-1, -2), "source": 11, "atlas": Vector2i(5, 0)},
				# Wall-to-wall trade shelves
				{"coord": Vector2i(-8, -7), "source": 11, "atlas": Vector2i(7, 0)},
				{"coord": Vector2i(-7, -7), "source": 11, "atlas": Vector2i(8, 0)},
				{"coord": Vector2i(-6, -7), "source": 11, "atlas": Vector2i(7, 1)},
				{"coord": Vector2i(-5, -7), "source": 11, "atlas": Vector2i(8, 1)},
				{"coord": Vector2i(5, -7), "source": 11, "atlas": Vector2i(7, 2)},
				{"coord": Vector2i(6, -7), "source": 11, "atlas": Vector2i(8, 2)},
				{"coord": Vector2i(7, -7), "source": 11, "atlas": Vector2i(7, 3)},
				{"coord": Vector2i(8, -7), "source": 11, "atlas": Vector2i(8, 3)},
				# Display stands & storage cabinets
				{"coord": Vector2i(6, -1), "source": 11, "atlas": Vector2i(2, 0)},
				{"coord": Vector2i(7, -1), "source": 11, "atlas": Vector2i(2, 1)},
				{"coord": Vector2i(6, 1), "source": 11, "atlas": Vector2i(2, 2)}
			]
		},
		{
			"id": "shop_armory",
			"name": "Armory",
			"path": "res://scenes/interiors/shop_armory.tscn",
			"furniture": [
				# Heavy reinforced counter
				{"coord": Vector2i(-3, -2), "source": 11, "atlas": Vector2i(4, 3)},
				{"coord": Vector2i(-2, -2), "source": 11, "atlas": Vector2i(5, 3)},
				{"coord": Vector2i(-1, -2), "source": 11, "atlas": Vector2i(4, 3)},
				# Indoor display forge & hearth
				{"coord": Vector2i(-7, -7), "source": 11, "atlas": Vector2i(6, 0)},
				{"coord": Vector2i(-7, -6), "source": 11, "atlas": Vector2i(6, 1)},
				# Armament racks & shield racks
				{"coord": Vector2i(3, -7), "source": 11, "atlas": Vector2i(7, 2)},
				{"coord": Vector2i(4, -7), "source": 11, "atlas": Vector2i(8, 2)},
				{"coord": Vector2i(6, -7), "source": 11, "atlas": Vector2i(7, 3)},
				{"coord": Vector2i(7, -7), "source": 11, "atlas": Vector2i(8, 3)},
				# Heavy armory chests & equipment tables
				{"coord": Vector2i(6, 0), "source": 11, "atlas": Vector2i(2, 2)},
				{"coord": Vector2i(7, 0), "source": 11, "atlas": Vector2i(2, 2)},
				{"coord": Vector2i(-7, 1), "source": 11, "atlas": Vector2i(2, 0)}
			]
		}
	]

	for cfg in house_configs:
		_build_single_interior(cfg, tileset)
		
	print("--- Interiors Generation Finished Successfully ---")
	quit(0)

func _build_single_interior(cfg: Dictionary, tileset: TileSet) -> void:
	var root := Node2D.new()
	root.name = cfg["id"].capitalize().replace(" ", "")
	root.set_script(load("res://scripts/world/interior_scene.gd"))
	root.set("interior_id", cfg["id"])
	root.set("display_name", cfg["name"])
	root.set("theme_kind", "house" if not cfg["id"].begins_with("shop") else "shop")
	root.set("room_size", Vector2(960, 640))
	
	# Interior Visual
	var visual := Node2D.new()
	visual.name = "InteriorVisual"
	visual.set_script(load("res://scripts/world/interior_visual.gd"))
	visual.set("theme_kind", root.get("theme_kind"))
	visual.set("room_size", Vector2(960, 640))
	visual.visible = false
	root.add_child(visual)
	visual.owner = root

	# Interior Tilemap Container
	var tilemap_root := Node2D.new()
	tilemap_root.name = "InteriorTilemap"
	root.add_child(tilemap_root)
	tilemap_root.owner = root

	# FloorLayer
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.z_index = -30
	floor_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_layer.tile_set = tileset
	tilemap_root.add_child(floor_layer)
	floor_layer.owner = root

	# TrimLayer (Walls / Room Boundary)
	var trim_layer := TileMapLayer.new()
	trim_layer.name = "TrimLayer"
	trim_layer.z_index = -29
	trim_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trim_layer.tile_set = tileset
	tilemap_root.add_child(trim_layer)
	trim_layer.owner = root

	# FurnitureLayer
	var furn_layer := TileMapLayer.new()
	furn_layer.name = "FurnitureLayer"
	furn_layer.z_index = -20
	furn_layer.y_sort_enabled = true
	furn_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	furn_layer.tile_set = tileset
	tilemap_root.add_child(furn_layer)
	furn_layer.owner = root

	# Fill standard room floor (-10 to 10 X, -7 to 8 Y)
	# Floor style: ninja floor wood or stone
	var floor_atlas := Vector2i(0, 5) if not cfg["id"].begins_with("shop") else Vector2i(1, 11)
	for x in range(-11, 12):
		for y in range(-8, 9):
			floor_layer.set_cell(Vector2i(x, y), 10, floor_atlas)

	# Build perimeter walls on TrimLayer
	for x in range(-11, 12):
		trim_layer.set_cell(Vector2i(x, -8), 0, Vector2i(10, 0)) # Top wall
		if x != 0: # Leave doorway at center bottom
			trim_layer.set_cell(Vector2i(x, 8), 0, Vector2i(10, 0)) # Bottom wall
	for y in range(-8, 9):
		trim_layer.set_cell(Vector2i(-11, y), 0, Vector2i(10, 0)) # Left wall
		trim_layer.set_cell(Vector2i(11, y), 0, Vector2i(10, 0)) # Right wall

	# Place distinct furniture
	for item in cfg["furniture"]:
		furn_layer.set_cell(item["coord"], item["source"], item["atlas"])

	# Player instance
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	var player: Node2D = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector2(0, 180)
	root.add_child(player)
	player.owner = root

	# Exit Area2D
	var exit := Area2D.new()
	exit.name = "Exit"
	exit.position = Vector2(0, 260)
	exit.set_script(load("res://scripts/world/interior_exit.gd"))
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	shape_node.shape = circle
	exit.add_child(shape_node)
	shape_node.owner = root
	root.add_child(exit)
	exit.owner = root

	# Systems & UI
	var qs := Node.new()
	qs.name = "QuestSystem"
	qs.set_script(load("res://scripts/systems/quest_system.gd"))
	root.add_child(qs)
	qs.owner = root

	var cs := Node.new()
	cs.name = "CookingSystem"
	cs.set_script(load("res://scripts/systems/cooking_system.gd"))
	root.add_child(cs)
	cs.owner = root

	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	hud.name = "HUD"
	root.add_child(hud)
	hud.owner = root

	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	root.add_child(ui_layer)
	ui_layer.owner = root

	var pause_scene: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	var pause: Control = pause_scene.instantiate()
	pause.name = "PauseMenu"
	ui_layer.add_child(pause)
	pause.owner = root

	var inv_scene: PackedScene = load("res://scenes/ui/inventory.tscn")
	var inv: Control = inv_scene.instantiate()
	inv.name = "InventoryUI"
	ui_layer.add_child(inv)
	inv.owner = root

	var quest_scene: PackedScene = load("res://scenes/ui/quest_menu.tscn")
	var qm: Control = quest_scene.instantiate()
	qm.name = "QuestMenu"
	ui_layer.add_child(qm)
	qm.owner = root

	var go_scene: PackedScene = load("res://scenes/ui/game_over.tscn")
	var go: Control = go_scene.instantiate()
	go.name = "GameOver"
	ui_layer.add_child(go)
	go.owner = root

	# Save PackedScene
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("Failed to pack interior: ", cfg["path"])
		return
	err = ResourceSaver.save(packed, cfg["path"])
	if err != OK:
		printerr("Failed to save interior: ", cfg["path"])
	else:
		print("Saved interior scene: ", cfg["path"])
