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
        var label_zoom := 1.0 if kind == "water" else 1.4
        _add_map_location(key, display_name, _point_from_data(entry.get("center", {})), kind, 3, label_zoom)

    # Keep the chart useful even if a minimal test scene omits the JSON.
    _add_map_location_if_missing("northwest_highlands", "Northwest Highlands", Vector2(-2080.0, -2240.0), "landmark", 3, 1.4)
    _add_map_location_if_missing("western_farmlands", "Western Farmlands", Vector2(-1664.0, 1024.0), "landmark", 3, 1.4)
    _add_map_location_if_missing("whispering_woods", "Whispering Woods", Vector2(1984.0, -1760.0), "landmark", 3, 1.4)
    _add_map_location_if_missing("serpentine_lake", "Serpentine Lake & River", Vector2(1536.0, 896.0), "water", 3, 1.0)
    _add_map_location_if_missing("forgotten_citadel", "Forgotten Citadel", Vector2(160.0, 2304.0), "landmark", 3, 1.4)

func _refresh_map(water: TileMapLayer = null, farm: TileMapLayer = null) -> void:
    var used_rect := Rect2i(Vector2i(bounds.position / 32.0), Vector2i(bounds.size / 32.0))
    var dim_x: int = clampi(used_rect.size.x, 32, 1024)
    var dim_y: int = clampi(used_rect.size.y, 32, 1024)
    var img := Image.create(dim_x, dim_y, false, Image.FORMAT_RGBA8)
    img.fill(Color("#244853")) # Match MinimapDrawer ocean color

    # Paint the procedural outer landmass first. The map texture is capped at
    # 1024px, so this remains cheap even though the world itself is enormous.
    for y in range(dim_y):
        for x in range(dim_x):
            var world_p := Vector2(float(x) / float(dim_x) * bounds.size.x + bounds.position.x, float(y) / float(dim_y) * bounds.size.y + bounds.position.y)
            if world_p.length_squared() <= expanded_radius * expanded_radius:
                var biome_wave := sin(world_p.x * 0.00008) + cos(world_p.y * 0.00006)
                img.set_pixel(x, y, Color("#6f954d") if biome_wave > -0.4 else Color("#648b4a"))

    # 1. Base Ground (Grass & Cliffs)
    for cell: Vector2i in land:
        var color := Color("#73974c")
        if ground:
            var coords: Vector2i = ground.get_cell_atlas_coords(cell)
            if coords.y >= 8 and coords.y <= 13 and coords.x <= 5:
                color = Color("#5a5448")
        var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
        if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
            img.set_pixelv(pixel, color)

    # 2. Waterways and lakes. Paint every authored water cell so rivers are
    # never clipped by the old island-radius shortcut.
    if water:
        for cell: Vector2i in water.get_used_cells():
            var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
            if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
                img.set_pixelv(pixel, Color("#276b80"))

    # 3. Farmland plots
    if farm:
        for cell: Vector2i in farm.get_used_cells():
            var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
            if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
                img.set_pixelv(pixel, Color("#673e1e"))

    # 4. Pathways and roads
    if paths:
        for cell: Vector2i in paths.get_used_cells():
            var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
            if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
                img.set_pixelv(pixel, Color("#c39e68"))

    # 5. Wooden bridge
    if bridge:
        for cell: Vector2i in bridge.get_used_cells():
            var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
            if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
                img.set_pixelv(pixel, Color("#835327"))

    # 6. Tree groves
    if trees:
        for cell: Vector2i in trees.get_used_cells():
            var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
            if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
                img.set_pixelv(pixel, Color("#264c2f"))

    # 7. Structures: houses, ruins, and cave entrance
    if structures:
        for cell: Vector2i in structures.get_used_cells():
            var pixel: Vector2i = _world_to_map_pixel(Vector2(cell) * 32.0 + Vector2(16.0, 16.0), dim_x, dim_y)
            if pixel.x >= 0 and pixel.y >= 0 and pixel.x < dim_x and pixel.y < dim_y:
                img.set_pixelv(pixel, Color("#8b8277"))

    map_texture = ImageTexture.create_from_image(img)
    queue_redraw()

func _world_to_map_pixel(world_p: Vector2, width: int, height: int) -> Vector2i:
    var nx := clampf((world_p.x - bounds.position.x) / maxf(bounds.size.x, 1.0), 0.0, 0.999999)
    var ny := clampf((world_p.y - bounds.position.y) / maxf(bounds.size.y, 1.0), 0.0, 0.999999)
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
