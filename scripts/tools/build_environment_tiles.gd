extends SceneTree

## Builds the authored environment TileSet and the TileMapLayer scenes used by
## the overworld and interior rooms. This is an editor/build tool: the game
## does not generate these placements at runtime.

const TILESET_OUTPUT := "res://assets/tilesets/angel_environment_tileset.tres"
const ENVIRONMENT_OUTPUT := "res://scenes/world/authored_environment.tscn"
const HOUSE_INTERIOR_OUTPUT := "res://scenes/interiors/house_tiles.tscn"
const CHURCH_INTERIOR_OUTPUT := "res://scenes/interiors/church_tiles.tscn"
const MINE_INTERIOR_OUTPUT := "res://scenes/interiors/mine_tiles.tscn"
const MASTER_TILESET := "res://assets/tilesets/master_tileset.tres"

const SUPPLEMENTAL_SOURCES := {
	10: "res://assets/tilesets/scaled_32/ninja_floor_32.png",
	11: "res://assets/tilesets/scaled_32/Basic_Furniture.png",
	12: "res://assets/tilesets/scaled_32/Paths.png",
	13: "res://assets/tilesets/scaled_32/Water.png",
	14: "res://assets/tilesets/scaled_32/Grass.png",
	15: "res://assets/tilesets/scaled_32/Tilled_Dirt.png",
	16: "res://assets/tilesets/scaled_32/trees_atlas_32.png",
	17: "res://assets/tilesets/scaled_32/Fences.png",
	18: "res://assets/tilesets/scaled_32/Wood_Bridge.png",
	19: "res://assets/tilesets/scaled_32/Wooden_House.png",
	20: "res://assets/sprites/world/ore_vein.png",
	21: "res://assets/sprites/items/item_wood.png",
	22: "res://assets/sprites/items/item_herb.png",
	23: "res://assets/sprites/items/item_mushroom.png",
	24: "res://assets/sprites/items/item_ore.png",
	25: "res://assets/sprites/world/rock_boulder.png",
	26: "res://assets/sprites/world/wildflower.png",
	27: "res://assets/sprites/world/campfire.png",
}

func _init() -> void:
	var tileset := _build_tileset()
	if tileset == null:
		quit(1)
		return
	if ResourceSaver.save(tileset, TILESET_OUTPUT) != OK:
		push_error("Could not save " + TILESET_OUTPUT)
		quit(1)
		return

	_build_overworld_scene(tileset)
	_build_interior_scene(tileset, HOUSE_INTERIOR_OUTPUT, "HouseInteriorTiles", 5, 0)
	_build_interior_scene(tileset, CHURCH_INTERIOR_OUTPUT, "ChurchInteriorTiles", 11, 1)
	_build_interior_scene(tileset, MINE_INTERIOR_OUTPUT, "MineInteriorTiles", 8, 2)
	print("Built authored environment TileSet and TileMapLayer scenes.")
	quit()

func _build_tileset() -> TileSet:
	var base := load(MASTER_TILESET) as TileSet
	if base == null:
		push_error("Missing base TileSet: " + MASTER_TILESET)
		return null
	var tileset := base.duplicate(true) as TileSet
	tileset.resource_name = "Angel Environment TileSet"
	tileset.set_meta("purpose", "Authored roads, terrain, buildings, cave entrances, interiors and materials")
	tileset.set_meta("tile_size", Vector2i(32, 32))
	tileset.set_meta("source_catalog", "master atlas + floor/furniture/material atlases")

	# The base master atlas keeps its source IDs (0 and 2), including the
	# existing multi-cell buildings/ruins and their authored physics polygons.
	for source_id: int in SUPPLEMENTAL_SOURCES:
		if tileset.has_source(source_id):
			continue
		var texture := load(str(SUPPLEMENTAL_SOURCES[source_id])) as Texture2D
		if texture == null:
			push_warning("Skipping missing TileSet atlas: " + str(SUPPLEMENTAL_SOURCES[source_id]))
			continue
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(32, 32)
		var columns := maxi(1, int(texture.get_width() / 32))
		var rows := maxi(1, int(texture.get_height() / 32))
		for y in range(rows):
			for x in range(columns):
				source.create_tile(Vector2i(x, y))
		tileset.add_source(source, source_id)
	return tileset

func _new_layer(root: Node2D, layer_name: String, z: int, y_sort: bool = false) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.z_index = z
	layer.y_sort_enabled = y_sort
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.tile_set = load(TILESET_OUTPUT) as TileSet
	root.add_child(layer)
	layer.owner = root
	return layer

