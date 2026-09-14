class_name IslandWorld
extends Node2D

var ground: TileMapLayer
var paths: TileMapLayer
var trees: TileMapLayer
var bridge: TileMapLayer
var structures: TileMapLayer
var decor: TileMapLayer
var water_layer: TileMapLayer
var farm_layer: TileMapLayer
var map_texture: ImageTexture
var authored_map_texture: ImageTexture
var bounds := Rect2(-3520, -3520, 7040, 7040)
var radius: float = 3500.0
var authored_bounds := Rect2(-3520, -3520, 7040, 7040)
var authored_radius: float = 3500.0
var expanded_radius: float = 350000.0
const EXPANSION_MULTIPLIER: float = 100.0
var revision: int = 0
var reserved: Array[Vector2] = []
var land: Dictionary = {}
var map_locations: Array[Dictionary] = []

func rebuild(world: Node2D, config: Dictionary = {}) -> void:
    z_index = -200
    ground = world.get_node_or_null("GroundLayer")
    paths = world.get_node_or_null("PathLayer")
    trees = world.get_node_or_null("TreeLayer")
    bridge = world.get_node_or_null("BridgeLayer")
    structures = world.get_node_or_null("StructuresLayer")
    decor = world.get_node_or_null("DecorLayer")
    water_layer = world.get_node_or_null("WaterLayer")
    farm_layer = world.get_node_or_null("FarmLayer")
    y_sort_enabled = true

    land.clear()
    if ground:
        for cell: Vector2i in ground.get_used_cells():
            land[cell] = true
        var used_rect: Rect2i = ground.get_used_rect()
        authored_bounds = Rect2(Vector2(used_rect.position) * 32.0, Vector2(used_rect.size) * 32.0)
        authored_radius = maxf(authored_bounds.size.x, authored_bounds.size.y) * 0.5
    else:
        authored_bounds = Rect2(-3520, -3520, 7040, 7040)
        authored_radius = 3500.0

    # Preserve the authored island in the centre, then give the game a huge
    # procedural outer landmass. The 100x multiplier is intentionally exposed
    # as a constant so the playable border is not tied to scene tile data.
    radius = authored_radius
    expanded_radius = maxf(authored_radius, 3500.0) * EXPANSION_MULTIPLIER
    bounds = Rect2(-expanded_radius, -expanded_radius, expanded_radius * 2.0, expanded_radius * 2.0)

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

    var village_data: Dictionary = config.get("village", {})
    for house: Dictionary in village_data.get("houses", []):
        var pos_dict: Dictionary = house.get("pos", {})
        reserved.append(Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0))))
    for stone: Dictionary in config.get("waystones", []):
        var pos_dict: Dictionary = stone.get("pos", {})
        reserved.append(Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0))))

    _build_map_locations(config)
    _refresh_map(water_layer, farm_layer)
    revision += 1

func is_water(p: Vector2) -> bool:
    if not is_inside_playable_area(p):
        return true
    # Outside the authored rectangle, the expanded procedural landmass is
    # traversable. Inside it, retain the real tilemap's lakes and channels.
    if not authored_bounds.grow(64.0).has_point(p):
        return false
    if not is_instance_valid(ground):
        return false
    var cell: Vector2i = ground.local_to_map(ground.to_local(p))
    if is_instance_valid(bridge) and bridge.get_cell_source_id(cell) != -1:
        return false
    return not land.has(cell)

func is_inside_playable_area(p: Vector2) -> bool:
    return p.length_squared() <= expanded_radius * expanded_radius

func clamp_to_playable_area(p: Vector2) -> Vector2:
    if is_inside_playable_area(p):
        return p
    return p.normalized() * maxf(0.0, expanded_radius - 48.0)

func is_clear(p: Vector2, clearance: float = 36.0) -> bool:
    if is_water(p):
        return false
    if not is_instance_valid(ground):
        return is_inside_playable_area(p)
    var cell: Vector2i = ground.local_to_map(ground.to_local(p))
    if authored_bounds.grow(64.0).has_point(p) and is_instance_valid(paths) and paths.get_cell_source_id(cell) != -1:
        return false
    if authored_bounds.grow(64.0).has_point(p) and is_instance_valid(structures) and structures.get_cell_source_id(cell) != -1:
        return false
    for spot: Vector2 in reserved:
        if p.distance_to(spot) < clearance + 72.0:
            return false
    for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
        if is_water(p + offset * clearance):
            return false
    if authored_bounds.grow(64.0).has_point(p) and is_instance_valid(trees):
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if trees.get_cell_source_id(cell + Vector2i(dx, dy)) != -1:
                    return false
    return true

