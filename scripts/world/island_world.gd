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
var buildings: TileMapLayer
var caves: TileMapLayer
var landmarks: TileMapLayer
var materials: TileMapLayer
var objects: TileMapLayer
var _layer_sets: Dictionary = {}
var map_texture: ImageTexture
var authored_map_texture: ImageTexture
var _map_refresh_queued: bool = false
var bounds := Rect2(-3520, -3520, 7040, 7040)
var radius: float = 3500.0
var authored_bounds := Rect2(-3520, -3520, 7040, 7040)
var authored_radius: float = 3500.0
var expanded_radius: float = 350000.0
const EXPANSION_MULTIPLIER: float = 100.0
const OCEAN_WORLD_RECT := Rect2(-7200.0, -8128.0, 27744.0, 14400.0)
const VILLAGE_RING_SCRIPT = preload("res://scripts/world/village_safe_ring.gd")
var revision: int = 0
var reserved: Array[Vector2] = []
var land: Dictionary = {}
var map_locations: Array[Dictionary] = []
var village_center: Vector2 = Vector2.ZERO
var village_radius: float = 500.0
const VILLAGE_BOUNDARY_MARGIN: float = 24.0

func _layer_name_candidates(layer_name: String) -> Array:
    # RoadLayer and HouseLayer are the canonical editor-facing names. Keep the
    # previous names as read-only aliases so older test scenes and saved maps
    # continue to load without moving or deleting any tile data.
    if layer_name == "RoadLayer" or layer_name == "PathLayer":
        return ["RoadLayer", "PathLayer"]
    if layer_name == "HouseLayer" or layer_name == "BuildingLayer":
        return ["HouseLayer", "BuildingLayer"]
    if layer_name == "DecorLayer" or layer_name == "DecorationLayer":
        return ["DecorationLayer", "DecorLayer"]
    if layer_name == "StructureLayer":
        # StructureLayer is the canonical authored layer for the church,
        # ruins, and mine. Keep the old direct StructuresLayer as a read-only
        # compatibility source for the default world props.
        return ["StructureLayer", "StructuresLayer"]
    return [layer_name]

func _collect_world_layers(world: Node, layer_name: String) -> Array:
    var result: Array = []
    var authored_root := world.get_node_or_null("AuthoredEnvironment")
    for candidate: String in _layer_name_candidates(layer_name):
        var direct := world.get_node_or_null(candidate) as TileMapLayer
        if direct != null and not result.has(direct):
            result.append(direct)
        if authored_root != null:
            var authored := authored_root.get_node_or_null(candidate) as TileMapLayer
            if authored != null and not result.has(authored):
                result.append(authored)
    return result

func _primary_world_layer(world: Node, layer_name: String) -> TileMapLayer:
    var authored_root := world.get_node_or_null("AuthoredEnvironment")
    if authored_root != null:
        for candidate: String in _layer_name_candidates(layer_name):
            var authored := authored_root.get_node_or_null(candidate) as TileMapLayer
            if authored != null:
                return authored
    for candidate: String in _layer_name_candidates(layer_name):
        var direct := world.get_node_or_null(candidate) as TileMapLayer
        if direct != null:
            return direct
    return null

func _append_unique_layers(target: Array, additions: Array) -> void:
    for layer_value in additions:
        if layer_value is TileMapLayer and not target.has(layer_value):
            target.append(layer_value)

func get_layer_cells(layer_key: String) -> Array:
    var cells: Array = []
    var seen: Dictionary = {}
    var layers: Array = _layer_sets.get(layer_key, [])
    for layer_value in layers:
        if not (layer_value is TileMapLayer):
            continue
        var layer := layer_value as TileMapLayer
        if not is_instance_valid(layer):
            continue
        for cell in layer.get_used_cells():
            if cell is Vector2i and not seen.has(cell):
                seen[cell] = true
                cells.append(cell)
    return cells

func _has_layer_cell(layer_key: String, cell: Vector2i) -> bool:
    var layers: Array = _layer_sets.get(layer_key, [])
    for layer_value in layers:
        if layer_value is TileMapLayer and is_instance_valid(layer_value):
            var layer := layer_value as TileMapLayer
            if layer.get_cell_source_id(cell) != -1:
                return true
    return false

