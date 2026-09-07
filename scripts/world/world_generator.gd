class_name WorldGenerator
extends Node2D

const CookingPotScript = preload("res://scripts/world/cooking_pot.gd")
const WaterZoneScript = preload("res://scripts/world/water_zone.gd")

## Populates island world with environmental features, NPCs, wildlife, and structures

var layout_config: Dictionary = {}

func _ready() -> void:
	y_sort_enabled = true
	_load_config()
	generate_world()

func _load_config() -> void:
	var path := "res://data/island_layout.json"
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json_str := file.get_as_text()
			var json = JSON.parse_string(json_str)
			if json and typeof(json) == TYPE_DICTIONARY:
				layout_config = json
				return
	
	# Default fallback config
	layout_config = {
		"island_settings": {"base_radius": 1050.0, "beach_radius": 1150.0, "village_radius": 350.0},
		"density_settings": {
			"tree_count": 0, "rock_clusters": 0, "flower_count": 0,
			"wildlife_rabbits": 6, "wildlife_deer": 4, "wildlife_birds": 6,
			"material_wood": 12, "material_herb": 12, "material_mushroom": 10,
			"mining_nodes": 8
		}
	}

func generate_world() -> void:
	# Clear previous children safely (deferred free, then build fresh).
	for child in get_children():
		remove_child(child)
		child.queue_free()
	
	var terrain := IslandWorld.new()
	terrain.name = "IslandWorld"
	terrain.add_to_group("island_world")
	add_child(terrain)
	terrain.rebuild(get_parent(), layout_config)

	_spawn_village()
	_spawn_tree_ring()
	_spawn_forest_trees()
	_spawn_rocks()
	_spawn_flowers()
	_spawn_ruins()
	_spawn_cave_mining_area()
	_spawn_wildlife()
	_spawn_collectables()
	_spawn_waystones()
	# Swimming follows the same occupied cells that are drawn on the map.
	if GameManager.player:
		GameManager.player.set_swimming(terrain.is_water(GameManager.player.global_position))

# --- Map-aware placement helpers (mirrors island_layout.json) ---
func _is_water_point(pos: Vector2) -> bool:
	var terrain := get_node_or_null("IslandWorld") as IslandWorld
	if terrain:
		return terrain.is_water(pos)
	if pos.distance_to(Vector2(670, 32)) < 200.0:
		return true
	# Outer Ocean
	var base_r: float = layout_config.get("island_settings", {}).get("base_radius", 1050.0)
	if pos.length() > base_r - 80.0:
		return true
	return false

func _is_on_highway(pos: Vector2) -> bool:
	# Keep clear of main road cross (+/- 50 px from X=0 and Y=0 within village radius)
	if absf(pos.x) < 50.0 and absf(pos.y) < 700.0:
		return true
	if absf(pos.y) < 50.0 and absf(pos.x) < 800.0:
		return true
	return false

func _scatter_land_position(min_r: float, max_r: float) -> Vector2:
	var base_r: float = layout_config.get("island_settings", {}).get("base_radius", 1050.0)
	var real_max_r: float = minf(max_r * 3.0, base_r - 180.0)
	var real_min_r: float = minf(min_r, real_max_r * 0.4)
	for attempt in range(20):
		var ang := randf() * TAU
		var dist := randf_range(real_min_r, real_max_r)
		var pos := Vector2(cos(ang) * dist, sin(ang) * dist)
		var terrain := get_node_or_null("IslandWorld") as IslandWorld
		if _is_water_point(pos) or (terrain != null and not terrain.is_clear(pos)) or _is_on_highway(pos):
			continue
		if terrain:
			terrain.reserved.append(pos)
		return pos
	var fallback_terrain := get_node_or_null("IslandWorld") as IslandWorld
	if fallback_terrain:
		for cell: Vector2i in fallback_terrain.land:
			var candidate: Vector2 = fallback_terrain.ground.map_to_local(cell)
			if fallback_terrain.is_clear(candidate):
				fallback_terrain.reserved.append(candidate)
				return candidate
	return Vector2(0, 90)

