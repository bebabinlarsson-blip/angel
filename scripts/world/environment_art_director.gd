class_name EnvironmentArtDirector
extends Node

## Composes the authored overworld from the project's canonical 32 px atlas.
##
## This deliberately writes into the existing gameplay-aware TileMapLayers
## instead of drawing colored shapes or creating one node per prop. Keeping
## paths, farms, decor, trees and structures in those layers preserves the
## minimap, clear-space checks, collision source and y-sorting conventions.

const CELL_SIZE := 32
const MASTER_SOURCE_ID := 0

const PATH_TILES := [Vector2i(10, 0), Vector2i(11, 0), Vector2i(12, 0)]
const FLOWER_TILES := [
	Vector2i(10, 8), Vector2i(11, 8), Vector2i(12, 8), Vector2i(13, 8),
	Vector2i(14, 8), Vector2i(7, 10), Vector2i(8, 10), Vector2i(12, 10),
	Vector2i(13, 10), Vector2i(14, 10), Vector2i(17, 10), Vector2i(18, 10),
]
const ROCK_TILES := [Vector2i(19, 8), Vector2i(20, 8), Vector2i(21, 8)]
const CROP_TILES := [Vector2i(19, 24), Vector2i(20, 24), Vector2i(21, 24), Vector2i(23, 24), Vector2i(24, 24)]
const TREE_TILES := [
	Vector2i(0, 14), Vector2i(3, 14), Vector2i(6, 14), Vector2i(8, 14),
	Vector2i(10, 14), Vector2i(12, 14), Vector2i(14, 14),
]
const TREE_SIZES := [
	Vector2i(3, 4), Vector2i(3, 4), Vector2i(2, 4), Vector2i(2, 4),
	Vector2i(2, 2), Vector2i(2, 2), Vector2i(2, 2),
]

const PATH_TILE := Vector2i(10, 0)
const FENCE_POST_TILE := Vector2i(24, 0)
const BRIDGE_TILES := [Vector2i(18, 1), Vector2i(19, 1), Vector2i(20, 1), Vector2i(21, 1)]

var ground: TileMapLayer
var paths: TileMapLayer
var decor: TileMapLayer
var bridge: TileMapLayer
var farm: TileMapLayer
var trees: TileMapLayer
var structures: TileMapLayer


func rebuild(world: Node2D, config: Dictionary) -> void:
	_cache_layers(world)
	if ground == null or ground.tile_set == null:
		push_warning("Angel: environment art could not find GroundLayer or its TileSet.")
		return
	if not ground.tile_set.has_source(MASTER_SOURCE_ID):
		push_warning("Angel: master TileSet source 0 is unavailable for environment art.")
		return

	_prepare_layers()
	var village_cell := _point_to_cell(_dictionary_point(config.get("village", {}).get("center", {})))
	_build_village(village_cell, config)
	_build_farmland(_landmark_cell(config, "western_farmlands", Vector2i(-52, 32)))
	_build_highlands(_landmark_cell(config, "northwest_highlands", Vector2i(-65, -70)))
	_build_woods(_landmark_cell(config, "whispering_woods", Vector2i(62, -55)))
	_build_lakeshore(_landmark_cell(config, "serpentine_lake", Vector2i(48, 28)))
	_build_citadel(_landmark_cell(config, "forgotten_citadel", Vector2i(5, 72)))
	_scatter_meadow_detail(village_cell)
	_scatter_grounded_trees(village_cell)


func _cache_layers(world: Node2D) -> void:
	ground = world.get_node_or_null("GroundLayer") as TileMapLayer
	paths = world.get_node_or_null("PathLayer") as TileMapLayer
	decor = world.get_node_or_null("DecorLayer") as TileMapLayer
	bridge = world.get_node_or_null("BridgeLayer") as TileMapLayer
	farm = world.get_node_or_null("FarmLayer") as TileMapLayer
	trees = world.get_node_or_null("TreeLayer") as TileMapLayer
	structures = world.get_node_or_null("StructuresLayer") as TileMapLayer


func _prepare_layers() -> void:
	for layer in [paths, decor, bridge, farm, trees, structures]:
		if layer == null:
			continue
		layer.clear()
		layer.position = Vector2.ZERO
		layer.scale = Vector2.ONE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.tile_set = ground.tile_set

	if paths != null:
		paths.z_index = -90
	if farm != null:
		farm.z_index = -85
	if bridge != null:
		bridge.z_index = -80
	for layer in [decor, trees, structures]:
		if layer != null:
			layer.y_sort_enabled = true


