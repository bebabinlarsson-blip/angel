class_name IslandWorld
extends Node2D

var ground: TileMapLayer
var paths: TileMapLayer
var trees: TileMapLayer
var bridge: TileMapLayer
var structures: TileMapLayer
var decor: TileMapLayer
var map_texture: ImageTexture
var bounds := Rect2(-3520, -3520, 7040, 7040)
var radius: float = 3500.0
var revision: int = 0
var reserved: Array[Vector2] = []
var land: Dictionary = {}

func rebuild(world: Node2D, config: Dictionary = {}) -> void:
	ground = world.get_node_or_null("GroundLayer")
	paths = world.get_node_or_null("PathLayer")
	trees = world.get_node_or_null("TreeLayer")
	bridge = world.get_node_or_null("BridgeLayer")
	structures = world.get_node_or_null("StructuresLayer")
	decor = world.get_node_or_null("DecorLayer")
	y_sort_enabled = true
	
	var water_layer: TileMapLayer = world.get_node_or_null("WaterLayer")
	var farm_layer: TileMapLayer = world.get_node_or_null("FarmLayer")
	
	land.clear()
	if ground:
		for cell: Vector2i in ground.get_used_cells():
			land[cell] = true
		var used_rect: Rect2i = ground.get_used_rect()
		bounds = Rect2(Vector2(used_rect.position) * 32.0, Vector2(used_rect.size) * 32.0)
		radius = maxf(bounds.size.x, bounds.size.y) * 0.5
	else:
		bounds = Rect2(-3520, -3520, 7040, 7040)
		radius = 3500.0

	reserved.clear()
	var waystones := world.get_node_or_null("Waystones")
	if waystones:
		for child in waystones.get_children():
			if child is Node2D:
				reserved.append(child.global_position)
	var npcs := world.get_node_or_null("VillageNPCs")
	if npcs:
		for child in npcs.get_children():
			if child is Node2D:
				reserved.append(child.global_position)
	var campfire := world.get_node_or_null("Campfire")
	if campfire is Node2D:
		reserved.append(campfire.global_position)
	var mining := world.get_node_or_null("MiningArea")
	if mining:
		for child in mining.get_children():
			if child is Node2D:
				reserved.append(child.global_position)
	
	for house: Dictionary in config.get("village", {}).get("houses", []):
		var pos_dict = house.get("pos", {})
		reserved.append(Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0)))
	for stone: Dictionary in config.get("waystones", []):
		var pos_dict = stone.get("pos", {})
		reserved.append(Vector2(pos_dict.get("x", 0.0), pos_dict.get("y", 0.0)))
	
	_refresh_map(water_layer, farm_layer)
	revision += 1

func is_water(p: Vector2) -> bool:
	if not is_instance_valid(ground):
		return false
	var cell: Vector2i = ground.local_to_map(ground.to_local(p))
	if is_instance_valid(bridge) and bridge.get_cell_source_id(cell) != -1:
		return false
	return not land.has(cell)

func is_clear(p: Vector2, clearance: float = 36.0) -> bool:
	if is_water(p):
		return false
	if not is_instance_valid(ground):
		return true
	var cell: Vector2i = ground.local_to_map(ground.to_local(p))
	if is_instance_valid(paths) and paths.get_cell_source_id(cell) != -1:
		return false
	if is_instance_valid(structures) and structures.get_cell_source_id(cell) != -1:
		return false
	for spot: Vector2 in reserved:
		if p.distance_to(spot) < clearance + 72.0:
			return false
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if is_water(p + offset * clearance):
			return false
	if is_instance_valid(trees):
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if trees.get_cell_source_id(cell + Vector2i(dx, dy)) != -1:
					return false
	return true

func _refresh_map(water_layer: TileMapLayer = null, farm_layer: TileMapLayer = null) -> void:
	var used_rect := Rect2i(Vector2i(bounds.position / 32.0), Vector2i(bounds.size / 32.0))
	var dim_x: int = clampi(used_rect.size.x, 32, 1024)
	var dim_y: int = clampi(used_rect.size.y, 32, 1024)
	var img := Image.create(dim_x, dim_y, false, Image.FORMAT_RGBA8)
	img.fill(Color("#244853")) # Match MinimapDrawer ocean color
	
	var origin: Vector2i = used_rect.position
	
	# 1. Base Ground (Grass & Cliffs)
	for cell: Vector2i in land:
		var color := Color("#73974c") # Lush Grass
		if ground:
			var coords: Vector2i = ground.get_cell_atlas_coords(cell)
			if coords.y >= 8 and coords.y <= 13 and coords.x <= 5:
				color = Color("#5a5448") # Rocky Cliff
		var pixel: Vector2i = cell - origin
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
			img.set_pixelv(pixel, color)
			
	# 2. Lake Water
	if water_layer:
		var cell_radius: float = radius / 32.0
		for cell: Vector2i in water_layer.get_used_cells():
			if cell.length() < cell_radius and not land.has(cell):
				var pixel: Vector2i = cell - origin
				if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
					img.set_pixelv(pixel, Color("#276b80"))
					
	# 3. Farmland plots
	if farm_layer:
		for cell: Vector2i in farm_layer.get_used_cells():
			var pixel: Vector2i = cell - origin
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
				img.set_pixelv(pixel, Color("#673e1e"))
				
	# 4. Pathways & Roads
	if paths:
		for cell: Vector2i in paths.get_used_cells():
			var pixel: Vector2i = cell - origin
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
				img.set_pixelv(pixel, Color("#c39e68"))
				
	# 5. Wooden Bridge
	if bridge:
		for cell: Vector2i in bridge.get_used_cells():
			var pixel: Vector2i = cell - origin
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
				img.set_pixelv(pixel, Color("#835327"))
				
	# 6. Tree Groves
	if trees:
		for cell: Vector2i in trees.get_used_cells():
			var pixel: Vector2i = cell - origin
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
				img.set_pixelv(pixel, Color("#264c2f"))
	
	# 7. Structures (Houses, Ruins, Cave Entrance)
	if structures:
		for cell: Vector2i in structures.get_used_cells():
			var pixel: Vector2i = cell - origin
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
				img.set_pixelv(pixel, Color("#8b8277"))
				
	map_texture = ImageTexture.create_from_image(img)