func _spawn_village() -> void:
	var village_node := Node2D.new()
	village_node.name = "Village"
	village_node.y_sort_enabled = true
	add_child(village_node)
	
	# Campfire with Cooking Pot
	var campfire := CookingPotScript.new()
	campfire.name = "Campfire"
	campfire.y_sort_enabled = true
	campfire.position = Vector2.ZERO
	
	var camp_col := CollisionShape2D.new()
	var camp_shape := CircleShape2D.new()
	camp_shape.radius = 12.0
	camp_col.shape = camp_shape
	camp_col.position = Vector2(0, 2)
	campfire.add_child(camp_col)
	
	village_node.add_child(campfire)
	
	# Village Houses from Layout
	var houses_node := Node2D.new()
	houses_node.name = "Houses"
	houses_node.y_sort_enabled = true
	village_node.add_child(houses_node)
	
	var houses_list: Array = layout_config.get("village", {}).get("houses", [
		{"id": "house1", "pos": {"x": -350.0, "y": -260.0}},
		{"id": "house2", "pos": {"x": 350.0, "y": -260.0}},
		{"id": "house3", "pos": {"x": -350.0, "y": 280.0}},
		{"id": "house4", "pos": {"x": 350.0, "y": 280.0}}
	])
	
	for i in range(houses_list.size()):
		var h: Dictionary = houses_list[i]
		var pos_dict: Dictionary = h.get("pos", {"x": 0.0, "y": 0.0})
		var h_pos := Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
		_create_house(houses_node, h_pos, i)
	
	# Village Quest NPCs
	var npcs_node := Node2D.new()
	npcs_node.name = "VillageNPCs"
	npcs_node.y_sort_enabled = true
	village_node.add_child(npcs_node)
	
	var npc_list: Array = layout_config.get("village", {}).get("npcs", [])
	if npc_list.is_empty():
		_spawn_default_npcs(npcs_node)
	else:
		for npc_data in npc_list:
			var pos_dict: Dictionary = npc_data.get("pos", {"x": 0.0, "y": 0.0})
			var n_pos := Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
			var npc_id: String = npc_data.get("id", "elder")
			var npc_name: String = npc_data.get("name", "Elder")
			var quest_id: String = npc_data.get("quest_id", "")
			var draw_type: int = npc_data.get("type", 9)
			_create_configured_npc(npcs_node, npc_name, npc_id, quest_id, n_pos, draw_type)

func _create_house(parent: Node2D, pos: Vector2, house_idx: int = 0) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.y_sort_enabled = true
	
	# Accurate physics collision at wall base (allows walking behind roof with Y-sorting)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(96, 32)
	col.shape = shape
	col.position = Vector2(0, 16)
	body.add_child(col)
	
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = Vector2(0, -16)
	var house_textures := [
		"res://assets/sprites/buildings/house_red.png",
		"res://assets/sprites/buildings/house_blue.png",
		"res://assets/sprites/buildings/house_green.png",
		"res://assets/sprites/buildings/house_stone.png"
	]
	var chosen_tex: String = house_textures[house_idx % house_textures.size()]
	sprite.texture = load(chosen_tex)
	body.add_child(sprite)
	
	parent.add_child(body)

func _spawn_default_npcs(parent: Node2D) -> void:
	_create_configured_npc(parent, "Village Elder", "elder", "slay_slimes", Vector2(-140, -100), CustomDraw2D.EntityType.NPC_ELDER)
	_create_configured_npc(parent, "Carpenter", "carpenter", "gather_wood", Vector2(260, -100), CustomDraw2D.EntityType.NPC_CARPENTER)
	_create_configured_npc(parent, "Chef Maria", "cook", "first_meal", Vector2(100, 50), CustomDraw2D.EntityType.NPC_COOK)
	_create_configured_npc(parent, "Miner Torvald", "miner", "explore_cave", Vector2(-60, -380), CustomDraw2D.EntityType.NPC_MINER)

