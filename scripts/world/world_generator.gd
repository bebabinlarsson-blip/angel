class_name WorldGenerator
extends Node2D

const CookingPotScript = preload("res://scripts/world/cooking_pot.gd")
const WaterZoneScript = preload("res://scripts/world/water_zone.gd")

## Populates 15x starting island with customizable environmental features, NPCs, wildlife, and structures

var layout_config: Dictionary = {}
var terrain_node: IslandTerrain = null

func _ready() -> void:
	y_sort_enabled = true
	_load_config()
	generate_world()

func _load_config() -> void:
	if FileAccess.file_exists("res://data/island_layout.json"):
		var file := FileAccess.open("res://data/island_layout.json", FileAccess.READ)
		if file:
			var json_str := file.get_as_text()
			var json = JSON.parse_string(json_str)
			if json and typeof(json) == TYPE_DICTIONARY:
				layout_config = json
				return
	
	# Default fallback config
	layout_config = {
		"island_settings": {"base_radius": 16800.0, "beach_radius": 18500.0, "village_radius": 800.0},
		"density_settings": {
			"tree_count": 350, "rock_clusters": 24, "flower_count": 220,
			"wildlife_rabbits": 28, "wildlife_deer": 20, "wildlife_birds": 30,
			"material_wood": 60, "material_herb": 60, "material_mushroom": 50,
			"mining_nodes": 32
		}
	}

func generate_world() -> void:
	# Clear previous children except terrain if already present
	for child in get_children():
		child.queue_free()
	
	# Add terrain visual
	terrain_node = IslandTerrain.new()
	terrain_node.name = "IslandTerrain"
	terrain_node.z_index = -100
	terrain_node.z_as_relative = false
	add_child(terrain_node)
	
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
	_setup_water_zones()

func regenerate_world(new_config: Dictionary = {}) -> void:
	if not new_config.is_empty():
		layout_config = new_config
	generate_world()

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
	
	var camp_vis := CustomDraw2D.new()
	camp_vis.entity_type = CustomDraw2D.EntityType.CAMPFIRE
	campfire.add_child(camp_vis)
	
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
	
	for h in houses_list:
		var pos_dict: Dictionary = h.get("pos", {"x": 0.0, "y": 0.0})
		var h_pos := Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0))
		_create_house(houses_node, h_pos)
	
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