func _build_village(center: Vector2i, config: Dictionary) -> void:
	# A compact, connected road network replaces the legacy draw_polyline roads.
	var plaza := center + Vector2i(0, -7)
	_paint_square(paths, plaza, Vector2i(4, 3), PATH_TILES)
	_paint_road([center + Vector2i(-36, 12), center + Vector2i(-22, 8), center + Vector2i(-9, 2), plaza], 1)
	_paint_road([center + Vector2i(36, 11), center + Vector2i(20, 7), center + Vector2i(8, 1), plaza], 1)
	_paint_road([center + Vector2i(-7, -34), center + Vector2i(-5, -18), center + Vector2i(-2, -10), plaza], 1)
	_paint_road([center + Vector2i(8, 34), center + Vector2i(5, 18), center + Vector2i(2, 2), plaza], 1)

	# Named homes match the layout JSON and leave clear approach space for NPCs.
	var houses: Array = config.get("village", {}).get("houses", [])
	var house_atlases := [Vector2i(0, 36), Vector2i(4, 36), Vector2i(8, 36), Vector2i(12, 36)]
	for index in range(mini(houses.size(), house_atlases.size())):
		var house: Dictionary = houses[index]
		var anchor := _point_to_cell(_dictionary_point(house.get("pos", {}))) + Vector2i(-2, -3)
		_place_object(structures, anchor, house_atlases[index], Vector2i(4, 4))

	# The centre uses atlas props, not a hand-drawn fountain or market.
	_place_object(structures, plaza + Vector2i(-1, 0), Vector2i(19, 19), Vector2i(2, 2))
	_place_object(structures, center + Vector2i(-7, -4), Vector2i(16, 18), Vector2i(3, 3))
	_place_object(structures, center + Vector2i(5, -4), Vector2i(16, 18), Vector2i(3, 3))
	# This footprint ends at the existing abandoned-church transition trigger.
	_place_object(structures, center + Vector2i(14, -26), Vector2i(11, 40), Vector2i(5, 5))
	_place_fence_ring(center, 15, 12)
	_scatter_cells(decor, center, [
		Vector2i(-10, -11), Vector2i(10, -11), Vector2i(-13, -3), Vector2i(13, -3),
		Vector2i(-11, 7), Vector2i(11, 7), Vector2i(-4, 10), Vector2i(4, 10),
	], FLOWER_TILES)


func _build_farmland(center: Vector2i) -> void:
	var field_origin := center + Vector2i(-10, -6)
	var field_size := Vector2i(20, 13)
	_paint_rect(farm, field_origin, field_size, PATH_TILES)
	for y in range(1, field_size.y - 1):
		for x in range(1, field_size.x - 1):
			if (x + y * 3) % 3 == 0:
				_place_cell(farm, field_origin + Vector2i(x, y), CROP_TILES[(x + y) % CROP_TILES.size()])
	_place_field_fence(field_origin, field_size)
	_paint_road([center + Vector2i(0, 0), center + Vector2i(14, -2), center + Vector2i(34, -10)], 1)
	_place_object(structures, center + Vector2i(-4, 9), Vector2i(12, 18), Vector2i(4, 3))


func _build_highlands(center: Vector2i) -> void:
	# The base aligns to the already-authored Northern Mine transition at
	# (-2112, -2016), rather than leaving the door detached from its landmark.
	var cave_anchor := center + Vector2i(-3, 3)
	_place_object(structures, cave_anchor, Vector2i(16, 40), Vector2i(5, 4))
	_place_object(structures, center + Vector2i(-12, 6), Vector2i(21, 40), Vector2i(4, 4))
	_scatter_cells(decor, center, [
		Vector2i(-15, -7), Vector2i(-11, -11), Vector2i(-6, -10), Vector2i(4, -8),
		Vector2i(9, -3), Vector2i(12, 5), Vector2i(-13, 8), Vector2i(-7, 10),
	], ROCK_TILES)
	_paint_road([center + Vector2i(1, 22), center + Vector2i(-2, 11), center + Vector2i(0, 4)], 1)


