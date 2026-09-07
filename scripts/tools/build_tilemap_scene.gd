extends SceneTree

func _init():
    print("Generating tilemap scene...")
    var tileset = TileSet.new()
    tileset.tile_size = Vector2i(32, 32)
    
    var source = TileSetAtlasSource.new()
    source.texture = load("res://assets/tilesets/atlas_tileset.png")
    source.texture_region_size = Vector2i(32, 32)
    
    for x in range(32):
        for y in range(21):
            source.create_tile(Vector2i(x, y))
    
    tileset.add_source(source, 1)
    
    var dir = DirAccess.open("res://assets/tilesets")
    if dir:
        ResourceSaver.save(tileset, "res://assets/tilesets/grass_tileset.tres")
    
    var scene_root = Node2D.new()
    scene_root.name = "IslandTilemap"
    
    var ground_layer = TileMapLayer.new()
    ground_layer.name = "GroundLayer"
    ground_layer.tile_set = tileset
    scene_root.add_child(ground_layer)
    ground_layer.owner = scene_root
    
    var path_layer = TileMapLayer.new()
    path_layer.name = "PathLayer"
    path_layer.tile_set = tileset
    scene_root.add_child(path_layer)
    path_layer.owner = scene_root
    
    # Generate map
    var noise = FastNoiseLite.new()
    noise.seed = 1234
    noise.frequency = 0.05
    
    var radius = 250
    # Create an actual village footprint (0,0) and a small island shape
    for x in range(-300, 300):
        for y in range(-300, 300):
            var p = Vector2(x, y)
            var d = p.length()
            if d < radius + noise.get_noise_2d(x*10, y*10) * 40:
                ground_layer.set_cell(Vector2i(x, y), 1, Vector2i(0, 0)) # default grass
                
                # Random flowers or rocks
                if randf() < 0.05:
                    path_layer.set_cell(Vector2i(x, y), 1, Vector2i(2, 0)) # assuming some flower/rock tile
            else:
                pass # empty is space or water depending on what we want
                
    # Create simple paths connecting some areas
    for i in range(-50, 50):
        path_layer.set_cell(Vector2i(i, 0), 1, Vector2i(1, 0)) # path tile
        path_layer.set_cell(Vector2i(0, i), 1, Vector2i(1, 0)) # path tile
                
    var packed = PackedScene.new()
    packed.pack(scene_root)
    
    var scenes_dir = DirAccess.open("res://scenes/world")
    if not scenes_dir:
        DirAccess.make_dir_absolute("res://scenes/world")
        
    ResourceSaver.save(packed, "res://scenes/world/island_tilemap.tscn")
    
    print("Done generating scene res://scenes/world/island_tilemap.tscn")
    quit()