func rebuild(world: Node2D, config: Dictionary = {}) -> void:
    z_index = -200
    add_to_group("island_world")
    ground = _primary_world_layer(world, "GroundLayer")
    paths = _primary_world_layer(world, "RoadLayer")
    trees = _primary_world_layer(world, "TreeLayer")
    bridge = _primary_world_layer(world, "BridgeLayer")
    # StructureLayer is the editor-facing home for the authored church, ruins,
    # and mine. The old StructuresLayer remains available through the layer
    # set as a compatibility source for default world props.
    structures = _primary_world_layer(world, "StructureLayer")
    decor = _primary_world_layer(world, "DecorLayer")
    water_layer = _primary_world_layer(world, "WaterLayer")
    farm_layer = _primary_world_layer(world, "FarmLayer")
    buildings = _primary_world_layer(world, "HouseLayer")
    caves = _primary_world_layer(world, "CaveLayer")
    landmarks = _primary_world_layer(world, "LandmarkLayer")
    materials = _primary_world_layer(world, "MaterialLayer")
    objects = _primary_world_layer(world, "ObjectLayer")

    _layer_sets.clear()
    _layer_sets["ground"] = _collect_world_layers(world, "GroundLayer")
    _layer_sets["paths"] = _collect_world_layers(world, "RoadLayer")
    _layer_sets["trees"] = _collect_world_layers(world, "TreeLayer")
    _layer_sets["bridge"] = _collect_world_layers(world, "BridgeLayer")
    _layer_sets["decor"] = _collect_world_layers(world, "DecorLayer")
    _layer_sets["water"] = _collect_world_layers(world, "WaterLayer")
    _layer_sets["farm"] = _collect_world_layers(world, "FarmLayer")
    var structure_layers: Array = _collect_world_layers(world, "StructuresLayer")
    _append_unique_layers(structure_layers, _collect_world_layers(world, "StructureLayer"))
    _append_unique_layers(structure_layers, _collect_world_layers(world, "HouseLayer"))
    _append_unique_layers(structure_layers, _collect_world_layers(world, "CaveLayer"))
    _append_unique_layers(structure_layers, _collect_world_layers(world, "LandmarkLayer"))
    _layer_sets["structures"] = structure_layers
    _layer_sets["buildings"] = _collect_world_layers(world, "HouseLayer")
    _layer_sets["caves"] = _collect_world_layers(world, "CaveLayer")
    _layer_sets["landmarks"] = _collect_world_layers(world, "LandmarkLayer")
    _layer_sets["materials"] = _collect_world_layers(world, "MaterialLayer")
    _layer_sets["objects"] = _collect_world_layers(world, "ObjectLayer")
    y_sort_enabled = true

    var village_data: Dictionary = config.get("village", {})
    var island_settings: Dictionary = config.get("island_settings", {})
    village_center = _point_from_data(village_data.get("center", {}), Vector2.ZERO)
    village_radius = maxf(160.0, float(village_data.get("tree_ring_radius", island_settings.get("village_radius", 500.0))))
    _update_village_ring()

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
    var interiors := world.get_node_or_null("Interiors")
    if interiors:
        for child in interiors.get_children():
            if child is Node2D:
                reserved.append(child.global_position)
    # Entries are reparented under their authored tile layer after the first
    # frame. Reserve them by group as well so streaming never places a resource
    # or enemy over a doorway during that handoff.
    for entry in get_tree().get_nodes_in_group("interior_entries"):
        if entry is Node2D:
            reserved.append((entry as Node2D).global_position)

    for house: Dictionary in village_data.get("houses", []):
        var pos_dict: Dictionary = house.get("pos", {})
        reserved.append(Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0))))
    for stone: Dictionary in config.get("waystones", []):
        var pos_dict: Dictionary = stone.get("pos", {})
        reserved.append(Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0))))

    _build_map_locations(config)
    # The map is a cached presentation asset, not a gameplay dependency.
    # Bake it after the first frame so the player can see the authored world
    # immediately on low-end CPUs; MinimapDrawer already handles a null cache
    # with a short "Charting island..." state.
    if not _map_refresh_queued:
        _map_refresh_queued = true
        call_deferred("_refresh_map_when_idle")
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
    if _has_layer_cell("bridge", cell):
        return false
    if _has_layer_cell("water", cell):
        return true
    return not land.has(cell)

