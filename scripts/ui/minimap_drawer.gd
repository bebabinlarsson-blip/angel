class_name MinimapDrawer
extends Control

@export var is_big_map: bool = false
@export var world_radius: float = 3200.0
var map_offset := Vector2.ZERO
var map_zoom: float = 1.0
var _dragging: bool = false
var _timer: float = 0.0
var _terrain: IslandWorld
var _stones: Array[Node] = []
var _npcs: Array[Node] = []
const INK := Color("#f3e7ce")
const OCEAN := Color("#244853")

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
	if _timer < 0.08:
		return
	_timer = 0.0
	if not is_instance_valid(_terrain):
		_terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
	_stones = get_tree().get_nodes_in_group("waystones")
	_npcs = get_tree().get_nodes_in_group("npcs")
	queue_redraw()

func _map_scale() -> float:
	if not is_instance_valid(_terrain):
		return 1.0
	if not is_big_map:
		return minf(size.x, size.y - 22.0) / 1500.0
	return minf(size.x - 340.0, size.y - 130.0) / _terrain.bounds.size.x * map_zoom

func _center() -> Vector2:
	if is_big_map:
		return Vector2((size.x - 200.0) * 0.5, size.y * 0.5 + 10.0) + map_offset * _map_scale()
	var p := Vector2.ZERO
	if is_instance_valid(GameManager.player):
		p = GameManager.player.global_position
	return Vector2(size.x * 0.5, (size.y + 22.0) * 0.5) - p * _map_scale()

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
	_zoom_by(1.25, pivot)

func zoom_out(pivot: Vector2 = Vector2.INF) -> void:
	_zoom_by(1.0 / 1.25, pivot)

func _zoom_by(factor: float, pivot: Vector2 = Vector2.INF) -> void:
	if not is_big_map:
		return
	var old_zoom: float = map_zoom
	var new_zoom: float = clampf(map_zoom * factor, 0.5, 6.0)
	if is_equal_approx(old_zoom, new_zoom):
		return
	var screen_mid := Vector2((size.x - 210.0) * 0.5, size.y * 0.5 + 10.0)
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
	if is_instance_valid(_terrain) and _terrain.radius > 0.0:
		limit = _terrain.radius * 1.5
	map_offset.x = clampf(map_offset.x, -limit, limit)
	map_offset.y = clampf(map_offset.y, -limit, limit)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not is_big_map and event.pressed:
				get_tree().root.find_child("HUD", true, false).set_map_open(true)
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
			get_tree().root.find_child("HUD", true, false).set_map_open(true)
		elif is_big_map:
			match event.keycode:
				KEY_LEFT: map_offset.x += 120.0 / map_zoom
				KEY_RIGHT: map_offset.x -= 120.0 / map_zoom
				KEY_UP: map_offset.y += 120.0 / map_zoom
				KEY_DOWN: map_offset.y -= 120.0 / map_zoom
				KEY_EQUAL, KEY_PLUS: zoom_in()
				KEY_MINUS: zoom_out()
			_clamp_offset()
			accept_event()
	queue_redraw()

