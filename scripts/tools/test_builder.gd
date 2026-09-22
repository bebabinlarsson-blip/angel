@tool
extends SceneTree

func _init() -> void:
	print("--- Running Test Builder ---")
	var layer := TileMapLayer.new()
	layer.name = "TestLayer"
	var tileset: TileSet = load("res://assets/tilesets/angel_environment_tileset.tres")
	layer.tile_set = tileset
	layer.set_cell(Vector2i(0, 0), 14, Vector2i(1, 1))
	print("Cell set at 0,0: ", layer.get_cell_source_id(Vector2i(0, 0)))
	quit(0)