func is_inside_playable_area(p: Vector2) -> bool:
    return p.length_squared() <= expanded_radius * expanded_radius

func clamp_to_playable_area(p: Vector2) -> Vector2:
    if is_inside_playable_area(p):
        return p
    return p.normalized() * maxf(0.0, expanded_radius - 48.0)

func is_inside_village_safe_zone(p: Vector2, margin: float = 0.0) -> bool:
    # Positive margin expands the protected area, leaving a small buffer
    # outside the visible ring for streamed content and hostile pathing.
    var protected_radius: float = maxf(0.0, village_radius + margin)
    return p.distance_squared_to(village_center) <= protected_radius * protected_radius

func clamp_to_village_boundary(p: Vector2, margin: float = VILLAGE_BOUNDARY_MARGIN) -> Vector2:
    var safe_radius: float = maxf(32.0, village_radius - margin)
    var offset: Vector2 = p - village_center
    if offset.length_squared() <= safe_radius * safe_radius:
        return p
    if offset.length_squared() <= 0.001:
        return village_center
    return village_center + offset.normalized() * safe_radius

func _update_village_ring() -> void:
    var safe_ring: Node2D = get_node_or_null("VillageSafeRing") as Node2D
    if safe_ring == null:
        safe_ring = VILLAGE_RING_SCRIPT.new() as Node2D
        safe_ring.name = "VillageSafeRing"
        add_child(safe_ring)
    safe_ring.set("ring_center", village_center)
    safe_ring.set("ring_radius", village_radius)
    safe_ring.queue_redraw()

func is_clear(p: Vector2, clearance: float = 36.0) -> bool:
    if is_inside_village_safe_zone(p, VILLAGE_BOUNDARY_MARGIN):
        return false
    if is_water(p):
        return false
    if not is_instance_valid(ground):
        return is_inside_playable_area(p)
    var cell: Vector2i = ground.local_to_map(ground.to_local(p))
    if authored_bounds.grow(64.0).has_point(p) and _has_layer_cell("paths", cell):
        return false
    if authored_bounds.grow(64.0).has_point(p) and _has_layer_cell("structures", cell):
        return false
    for spot: Vector2 in reserved:
        if p.distance_to(spot) < clearance + 72.0:
            return false
    for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
        if is_water(p + offset * clearance):
            return false
    if authored_bounds.grow(64.0).has_point(p):
        for dx in range(-2, 3):
            for dy in range(-2, 3):
                if _has_layer_cell("trees", cell + Vector2i(dx, dy)):
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

func get_ocean_world_rect() -> Rect2:
    return OCEAN_WORLD_RECT

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

func _add_map_location(location_id: String, display_name: String, world_position: Vector2, kind: String, priority: int = 1, label_zoom: float = 1.4) -> void:
    map_locations.append({
        "id": location_id,
        "name": display_name,
        "pos": world_position,
        "kind": kind,
        "priority": priority,
        "label_zoom": label_zoom
    })

func _add_map_location_if_missing(location_id: String, display_name: String, world_position: Vector2, kind: String, priority: int = 1, label_zoom: float = 1.4) -> void:
    if not _has_map_location(location_id):
        _add_map_location(location_id, display_name, world_position, kind, priority, label_zoom)

