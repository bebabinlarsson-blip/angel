class_name TileMapTerrain
extends Node2D

var tileset: TileSet = preload("res://assets/tilesets/grass_tileset.tres")
var layout_config: Dictionary = {}

var ground_layer: TileMapLayer
var path_layer: TileMapLayer
var decor_layer: TileMapLayer

func _init() -> void:
	y_sort_enabled = true
	
	ground_layer = TileMapLayer.new()
	ground_layer.name = "GroundLayer"
	ground_layer.tile_set = tileset
	ground_layer.z_index = -100
	add_child(ground_layer)
	
	path_layer = TileMapLayer.new()
	path_layer.name = "PathLayer"
	path_layer.tile_set = tileset
	path_layer.z_index = -99
	add_child(path_layer)
	
	decor_layer = TileMapLayer.new()
	decor_layer.name = "DecorLayer"
	decor_layer.tile_set = tileset
	decor_layer.z_index = -98
	add_child(decor_layer)

func set_layout(config: Dictionary) -> void:
	layout_config = config
	generate_tiles()

func generate_tiles() -> void:
	ground_layer.clear()
	path_layer.clear()
	decor_layer.clear()
	
	var base_r: float = layout_config.get("island_settings", {}).get("base_radius", 16800.0)
	var tile_radius: int = mini(int(base_r / 32.0), 260)
	
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = 42
	terrain_noise.frequency = 0.015
	
	var meadow_noise := FastNoiseLite.new()
	meadow_noise.seed = 999
	meadow_noise.frequency = 0.03
	
	# 1. Base Island Ground Generation
	for x in range(-tile_radius - 6, tile_radius + 7):
		for y in range(-tile_radius - 6, tile_radius + 7):
			var dist: float = Vector2(x, y).length()
			var coast_wobble: float = terrain_noise.get_noise_2d(x * 1.5, y * 1.5) * 12.0
			var effective_radius: float = float(tile_radius) + coast_wobble
			
			if dist < effective_radius - 6.0:
				# Landmass: Rolling grassy meadows
				var m_val: float = meadow_noise.get_noise_2d(x, y)
				var grass_variant: int = 0
				if m_val > 0.35:
					grass_variant = 1 # Tufted grass
				elif m_val < -0.35:
					grass_variant = 2 # Daisy grass
				elif abs(m_val) < 0.05:
					grass_variant = 3 # Wildflower grass
				ground_layer.set_cell(Vector2i(x, y), 1, Vector2i(grass_variant, 0))
			elif dist < effective_radius:
				# Soft Golden Beach Coast
				ground_layer.set_cell(Vector2i(x, y), 1, Vector2i(4, 0))
			elif dist < effective_radius + 8.0:
				# Azure Ocean Waters
				ground_layer.set_cell(Vector2i(x, y), 1, Vector2i(5, 1))
				
	# 2. Handcrafted Village Pathways
	_build_village_paths()
	
	# 3. Handcrafted Village Grounds & Gardens
	_decorate_village_properties()
	
	# 4. Clustered Natural Wilderness Dressing
	_scatter_clustered_wilderness(tile_radius)