func _build_woods(center: Vector2i) -> void:
	_place_tree_cluster(center, [
		Vector2i(-16, -10), Vector2i(-8, -13), Vector2i(0, -11), Vector2i(9, -12),
		Vector2i(16, -8), Vector2i(-18, 1), Vector2i(-11, 4), Vector2i(0, 1),
		Vector2i(10, 3), Vector2i(18, 8), Vector2i(-14, 12), Vector2i(-3, 13), Vector2i(7, 14),
	])
	_scatter_cells(decor, center, [
		Vector2i(-4, -5), Vector2i(5, -6), Vector2i(-7, 7), Vector2i(4, 8), Vector2i(12, 11),
	], FLOWER_TILES)
	_paint_road([center + Vector2i(-30, 18), center + Vector2i(-16, 12), center + Vector2i(-5, 8)], 1)


func _build_lakeshore(center: Vector2i) -> void:
	# A short boardwalk is intentionally placed on stable land next to the lake
	# landmark, so it reads as a dock without changing water collision rules.
	for x in range(-4, 5):
		_place_cell(bridge, center + Vector2i(x, 2), BRIDGE_TILES[(x + 4) % BRIDGE_TILES.size()])
	_place_object(structures, center + Vector2i(-8, -8), Vector2i(22, 18), Vector2i(2, 3))
	_place_tree_cluster(center + Vector2i(10, -6), [Vector2i(-2, 0), Vector2i(5, -3), Vector2i(10, 2), Vector2i(2, 8)])
	_scatter_cells(decor, center, [Vector2i(-11, 2), Vector2i(-8, 7), Vector2i(9, 5), Vector2i(12, 9)], FLOWER_TILES)


func _build_citadel(center: Vector2i) -> void:
	_place_object(structures, center + Vector2i(-3, -6), Vector2i(11, 40), Vector2i(5, 5))
	_place_object(structures, center + Vector2i(-15, 3), Vector2i(0, 40), Vector2i(6, 5))
	_place_object(structures, center + Vector2i(10, 5), Vector2i(21, 40), Vector2i(4, 4))
	_scatter_cells(decor, center, [
		Vector2i(-12, -7), Vector2i(-8, -10), Vector2i(5, -8), Vector2i(12, -5),
		Vector2i(-15, 12), Vector2i(-7, 13), Vector2i(8, 13), Vector2i(15, 10),
	], ROCK_TILES)
	_paint_road([center + Vector2i(0, -28), center + Vector2i(-1, -14), center + Vector2i(0, -5)], 1)


func _scatter_meadow_detail(center: Vector2i) -> void:
	_scatter_cells(decor, center, [
		Vector2i(-24, -20), Vector2i(-19, -15), Vector2i(-28, -7), Vector2i(-22, 18),
		Vector2i(22, -18), Vector2i(28, -9), Vector2i(19, 18), Vector2i(27, 20),
		Vector2i(-38, 6), Vector2i(39, 3), Vector2i(-5, 26), Vector2i(7, 27),
	], FLOWER_TILES)
	_place_tree_cluster(center, [
		Vector2i(-31, -23), Vector2i(-27, 23), Vector2i(29, -21), Vector2i(31, 23),
		Vector2i(-42, -4), Vector2i(42, 6),
	])


func _scatter_grounded_trees(village_center: Vector2i) -> void:
	# The large authored island has an irregular coastline. This pass fills its
	# valid interior cells with the compact 2x2 tree family, while keeping the
	# village approaches, roads, farms and structures clear for gameplay.
	var planted := 0
	for value in ground.get_used_cells():
		if planted >= 48:
			break
		var cell: Vector2i = value
		if cell.distance_squared_to(village_center) < 22 * 22:
			continue
		if posmod(cell.x * 31 + cell.y * 17, 37) != 0:
			continue
		if not _footprint_is_free(cell, Vector2i(2, 2)):
			continue
		var tree_index := 4 + posmod(cell.x + cell.y, 3)
		if _place_object(trees, cell, TREE_TILES[tree_index], TREE_SIZES[tree_index]):
			planted += 1


func _paint_road(points: Array, half_width: int) -> void:
	if paths == null or points.size() < 2:
		return
	for index in range(points.size() - 1):
		var start: Vector2i = points[index]
		var finish: Vector2i = points[index + 1]
		var steps := maxi(absi(finish.x - start.x), absi(finish.y - start.y))
		for step in range(steps + 1):
			var weight := float(step) / float(maxi(steps, 1))
			var cell := Vector2i(roundi(lerpf(float(start.x), float(finish.x), weight)), roundi(lerpf(float(start.y), float(finish.y), weight)))
			for y in range(-half_width, half_width + 1):
				for x in range(-half_width, half_width + 1):
					_place_cell(paths, cell + Vector2i(x, y), PATH_TILES[(cell.x + cell.y + x + y) % PATH_TILES.size()])