func _create_configured_npc(parent: Node2D, npc_name: String, npc_id: String, quest_id: String, pos: Vector2, _draw_type: int) -> void:
	var npc := QuestNPC.new()
	npc.npc_name = npc_name
	npc.npc_id = npc_id
	npc.quest_id = quest_id
	npc.position = pos
	npc.y_sort_enabled = true
	npc.add_to_group("npcs")
	
	match npc_id:
		"elder":
			npc.greeting_text = "Welcome to the grand Angel Island!"
			npc.quest_offer_text = "Slimes roam the outskirts. Defeat 5 slimes to help secure our borders!"
			npc.quest_active_text = "Keep up the fight against the slimes!"
			npc.quest_complete_text = "Magnificent work! Here is your gold and EXP reward."
			npc.quest_done_text = "The village is safe thanks to you."
		"carpenter":
			npc.greeting_text = "Hello traveler! Need repairs or building supplies?"
			npc.quest_offer_text = "I am reinforcing the village fences. Could you gather 10 Wood?"
			npc.quest_active_text = "Still searching for those 10 pieces of wood?"
			npc.quest_complete_text = "Excellent lumber! Here is your payment."
			npc.quest_done_text = "Our fortifications are sturdy now."
		"cook":
			npc.greeting_text = "Welcome to the campfire hearth!"
			npc.quest_offer_text = "Try your hand at cooking a hearty meal at the campfire [F]!"
			npc.quest_active_text = "Cook any recipe at the campfire using herbs and mushrooms."
			npc.quest_complete_text = "Delicious aroma! You have a true chef's talent. Take this!"
			npc.quest_done_text = "Eat well to keep your strength up on your journey!"
		"miner":
			npc.greeting_text = "Greetings! The northern mountains hold vast mineral wealth."
			npc.quest_offer_text = "Explore the northern cave quarries and mine 3 Iron Ores for me."
			npc.quest_active_text = "Strike the ore nodes with your weapon or interact [F] to extract ore."
			npc.quest_complete_text = "High-grade ore! You are a master prospector. Here is your reward."
			npc.quest_done_text = "May fortune smile on your excavations!"
		_:
			npc.greeting_text = "Greetings, adventurer!"
			npc.quest_offer_text = "Safe travels across the island!"
			npc.quest_done_text = "Good luck!"
	
	# Accurate feet collision
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	col.shape = shape
	col.position = Vector2(0, 6)
	npc.add_child(col)
	
	var visual := AnimatedSprite2D.new()
	visual.name = "AnimatedSprite2D"
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.position = Vector2(0, -12)
	var frames_path := "res://assets/sprites/npc_%s_frames.tres" % npc_id
	if ResourceLoader.exists(frames_path):
		visual.sprite_frames = load(frames_path)
	else:
		visual.sprite_frames = load("res://assets/sprites/npc_elder_frames.tres")
	visual.animation = "idle"
	visual.play("idle")
	npc.add_child(visual)
	
	var label := Label.new()
	label.name = "NameLabel"
	label.text = npc_name
	# Explicit rect centered above the head: min size alone leaves size at
	# zero until layout runs, which offset the name on some frames/zooms.
	label.position = Vector2(-40, -34)
	label.size = Vector2(80, 20)
	label.custom_minimum_size = Vector2(80, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	npc.add_child(label)
	
	parent.add_child(npc)

func _spawn_tree_ring() -> void:
	if get_parent() and get_parent().get_node_or_null("TreeLayer") != null:
		return
	if layout_config.get("village", {}).get("tree_ring_count", 0) == 0:
		return
	
	var tree_ring_node := Node2D.new()
	tree_ring_node.name = "ProtectiveTreeRing"
	tree_ring_node.y_sort_enabled = true
	add_child(tree_ring_node)
	
	var count: int = layout_config.get("village", {}).get("tree_ring_count", 0)
	var radius: float = layout_config.get("village", {}).get("tree_ring_radius", 780.0)
	
	for i in range(count):
		var angle: float = (TAU * float(i)) / float(count)
		var deg := fposmod(rad_to_deg(angle), 360.0)
		# Openings for 4 cardinal highways
		if (deg > 342 or deg < 18) or (deg > 72 and deg < 108) or (deg > 162 and deg < 198) or (deg > 252 and deg < 288):
			continue
		
		var r: float = randf_range(radius - 20.0, radius + 20.0)
		var pos := Vector2(cos(angle) * r, sin(angle) * r)
		_create_tree(tree_ring_node, pos)

func _spawn_forest_trees() -> void:
	if get_parent() and get_parent().get_node_or_null("TreeLayer") != null:
		return
	if layout_config.get("density_settings", {}).get("tree_count", 0) == 0:
		return

func _create_tree(parent: Node2D, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.y_sort_enabled = true
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	col.shape = shape
	col.position = Vector2(0, 6)
	body.add_child(col)
	
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = load("res://assets/sprites/world/tree_oak.png")
	spr.offset = Vector2(0, -18)
	body.add_child(spr)
	
	parent.add_child(body)

func _spawn_rocks() -> void:
	if get_parent() and get_parent().get_node_or_null("DecorLayer") != null:
		return
	if layout_config.get("density_settings", {}).get("rock_clusters", 0) == 0:
		return

func _spawn_flowers() -> void:
	if get_parent() and get_parent().get_node_or_null("DecorLayer") != null:
		return
	if layout_config.get("density_settings", {}).get("flower_count", 0) == 0:
		return

func _spawn_ruins() -> void:
	if get_parent() and get_parent().get_node_or_null("DecorLayer") != null:
		return

func _spawn_cave_mining_area() -> void:
	var cave_area := Node2D.new()
	cave_area.name = "CaveMiningArea"
	cave_area.y_sort_enabled = true
	var c_pos_dict: Dictionary = layout_config.get("landmarks", {}).get("northern_mountain", {}).get("cave_mouth", {"x": 0.0, "y": -680.0})
	cave_area.position = Vector2(c_pos_dict.get("x", 0.0), c_pos_dict.get("y", -680.0))
	add_child(cave_area)
	
	var mining_count: int = layout_config.get("density_settings", {}).get("mining_nodes", 8)
	for i in range(mining_count):
		var ore_type := "iron_ore" if i % 3 != 0 else "gold_ore"
		var ore_name := "Iron Ore" if ore_type == "iron_ore" else "Gold Ore"
		var angle := randf() * TAU
		var dist := randf_range(30.0, 150.0)
		var rock_pos := Vector2(cos(angle) * dist, sin(angle) * dist * 0.5)
		
		var rock := MiningRock.new()
		rock.position = rock_pos
		rock.ore_type = ore_type
		rock.ore_name = ore_name
		rock.y_sort_enabled = true
		
		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 11.0
		col.shape = shape
		col.position = Vector2(0, 3)
		rock.add_child(col)
		
		cave_area.add_child(rock)

func _spawn_wildlife() -> void:
	var animals_node := Node2D.new()
	animals_node.name = "Wildlife"
	animals_node.y_sort_enabled = true
	add_child(animals_node)
	
	var rabbits_n: int = layout_config.get("density_settings", {}).get("wildlife_rabbits", 6)
	var deer_n: int = layout_config.get("density_settings", {}).get("wildlife_deer", 4)
	var birds_n: int = layout_config.get("density_settings", {}).get("wildlife_birds", 6)
	
	# Rabbits in grasslands
	for i in range(rabbits_n):
		var rabbit := Wildlife.new()
		rabbit.animal_type = Wildlife.AnimalType.RABBIT
		rabbit.position = _scatter_land_position(200.0, 800.0)
		animals_node.add_child(rabbit)
	
	# Deer in woods
	for i in range(deer_n):
		var deer := Wildlife.new()
		deer.animal_type = Wildlife.AnimalType.DEER
		deer.position = _scatter_land_position(200.0, 800.0)
		animals_node.add_child(deer)
	
	# Birds
	for i in range(birds_n):
		var bird := Wildlife.new()
		bird.animal_type = Wildlife.AnimalType.BIRD
		bird.position = _scatter_land_position(200.0, 800.0)
		animals_node.add_child(bird)

func _spawn_collectables() -> void:
	var coll_node := Node2D.new()
	coll_node.name = "MaterialSpawns"
	coll_node.y_sort_enabled = true
	add_child(coll_node)
	
	var wood_n: int = layout_config.get("density_settings", {}).get("material_wood", 60)
	var herb_n: int = layout_config.get("density_settings", {}).get("material_herb", 60)
	var mush_n: int = layout_config.get("density_settings", {}).get("material_mushroom", 50)
	
	# Wood logs
	for i in range(wood_n):
		_spawn_item(coll_node, "wood", "Wood", 0, CustomDraw2D.EntityType.ITEM_WOOD,
			_scatter_land_position(180.0, 800.0))
	
	# Healing Herbs
	for i in range(herb_n):
		_spawn_item(coll_node, "herb", "Herb", 0, CustomDraw2D.EntityType.ITEM_HERB,
			_scatter_land_position(180.0, 800.0))
	
	# Red Mushrooms
	for i in range(mush_n):
		_spawn_item(coll_node, "mushroom", "Mushroom", 0, CustomDraw2D.EntityType.ITEM_MUSHROOM,
			_scatter_land_position(180.0, 800.0))

func _spawn_item(parent: Node2D, item_id: String, item_name: String, item_type: int, _draw_type: CustomDraw2D.EntityType, pos: Vector2) -> void:
	var item := CollectableItem.new()
	item.item_id = item_id
	item.item_name = item_name
	item.item_type = item_type
	item.position = pos
	item.y_sort_enabled = true
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	col.shape = shape
	item.add_child(col)
	
	parent.add_child(item)

func _spawn_waystones() -> void:
	var ws_node := Node2D.new()
	ws_node.name = "Waystones"
	ws_node.y_sort_enabled = true
	add_child(ws_node)
	
	var waystones_data: Array = layout_config.get("waystones", [
		{"id": "village", "name": "Village Waystone", "pos": {"x": 0.0, "y": -220.0}, "unlocked": true},
		{"id": "cave", "name": "Northern Cave Waystone", "pos": {"x": 0.0, "y": -700.0}, "unlocked": false},
		{"id": "ruins", "name": "Southern Ruins Waystone", "pos": {"x": -180.0, "y": 680.0}, "unlocked": false},
		{"id": "east_forest", "name": "Eastern Forest Waystone", "pos": {"x": 750.0, "y": 40.0}, "unlocked": false},
		{"id": "west_cliffs", "name": "Western Orchard Waystone", "pos": {"x": -750.0, "y": 40.0}, "unlocked": false}
	])
	
	for ws in waystones_data:
		var pos_dict: Dictionary = ws.get("pos", {"x": 0.0, "y": 0.0})
		var waystone := Waystone.new()
		waystone.waystone_id = ws.get("id", "village")
		waystone.display_name = ws.get("name", "Waystone")
		waystone.is_unlocked = ws.get("unlocked", false)
		waystone.position = Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
		waystone.y_sort_enabled = true
		
		# Base collision
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(16, 12)
		col.shape = shape
		col.position = Vector2(0, 4)
		waystone.add_child(col)
		
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = load("res://assets/sprites/world/waystone.png")
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(0, -16)
		waystone.add_child(sprite)
		
		ws_node.add_child(waystone)

func _setup_water_zones() -> void:
	var water_zones := Node2D.new()
	water_zones.name = "WaterZones"
	add_child(water_zones)
	
	# Eastern Great Lake
	var lake := WaterZoneScript.new()
	lake.position = Vector2(670, 32)
	var col_lake := CollisionShape2D.new()
	var s_lake := CircleShape2D.new()
	s_lake.radius = 180.0
	col_lake.shape = s_lake
	lake.add_child(col_lake)
	water_zones.add_child(lake)
	
	# Outer Ocean Swimming Ring
	var ocean_zone := WaterZoneScript.new()
	var base_r: float = layout_config.get("island_settings", {}).get("base_radius", 1050.0)
	for i in range(12):
		var angle: float = float(i) * (TAU / 12.0)
		var o_pos := Vector2(cos(angle) * (base_r + 200.0), sin(angle) * (base_r + 200.0))
		var o_col := CollisionShape2D.new()
		var o_shape := CircleShape2D.new()
		o_shape.radius = 400.0
		o_col.shape = o_shape
		o_col.position = o_pos
		ocean_zone.add_child(o_col)
	water_zones.add_child(ocean_zone)
