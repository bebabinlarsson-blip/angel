@tool
extends SceneTree

func _init() -> void:
	var ts: TileSet = load("res://assets/tilesets/angel_environment_tileset.tres")
	for src_id in [0, 11, 12, 14, 16, 17, 19]:
		var atlas: TileSetAtlasSource = ts.get_source(src_id)
		var list: Array[Vector2i] = []
		for idx in range(mini(atlas.get_tiles_count(), 20)):
			list.append(atlas.get_tile_id(idx))
		print("Source ", src_id, " sample tiles: ", list)
	quit(0)
