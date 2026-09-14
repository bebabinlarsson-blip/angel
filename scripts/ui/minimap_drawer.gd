class_name MinimapDrawer
extends Control

@export var is_big_map: bool = false
@export var world_radius: float = 3200.0

var map_offset := Vector2.ZERO
var map_zoom: float = 1.0
var _dragging: bool = false
var _timer: float = 0.0
var _marker_timer: float = 0.0
var _markers_initialized: bool = false
var _terrain: IslandWorld
var _stones: Array[Node] = []
var _npcs: Array[Node] = []
var _locations: Array[Dictionary] = []
var _water_cells: Array = []
var _farm_cells: Array = []
var _path_cells: Array = []
var _bridge_cells: Array = []
var _tree_cells: Array = []
var _structure_cells: Array = []
var _layer_cache_revision: int = -1

const INK := Color("#f3e7ce")
const OCEAN := Color("#244853")
const MAP_PANEL_WIDTH: float = 210.0
const MAX_MAP_ZOOM: float = 96.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    clip_contents = true
    texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL
    tooltip_text = "Open island chart [M]" if not is_big_map else "Drag to pan. Scroll to zoom. Home to find yourself."
    gui_input.connect(_on_gui_input)
    visibility_changed.connect(func(): _dragging = false)
    resized.connect(queue_redraw)

func _process(delta: float) -> void:
    if not is_visible_in_tree():
        return
    _timer += delta
    _marker_timer += delta
    if _timer < 0.08:
        return
    _timer = 0.0
    if not is_instance_valid(_terrain):
        _terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
    if not _markers_initialized or _marker_timer >= 0.5:
        _stones = get_tree().get_nodes_in_group("waystones")
        _npcs = get_tree().get_nodes_in_group("npcs")
        _markers_initialized = true
        _marker_timer = 0.0
    _refresh_layer_cache()
    queue_redraw()

func _refresh_layer_cache() -> void:
    if not is_instance_valid(_terrain):
        return
    if _layer_cache_revision == _terrain.revision:
        return
    _locations.clear()
    if _terrain.has_method("get_map_locations"):
        for location in _terrain.get_map_locations():
            if location is Dictionary:
                _locations.append(location)
    _water_cells = _layer_cells(_terrain.water_layer)
    _farm_cells = _layer_cells(_terrain.farm_layer)
    _path_cells = _layer_cells(_terrain.paths)
    _bridge_cells = _layer_cells(_terrain.bridge)
    _tree_cells = _layer_cells(_terrain.trees)
    _structure_cells = _layer_cells(_terrain.structures)
    _layer_cache_revision = _terrain.revision

func _layer_cells(layer: TileMapLayer) -> Array:
    if layer == null or not is_instance_valid(layer):
        return []
    var cells: Array = []
    for cell in layer.get_used_cells():
        if cell is Vector2i:
            cells.append(cell)
    return cells

func _map_view_rect() -> Rect2:
    if is_big_map:
        return Rect2(0.0, 56.0, maxf(size.x - MAP_PANEL_WIDTH, 1.0), maxf(size.y - 92.0, 1.0))
    return Rect2(0.0, 22.0, maxf(size.x, 1.0), maxf(size.y - 22.0, 1.0))

func _map_panel_center() -> Vector2:
    if is_big_map:
        return Vector2((size.x - MAP_PANEL_WIDTH) * 0.5, size.y * 0.5 + 10.0)
    return Vector2(size.x * 0.5, (size.y + 22.0) * 0.5)

func _map_scale() -> float:
    if not is_instance_valid(_terrain):
        return 1.0
    if not is_big_map:
        # The world can now be much larger than the authored village. Keep the
        # minimap useful by showing a generous local area around the player.
        return minf(size.x, size.y - 22.0) / 8000.0
    var available := _map_view_rect().size
    return minf(available.x, available.y) / maxf(_terrain.bounds.size.x, 1.0) * map_zoom

func _center() -> Vector2:
    if is_big_map:
        return _map_panel_center() + map_offset * _map_scale()
    var p := Vector2.ZERO
    if is_instance_valid(GameManager.player):
        p = GameManager.player.global_position
    return _map_panel_center() - p * _map_scale()

func center_on_player() -> void:
    if is_instance_valid(GameManager.player):
        map_offset = -GameManager.player.global_position
        _clamp_offset()
    queue_redraw()

func fit_island() -> void:
    map_zoom = 1.0
    if is_instance_valid(_terrain):
        map_offset = -_terrain.bounds.get_center()
    else:
        map_offset = Vector2.ZERO
    queue_redraw()

