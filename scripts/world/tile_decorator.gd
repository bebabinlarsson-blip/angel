class_name TileDecorator
extends TileMapLayer

const TILESET_PATH = "res://assets/tilesets/grass_tileset.png"
const TILE_SIZE = Vector2i(32, 32)
const SOURCE_ID = 0

var grass_tiles = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
var flower_tiles = [Vector2i(0, 1), Vector2i(1, 1)]
var rock_tiles = [Vector2i(0, 2), Vector2i(1, 2)]

func _ready() -> void:
	_setup_tileset()

func _setup_tileset() -> void:
	var tex = load(TILESET_PATH)
	if not tex:
		push_error("Failed to load tileset texture")
		return
	
	var ts = TileSet.new()
	ts.tile_size = TILE_SIZE
	
	var source = TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = TILE_SIZE
	
	# Create tiles in source for the coordinates we will use
	for coords in grass_tiles + flower_tiles + rock_tiles:
		source.create_tile(coords)
		
	ts.add_source(source, SOURCE_ID)
	
	self.tile_set = ts

func scatter_decorations(center: Vector2, radius: float, density: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var village_radius = radius * 0.3 # Leave 30% of center clear for village
	
	for i in range(density):
		var angle = rng.randf_range(0, TAU)
		var dist = rng.randf_range(village_radius, radius)
		
		var pos = center + Vector2(cos(angle), sin(angle)) * dist
		var cell_pos = local_to_map(pos)
		
		# Pick a random tile type based on some weights
		var roll = rng.randf()
		var atlas_coords = Vector2i.ZERO
		
		if roll < 0.7:
			# 70% grass detail
			atlas_coords = grass_tiles[rng.randi() % grass_tiles.size()]
		elif roll < 0.9:
			# 20% flowers
			atlas_coords = flower_tiles[rng.randi() % flower_tiles.size()]
		else:
			# 10% rocks
			atlas_coords = rock_tiles[rng.randi() % rock_tiles.size()]
			
		set_cell(cell_pos, SOURCE_ID, atlas_coords)
