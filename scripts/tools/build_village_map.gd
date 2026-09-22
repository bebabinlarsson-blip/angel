@tool
extends SceneTree

# Builder script to generate the entire authored village environment according to requirements:
# 1. TileMap Layer Assignment Hierarchy (GroundLayer, RoadLayer, HouseLayer, DecorationLayer, CollisionLayer, TriggerLayer)
# 2. Map & Environment Contents (64x64+ grid, Village ring with Fountain, 2 Shops, Market with 4 stalls, Blacksmith with forge/anvil/table, 6 Houses, Fences with 3 gates, North Ruins, West Church, East Mine)
# 3. Hitboxes on CollisionLayer, 1x1 Tile Triggers on TriggerLayer (11 entrances)

func _init() -> void:
	print("--- Starting Village Map Generation ---")
	var tileset: TileSet = load("res://assets/tilesets/angel_environment_tileset.tres")
	
	var root := Node2D.new()
	root.name = "AuthoredEnvironment"
	root.set_meta("authored_tileset", "res://assets/tilesets/angel_environment_tileset.tres")
	root.set_meta("map_grid_size", "68x68 tiles (expanded ring)")

	# 1. GroundLayer (Grass, dirt paths, water, cliffs)
	var ground_layer := TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -100
	ground_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_layer.tile_set = tileset
	root.add_child(ground_layer)
	ground_layer.owner = root

	# 2. RoadLayer (Paved cobblestone, dirt tracks, stone plazas)
	var road_layer := TileMapLayer.new()
	road_layer.name = "RoadLayer"
	road_layer.z_index = -90
	road_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	road_layer.tile_set = tileset
	root.add_child(road_layer)
	road_layer.owner = root

	# 3. HouseLayer (Main exterior walls, roofs, chimneys, static building structures)
	var house_layer := TileMapLayer.new()
	house_layer.name = "HouseLayer"
	house_layer.z_index = -50
	house_layer.y_sort_enabled = true
	house_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	house_layer.tile_set = tileset
	root.add_child(house_layer)
	house_layer.owner = root

	# 4. DecorationLayer (Fencing, street lamps, market stalls, barrels, signs, interior furniture)
	var decor_layer := TileMapLayer.new()
	decor_layer.name = "DecorationLayer"
	decor_layer.z_index = -40
	decor_layer.y_sort_enabled = true
	decor_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	decor_layer.tile_set = tileset
	root.add_child(decor_layer)
	decor_layer.owner = root

	# 5. CollisionLayer (Hard physical hitboxes for all solid structures, props, and trees)
	var collision_layer := StaticBody2D.new()
	collision_layer.name = "CollisionLayer"
	collision_layer.collision_layer = 1
	collision_layer.collision_mask = 1
	root.add_child(collision_layer)
	collision_layer.owner = root

	# 6. TriggerLayer (Interactive sensor zones placed over building entryways)
	var trigger_layer := Node2D.new()
	trigger_layer.name = "TriggerLayer"
	root.add_child(trigger_layer)
	trigger_layer.owner = root

	# ----------------------------------------------------
	# POPULATE GROUND LAYER (68x68 tiles: -34 to +33)
	# ----------------------------------------------------
	print("Populating GroundLayer (68x68 tiles)...")
	for x in range(-34, 34):
		for y in range(-34, 34):
			# Base lush grass (Source 14)
			var grass_atlas := Vector2i(0, 0)
			if (abs(x) + abs(y)) % 7 == 0:
				grass_atlas = Vector2i(1, 0) # subtle flower/tuft
			elif (x * 3 + y * 5) % 11 == 0:
				grass_atlas = Vector2i(2, 0) # grass variant
			ground_layer.set_cell(Vector2i(x, y), 14, grass_atlas)

	# South-East Village Pond (Water: Source 13)
	for px in range(12, 18):
		for py in range(9, 14):
			ground_layer.set_cell(Vector2i(px, py), 13, Vector2i(0, 0))

	# ----------------------------------------------------
	# POPULATE ROAD LAYER (Paved cobblestone & dirt paths)
	# ----------------------------------------------------
	print("Populating RoadLayer...")
	# Central Hub Cobblestone Plaza (-4 to 4 X, -4 to 4 Y)
	for x in range(-4, 5):
		for y in range(-4, 5):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# North Avenue: (0, -4) to (0, -15) - 3 tiles wide (X: -1 to 1)
	for y in range(-15, -4):
		for x in range(-1, 2):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# South Avenue: (0, 4) to (0, 15) - 3 tiles wide (X: -1 to 1)
	for y in range(5, 16):
		for x in range(-1, 2):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# West Avenue: (-4, 0) to (-15, 0) - 3 tiles wide (Y: -1 to 1) through Market
	for x in range(-15, -4):
		for y in range(-1, 2):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# East Avenue: (4, 0) to (15, 0) - 3 tiles wide (Y: -1 to 1) past Blacksmith
	for x in range(5, 16):
		for y in range(-1, 2):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# Secondary connecting pathways:
	# Market Square cobblestone plaza (-9 to -5 X, -3 to 3 Y)
	for x in range(-9, -4):
		for y in range(-3, 4):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# North-East path to House 2: (1 to 8 X, -8 Y)
	for x in range(1, 9):
		road_layer.set_cell(Vector2i(x, -8), 12, Vector2i(1, 1))

	# East-Central path to House 3 & House 5: (8 to 11 X, -1 to 5 Y)
	for y in range(-1, 6):
		road_layer.set_cell(Vector2i(8, y), 12, Vector2i(1, 1))
	road_layer.set_cell(Vector2i(9, -1), 12, Vector2i(1, 1))
	road_layer.set_cell(Vector2i(10, -1), 12, Vector2i(1, 1))
	road_layer.set_cell(Vector2i(9, 5), 12, Vector2i(1, 1))
	road_layer.set_cell(Vector2i(10, 5), 12, Vector2i(1, 1))

	# West path to House 6: (-12 to -9 X, 2 Y)
	for x in range(-12, -8):
		road_layer.set_cell(Vector2i(x, 2), 12, Vector2i(1, 1))

	# Paths to Shops:
	# General Goods: (-8 X, -4 to -1 Y)
	for y in range(-4, -1):
		road_layer.set_cell(Vector2i(-8, y), 12, Vector2i(1, 1))
	# Armory: (-8 X, 1 to 4 Y)
	for y in range(1, 5):
		road_layer.set_cell(Vector2i(-8, y), 12, Vector2i(1, 1))

	# Blacksmith work court: (5 to 8 X, 2 to 4 Y)
	for x in range(5, 9):
		for y in range(2, 5):
			road_layer.set_cell(Vector2i(x, y), 12, Vector2i(1, 1))

	# Outside Leads (Tracks / Roads):
	# North Lead (to Ancient Ruins): from (0, -15) to (0, -26)
	for y in range(-26, -15):
		road_layer.set_cell(Vector2i(0, y), 12, Vector2i(2, 1))
		road_layer.set_cell(Vector2i(-1, y), 12, Vector2i(2, 1))

	# West Lead (to Old Church): from (-15, 0) to (-26, 0)
	for x in range(-26, -15):
		road_layer.set_cell(Vector2i(x, 0), 12, Vector2i(2, 1))
		road_layer.set_cell(Vector2i(x, -1), 12, Vector2i(2, 1))

	# East Lead (to Abandoned Mines): from (15, 0) to (26, 0)
	for x in range(15, 27):
		road_layer.set_cell(Vector2i(x, 0), 12, Vector2i(2, 1))
		road_layer.set_cell(Vector2i(x, 1), 12, Vector2i(2, 1))

	# ----------------------------------------------------
	# POPULATE HOUSE LAYER (Walls, roofs, chimneys)
	# ----------------------------------------------------
	print("Populating HouseLayer...")
	# Helper lambda to build wooden houses
	var build_house = func(start_x: int, start_y: int, w: int, h: int, door_x: int, has_chimney: bool):
		for x in range(start_x, start_x + w):
			# Roof top row
			house_layer.set_cell(Vector2i(x, start_y), 19, Vector2i(1, 0))
			# Roof bottom row
			house_layer.set_cell(Vector2i(x, start_y + 1), 19, Vector2i(1, 1))
			# Wall rows
			for y in range(start_y + 2, start_y + h):
				if y == start_y + h - 1 and x == door_x:
					house_layer.set_cell(Vector2i(x, y), 19, Vector2i(1, 3)) # Door tile
				else:
					house_layer.set_cell(Vector2i(x, y), 19, Vector2i(1, 2)) # Wall / window
		if has_chimney:
			house_layer.set_cell(Vector2i(start_x + w - 1, start_y - 1), 19, Vector2i(3, 0))

	# 1. House 1 (Lina's House - North): 5x4 at (-2, -13)
	build_house.call(-2, -13, 5, 4, 0, true)
	# 2. House 2 (Baker's House - North-East): 5x4 at (6, -12)
	build_house.call(6, -12, 5, 4, 8, true)
	# 3. House 3 (Guard's House - East): 5x4 at (8, -5)
	build_house.call(8, -5, 5, 4, 10, false)
	# 4. House 4 (Elder's House - South): 5x4 at (-2, 9)
	build_house.call(-2, 9, 5, 4, 0, true)
	# 5. House 5 (Craftsman's House - East-Central): 5x4 at (8, 1)
	build_house.call(8, 1, 5, 4, 10, false)
	# 6. House 6 (Herbalist's House - West): 5x4 at (-13, -1)
	build_house.call(-13, -1, 5, 4, -11, true)

	# 7. General Goods Shop (-10, -8, 5x4)
	build_house.call(-10, -8, 5, 4, -8, true)
	# 8. Armory Shop (-10, 5, 5x4)
	build_house.call(-10, 5, 5, 4, -8, true)
	# 9. Blacksmith Building (5, 5, 5x4)
	build_house.call(5, 5, 5, 4, 7, true)

	# Outside Landmark Structures on HouseLayer:
	# North: Ancient Ruins (-2 to 2 X, -26 to -23 Y)
	for x in range(-2, 3):
		for y in range(-26, -23):
			house_layer.set_cell(Vector2i(x, y), 0, Vector2i(21, 0)) # Stone ruins masonry

	# West: Old Church (-26 to -21 X, -2 to 2 Y)
	for x in range(-26, -21):
		for y in range(-2, 3):
			house_layer.set_cell(Vector2i(x, y), 0, Vector2i(18, 0)) # Church stone wall

	# East: Abandoned Mines (21 to 26 X, -2 to 2 Y)
	for x in range(21, 27):
		for y in range(-2, 3):
			house_layer.set_cell(Vector2i(x, y), 0, Vector2i(23, 0)) # Mine cavern stone

	# ----------------------------------------------------
	# POPULATE DECORATION LAYER (Fencing, lamps, stalls, fountain, props)
	# ----------------------------------------------------
	print("Populating DecorationLayer...")
	# Central Hub: Stone Fountain 2x2 at (0, 0)
	decor_layer.set_cell(Vector2i(-1, -1), 0, Vector2i(10, 5))
	decor_layer.set_cell(Vector2i(0, -1), 0, Vector2i(11, 5))
	decor_layer.set_cell(Vector2i(-1, 0), 0, Vector2i(10, 6))
	decor_layer.set_cell(Vector2i(0, 0), 0, Vector2i(11, 6))

	# Plaza Benches & Lamps:
	decor_layer.set_cell(Vector2i(0, -3), 11, Vector2i(3, 2))  # Bench North
	decor_layer.set_cell(Vector2i(0, 3), 11, Vector2i(3, 2))   # Bench South
	decor_layer.set_cell(Vector2i(-3, 0), 11, Vector2i(3, 3))  # Bench West
	decor_layer.set_cell(Vector2i(3, 0), 11, Vector2i(3, 3))   # Bench East

	# Street lamps at plaza corners:
	decor_layer.set_cell(Vector2i(-3, -3), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(3, -3), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(-3, 3), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(3, 3), 0, Vector2i(5, 4))

	# Water Well & Bulletin Board:
	decor_layer.set_cell(Vector2i(2, -2), 0, Vector2i(7, 4))  # Water well
	decor_layer.set_cell(Vector2i(-2, -2), 0, Vector2i(6, 4)) # Bulletin board

	# Market Square (4 Vendor Stalls):
	# Stall 1 (Produce): (-8, -2)
	decor_layer.set_cell(Vector2i(-8, -2), 0, Vector2i(15, 2))
	decor_layer.set_cell(Vector2i(-7, -2), 0, Vector2i(16, 2))
	# Stall 2 (Herbs): (-6, -2)
	decor_layer.set_cell(Vector2i(-6, -2), 0, Vector2i(15, 3))
	decor_layer.set_cell(Vector2i(-5, -2), 0, Vector2i(16, 3))
	# Stall 3 (Fish/Meat): (-8, 2)
	decor_layer.set_cell(Vector2i(-8, 2), 0, Vector2i(15, 2))
	decor_layer.set_cell(Vector2i(-7, 2), 0, Vector2i(16, 2))
	# Stall 4 (Trinkets): (-6, 2)
	decor_layer.set_cell(Vector2i(-6, 2), 0, Vector2i(15, 3))
	decor_layer.set_cell(Vector2i(-5, 2), 0, Vector2i(16, 3))

	# Market crates and barrels:
	decor_layer.set_cell(Vector2i(-9, -2), 0, Vector2i(8, 2))
	decor_layer.set_cell(Vector2i(-9, 2), 0, Vector2i(8, 3))
	decor_layer.set_cell(Vector2i(-4, -2), 0, Vector2i(9, 2))
	decor_layer.set_cell(Vector2i(-4, 2), 0, Vector2i(9, 3))

	# Blacksmith Exterior Workshop:
	# Forge at (6, 3)
	decor_layer.set_cell(Vector2i(6, 3), 27, Vector2i(0, 0))
	# Anvil at (8, 3)
	decor_layer.set_cell(Vector2i(8, 3), 0, Vector2i(12, 4))
	# Blacksmith Table at (7, 2)
	decor_layer.set_cell(Vector2i(7, 2), 11, Vector2i(4, 3))

	# Wooden Perimeter Fence Ring (~15 tiles radius):
	# Build circular fence with 3 gates (North at 0,-15; West at -15,0; East at 15,0)
	var fence_radius := 15.0
	for deg in range(0, 360, 4):
		var rad := deg_to_rad(float(deg))
		var fx := int(round(cos(rad) * fence_radius))
		var fy := int(round(sin(rad) * fence_radius))
		# Gates openings:
		if abs(fx) <= 1 and fy <= -14:
			continue # North Gate opening
		if fx <= -14 and abs(fy) <= 1:
			continue # West Gate opening
		if fx >= 14 and abs(fy) <= 1:
			continue # East Gate opening
		decor_layer.set_cell(Vector2i(fx, fy), 17, Vector2i(1, 0))

	# Gate Street Lamps:
	decor_layer.set_cell(Vector2i(-2, -15), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(2, -15), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(-15, -2), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(-15, 2), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(15, -2), 0, Vector2i(5, 4))
	decor_layer.set_cell(Vector2i(15, 2), 0, Vector2i(5, 4))

	# Outside Landmark Decor:
	# North Ancient Ruins (stone altar at 0,-25, pillars, arches)
	decor_layer.set_cell(Vector2i(0, -25), 0, Vector2i(14, 5)) # Stone altar
	decor_layer.set_cell(Vector2i(-2, -24), 0, Vector2i(13, 5)) # Broken pillar left
	decor_layer.set_cell(Vector2i(2, -24), 0, Vector2i(13, 5))  # Broken pillar right
	decor_layer.set_cell(Vector2i(-1, -26), 0, Vector2i(14, 4)) # Overgrown arch
	decor_layer.set_cell(Vector2i(1, -26), 0, Vector2i(14, 4))

	# West Old Church (bell tower, stained glass, wooden pews)
	decor_layer.set_cell(Vector2i(-24, -3), 0, Vector2i(18, 2)) # Bell tower top
	decor_layer.set_cell(Vector2i(-23, -1), 11, Vector2i(3, 2)) # Wooden pew
	decor_layer.set_cell(Vector2i(-23, 1), 11, Vector2i(3, 2))  # Wooden pew
	decor_layer.set_cell(Vector2i(-25, 0), 0, Vector2i(19, 1))  # Stained glass window

	# East Abandoned Mines (timber supports, minecart tracks)
	decor_layer.set_cell(Vector2i(22, -1), 18, Vector2i(1, 0)) # Timber support
	decor_layer.set_cell(Vector2i(22, 1), 18, Vector2i(1, 0))
	decor_layer.set_cell(Vector2i(23, 0), 0, Vector2i(15, 4))  # Minecart tracks
	decor_layer.set_cell(Vector2i(24, 0), 0, Vector2i(15, 4))

	# ----------------------------------------------------
	# POPULATE COLLISION LAYER (Hard hitboxes for solid objects)
	# ----------------------------------------------------
	print("Populating CollisionLayer hitboxes...")
	var add_box_collider = func(center_pos: Vector2, size: Vector2, col_name: String):
		var shape_node := CollisionShape2D.new()
		shape_node.name = col_name
		shape_node.position = center_pos
		var box := RectangleShape2D.new()
		box.size = size
		shape_node.shape = box
		collision_layer.add_child(shape_node)
		shape_node.owner = root

	# 1. Central Fountain Base Hitbox (64x64 at pos -8, -8)
	add_box_collider.call(Vector2(-8, -8), Vector2(64, 64), "Col_Fountain")

	# 2. House Walls Hitboxes (allowing door passage):
	# House 1: (-2 to 2 X, -13 to -10 Y) -> pos (0, -368), size (160, 96)
	add_box_collider.call(Vector2(0, -384), Vector2(160, 96), "Col_House_1")
	# House 2: (6 to 10 X, -12 to -9 Y) -> pos (256, -336)
	add_box_collider.call(Vector2(256, -352), Vector2(160, 96), "Col_House_2")
	# House 3: (8 to 12 X, -5 to -2 Y) -> pos (320, -112)
	add_box_collider.call(Vector2(320, -128), Vector2(160, 96), "Col_House_3")
	# House 4: (-2 to 2 X, 9 to 12 Y) -> pos (0, 336)
	add_box_collider.call(Vector2(0, 352), Vector2(160, 96), "Col_House_4")
	# House 5: (8 to 12 X, 1 to 4 Y) -> pos (320, 80)
	add_box_collider.call(Vector2(320, 96), Vector2(160, 96), "Col_House_5")
	# House 6: (-13 to -9 X, -1 to 2 Y) -> pos (-352, 16)
	add_box_collider.call(Vector2(-352, 0), Vector2(160, 96), "Col_House_6")

	# 3. Shop Walls:
	# General Goods: (-10 to -6 X, -8 to -5 Y)
	add_box_collider.call(Vector2(-256, -224), Vector2(160, 96), "Col_Shop_General")
	# Armory: (-10 to -6 X, 5 to 8 Y)
	add_box_collider.call(Vector2(-256, 224), Vector2(160, 96), "Col_Shop_Armory")

	# 4. Blacksmith Building & Crafting hitboxes:
	add_box_collider.call(Vector2(224, 224), Vector2(160, 96), "Col_Blacksmith_Building")
	# Forge: (6, 3) -> (192, 96)
	add_box_collider.call(Vector2(192, 96), Vector2(32, 32), "Col_Forge")
	# Anvil: (8, 3) -> (256, 96)
	add_box_collider.call(Vector2(256, 96), Vector2(28, 28), "Col_Anvil")
	# Blacksmith Table: (7, 2) -> (224, 64)
	add_box_collider.call(Vector2(224, 64), Vector2(32, 32), "Col_Blacksmith_Table")

	# 5. Market Stalls Hitboxes:
	add_box_collider.call(Vector2(-208, -64), Vector2(56, 28), "Col_Stall_1")
	add_box_collider.call(Vector2(-144, -64), Vector2(56, 28), "Col_Stall_2")
	add_box_collider.call(Vector2(-208, 64), Vector2(56, 28), "Col_Stall_3")
	add_box_collider.call(Vector2(-144, 64), Vector2(56, 28), "Col_Stall_4")

	# 6. Outside Landmarks Hitboxes:
	# Ancient Ruins Altar & Pillars: (0, -800)
	add_box_collider.call(Vector2(0, -800), Vector2(140, 90), "Col_Ruins_Altar")
	# Old Church Walls: (-800, 0)
	add_box_collider.call(Vector2(-752, 0), Vector2(140, 140), "Col_Church_Walls")
	# Abandoned Mine Cavern: (800, 0)
	add_box_collider.call(Vector2(752, 0), Vector2(140, 140), "Col_Mine_Cavern")

	# ----------------------------------------------------
	# POPULATE TRIGGER LAYER (1x1 Tile = 32x32 Sensor Zones)
	# ----------------------------------------------------
	print("Populating TriggerLayer (11 entrances)...")
	var entry_script = load("res://scripts/world/interior_entry.gd")

	var entrance_list := [
		{"name": "Trigger_House_1", "pos": Vector2(0, -288), "id": "house_1", "display": "Lina's House", "scene": "res://scenes/interiors/house_1.tscn"},
		{"name": "Trigger_House_2", "pos": Vector2(256, -256), "id": "house_2", "display": "Baker's House", "scene": "res://scenes/interiors/house_2.tscn"},
		{"name": "Trigger_House_3", "pos": Vector2(320, -32), "id": "house_3", "display": "Guard's House", "scene": "res://scenes/interiors/house_3.tscn"},
		{"name": "Trigger_House_4", "pos": Vector2(0, 256), "id": "house_4", "display": "Elder's House", "scene": "res://scenes/interiors/house_4.tscn"},
		{"name": "Trigger_House_5", "pos": Vector2(320, 160), "id": "house_5", "display": "Craftsman's House", "scene": "res://scenes/interiors/house_5.tscn"},
		{"name": "Trigger_House_6", "pos": Vector2(-352, 64), "id": "house_6", "display": "Herbalist's House", "scene": "res://scenes/interiors/house_6.tscn"},
		{"name": "Trigger_Shop_General", "pos": Vector2(-256, -128), "id": "shop_general", "display": "General Goods", "scene": "res://scenes/interiors/shop_general.tscn"},
		{"name": "Trigger_Shop_Armory", "pos": Vector2(-256, 128), "id": "shop_armory", "display": "Armory", "scene": "res://scenes/interiors/shop_armory.tscn"},
		{"name": "Trigger_Church", "pos": Vector2(-672, 0), "id": "abandoned_church", "display": "Old Church", "scene": "res://scenes/interiors/abandoned_church.tscn"},
		{"name": "Trigger_Ruins", "pos": Vector2(0, -704), "id": "ruins", "display": "Ancient Ruins", "scene": "res://scenes/interiors/ruins.tscn"},
		{"name": "Trigger_Mine", "pos": Vector2(672, 0), "id": "mine", "display": "Abandoned Mines", "scene": "res://scenes/interiors/mine.tscn"},
	]

	for ent in entrance_list:
		var area := Area2D.new()
		area.name = ent["name"]
		area.position = ent["pos"]
		area.set_script(entry_script)
		area.set("interior_id", ent["id"])
		area.set("display_name", ent["display"])
		area.set("interior_scene_path", ent["scene"])
		area.set("destination_spawn", Vector2(0, 180))
		area.set("linked_layer_name", "TriggerLayer")

		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var box := RectangleShape2D.new()
		box.size = Vector2(32, 32) # Exactly 1x1 tile!
		col.shape = box
		area.add_child(col)
		trigger_layer.add_child(area)
		area.owner = root
		col.owner = root
		print("Added trigger: ", ent["name"], " at ", ent["pos"], " -> ", ent["scene"])

	# Pack and save scenes/world/authored_environment.tscn
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		printerr("Error packing AuthoredEnvironment scene: ", err)
		quit(1)
		return
	err = ResourceSaver.save(packed, "res://scenes/world/authored_environment.tscn")
	if err != OK:
		printerr("Error saving authored_environment.tscn: ", err)
		quit(1)
		return

	print("Successfully saved res://scenes/world/authored_environment.tscn!")
	quit(0)