func zoom_in(pivot: Vector2 = Vector2.INF) -> void:
    _zoom_by(1.35, pivot)

func zoom_out(pivot: Vector2 = Vector2.INF) -> void:
    _zoom_by(1.0 / 1.35, pivot)

func _zoom_by(factor: float, pivot: Vector2 = Vector2.INF) -> void:
    if not is_big_map:
        return
    var old_zoom: float = map_zoom
    var new_zoom: float = clampf(map_zoom * factor, 0.5, MAX_MAP_ZOOM)
    if is_equal_approx(old_zoom, new_zoom):
        return
    var screen_mid := _map_panel_center()
    var focus_screen: Vector2 = pivot if pivot != Vector2.INF else screen_mid
    var old_scale: float = _map_scale()
    var old_center: Vector2 = _center()
    var world_p: Vector2 = (focus_screen - old_center) / maxf(old_scale, 0.0001)
    map_zoom = new_zoom
    var new_scale: float = _map_scale()
    map_offset = (focus_screen - screen_mid) / maxf(new_scale, 0.0001) - world_p
    _clamp_offset()
    queue_redraw()

func _clamp_offset() -> void:
    if not is_big_map:
        return
    var limit: float = 3800.0
    if is_instance_valid(_terrain) and _terrain.expanded_radius > 0.0:
        limit = _terrain.expanded_radius * 1.5
    map_offset.x = clampf(map_offset.x, -limit, limit)
    map_offset.y = clampf(map_offset.y, -limit, limit)

func _open_big_map() -> void:
    var hud := get_tree().root.find_child("HUD", true, false)
    if hud and hud.has_method("set_map_open"):
        hud.set_map_open(true)

func _on_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if not is_big_map and event.pressed:
                _open_big_map()
            else:
                _dragging = event.pressed
                grab_focus()
        elif is_big_map and event.pressed:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                zoom_in(event.position)
            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                zoom_out(event.position)
        accept_event()
    elif event is InputEventMouseMotion and _dragging:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            map_offset += event.relative / maxf(_map_scale(), 0.001)
            _clamp_offset()
        else:
            _dragging = false
    elif event is InputEventKey and event.pressed:
        if event.keycode == KEY_HOME:
            center_on_player()
        elif event.keycode == KEY_ENTER and not is_big_map:
            _open_big_map()
        elif is_big_map:
            match event.keycode:
                KEY_LEFT:
                    map_offset.x += 120.0 / maxf(map_zoom, 0.5)
                KEY_RIGHT:
                    map_offset.x -= 120.0 / maxf(map_zoom, 0.5)
                KEY_UP:
                    map_offset.y += 120.0 / maxf(map_zoom, 0.5)
                KEY_DOWN:
                    map_offset.y -= 120.0 / maxf(map_zoom, 0.5)
                KEY_EQUAL, KEY_PLUS:
                    zoom_in()
                KEY_MINUS:
                    zoom_out()
            _clamp_offset()
            accept_event()
    queue_redraw()

func _label(pos: Vector2, text: String, font_size: int = 14, color: Color = INK) -> void:
    draw_string_outline(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color("#101c24"))
    draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw_layer_cells(cells: Array, center: Vector2, factor: float, color: Color, view: Rect2) -> void:
    var cell_px := 32.0 * factor
    if cell_px < 0.45:
        return
    var half := Vector2.ONE * cell_px * 0.5
    var safe_view := view.grow(cell_px * 2.0)
    for cell in cells:
        if not (cell is Vector2i):
            continue
        var cell_pos: Vector2i = cell
        var world_pos := Vector2(float(cell_pos.x) * 32.0 + 16.0, float(cell_pos.y) * 32.0 + 16.0)
        var screen_pos := center + world_pos * factor
        if not safe_view.has_point(screen_pos):
            continue
        draw_rect(Rect2(screen_pos - half, Vector2.ONE * cell_px), color)

func _draw_layer_details(center: Vector2, factor: float) -> void:
    # The 1024px overview texture keeps the complete 100x island readable.
    # At closer zoom levels, redraw authored tiles as real-sized cells so
    # rivers, trees, houses, farms and roads resolve instead of becoming one
    # indistinguishable pixel.
    var view := _map_view_rect()
    _draw_layer_cells(_water_cells, center, factor, Color("#2f879b"), view)
    _draw_layer_cells(_farm_cells, center, factor, Color("#8d5727"), view)
    _draw_layer_cells(_path_cells, center, factor, Color("#d1aa75"), view)
    _draw_layer_cells(_bridge_cells, center, factor, Color("#9a6235"), view)
    _draw_layer_cells(_tree_cells, center, factor, Color("#2f653b"), view)
    _draw_layer_cells(_structure_cells, center, factor, Color("#c9a269"), view)