func _build_village_paths() -> void:
	# Campfire hearth: cozy rounded cobblestone clearing (not a giant square)
	var hearth_points: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	for pt in hearth_points:
		path_layer.set_cell(pt, 1, Vector2i(0, 1))
	
	# Waystone shrine: ancient circle
	var shrine_center := Vector2i(0, -4)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			path_layer.set_cell(shrine_center + Vector2i(dx, dy), 1, Vector2i(0, 1))
	
	# Connecting trail from Campfire to Waystone
	_draw_organic_trail(Vector2(0, -32), Vector2(0, -100))
	
	# Gentle 1-tile winding trails to the 4 houses
	# House 1: NW Elder (-350, -230)
	_draw_organic_trail(Vector2(-32, -16), Vector2(-160, -80))
	_draw_organic_trail(Vector2(-160, -80), Vector2(-350, -210))
	
	# House 2: NE Carpenter (350, -230)
	_draw_organic_trail(Vector2(32, -16), Vector2(160, -80))
	_draw_organic_trail(Vector2(160, -80), Vector2(350, -210))
	
	# House 3: SW Chef (-350, 310)
	_draw_organic_trail(Vector2(-32, 16), Vector2(-160, 120))
	_draw_organic_trail(Vector2(-160, 120), Vector2(-350, 260))
	
	# House 4: SE Storage/Miner (350, 310)
	_draw_organic_trail(Vector2(32, 16), Vector2(160, 120))
	_draw_organic_trail(Vector2(160, 120), Vector2(350, 260))
	
	# Outpost trail to Miner Torvald (North Quarry)
	_draw_organic_trail(Vector2(0, -130), Vector2(-60, -350))

func _draw_organic_trail(from_pos: Vector2, to_pos: Vector2) -> void:
	var from_t := from_pos / 32.0
	var to_t := to_pos / 32.0
	var dist := from_t.distance_to(to_t)
	var steps := int(dist)
	var prev_tile := Vector2i(-9999, -9999)
	
	for i in range(steps + 1):
		var t: float = float(i) / maxf(float(steps), 1.0)
		var base_pt := from_t.lerp(to_t, t)
		var tile_pos := Vector2i(roundi(base_pt.x), roundi(base_pt.y))
		
		if tile_pos != prev_tile:
			prev_tile = tile_pos
			# Alternate between packed earth (0,1) and occasional stepping stones (3,1 / 4,1)
			if (tile_pos.x + tile_pos.y) % 5 == 0:
				path_layer.set_cell(tile_pos, 1, Vector2i(3, 1))
			else:
				path_layer.set_cell(tile_pos, 1, Vector2i(0, 1))