func _create_house(parent: Node2D, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.y_sort_enabled = true
	
	# Accurate physics collision at wall base (allows walking behind roof with Y-sorting)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60, 22)
	col.shape = shape
	col.position = Vector2(0, 8)
	body.add_child(col)
	
	var visual := CustomDraw2D.new()
	visual.entity_type = CustomDraw2D.EntityType.HOUSE
	body.add_child(visual)
	
	parent.add_child(body)

func _spawn_default_npcs(parent: Node2D) -> void:
	_create_configured_npc(parent, "Village Elder", "elder", "slay_slimes", Vector2(-140, -100), CustomDraw2D.EntityType.NPC_ELDER)
	_create_configured_npc(parent, "Carpenter", "carpenter", "gather_wood", Vector2(260, -100), CustomDraw2D.EntityType.NPC_CARPENTER)
	_create_configured_npc(parent, "Chef Maria", "cook", "first_meal", Vector2(100, 50), CustomDraw2D.EntityType.NPC_COOK)
	_create_configured_npc(parent, "Miner Torvald", "miner", "explore_cave", Vector2(-60, -380), CustomDraw2D.EntityType.NPC_MINER)

func _create_configured_npc(parent: Node2D, npc_name: String, npc_id: String, quest_id: String, pos: Vector2, draw_type: int) -> void:
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
	
	var visual := CustomDraw2D.new()
	visual.entity_type = draw_type as CustomDraw2D.EntityType
	npc.add_child(visual)
	
	var label := Label.new()
	label.name = "NameLabel"
	label.text = npc_name
	label.position = Vector2(-40, -32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(80, 20)
	npc.add_child(label)
	
	parent.add_child(npc)

func _spawn_tree_ring() -> void:
	var tree_ring_node := Node2D.new()
	tree_ring_node.name = "ProtectiveTreeRing"
	tree_ring_node.y_sort_enabled = true
	add_child(tree_ring_node)
	
	var count: int = layout_config.get("village", {}).get("tree_ring_count", 36)
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
	var forests_node := Node2D.new()
	forests_node.name = "ForestGroves"
	forests_node.y_sort_enabled = true
	add_child(forests_node)
	
	var total_trees: int = layout_config.get("density_settings", {}).get("tree_count", 350)
	var per_grove: int = int(float(total_trees) / 5.0)
	
	# 1. Northwest Ancient Redwood Grove
	for i in range(per_grove):
		var pos := Vector2(randf_range(-12000, -2500), randf_range(-12000, -2500))
		_create_tree(forests_node, pos)
	
	# 2. Southwest Whispering Woods
	for i in range(per_grove):
		var pos := Vector2(randf_range(-12000, -2500), randf_range(2500, 12000))
		_create_tree(forests_node, pos)
	
	# 3. Southeast Great Forest
	for i in range(per_grove):
		var pos := Vector2(randf_range(2500, 12000), randf_range(2500, 12000))
		_create_tree(forests_node, pos)
	
	# 4. Northeast Lake Canopy
	for i in range(per_grove):
		var pos := Vector2(randf_range(2500, 12000), randf_range(-12000, -2500))
		_create_tree(forests_node, pos)
	
	# 5. Midland Meadows Groves
	for i in range(per_grove):
		var angle := randf() * TAU
		var dist := randf_range(1200.0, 5000.0)
		var pos := Vector2(cos(angle) * dist, sin(angle) * dist)
		_create_tree(forests_node, pos)

func _create_tree(parent: Node2D, pos: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.y_sort_enabled = true
	
	# Accurate trunk base physics collision
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 7.0
	col.shape = shape
	col.position = Vector2(0, 6)
	body.add_child(col)
	
	var visual := CustomDraw2D.new()
	visual.entity_type = CustomDraw2D.EntityType.TREE
	body.add_child(visual)
	
	parent.add_child(body)

func _spawn_rocks() -> void:
	var rocks_node := Node2D.new()
	rocks_node.name = "Rocks"
	rocks_node.y_sort_enabled = true
	add_child(rocks_node)
	
	var clusters_count: int = layout_config.get("density_settings", {}).get("rock_clusters", 24)
	
	for c in range(clusters_count):
		var cluster_angle := randf() * TAU
		var cluster_dist := randf_range(1500.0, 14000.0)
		var center := Vector2(cos(cluster_angle) * cluster_dist, sin(cluster_angle) * cluster_dist)
		
		for i in range(5):
			var r_pos := center + Vector2(randf_range(-120, 120), randf_range(-120, 120))
			var body := StaticBody2D.new()
			body.position = r_pos
			body.y_sort_enabled = true
			
			var col := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = 10.0
			col.shape = shape
			col.position = Vector2(0, 3)
			body.add_child(col)
			
			var visual := CustomDraw2D.new()
			visual.entity_type = CustomDraw2D.EntityType.ROCK
			body.add_child(visual)
			
			rocks_node.add_child(body)

func _spawn_flowers() -> void:
	var flowers_node := Node2D.new()
	flowers_node.name = "Flowers"
	flowers_node.y_sort_enabled = true
	add_child(flowers_node)
	
	var flower_colors: Array[Color] = [
		Color(0.95, 0.3, 0.3), Color(0.95, 0.85, 0.2),
		Color(0.4, 0.6, 0.95), Color(0.85, 0.4, 0.9), Color(1.0, 0.6, 0.8)
	]
	
	var count: int = layout_config.get("density_settings", {}).get("flower_count", 220)
	for i in range(count):
		var angle: float = randf() * TAU
		var dist: float = randf_range(850.0, 15000.0)
		var f_pos := Vector2(cos(angle) * dist, sin(angle) * dist)
		
		var f := Node2D.new()
		f.position = f_pos
		f.y_sort_enabled = true
		var visual := CustomDraw2D.new()
		visual.entity_type = CustomDraw2D.EntityType.FLOWER
		visual.custom_color = flower_colors[i % flower_colors.size()]
		f.add_child(visual)
		flowers_node.add_child(f)

func _spawn_ruins() -> void:
	var ruins_node := Node2D.new()
	ruins_node.name = "AncientRuins"
	ruins_node.y_sort_enabled = true
	var r_center_dict: Dictionary = layout_config.get("landmarks", {}).get("ancient_ruins", {}).get("center", {"x": -2000.0, "y": 8000.0})
	ruins_node.position = Vector2(r_center_dict.get("x", -2000.0), r_center_dict.get("y", 8000.0))
	add_child(ruins_node)
	
	var ruin_offsets: Array[Vector2] = [
		Vector2(-160, -120), Vector2(0, -160), Vector2(160, -120),
		Vector2(-200, 0), Vector2(200, 0),
		Vector2(-140, 140), Vector2(0, 180), Vector2(140, 140),
		Vector2(-80, -40), Vector2(80, -40), Vector2(-60, 60), Vector2(60, 60)
	]
	for off in ruin_offsets:
		var body := StaticBody2D.new()
		body.position = off
		body.y_sort_enabled = true
		
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(24, 18)
		col.shape = shape
		col.position = Vector2(0, 6)
		body.add_child(col)
		
		var visual := CustomDraw2D.new()
		visual.entity_type = CustomDraw2D.EntityType.RUIN
		body.add_child(visual)
		
		ruins_node.add_child(body)

func _spawn_cave_mining_area() -> void:
	var cave_area := Node2D.new()
	cave_area.name = "CaveMiningArea"
	cave_area.y_sort_enabled = true
	var c_pos_dict: Dictionary = layout_config.get("landmarks", {}).get("northern_mountain", {}).get("cave_mouth", {"x": 0.0, "y": -7500.0})
	cave_area.position = Vector2(c_pos_dict.get("x", 0.0), c_pos_dict.get("y", -7500.0))
	add_child(cave_area)
	
	var mining_count: int = layout_config.get("density_settings", {}).get("mining_nodes", 32)
	
	for i in range(mining_count):
		var ore_type := "iron_ore" if i % 3 != 0 else "gold_ore"
		var ore_name := "Iron Ore" if ore_type == "iron_ore" else "Gold Ore"
		var angle := randf() * TAU
		var dist := randf_range(80.0, 700.0)
		var rock_pos := Vector2(cos(angle) * dist, sin(angle) * dist * 0.6)
		
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
		
		var visual := CustomDraw2D.new()
		visual.entity_type = CustomDraw2D.EntityType.ORE_VEIN
		rock.add_child(visual)
		
		cave_area.add_child(rock)

func _spawn_wildlife() -> void:
	var animals_node := Node2D.new()
	animals_node.name = "Wildlife"
	animals_node.y_sort_enabled = true
	add_child(animals_node)
	
	var rabbits_n: int = layout_config.get("density_settings", {}).get("wildlife_rabbits", 28)
	var deer_n: int = layout_config.get("density_settings", {}).get("wildlife_deer", 20)
	var birds_n: int = layout_config.get("density_settings", {}).get("wildlife_birds", 30)
	
	# Rabbits in grasslands
	for i in range(rabbits_n):
		var rabbit := Wildlife.new()
		rabbit.animal_type = Wildlife.AnimalType.RABBIT
		rabbit.position = Vector2(randf_range(-14000, 14000), randf_range(-14000, 14000))
		animals_node.add_child(rabbit)
	
	# Deer in woods
	for i in range(deer_n):
		var deer := Wildlife.new()
		deer.animal_type = Wildlife.AnimalType.DEER
		deer.position = Vector2(randf_range(-13000, 13000), randf_range(-13000, 13000))
		animals_node.add_child(deer)
	
	# Birds
	for i in range(birds_n):
		var bird := Wildlife.new()
		bird.animal_type = Wildlife.AnimalType.BIRD
		bird.position = Vector2(randf_range(-15000, 15000), randf_range(-15000, 15000))
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
			Vector2(randf_range(-14000, 14000), randf_range(-14000, 14000)))
	
	# Healing Herbs
	for i in range(herb_n):
		_spawn_item(coll_node, "herb", "Herb", 0, CustomDraw2D.EntityType.ITEM_HERB,
			Vector2(randf_range(-14000, 14000), randf_range(-14000, 14000)))
	
	# Red Mushrooms
	for i in range(mush_n):
		_spawn_item(coll_node, "mushroom", "Mushroom", 0, CustomDraw2D.EntityType.ITEM_MUSHROOM,
			Vector2(randf_range(-14000, 14000), randf_range(-14000, 14000)))

func _spawn_item(parent: Node2D, item_id: String, item_name: String, item_type: int, draw_type: CustomDraw2D.EntityType, pos: Vector2) -> void:
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
	
	var visual := CustomDraw2D.new()
	visual.entity_type = draw_type
	item.add_child(visual)
	
	parent.add_child(item)

func _spawn_waystones() -> void:
	var ws_node := Node2D.new()
	ws_node.name = "Waystones"
	ws_node.y_sort_enabled = true
	add_child(ws_node)
	
	var waystones_data: Array = layout_config.get("waystones", [
		{"id": "village", "name": "Village Waystone", "pos": {"x": 0.0, "y": -220.0}, "unlocked": true},
		{"id": "cave", "name": "Northern Cave Waystone", "pos": {"x": 0.0, "y": -7200.0}, "unlocked": false},
		{"id": "ruins", "name": "Southern Ruins Waystone", "pos": {"x": -1800.0, "y": 7500.0}, "unlocked": false},
		{"id": "east_forest", "name": "Eastern Forest Waystone", "pos": {"x": 7500.0, "y": 1200.0}, "unlocked": false},
		{"id": "west_cliffs", "name": "Western Cliffs Waystone", "pos": {"x": -7500.0, "y": -1000.0}, "unlocked": false},
		{"id": "coast", "name": "Sunrise Coast Waystone", "pos": {"x": 9500.0, "y": 5000.0}, "unlocked": false}
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
		
		var visual := CustomDraw2D.new()
		visual.entity_type = CustomDraw2D.EntityType.WAYSTONE
		waystone.add_child(visual)
		
		ws_node.add_child(waystone)

func _setup_water_zones() -> void:
	var water_zones := Node2D.new()
	water_zones.name = "WaterZones"
	add_child(water_zones)
	
	# Eastern Great Lake
	var lake := WaterZone.new()
	lake.position = Vector2(5500, 2500)
	var col_lake := CollisionShape2D.new()
	var s_lake := CircleShape2D.new()
	s_lake.radius = 1200.0
	col_lake.shape = s_lake
	lake.add_child(col_lake)
	water_zones.add_child(lake)
	
	# Western Pond
	var w_pond := WaterZone.new()
	w_pond.position = Vector2(-5000, 3500)
	var col_wp := CollisionShape2D.new()
	var s_wp := CircleShape2D.new()
	s_wp.radius = 900.0
	col_wp.shape = s_wp
	w_pond.add_child(col_wp)
	water_zones.add_child(w_pond)
	
	# Southern Lagoon
	var lagoon := WaterZone.new()
	lagoon.position = Vector2(3000, 9000)
	var col_lagoon := CollisionShape2D.new()
	var s_lagoon := CircleShape2D.new()
	s_lagoon.radius = 1100.0
	col_lagoon.shape = s_lagoon
	lagoon.add_child(col_lagoon)
	water_zones.add_child(lagoon)
	
	# Village Ponds
	var v_pond1 := WaterZone.new()
	v_pond1.position = Vector2(550, 320)
	var col_vp1 := CollisionShape2D.new()
	var s_vp1 := CircleShape2D.new()
	s_vp1.radius = 120.0
	col_vp1.shape = s_vp1
	v_pond1.add_child(col_vp1)
	water_zones.add_child(v_pond1)
	
	var v_pond2 := WaterZone.new()
	v_pond2.position = Vector2(-600, 480)
	var col_vp2 := CollisionShape2D.new()
	var s_vp2 := CircleShape2D.new()
	s_vp2.radius = 100.0
	col_vp2.shape = s_vp2
	v_pond2.add_child(col_vp2)
	water_zones.add_child(v_pond2)
	
	# Outer Ocean Swimming Ring
	var ocean_zone := WaterZone.new()
	var base_r: float = layout_config.get("island_settings", {}).get("base_radius", 16800.0)
	for i in range(16):
		var angle: float = float(i) * (TAU / 16.0)
		var o_pos := Vector2(cos(angle) * (base_r + 1500.0), sin(angle) * (base_r + 1500.0))
		var o_col := CollisionShape2D.new()
		var o_shape := CircleShape2D.new()
		o_shape.radius = 3500.0
		o_col.shape = o_shape
		o_col.position = o_pos
		ocean_zone.add_child(o_col)
	water_zones.add_child(ocean_zone)