func _draw_named_locations(center: Vector2, factor: float) -> void:
    var view := _map_view_rect()
    for location: Dictionary in _locations:
        var raw_pos: Variant = location.get("pos", Vector2.ZERO)
        if not (raw_pos is Vector2):
            continue
        var world_pos: Vector2 = raw_pos
        var p := center + world_pos * factor
        if not view.grow(32.0).has_point(p):
            continue

        var kind := str(location.get("kind", "landmark"))
        match kind:
            "village":
                draw_circle(p, 14.0, Color("#101c24"))
                draw_rect(Rect2(p - Vector2(8, 5), Vector2(16, 10)), Color("#d9a45f"))
                draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -5), p + Vector2(0, -14), p + Vector2(10, -5)]), Color("#a84f43"))
            "house":
                draw_rect(Rect2(p - Vector2(8, 6), Vector2(16, 12)), Color("#101c24"))
                draw_rect(Rect2(p - Vector2(6, 5), Vector2(12, 10)), Color("#c9a269"))
                draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -5), p + Vector2(0, -13), p + Vector2(9, -5)]), Color("#9a5144"))
            "water":
                draw_circle(p, 11.0, Color("#143946"))
                draw_arc(p, 9.0, 0.0, TAU, 20, Color("#6ad3dd"), 2.0)
                draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color("#6ad3dd"), 2.0)
            _:
                draw_circle(p, 10.0, Color("#101c24"))
                draw_circle(p, 7.0, Color("#d5a94d"))
                draw_circle(p, 3.0, Color("#fff0a8"))

        var label_zoom := float(location.get("label_zoom", 1.4))
        var show_label := kind == "village"
        if is_big_map and kind != "village":
            show_label = map_zoom >= label_zoom
        if not show_label:
            continue
        var label_pos := p + Vector2(16, 5)
        if label_pos.x < view.position.x or label_pos.x > view.end.x - 4.0:
            continue
        _label(label_pos, str(location.get("name", "Unknown Place")), 13 if is_big_map else 10, Color("#ffe08a"))

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    if not is_instance_valid(_terrain):
        _terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
    if not _markers_initialized:
        _stones = get_tree().get_nodes_in_group("waystones")
        _npcs = get_tree().get_nodes_in_group("npcs")
        _markers_initialized = true
    _refresh_layer_cache()

    # 1. Base ocean fill
    draw_rect(Rect2(Vector2.ZERO, size), OCEAN)

    if not is_instance_valid(_terrain) or _terrain.map_texture == null:
        _label(Vector2(12, 28), "Charting island...", 14)
        return

    var factor: float = _map_scale()
    var center: Vector2 = _center()

    # 2. Complete overview plus high-detail authored layers
    var map_rect := Rect2(center + _terrain.bounds.position * factor, _terrain.bounds.size * factor)
    draw_texture_rect(_terrain.map_texture, map_rect, false)
    _draw_layer_details(center, factor)
    _draw_named_locations(center, factor)

    # 3. Subtle grid lines on Big Map (32 tiles / 1024 units per grid square)
    if is_big_map:
        var grid_step: float = 32.0 * 32.0 * factor
        if grid_step > 20.0:
            var start_x: float = fposmod(map_rect.position.x, grid_step)
            while start_x < size.x - MAP_PANEL_WIDTH:
                if start_x > 0:
                    draw_line(Vector2(start_x, 56), Vector2(start_x, size.y - 36), Color(0.12, 0.22, 0.28, 0.35), 1.0)
                start_x += grid_step
            var start_y: float = fposmod(map_rect.position.y, grid_step)
            while start_y < size.y - 36.0:
                if start_y > 56:
                    draw_line(Vector2(0, start_y), Vector2(size.x - MAP_PANEL_WIDTH, start_y), Color(0.12, 0.22, 0.28, 0.35), 1.0)
                start_y += grid_step

    # 4. Waystones markers
    for stone: Node in _stones:
        if not is_instance_valid(stone) or not (stone is Node2D):
            continue
        var stone_2d := stone as Node2D
        var p: Vector2 = center + stone_2d.global_position * factor
        var unlocked := bool(stone.get("is_unlocked"))
        var col_gem := Color("#4ef3e6") if unlocked else Color("#889299")
        var d_out := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)])
        var d_in := PackedVector2Array([p + Vector2(0, -4), p + Vector2(3.5, 0), p + Vector2(0, 4), p + Vector2(-3.5, 0)])
        draw_colored_polygon(d_out, Color("#101c24"))
        draw_colored_polygon(d_in, col_gem)
        if is_big_map and (map_zoom >= 1.8 or unlocked):
            _label(p + Vector2(10, 4), String(stone.display_name).replace(" Waystone", ""), 12, Color("#eef3f6"))

    # 5. NPC markers
    for npc: Node in _npcs:
        if is_instance_valid(npc) and npc is Node2D and (not is_big_map or map_zoom >= 1.6):
            var p: Vector2 = center + (npc as Node2D).global_position * factor
            draw_circle(p, 4.0, Color("#101c24"))
            draw_circle(p, 2.5, Color("#ffcf48"))

    # 6. Player marker
    if is_instance_valid(GameManager.player):
        var p: Vector2 = center + GameManager.player.global_position * factor
        var facing: Vector2 = GameManager.player.look_direction.normalized()
        if facing == Vector2.ZERO:
            facing = Vector2.DOWN
        var side: Vector2 = facing.orthogonal()
        var pts_outline := PackedVector2Array([
            p + facing * 11,
            p - facing * 7 + side * 7,
            p - facing * 4,
            p - facing * 7 - side * 7
        ])
        var pts_inner := PackedVector2Array([
            p + facing * 8,
            p - facing * 5 + side * 5,
            p - facing * 3,
            p - facing * 5 - side * 5
        ])
        draw_circle(p, 8.5, Color("#101c24"))
        draw_colored_polygon(pts_outline, Color("#ffd448"))
        draw_colored_polygon(pts_inner, Color("#1b394f"))
        draw_circle(p + facing * 2, 2.0, Color("#ffd448"))

    # 7. Framing and overlays
    if is_big_map:
        # Top header banner
        draw_rect(Rect2(0, 0, size.x, 56), Color("#12202a"))
        draw_line(Vector2(0, 56), Vector2(size.x, 56), Color("#9f824e"), 2.0)
        _label(Vector2(24, 28), "ANGEL ISLAND: EXPLORER'S CHART", 18, Color("#ffe08a"))
        _label(Vector2(24, 46), "Water, rivers, trees, houses, roads and named landmarks", 12, Color("#a8c0cf"))
        _label(Vector2(size.x - 330, 30), "ZOOM x%.1f" % map_zoom, 13, Color("#ffe08a"))

        # Right ledger / legend panel
        var leg_w: float = MAP_PANEL_WIDTH
        var leg_x: float = size.x - leg_w
        draw_rect(Rect2(leg_x, 56, leg_w, size.y - 56 - 36), Color("#101c25"))
        draw_line(Vector2(leg_x, 56), Vector2(leg_x, size.y - 36), Color("#9f824e"), 2.0)

        var ly: float = 84.0
        _label(Vector2(leg_x + 18, ly), "CHART KEY", 14, Color("#ffe08a"))
        draw_line(Vector2(leg_x + 18, ly + 6), Vector2(leg_x + leg_w - 18, ly + 6), Color("#564731"), 1.0)
        ly += 28.0

        draw_circle(Vector2(leg_x + 28, ly - 4), 6.0, Color("#101c24"))
        draw_colored_polygon(PackedVector2Array([Vector2(leg_x + 28, ly - 9), Vector2(leg_x + 33, ly), Vector2(leg_x + 28, ly - 2), Vector2(leg_x + 23, ly)]), Color("#ffd448"))
        _label(Vector2(leg_x + 44, ly), "You (Explorer)", 13, Color("#eef3f6"))
        ly += 26.0

        draw_circle(Vector2(leg_x + 28, ly - 4), 4.5, Color("#101c24"))
        draw_circle(Vector2(leg_x + 28, ly - 4), 3.0, Color("#ffcf48"))
        _label(Vector2(leg_x + 44, ly), "Villagers", 13, Color("#eef3f6"))
        ly += 26.0

        var d_u := PackedVector2Array([Vector2(leg_x + 28, ly - 10), Vector2(leg_x + 34, ly - 4), Vector2(leg_x + 28, ly + 2), Vector2(leg_x + 22, ly - 4)])
        draw_colored_polygon(d_u, Color("#4ef3e6"))
        _label(Vector2(leg_x + 44, ly), "Active Waystone", 13, Color("#eef3f6"))
        ly += 26.0

        var d_l := PackedVector2Array([Vector2(leg_x + 28, ly - 10), Vector2(leg_x + 34, ly - 4), Vector2(leg_x + 28, ly + 2), Vector2(leg_x + 22, ly - 4)])
        draw_polyline(d_l, Color("#889299"), 2.0)
        _label(Vector2(leg_x + 44, ly), "Dormant Beacon", 13, Color("#a8b3ba"))
        ly += 26.0

        draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#c39e68"))
        _label(Vector2(leg_x + 44, ly), "Stone & Dirt Paths", 13, Color("#eef3f6"))
        ly += 26.0

        draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#264c2f"))
        _label(Vector2(leg_x + 44, ly), "Woodland Groves", 13, Color("#eef3f6"))
        ly += 26.0

        draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#673e1e"))
        _label(Vector2(leg_x + 44, ly), "Village Farmland", 13, Color("#eef3f6"))
        ly += 26.0

        draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#2f879b"))
        _label(Vector2(leg_x + 44, ly), "Rivers & Lakes", 13, Color("#eef3f6"))
        ly += 26.0

        draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#c9a269"))
        _label(Vector2(leg_x + 44, ly), "Houses & Ruins", 13, Color("#eef3f6"))

        # Compass rose
        var cr_pos := Vector2(leg_x + leg_w * 0.5, size.y - 100.0)
        draw_circle(cr_pos, 22.0, Color("#0d171e"))
        draw_circle(cr_pos, 20.0, Color("#15242f"))
        draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(0, -18), cr_pos + Vector2(4, 0), cr_pos, cr_pos + Vector2(-4, 0)]), Color("#e84a4a"))
        draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(0, 18), cr_pos + Vector2(4, 0), cr_pos, cr_pos + Vector2(-4, 0)]), Color("#c8d0d6"))
        draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(18, 0), cr_pos + Vector2(0, 4), cr_pos, cr_pos + Vector2(0, -4)]), Color("#889299"))
        draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(-18, 0), cr_pos + Vector2(0, 4), cr_pos, cr_pos + Vector2(0, -4)]), Color("#889299"))
        draw_circle(cr_pos, 3.0, Color("#ffe08a"))
        _label(cr_pos + Vector2(-5, -22), "N", 12, Color("#ff6b6b"))

        # Bottom bar
        var b_y: float = size.y - 36.0
        draw_rect(Rect2(0, b_y, size.x, 36), Color("#12202a"))
        var paces_options: Array[float] = [100.0, 200.0, 500.0, 1000.0, 2000.0, 4000.0]
        var chosen_paces: float = 500.0
        for p_opt: float in paces_options:
            var px: float = p_opt * factor
            if px >= 35.0 and px <= 160.0:
                chosen_paces = p_opt
                break
        var bar_px: float = chosen_paces * factor
        if bar_px > 10.0 and bar_px < 220.0:
            draw_line(Vector2(24, b_y + 18), Vector2(24 + bar_px, b_y + 18), Color("#ffe08a"), 2.0)
            draw_line(Vector2(24, b_y + 12), Vector2(24, b_y + 24), Color("#ffe08a"), 2.0)
            draw_line(Vector2(24 + bar_px, b_y + 12), Vector2(24 + bar_px, b_y + 24), Color("#ffe08a"), 2.0)
            _label(Vector2(28 + bar_px, b_y + 22), "%d paces" % int(chosen_paces), 12, Color("#ffe08a"))
        _label(Vector2(size.x * 0.35, b_y + 22), "Drag / Arrows: Pan   |   Wheel / (+/-): Zoom   |   [Home]: Center   |   [M]: Close", 13, Color("#c3d4e0"))

        draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("#9f824e"), false, 3.0)
    else:
        # Minimap header
        draw_rect(Rect2(0, 0, size.x, 22), Color("#12202a"))
        draw_line(Vector2(0, 22), Vector2(size.x, 22), Color("#8a7143"), 1.0)
        _label(Vector2(8, 16), "Nearby [M]", 11, Color("#ffe08a"))
        var comp_x: float = size.x - 22.0
        draw_colored_polygon(PackedVector2Array([Vector2(comp_x, 4), Vector2(comp_x + 3, 11), Vector2(comp_x - 3, 11)]), Color("#e84a4a"))
        draw_colored_polygon(PackedVector2Array([Vector2(comp_x, 18), Vector2(comp_x + 3, 11), Vector2(comp_x - 3, 11)]), Color("#c8d0d6"))
        _label(Vector2(size.x - 12, 16), "N", 10, Color("#ff7b7b"))
        draw_rect(Rect2(Vector2.ZERO, size), Color("#101c24"), false, 3.0)
        draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#9f824e") if has_focus() else Color("#6b5735"), false, 1.0)