func _decorate_village_properties() -> void:
	# Campfire hearth seating: wooden log bench and stump
	decor_layer.set_cell(Vector2i(-2, 0), 1, Vector2i(2, 3)) # Tree stump seat west
	decor_layer.set_cell(Vector2i(2, 0), 1, Vector2i(3, 3))  # Mossy log bench east
	
	# Waystone shrine: ring of mystic blue flowers and wild grass
	decor_layer.set_cell(Vector2i(-2, -4), 1, Vector2i(2, 2)) # Blue blossoms
	decor_layer.set_cell(Vector2i(2, -4), 1, Vector2i(2, 2))  # Blue blossoms
	decor_layer.set_cell(Vector2i(0, -6), 1, Vector2i(5, 2))  # Tall grass tuft
	decor_layer.set_cell(Vector2i(-1, -6), 1, Vector2i(5, 2)) # Tall grass tuft
	
	# 1. Elder Estate (-350, -260) -> Tile (-11, -8)
	var e_base := Vector2i(-11, -8)
	decor_layer.set_cell(e_base + Vector2i(-2, 0), 1, Vector2i(3, 2)) # Red poppies
	decor_layer.set_cell(e_base + Vector2i(-2, 1), 1, Vector2i(3, 2))
	decor_layer.set_cell(e_base + Vector2i(2, 0), 1, Vector2i(0, 2)) # White daisies
	decor_layer.set_cell(e_base + Vector2i(2, 1), 1, Vector2i(0, 2))
	decor_layer.set_cell(e_base + Vector2i(-3, -2), 1, Vector2i(4, 2)) # Green hedge
	decor_layer.set_cell(e_base + Vector2i(0, -2), 1, Vector2i(4, 2))
	decor_layer.set_cell(e_base + Vector2i(3, -2), 1, Vector2i(4, 2))
	
	# 2. Carpenter Workshop (350, -260) -> Tile (11, -8)
	var c_base := Vector2i(11, -8)
	decor_layer.set_cell(c_base + Vector2i(-2, 1), 1, Vector2i(2, 3)) # Chopped stump
	decor_layer.set_cell(c_base + Vector2i(2, 0), 1, Vector2i(3, 3))  # Fallen log
	decor_layer.set_cell(c_base + Vector2i(2, 1), 1, Vector2i(3, 3))  # Fallen log
	decor_layer.set_cell(c_base + Vector2i(3, 0), 1, Vector2i(5, 3))  # Shrub/clover
	decor_layer.set_cell(c_base + Vector2i(-2, -1), 1, Vector2i(0, 3)) # Cobblestone
	
	# 3. Chef Maria Cottage (-350, 280) -> Tile (-11, 9)
	var f_base := Vector2i(-11, 9)
	decor_layer.set_cell(f_base + Vector2i(-2, 0), 1, Vector2i(1, 2)) # Yellow spice flowers
	decor_layer.set_cell(f_base + Vector2i(-2, -1), 1, Vector2i(2, 2)) # Blue herbs
	decor_layer.set_cell(f_base + Vector2i(2, 0), 1, Vector2i(4, 3))  # Ferns
	decor_layer.set_cell(f_base + Vector2i(2, -1), 1, Vector2i(5, 3)) # Clover
	decor_layer.set_cell(f_base + Vector2i(-3, 1), 1, Vector2i(4, 2)) # Rounded bush
	
	# 4. Miner Outpost (350, 280) -> Tile (11, 9)
	var m_base := Vector2i(11, 9)
	decor_layer.set_cell(m_base + Vector2i(2, 0), 1, Vector2i(1, 3))  # Mossy boulder
	decor_layer.set_cell(m_base + Vector2i(2, 1), 1, Vector2i(0, 3))  # Small rock
	decor_layer.set_cell(m_base + Vector2i(-2, 1), 1, Vector2i(1, 3)) # Mossy boulder
	decor_layer.set_cell(m_base + Vector2i(-2, 0), 1, Vector2i(0, 3)) # Small rock
	
	# 5. Northern Quarry (Miner Torvald: -60, -380 -> Tile -2, -12)
	var q_base := Vector2i(-2, -12)
	decor_layer.set_cell(q_base + Vector2i(-1, 0), 1, Vector2i(1, 3)) # Mossy boulder
	decor_layer.set_cell(q_base + Vector2i(1, 1), 1, Vector2i(0, 3))  # Rocks
	decor_layer.set_cell(q_base + Vector2i(2, -1), 1, Vector2i(1, 3)) # Boulder

func _scatter_clustered_wilderness(radius: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	
	var cluster_count := int(radius * 0.35)
	for _c in range(cluster_count):
		var angle := rng.randf_range(0, TAU)
		var dist := rng.randf_range(16.0, float(radius) - 10.0)
		var cluster_center := Vector2i(roundi(cos(angle) * dist), roundi(sin(angle) * dist))
		
		var cluster_type := rng.randi() % 4
		var cluster_size := rng.randi_range(3, 5)
		
		for _s in range(cluster_size):
			var offset := Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			var pt := cluster_center + offset
			
			if path_layer.get_cell_source_id(pt) != -1 or decor_layer.get_cell_source_id(pt) != -1:
				continue
			
			match cluster_type:
				0:
					var flw_idx := 0 if rng.randf() < 0.6 else 1
					decor_layer.set_cell(pt, 1, Vector2i(flw_idx, 2))
				1:
					var f_tile := Vector2i(4, 2) if rng.randf() < 0.5 else Vector2i(5, 2)
					decor_layer.set_cell(pt, 1, f_tile)
				2:
					var r_tile := Vector2i(1, 3) if rng.randf() < 0.5 else Vector2i(2, 3)
					decor_layer.set_cell(pt, 1, r_tile)
				3:
					var b_tile := Vector2i(2, 2) if rng.randf() < 0.5 else Vector2i(3, 2)
					decor_layer.set_cell(pt, 1, b_tile)

func reload_terrain() -> void:
	generate_tiles()
