class_name TileSetVisual
extends RefCounted

## Shared atlas lookup for world props and collectible materials.
## The map and the pickup entities use the same imported source textures.

const TILESET_PATH := "res://assets/tilesets/angel_world_tileset.tres"
static var _world_tileset: TileSet = null

static func _get_tileset() -> TileSet:
	if _world_tileset == null:
		_world_tileset = load(TILESET_PATH) as TileSet
	return _world_tileset

static func _source_texture(source_id: int) -> Texture2D:
	var world_tileset := _get_tileset()
	if world_tileset == null:
		return null
	var source := world_tileset.get_source(source_id) as TileSetAtlasSource
	if source == null:
		return null
	return source.texture

static func _texture_region(source_id: int, origin: Vector2, region_size: Vector2) -> Texture2D:
	var atlas := _source_texture(source_id)
	if atlas == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(origin, region_size)
	return texture

static func texture_for_item(item_id: String) -> Texture2D:
	var direct_sources := {
		"wood": 19,
		"herb": 20,
		"mushroom": 21,
		"iron_ore": 22,
		"gold_ore": 22,
		"stone": 22,
		"coal": 22,
		"ore": 22,
		"ore_vein": 43,
		"wildflower": 23,
	}
	if direct_sources.has(item_id):
		return _texture_region(int(direct_sources[item_id]), Vector2.ZERO, Vector2(32.0, 32.0))

	var plant_coords := {
		"plant": Vector2(0.0, 0.0),
		"flower": Vector2(16.0, 0.0),
		"berry": Vector2(32.0, 0.0),
		"apple": Vector2(48.0, 0.0),
		"orange": Vector2(64.0, 0.0),
		"pear": Vector2(80.0, 0.0),
		"banana": Vector2(0.0, 16.0),
		"grapes": Vector2(16.0, 16.0),
		"tomato": Vector2(32.0, 16.0),
		"carrot": Vector2(48.0, 16.0),
		"coconut": Vector2(64.0, 16.0),
		"watermelon": Vector2(80.0, 16.0),
		"wheat": Vector2(0.0, 0.0),
		"reeds": Vector2(16.0, 0.0),
		"fiber": Vector2(32.0, 0.0),
		"clover": Vector2(48.0, 16.0),
		"mint": Vector2(64.0, 16.0),
		"lavender": Vector2(80.0, 16.0),
		"rose": Vector2(16.0, 16.0),
		"moon_petal": Vector2(32.0, 16.0),
	}
	if plant_coords.has(item_id):
		return _texture_region(17, plant_coords[item_id], Vector2(16.0, 16.0))
	return null

static func scale_for_item(item_id: String) -> float:
	var plant_ids := [
		"plant", "flower", "berry", "apple", "orange", "pear", "banana",
		"grapes", "tomato", "carrot", "coconut", "watermelon", "wheat",
		"reeds", "fiber", "clover", "mint", "lavender", "rose", "moon_petal"
	]
	return 2.0 if item_id in plant_ids else 1.25