func _label(pos: Vector2, text: String, font_size: int = 14, color: Color = INK) -> void:
	draw_string_outline(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color("#101c24"))
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if not is_instance_valid(_terrain):
		_terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
	if _stones.is_empty():
		_stones = get_tree().get_nodes_in_group("waystones")
	if _npcs.is_empty():
		_npcs = get_tree().get_nodes_in_group("npcs")

	# 1. Base ocean fill
	draw_rect(Rect2(Vector2.ZERO, size), OCEAN)
	
	if not is_instance_valid(_terrain) or _terrain.map_texture == null:
		_label(Vector2(12, 28), "Charting island...", 14)
		return
		
	var factor: float = _map_scale()
	var center: Vector2 = _center()
	
	# 2. Map terrain texture (nearest neighbor crisp rendering)
	var map_rect := Rect2(center + _terrain.bounds.position * factor, _terrain.bounds.size * factor)
	draw_texture_rect(_terrain.map_texture, map_rect, false)
	
	# 3. Subtle grid lines on Big Map (32 tiles / 1024 units per grid square)
	if is_big_map:
		var grid_step: float = 32.0 * 32.0 * factor
		if grid_step > 20.0:
			var start_x: float = fposmod(map_rect.position.x, grid_step)
			while start_x < size.x - 210.0:
				if start_x > 0:
					draw_line(Vector2(start_x, 56), Vector2(start_x, size.y - 36), Color(0.12, 0.22, 0.28, 0.35), 1.0)
				start_x += grid_step
			var start_y: float = fposmod(map_rect.position.y, grid_step)
			while start_y < size.y - 36.0:
				if start_y > 56:
					draw_line(Vector2(0, start_y), Vector2(size.x - 210.0, start_y), Color(0.12, 0.22, 0.28, 0.35), 1.0)
				start_y += grid_step

	# 4. Waystones markers
	for stone: Node in _stones:
		if not is_instance_valid(stone):
			continue
		var p: Vector2 = center + stone.global_position * factor
		var unlocked: bool = stone.is_unlocked
		var col_gem := Color("#4ef3e6") if unlocked else Color("#889299")
		# Diamond shape
		var d_out := PackedVector2Array([p + Vector2(0, -7), p + Vector2(6, 0), p + Vector2(0, 7), p + Vector2(-6, 0)])
		var d_in := PackedVector2Array([p + Vector2(0, -4), p + Vector2(3.5, 0), p + Vector2(0, 4), p + Vector2(-3.5, 0)])
		draw_colored_polygon(d_out, Color("#101c24"))
		draw_colored_polygon(d_in, col_gem)
		if is_big_map and map_zoom >= 0.8:
			_label(p + Vector2(10, 4), String(stone.display_name).replace(" Waystone", ""), 12, Color("#eef3f6"))

	# 5. NPCs markers
	for npc: Node in _npcs:
		if is_instance_valid(npc) and (not is_big_map or map_zoom >= 1.6):
			var p: Vector2 = center + npc.global_position * factor
			draw_circle(p, 4.0, Color("#101c24"))
			draw_circle(p, 2.5, Color("#ffcf48"))

	# 6. Player marker
	if is_instance_valid(GameManager.player):
		var p: Vector2 = center + GameManager.player.global_position * factor
		var facing: Vector2 = GameManager.player.look_direction.normalized()
		if facing == Vector2.ZERO:
			facing = Vector2.DOWN
		var side: Vector2 = facing.orthogonal()
		# High-contrast golden explorer arrow
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

	# 7. Framing and Overlays
	if is_big_map:
		# Top Header Banner
		draw_rect(Rect2(0, 0, size.x, 56), Color("#12202a"))
		draw_line(Vector2(0, 56), Vector2(size.x, 56), Color("#9f824e"), 2.0)
		_label(Vector2(24, 28), "ANGEL ISLAND: EXPLORER'S CHART", 18, Color("#ffe08a"))
		_label(Vector2(24, 46), "Recorded landmarks, paths, woodland and waystone beacons", 12, Color("#a8c0cf"))

		# Right Ledger / Legend Panel
		var leg_w: float = 210.0
		var leg_x: float = size.x - leg_w
		draw_rect(Rect2(leg_x, 56, leg_w, size.y - 56 - 36), Color("#101c25"))
		draw_line(Vector2(leg_x, 56), Vector2(leg_x, size.y - 36), Color("#9f824e"), 2.0)
		
		var ly: float = 84.0
		_label(Vector2(leg_x + 18, ly), "CHART KEY", 14, Color("#ffe08a"))
		draw_line(Vector2(leg_x + 18, ly + 6), Vector2(leg_x + leg_w - 18, ly + 6), Color("#564731"), 1.0)
		ly += 28.0

		# Key item: Player
		draw_circle(Vector2(leg_x + 28, ly - 4), 6.0, Color("#101c24"))
		draw_colored_polygon(PackedVector2Array([Vector2(leg_x + 28, ly - 9), Vector2(leg_x + 33, ly), Vector2(leg_x + 28, ly - 2), Vector2(leg_x + 23, ly)]), Color("#ffd448"))
		_label(Vector2(leg_x + 44, ly), "You (Explorer)", 13, Color("#eef3f6"))
		ly += 26.0

		# Key item: NPC
		draw_circle(Vector2(leg_x + 28, ly - 4), 4.5, Color("#101c24"))
		draw_circle(Vector2(leg_x + 28, ly - 4), 3.0, Color("#ffcf48"))
		_label(Vector2(leg_x + 44, ly), "Villagers", 13, Color("#eef3f6"))
		ly += 26.0

		# Key item: Unlocked Waystone
		var d_u := PackedVector2Array([Vector2(leg_x + 28, ly - 10), Vector2(leg_x + 34, ly - 4), Vector2(leg_x + 28, ly + 2), Vector2(leg_x + 22, ly - 4)])
		draw_colored_polygon(d_u, Color("#4ef3e6"))
		_label(Vector2(leg_x + 44, ly), "Active Waystone", 13, Color("#eef3f6"))
		ly += 26.0

		# Key item: Dormant Waystone
		var d_l := PackedVector2Array([Vector2(leg_x + 28, ly - 10), Vector2(leg_x + 34, ly - 4), Vector2(leg_x + 28, ly + 2), Vector2(leg_x + 22, ly - 4)])
		draw_polyline(d_l, Color("#889299"), 2.0)
		_label(Vector2(leg_x + 44, ly), "Dormant Beacon", 13, Color("#a8b3ba"))
		ly += 26.0

		# Key item: Road & Bridge
		draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#c39e68"))
		_label(Vector2(leg_x + 44, ly), "Stone & Dirt Paths", 13, Color("#eef3f6"))
		ly += 26.0

		# Key item: Forest
		draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#264c2f"))
		_label(Vector2(leg_x + 44, ly), "Woodland Groves", 13, Color("#eef3f6"))
		ly += 26.0

		# Key item: Farmland
		draw_rect(Rect2(leg_x + 22, ly - 9, 12, 10), Color("#673e1e"))
		_label(Vector2(leg_x + 44, ly), "Village Farmland", 13, Color("#eef3f6"))
		
		# Compass Rose
		var cr_pos := Vector2(leg_x + leg_w * 0.5, size.y - 100.0)
		draw_circle(cr_pos, 22.0, Color("#0d171e"))
		draw_circle(cr_pos, 20.0, Color("#15242f"))
		# North needle (red)
		draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(0, -18), cr_pos + Vector2(4, 0), cr_pos, cr_pos + Vector2(-4, 0)]), Color("#e84a4a"))
		# South needle (silver)
		draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(0, 18), cr_pos + Vector2(4, 0), cr_pos, cr_pos + Vector2(-4, 0)]), Color("#c8d0d6"))
		# East/West needles
		draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(18, 0), cr_pos + Vector2(0, 4), cr_pos, cr_pos + Vector2(0, -4)]), Color("#889299"))
		draw_colored_polygon(PackedVector2Array([cr_pos + Vector2(-18, 0), cr_pos + Vector2(0, 4), cr_pos, cr_pos + Vector2(0, -4)]), Color("#889299"))
		draw_circle(cr_pos, 3.0, Color("#ffe08a"))
		_label(cr_pos + Vector2(-5, -22), "N", 12, Color("#ff6b6b"))

		# Bottom Bar
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

		# Outer Border
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("#9f824e"), false, 3.0)
	else:
		# Minimap Header
		draw_rect(Rect2(0, 0, size.x, 22), Color("#12202a"))
		draw_line(Vector2(0, 22), Vector2(size.x, 22), Color("#8a7143"), 1.0)
		_label(Vector2(8, 16), "Nearby [M]", 11, Color("#ffe08a"))
		# Compass indicator
		var comp_x: float = size.x - 22.0
		draw_colored_polygon(PackedVector2Array([Vector2(comp_x, 4), Vector2(comp_x + 3, 11), Vector2(comp_x - 3, 11)]), Color("#e84a4a"))
		draw_colored_polygon(PackedVector2Array([Vector2(comp_x, 18), Vector2(comp_x + 3, 11), Vector2(comp_x - 3, 11)]), Color("#c8d0d6"))
		_label(Vector2(size.x - 12, 16), "N", 10, Color("#ff7b7b"))
		# Bezel Frame
		draw_rect(Rect2(Vector2.ZERO, size), Color("#101c24"), false, 3.0)
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#9f824e") if has_focus() else Color("#6b5735"), false, 1.0)