func _build_map_locations(config: Dictionary) -> void:
    map_locations.clear()

    var village_data: Dictionary = config.get("village", {})
    var map_village_center := _point_from_data(village_data.get("center", {}), Vector2.ZERO)
    _add_map_location("village", "Village", map_village_center, "village", 5, 0.5)

    for house: Dictionary in village_data.get("houses", []):
        var house_id := str(house.get("id", "house_%d" % map_locations.size()))
        var house_name := str(house.get("name", "Village House"))
        var house_pos := _point_from_data(house.get("pos", {}), map_village_center)
        _add_map_location(house_id, house_name, house_pos, "house", 1, 12.0)

    for entry in get_tree().get_nodes_in_group("interior_entries"):
        if not (entry is Node2D):
            continue
        var entry_id_value: Variant = entry.get("interior_id")
        var entry_name_value: Variant = entry.get("display_name")
        var entry_id := str(entry_id_value) if entry_id_value != null else "interior"
        var entry_name := str(entry_name_value) if entry_name_value != null else entry_id.capitalize()
        _add_map_location_if_missing(entry_id, entry_name, (entry as Node2D).global_position, "landmark", 3, 1.0)

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

func _refresh_map_when_idle() -> void:
    _map_refresh_queued = false
    if not is_inside_tree():
        return
    _refresh_map(water_layer, farm_layer)