func get_biome_at(p: Vector2) -> String:
    if p.length() > expanded_radius * 0.84:
        return "shore"
    var biome_wave := sin(p.x * 0.00008) + cos(p.y * 0.00006)
    if biome_wave > 0.7:
        return "grove"
    if biome_wave < -0.55:
        return "quarry"
    return "meadow"

func get_map_locations() -> Array:
    # The map reads this immutable snapshot while drawing. Returning the
    # existing array avoids a deep copy every renderer refresh.
    return map_locations

func _point_from_data(data: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
    if data is Dictionary:
        var point: Dictionary = data
        return Vector2(float(point.get("x", fallback.x)), float(point.get("y", fallback.y)))
    return fallback

func _has_map_location(location_id: String) -> bool:
    for location: Dictionary in map_locations:
        if str(location.get("id", "")) == location_id:
            return true
    return false

func _add_map_location(location_id: String, display_name: String, position: Vector2, kind: String, priority: int = 1, label_zoom: float = 1.4) -> void:
    map_locations.append({
        "id": location_id,
        "name": display_name,
        "pos": position,
        "kind": kind,
        "priority": priority,
        "label_zoom": label_zoom
    })

func _add_map_location_if_missing(location_id: String, display_name: String, position: Vector2, kind: String, priority: int = 1, label_zoom: float = 1.4) -> void:
    if not _has_map_location(location_id):
        _add_map_location(location_id, display_name, position, kind, priority, label_zoom)

func _build_map_locations(config: Dictionary) -> void:
    map_locations.clear()

    var village_data: Dictionary = config.get("village", {})
    var village_center := _point_from_data(village_data.get("center", {}), Vector2.ZERO)
    _add_map_location("village", "Village", village_center, "village", 5, 0.5)

    for house: Dictionary in village_data.get("houses", []):
        var house_id := str(house.get("id", "house_%d" % map_locations.size()))
        var house_name := str(house.get("name", "Village House"))
        var house_pos := _point_from_data(house.get("pos", {}), village_center)
        _add_map_location(house_id, house_name, house_pos, "house", 1, 12.0)

    var landmark_names := {
        "northwest_highlands": "Northwest Highlands",
        "western_farmlands": "Western Farmlands",
        "whispering_woods": "Whispering Woods",
        "serpentine_lake": "Serpentine Lake & River",
        "forgotten_citadel": "Forgotten Citadel"
    }
    var landmarks: Dictionary = config.get("landmarks", {})
    for landmark_id in landmarks.keys():
        var entry: Dictionary = landmarks[landmark_id]
        var key := str(landmark_id)
        var display_name := str(landmark_names.get(key, key.replace("_", " ").capitalize()))
        var kind := "water" if key == "serpentine_lake" else "landmark"
        var label_zoom := 1.0 # Major place names are visible in the fit-to-island view.
        _add_map_location(key, display_name, _point_from_data(entry.get("center", {})), kind, 3, label_zoom)

    # Keep the chart useful even if a minimal test scene omits the JSON.
    _add_map_location_if_missing("northwest_highlands", "Northwest Highlands", Vector2(-2080.0, -2240.0), "landmark", 3, 1.0)
    _add_map_location_if_missing("western_farmlands", "Western Farmlands", Vector2(-1664.0, 1024.0), "landmark", 3, 1.0)
    _add_map_location_if_missing("whispering_woods", "Whispering Woods", Vector2(1984.0, -1760.0), "landmark", 3, 1.0)
    _add_map_location_if_missing("serpentine_lake", "Serpentine Lake & River", Vector2(1536.0, 896.0), "water", 3, 1.0)
    _add_map_location_if_missing("forgotten_citadel", "Forgotten Citadel", Vector2(160.0, 2304.0), "landmark", 3, 1.0)

func _refresh_map(water: TileMapLayer = null, farm: TileMapLayer = null) -> void:
    # Keep two projections: the full 100x world for orientation, and an exact
    # authored-island projection for the detailed chart view. Both are baked
    # once when the tilemap is rebuilt, so opening the map never scans tiles.
    map_texture = _build_map_texture(bounds, true, water, farm)
    authored_map_texture = _build_map_texture(authored_bounds, false, water, farm)
    queue_redraw()

func _build_map_texture(target_bounds: Rect2, include_outer_land: bool, water: TileMapLayer = null, farm: TileMapLayer = null) -> ImageTexture:
    const MAP_SIZE: int = 1024
    var img := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
    img.fill(Color("#244853")) # Ocean

    if include_outer_land:
        # Paint the expanded procedural landmass first. The texture stays
        # capped at 1024px, so the enlarged world remains inexpensive.
        for y in range(MAP_SIZE):
            for x in range(MAP_SIZE):
                var world_p := Vector2(
                    (float(x) + 0.5) / float(MAP_SIZE) * target_bounds.size.x + target_bounds.position.x,
                    (float(y) + 0.5) / float(MAP_SIZE) * target_bounds.size.y + target_bounds.position.y
                )
                if world_p.length_squared() <= expanded_radius * expanded_radius:
                    var biome_wave := sin(world_p.x * 0.00008) + cos(world_p.y * 0.00006)
                    img.set_pixel(x, y, Color("#6f954d") if biome_wave > -0.4 else Color("#648b4a"))

    # A tile occupies several pixels in the authored projection, which keeps
    # individual trees, buildings and waterways visible at the default view.
    var tile_pixels: float = 32.0 * float(MAP_SIZE) / maxf(target_bounds.size.x, 1.0)
    var stamp_radius: int = 0 if include_outer_land else clampi(int(ceilf(tile_pixels * 0.42)), 1, 3)

    # 1. The real ground footprint also defines the authored island's ocean
    # edge. This makes the chart a faithful copy of the playable land shape.
    for cell in land.keys():
        if not (cell is Vector2i):
            continue
        var cell_pos: Vector2i = cell
        var color := Color("#73974c")
        if is_instance_valid(ground):
            var coords: Vector2i = ground.get_cell_atlas_coords(cell_pos)
            if coords.y >= 8 and coords.y <= 13 and coords.x <= 5:
                color = Color("#5a5448")
        var world_p := Vector2(cell_pos) * 32.0 + Vector2(16.0, 16.0)
        _paint_map_cell(img, _world_to_map_pixel(world_p, MAP_SIZE, MAP_SIZE, target_bounds), color, stamp_radius)

    # 2. Decorative terrain, then the authored water, farms, paths and bridge.
    # Each layer is painted in the same order used by the world visual.
    _paint_map_layer(img, decor, Color("#476e3b"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layer(img, water, Color("#276b80"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layer(img, farm, Color("#673e1e"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layer(img, paths, Color("#c39e68"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layer(img, bridge, Color("#835327"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layer(img, trees, Color("#264c2f"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layer(img, structures, Color("#8b8277"), target_bounds, MAP_SIZE, stamp_radius)

    return ImageTexture.create_from_image(img)

func _paint_map_layer(image: Image, layer: TileMapLayer, color: Color, target_bounds: Rect2, map_size: int, stamp_radius: int) -> void:
    if layer == null or not is_instance_valid(layer):
        return
    for cell in layer.get_used_cells():
        if not (cell is Vector2i):
            continue
        var cell_pos: Vector2i = cell
        var world_p := Vector2(cell_pos) * 32.0 + Vector2(16.0, 16.0)
        _paint_map_cell(image, _world_to_map_pixel(world_p, map_size, map_size, target_bounds), color, stamp_radius)

func _paint_map_cell(image: Image, pixel: Vector2i, color: Color, stamp_radius: int) -> void:
    for dy in range(-stamp_radius, stamp_radius + 1):
        for dx in range(-stamp_radius, stamp_radius + 1):
            var p := pixel + Vector2i(dx, dy)
            if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
                image.set_pixelv(p, color)

func _world_to_map_pixel(world_p: Vector2, width: int, height: int, target_bounds: Rect2) -> Vector2i:
    var nx := clampf((world_p.x - target_bounds.position.x) / maxf(target_bounds.size.x, 1.0), 0.0, 0.999999)
    var ny := clampf((world_p.y - target_bounds.position.y) / maxf(target_bounds.size.y, 1.0), 0.0, 0.999999)
    return Vector2i(int(nx * width), int(ny * height))

func _draw() -> void:
    # This is the visual ground beneath the original authored tilemap. A broad
    # border, subtle biome rings and a water rim make the enlarged boundary
    # visible while keeping the detailed village tiles on top.
    draw_circle(Vector2.ZERO, expanded_radius + 900.0, Color("#244853"))
    draw_circle(Vector2.ZERO, expanded_radius, Color("#648b4a"))
    draw_arc(Vector2.ZERO, expanded_radius, 0.0, TAU, 256, Color("#a8c179"), 18.0)
    for i in range(32):
        var angle := float(i) * TAU / 32.0
        var p := Vector2.RIGHT.rotated(angle) * (expanded_radius * 0.78)
        draw_circle(p, expanded_radius * 0.035, Color(0.23, 0.40, 0.22, 0.16))