func _build_overworld_scene(tileset: TileSet) -> void:
	var root := Node2D.new()
	root.name = "AuthoredEnvironment"
	root.set_meta("authored_tileset", TILESET_OUTPUT)
	root.set_meta("placement_mode", "TileMapLayer cells; no runtime environment drawing")

	var path_layer := _new_layer(root, "PathLayer", -92, false)
	var water_layer := _new_layer(root, "WaterLayer", -111, false)
	var farm_layer := _new_layer(root, "FarmLayer", -86, false)
	var decor_layer := _new_layer(root, "DecorLayer", -84, true)
	var tree_layer := _new_layer(root, "TreeLayer", -54, true)
	var building_layer := _new_layer(root, "BuildingLayer", -52, true)
	var cave_layer := _new_layer(root, "CaveLayer", -51, true)
	var landmark_layer := _new_layer(root, "LandmarkLayer", -50, true)
	var material_layer := _new_layer(root, "MaterialLayer", -42, true)
	var object_layer := _new_layer(root, "ObjectLayer", -40, true)

	# Dirt-road tiles are real atlas cells from the master source. The small
	# variation tile keeps long paths from looking stamped without drawing them.
	_draw_line(path_layer, Vector2i(-34, 0), Vector2i(34, 0), 0, Vector2i(10, 0))
	_draw_line(path_layer, Vector2i(0, -34), Vector2i(0, 34), 0, Vector2i(11, 0))
	_draw_polyline(path_layer, [Vector2i(0, -30), Vector2i(-18, -48), Vector2i(-38, -62), Vector2i(-68, -74)], 0, Vector2i(10, 0))
	_draw_polyline(path_layer, [Vector2i(2, -2), Vector2i(8, -12), Vector2i(16, -22)], 0, Vector2i(11, 0))
	_draw_polyline(path_layer, [Vector2i(2, 3), Vector2i(-15, 16), Vector2i(-30, 30), Vector2i(-52, 34)], 0, Vector2i(10, 0))
	_draw_polyline(path_layer, [Vector2i(3, 4), Vector2i(20, 13), Vector2i(34, 21), Vector2i(48, 27)], 0, Vector2i(11, 0))

	# Authored lake cells, using the water tile from the same unified TileSet.
	for y in range(22, 31):
		for x in range(44, 59):
			water_layer.set_cell(Vector2i(x, y), 0, Vector2i(18, 0))
	for y in range(25, 28):
		for x in range(59, 65):
			water_layer.set_cell(Vector2i(x, y), 0, Vector2i(18, 0))

	# A tiled farm plot on the west route.
	for y in range(27, 38):
		for x in range(-58, -43):
			farm_layer.set_cell(Vector2i(x, y), 15, Vector2i(0, 0))

	# A few authored trees, not runtime-drawn village decoration. The master
	# atlas defines these as multi-cell tiles with y-sort origins and collisions.
	_place(tree_layer, Vector2i(25, -42), 0, Vector2i(0, 45))
	_place(tree_layer, Vector2i(42, -48), 0, Vector2i(4, 45))
	_place(tree_layer, Vector2i(57, -37), 0, Vector2i(8, 45))
	_place(tree_layer, Vector2i(-47, 18), 0, Vector2i(4, 45))

	# Four village buildings use the master atlas's full 4x4 house tiles.
	_place(building_layer, Vector2i(-14, -6), 0, Vector2i(0, 36))
	_place(building_layer, Vector2i(6, -6), 0, Vector2i(4, 36))
	_place(building_layer, Vector2i(-14, 1), 0, Vector2i(8, 36))
	_place(building_layer, Vector2i(6, 1), 0, Vector2i(12, 36))
	# A church landmark is another multi-cell atlas tile, with a clear front
	# door used by the authored InteriorEntry scene.
	_place(building_layer, Vector2i(14, -24), 0, Vector2i(11, 40))

	# The green ruin tile has a dark open doorway and is used as the northern
	# cave mouth. The entry trigger is authored at its front door in the scene.
	_place(cave_layer, Vector2i(-70, -77), 0, Vector2i(16, 40))
	# A citadel/temple landmark gives the southern route a tile-authored goal.
	_place(landmark_layer, Vector2i(2, 68), 0, Vector2i(0, 40))
	_place(landmark_layer, Vector2i(21, 40), 0, Vector2i(21, 40))

	# Interactive resource nodes still live as gameplay Area2Ds, but their
	# visible material tiles are authored here and come from the unified atlas.
	_place(material_layer, Vector2i(-48, 16), 21, Vector2i.ZERO) # wood
	_place(material_layer, Vector2i(-43, 20), 22, Vector2i.ZERO) # herb
	_place(material_layer, Vector2i(31, -45), 23, Vector2i.ZERO) # mushroom
	_place(material_layer, Vector2i(-64, -66), 20, Vector2i.ZERO) # ore vein
	_place(material_layer, Vector2i(-60, -62), 25, Vector2i.ZERO) # boulder
	_place(material_layer, Vector2i(37, -40), 26, Vector2i.ZERO) # wildflower
	_place(object_layer, Vector2i(0, 0), 27, Vector2i(0, 0)) # campfire tile

	_save_scene(root, ENVIRONMENT_OUTPUT)