func _paint_square(layer: TileMapLayer, center: Vector2i, half_size: Vector2i, tiles: Array) -> void:
	for y in range(-half_size.y, half_size.y + 1):
		for x in range(-half_size.x, half_size.x + 1):
			_place_cell(layer, center + Vector2i(x, y), tiles[(x + y + tiles.size() * 4) % tiles.size()])


func _paint_rect(layer: TileMapLayer, origin: Vector2i, size: Vector2i, tiles: Array) -> void:
	for y in range(size.y):
		for x in range(size.x):
			_place_cell(layer, origin + Vector2i(x, y), tiles[(x * 3 + y) % tiles.size()])


func _place_fence_ring(center: Vector2i, half_width: int, half_height: int) -> void:
	for x in range(-half_width, half_width + 1, 2):
		_place_cell(decor, center + Vector2i(x, -half_height), FENCE_POST_TILE)
		_place_cell(decor, center + Vector2i(x, half_height), FENCE_POST_TILE)
	for y in range(-half_height + 2, half_height, 2):
		_place_cell(decor, center + Vector2i(-half_width, y), FENCE_POST_TILE)
		_place_cell(decor, center + Vector2i(half_width, y), FENCE_POST_TILE)


func _place_field_fence(origin: Vector2i, size: Vector2i) -> void:
	for x in range(0, size.x, 2):
		_place_cell(decor, origin + Vector2i(x, 0), FENCE_POST_TILE)
		_place_cell(decor, origin + Vector2i(x, size.y - 1), FENCE_POST_TILE)
	for y in range(2, size.y - 1, 2):
		_place_cell(decor, origin + Vector2i(0, y), FENCE_POST_TILE)
		_place_cell(decor, origin + Vector2i(size.x - 1, y), FENCE_POST_TILE)


func _place_tree_cluster(center: Vector2i, offsets: Array) -> void:
	for index in range(offsets.size()):
		var offset: Vector2i = offsets[index]
		var tree_index := posmod(index + center.x + center.y, TREE_TILES.size())
		_place_object(trees, center + offset, TREE_TILES[tree_index], TREE_SIZES[tree_index])


func _scatter_cells(layer: TileMapLayer, center: Vector2i, offsets: Array, tiles: Array) -> void:
	for index in range(offsets.size()):
		var offset: Vector2i = offsets[index]
		_place_cell(layer, center + offset, tiles[posmod(index + center.x - center.y, tiles.size())])


func _place_cell(layer: TileMapLayer, cell: Vector2i, atlas: Vector2i) -> void:
	if layer == null or not _is_land(cell):
		return
	layer.set_cell(cell, MASTER_SOURCE_ID, atlas)


func _place_object(layer: TileMapLayer, anchor: Vector2i, atlas: Vector2i, size: Vector2i) -> bool:
	if layer == null or not _has_land_footprint(anchor, size):
		return false
	layer.set_cell(anchor, MASTER_SOURCE_ID, atlas)
	return true


func _is_land(cell: Vector2i) -> bool:
	return ground != null and ground.get_cell_source_id(cell) != -1


func _has_land_footprint(anchor: Vector2i, size: Vector2i) -> bool:
	for y in range(size.y):
		for x in range(size.x):
			if not _is_land(anchor + Vector2i(x, y)):
				return false
	return true


func _footprint_is_free(anchor: Vector2i, size: Vector2i) -> bool:
	for y in range(size.y):
		for x in range(size.x):
			var cell := anchor + Vector2i(x, y)
			if not _is_land(cell):
				return false
			for layer in [paths, farm, structures, trees]:
				if layer != null and layer.get_cell_source_id(cell) != -1:
					return false
	return true


func _landmark_cell(config: Dictionary, landmark_id: String, fallback: Vector2i) -> Vector2i:
	var landmarks: Dictionary = config.get("landmarks", {})
	var landmark: Dictionary = landmarks.get(landmark_id, {})
	var point: Dictionary = landmark.get("center", {})
	if point.is_empty():
		return fallback
	return _point_to_cell(_dictionary_point(point))


func _dictionary_point(value: Variant) -> Vector2:
	if value is Dictionary:
		var point: Dictionary = value
		return Vector2(float(point.get("x", 0.0)), float(point.get("y", 0.0)))
	return Vector2.ZERO


func _point_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x / CELL_SIZE), roundi(point.y / CELL_SIZE))