func _build_map_texture(target_bounds: Rect2, include_outer_land: bool, _water: TileMapLayer = null, farm: TileMapLayer = null) -> ImageTexture:
    const MAP_SIZE: int = 1024
    var img := Image.create(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8)
    img.fill(Color("#244853")) # Ocean

    if include_outer_land:
        # Paint the expanded procedural landmass first. Draw one short strip
        # per row instead of testing one million individual pixels; the
        # authored layer stamps below still provide the detailed island view.
        for y in range(MAP_SIZE):
            var world_y: float = (float(y) + 0.5) / float(MAP_SIZE) * target_bounds.size.y + target_bounds.position.y
            var normalized_y: float = world_y / maxf(expanded_radius, 1.0)
            if absf(normalized_y) > 1.0:
                continue
            var half_width: float = sqrt(maxf(0.0, 1.0 - normalized_y * normalized_y)) * expanded_radius
            var world_left: float = -half_width
            var world_right: float = half_width
            var left_x: int = clampi(int(floorf((world_left - target_bounds.position.x) / maxf(target_bounds.size.x, 1.0) * float(MAP_SIZE))), 0, MAP_SIZE - 1)
            var right_x: int = clampi(int(ceilf((world_right - target_bounds.position.x) / maxf(target_bounds.size.x, 1.0) * float(MAP_SIZE))), 0, MAP_SIZE - 1)
            if right_x < left_x:
                continue
            var segment_width: int = maxi(1, int(ceilf(float(right_x - left_x + 1) / 4.0)))
            for segment in range(4):
                var segment_start: int = left_x + segment * segment_width
                if segment_start > right_x:
                    break
                var segment_end: int = mini(right_x, segment_start + segment_width - 1)
                var sample_x: float = (float(segment_start + segment_end) * 0.5 + 0.5) / float(MAP_SIZE) * target_bounds.size.x + target_bounds.position.x
                var biome_wave: float = sin(sample_x * 0.00008) + cos(world_y * 0.00006)
                var biome_color: Color = Color("#6f954d") if biome_wave > -0.4 else Color("#648b4a")
                img.fill_rect(Rect2i(segment_start, y, segment_end - segment_start + 1, 1), biome_color)

    # A tile occupies several pixels in the authored projection, which keeps
    # individual trees, buildings and waterways visible at the default view.
    var tile_pixels: float = 32.0 * float(MAP_SIZE) / maxf(target_bounds.size.x, 1.0)
    var stamp_radius: int = 0 if include_outer_land else clampi(int(ceilf(tile_pixels * 0.42)), 1, 3)

    # 1. The real ground footprint also defines the authored island's ocean
    # edge. This makes the chart a faithful copy of the playable land shape.
    for cell in land:
        if not (cell is Vector2i):
            continue
        var cell_pos: Vector2i = cell
        var color := Color("#73974c")
        if is_instance_valid(ground):
            var coords: Vector2i = ground.get_cell_atlas_coords(cell_pos)
            if coords.y >= 8 and coords.y <= 13 and coords.x <= 5:
                color = Color("#5a5448")
        var world_p := Vector2(cell_pos) * 32.0 + Vector2(16.0, 16.0)
        if target_bounds.grow(32.0).has_point(world_p):
            _paint_map_cell(img, _world_to_map_pixel(world_p, MAP_SIZE, MAP_SIZE, target_bounds), color, stamp_radius)

    # 2. Decorative terrain, then the authored water, farms, paths and bridge.
    # Each layer is painted in the same order used by the world visual.
    _paint_map_layers(img, "decor", Color("#476e3b"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_ocean_map_layer(img, target_bounds, MAP_SIZE, Color("#276b80"))
    _paint_map_layers(img, "water", Color("#2f879b"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "farm", Color("#673e1e"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "paths", Color("#c39e68"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "bridge", Color("#835327"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "trees", Color("#264c2f"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "structures", Color("#8b8277"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "buildings", Color("#c9a269"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "caves", Color("#435d45"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "landmarks", Color("#b0a68b"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "materials", Color("#c88a4d"), target_bounds, MAP_SIZE, stamp_radius)
    _paint_map_layers(img, "objects", Color("#c17a43"), target_bounds, MAP_SIZE, stamp_radius)

    return ImageTexture.create_from_image(img)

func _paint_map_layers(image: Image, layer_key: String, color: Color, target_bounds: Rect2, map_size: int, stamp_radius: int) -> void:
    var layers: Array = _layer_sets.get(layer_key, [])
    for layer_value in layers:
        if layer_value is TileMapLayer:
            _paint_map_layer(image, layer_value as TileMapLayer, color, target_bounds, map_size, stamp_radius)

func _paint_map_layer(image: Image, layer: TileMapLayer, color: Color, target_bounds: Rect2, map_size: int, stamp_radius: int) -> void:
    if layer == null or not is_instance_valid(layer):
        return
    for cell in layer.get_used_cells():
        if not (cell is Vector2i):
            continue
        var cell_pos: Vector2i = cell
        var world_p := Vector2(cell_pos) * 32.0 + Vector2(16.0, 16.0)
        if target_bounds.grow(32.0).has_point(world_p):
            _paint_map_cell(image, _world_to_map_pixel(world_p, map_size, map_size, target_bounds), color, stamp_radius)

func _paint_ocean_map_layer(image: Image, target_bounds: Rect2, map_size: int, color: Color) -> void:
    # The authored ocean uses one repeated tile. Keep its exact silhouette in
    # the chart without asking the minimap or editor to retain 289k TileMap
    # cells. The compact run list is shared with OceanBackdrop.
    var runs := OceanBackdrop.WATER_RUNS
    for i in range(0, runs.size(), 3):
        var cell_x := float(runs[i])
        var cell_y := float(runs[i + 1])
        var cell_width := float(runs[i + 2])
        var world_rect := Rect2(
            Vector2(cell_x, cell_y) * 32.0,
            Vector2(cell_width, 1.0) * 32.0,
        )
        var clipped := world_rect.intersection(target_bounds)
        if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
            continue
        var top_left := _world_to_map_pixel(clipped.position, map_size, map_size, target_bounds)
        var bottom_right := _world_to_map_pixel(clipped.end - Vector2.ONE, map_size, map_size, target_bounds)
        var rect_size := Vector2i(
            maxi(1, bottom_right.x - top_left.x + 1),
            maxi(1, bottom_right.y - top_left.y + 1),
        )
        image.fill_rect(Rect2i(top_left, rect_size), color)

func _paint_map_cell(image: Image, pixel: Vector2i, color: Color, stamp_radius: int) -> void:
    # Image.fill_rect is implemented natively and produces the same square
    # stamp as the old per-pixel loops, but avoids millions of GDScript calls
    # while the two map textures are baked during scene startup.
    var start := Vector2i(
        maxi(0, pixel.x - stamp_radius),
        maxi(0, pixel.y - stamp_radius),
    )
    var end := Vector2i(
        mini(image.get_width() - 1, pixel.x + stamp_radius),
        mini(image.get_height() - 1, pixel.y + stamp_radius),
    )
    if end.x < start.x or end.y < start.y:
        return
    image.fill_rect(Rect2i(start, end - start + Vector2i.ONE), color)

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