func _build_interior_scene(tileset: TileSet, output_path: String, root_name: String, floor_x: int, style: int) -> void:
	var root := Node2D.new()
	root.name = root_name
	root.set_meta("authored_tileset", TILESET_OUTPUT)
	root.set_meta("placement_mode", "TileMapLayer cells; room visuals are scene-authored")
	var floor_layer := _new_layer(root, "FloorLayer", -30, false)
	var trim_layer := _new_layer(root, "TrimLayer", -29, false)
	var furniture_layer := _new_layer(root, "FurnitureLayer", -20, true)

	# Rooms are 30x20 cells, matching the 960x640 interior bounds.
	for y in range(-10, 10):
		for x in range(-15, 15):
			floor_layer.set_cell(Vector2i(x, y), 10, Vector2i(floor_x, style))
	for x in range(-15, 15):
		trim_layer.set_cell(Vector2i(x, -10), 0, Vector2i(10, 0))
		trim_layer.set_cell(Vector2i(x, 9), 0, Vector2i(10, 0))
	for y in range(-9, 9):
		trim_layer.set_cell(Vector2i(-15, y), 0, Vector2i(10, 0))
		trim_layer.set_cell(Vector2i(14, y), 0, Vector2i(10, 0))

	match style:
		0: # house furniture
			_place(furniture_layer, Vector2i(-10, -7), 11, Vector2i(2, 0))
			_place(furniture_layer, Vector2i(8, -7), 11, Vector2i(4, 0))
			_place(furniture_layer, Vector2i(-8, 2), 11, Vector2i(2, 3))
			_place(furniture_layer, Vector2i(4, 2), 11, Vector2i(3, 2))
			_place(furniture_layer, Vector2i(8, 2), 11, Vector2i(5, 3))
		1: # church pews and altar pieces
			for x in [-9, -3, 3, 9]:
				_place(furniture_layer, Vector2i(x, -3), 11, Vector2i(3, 2))
				_place(furniture_layer, Vector2i(x, 0), 11, Vector2i(3, 2))
			_place(furniture_layer, Vector2i(0, -7), 11, Vector2i(5, 3))
			_place(furniture_layer, Vector2i(0, 5), 11, Vector2i(2, 3))
		2: # mine props; rock visuals are supplied by authored MiningRock nodes
			for x in [-10, 10]:
				_place(furniture_layer, Vector2i(x, -6), 11, Vector2i(2, 3))
				_place(furniture_layer, Vector2i(x, 5), 11, Vector2i(3, 2))
			_place(furniture_layer, Vector2i(-2, -3), 11, Vector2i(0, 5))

	_save_scene(root, output_path)

func _draw_line(layer: TileMapLayer, from_cell: Vector2i, to_cell: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
	if from_cell.y == to_cell.y:
		for x in range(mini(from_cell.x, to_cell.x), maxi(from_cell.x, to_cell.x) + 1):
			layer.set_cell(Vector2i(x, from_cell.y), source_id, atlas_coords if x % 5 != 0 else Vector2i(11, 0))
	elif from_cell.x == to_cell.x:
		for y in range(mini(from_cell.y, to_cell.y), maxi(from_cell.y, to_cell.y) + 1):
			layer.set_cell(Vector2i(from_cell.x, y), source_id, atlas_coords if y % 5 != 0 else Vector2i(10, 0))

func _draw_polyline(layer: TileMapLayer, points: Array, source_id: int, atlas_coords: Vector2i) -> void:
	for i in range(points.size() - 1):
		var a: Vector2i = points[i]
		var b: Vector2i = points[i + 1]
		var steps := maxi(abs(b.x - a.x), abs(b.y - a.y))
		for step in range(steps + 1):
			var t := float(step) / float(maxi(steps, 1))
			var cell := Vector2i(roundi(lerpf(float(a.x), float(b.x), t)), roundi(lerpf(float(a.y), float(b.y), t)))
			layer.set_cell(cell, source_id, atlas_coords if step % 5 != 0 else Vector2i(11, 0))

func _place(layer: TileMapLayer, cell: Vector2i, source_id: int, atlas_coords: Vector2i) -> void:
	layer.set_cell(cell, source_id, atlas_coords)

func _save_scene(root: Node2D, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		push_error("Could not pack " + path + ": " + error_string(err))
		return
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("Could not save " + path + ": " + error_string(err))
