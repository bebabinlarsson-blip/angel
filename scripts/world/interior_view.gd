class_name InteriorView
extends Control

## Procedural room backdrop shared by houses, the mine, and the church.
## The view is deliberately data-driven so new interior kinds only need a
## definition entry rather than another scene or imported texture.

var interior_id: String = ""
var interior_kind: String = "house"
var display_name: String = ""
var world_tileset: TileSet = null
var mine_button: Button = null
var mine_status: Label = null
var mine_veins_remaining: int = 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_tileset = load("res://assets/tilesets/angel_world_tileset.tres") as TileSet
	resized.connect(_layout_mine_controls)
	_ensure_mine_controls()
	queue_redraw()

func configure(new_id: String, new_name: String, new_kind: String) -> void:
	interior_id = new_id
	display_name = new_name
	interior_kind = new_kind
	mine_veins_remaining = 3
	_ensure_mine_controls()
	queue_redraw()

signal mine_requested(ore_type: String, amount: int)

func _draw_atlas_floor(floor_rect: Rect2) -> void:
	if world_tileset == null:
		return
	var source_id: int = 16 if interior_kind == "mine" else 14
	var source := world_tileset.get_source(source_id) as TileSetAtlasSource
	if source == null or source.texture == null:
		return
	var source_region := Rect2(Vector2.ZERO, Vector2(32.0, 32.0))
	for y in range(int(floor_rect.position.y), int(floor_rect.end.y), 32):
		for x in range(int(floor_rect.position.x), int(floor_rect.end.x), 32):
			var dest := Rect2(Vector2(x, y), Vector2(32.0, 32.0))
			draw_texture_rect_region(source.texture, dest, source_region, Color(1.0, 1.0, 1.0, 0.28))

func _ensure_mine_controls() -> void:
	if mine_button == null:
		mine_button = Button.new()
		mine_button.name = "MineVeinButton"
		mine_button.custom_minimum_size = Vector2(210.0, 36.0)
		mine_button.mouse_filter = Control.MOUSE_FILTER_STOP
		mine_button.pressed.connect(_on_mine_pressed)
		UITheme.style_button(mine_button)
		add_child(mine_button)
	if mine_status == null:
		mine_status = Label.new()
		mine_status.name = "MineStatus"
		mine_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mine_status.add_theme_color_override("font_color", Color("#ffe08a"))
		mine_status.add_theme_color_override("font_outline_color", Color("#111b29"))
		mine_status.add_theme_constant_override("outline_size", 3)
		add_child(mine_status)
	mine_button.visible = interior_kind == "mine"
	mine_status.visible = interior_kind == "mine"
	_layout_mine_controls()

func _layout_mine_controls() -> void:
	if mine_button == null or mine_status == null:
		return
	mine_button.position = Vector2(18.0, maxf(18.0, size.y - 52.0))
	mine_status.position = Vector2(242.0, maxf(18.0, size.y - 46.0))
	mine_status.text = "%d veins remain" % mine_veins_remaining

func _on_mine_pressed() -> void:
	if interior_kind != "mine" or mine_veins_remaining <= 0:
		return
	mine_veins_remaining -= 1
	mine_button.disabled = mine_veins_remaining <= 0
	mine_status.text = "%d veins remain" % mine_veins_remaining
	mine_button.text = "Mine iron vein" if mine_veins_remaining > 0 else "Mine exhausted"
	mine_requested.emit("iron_ore", 2)
	queue_redraw()

func _draw() -> void:
	if size.x <= 8.0 or size.y <= 8.0:
		return
	var room := Rect2(8.0, 8.0, maxf(1.0, size.x - 16.0), maxf(1.0, size.y - 16.0))
	draw_rect(room, Color("#241c28"))
	draw_rect(room.grow(-7.0), Color("#8f6748"))
	_draw_floor(room)
	_draw_back_wall(room)
	match interior_kind:
		"mine":
			_draw_mine(room)
		"church":
			_draw_church(room)
		"smith":
			_draw_smith(room)
		"market":
			_draw_market(room)
		"cook":
			_draw_cook(room)
		_:
			_draw_house(room)

func _draw_floor(room: Rect2) -> void:
	var floor_rect := room.grow(-7.0)
	_draw_atlas_floor(floor_rect)
	for y in range(0, maxi(1, int(floor_rect.size.y)), 24):
		var line_y := floor_rect.position.y + float(y)
		draw_line(Vector2(floor_rect.position.x, line_y), Vector2(floor_rect.end.x, line_y), Color(0.25, 0.15, 0.12, 0.32), 1.0)
	for x in range(0, maxi(1, int(floor_rect.size.x)), 48):
		var line_x := floor_rect.position.x + float(x)
		draw_line(Vector2(line_x, floor_rect.position.y), Vector2(line_x, floor_rect.end.y), Color(0.25, 0.15, 0.12, 0.20), 1.0)

func _draw_back_wall(room: Rect2) -> void:
	var wall := Rect2(room.position + Vector2(7.0, 7.0), Vector2(maxf(1.0, room.size.x - 14.0), 46.0))
	draw_rect(wall, Color("#5e4050"))
	draw_line(wall.position + Vector2(0.0, wall.size.y), wall.end, Color("#d09b65"), 3.0)
	var window := Rect2(Vector2(room.get_center().x - 42.0, wall.position.y + 10.0), Vector2(84.0, 26.0))
	draw_rect(window, Color("#5ab0ba"))
	draw_rect(window, Color("#e8d38c"), false, 3.0)
	draw_line(window.get_center() - Vector2(0.0, 13.0), window.get_center() + Vector2(0.0, 13.0), Color("#e8d38c"), 2.0)
	draw_line(window.get_center() - Vector2(42.0, 0.0), window.get_center() + Vector2(42.0, 0.0), Color("#e8d38c"), 2.0)

func _draw_house(room: Rect2) -> void:
	_draw_bed(Vector2(room.position.x + 86.0, room.position.y + 96.0))
	_draw_table(room.get_center() + Vector2(66.0, 70.0), Color("#ad7449"))
	_draw_chest(Vector2(room.end.x - 88.0, room.position.y + 94.0), Color("#d09b4f"))
	_draw_rug(room.get_center() + Vector2(-54.0, 42.0), Color("#a74f5b"))

func _draw_cook(room: Rect2) -> void:
	_draw_table(room.get_center() + Vector2(0.0, 64.0), Color("#b97845"))
	_draw_pot(room.get_center() + Vector2(-86.0, 48.0))
	_draw_shelves(Vector2(room.end.x - 112.0, room.position.y + 76.0), Color("#d5a261"))
	_draw_rug(room.get_center() + Vector2(70.0, 100.0), Color("#c46a58"))

func _draw_market(room: Rect2) -> void:
	_draw_shelves(Vector2(room.position.x + 86.0, room.position.y + 72.0), Color("#d7aa5c"))
	_draw_shelves(Vector2(room.end.x - 94.0, room.position.y + 72.0), Color("#a96b4e"))
	_draw_table(room.get_center() + Vector2(0.0, 82.0), Color("#b87845"))
	_draw_crates(room.get_center() + Vector2(-112.0, 100.0), Color("#d2a04f"))
	_draw_crates(room.get_center() + Vector2(112.0, 100.0), Color("#7db068"))

func _draw_smith(room: Rect2) -> void:
	_draw_forge(Vector2(room.position.x + 106.0, room.position.y + 102.0))
	_draw_anvil(room.get_center() + Vector2(26.0, 96.0))
	_draw_rack(Vector2(room.end.x - 92.0, room.position.y + 82.0))
	_draw_crates(room.get_center() + Vector2(-78.0, 112.0), Color("#777d8f"))

func _draw_mine(room: Rect2) -> void:
	var rock_color := Color("#4a4558")
	for p in [
		Vector2(room.position.x + 48.0, room.position.y + 76.0),
		Vector2(room.end.x - 54.0, room.position.y + 92.0),
		Vector2(room.position.x + 76.0, room.end.y - 42.0),
		Vector2(room.end.x - 92.0, room.end.y - 36.0)
	]:
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-24.0, 16.0), p + Vector2(-16.0, -20.0),
			p + Vector2(4.0, -30.0), p + Vector2(28.0, -10.0),
			p + Vector2(18.0, 18.0)
		]), rock_color)
	for x in range(0, maxi(1, int(room.size.x)), 72):
		var rail_x := room.position.x + 30.0 + float(x)
		draw_line(Vector2(rail_x, room.end.y - 84.0), Vector2(rail_x + 72.0, room.end.y - 84.0), Color("#b98651"), 4.0)
		draw_line(Vector2(rail_x, room.end.y - 54.0), Vector2(rail_x + 72.0, room.end.y - 54.0), Color("#b98651"), 4.0)
		draw_line(Vector2(rail_x, room.end.y - 90.0), Vector2(rail_x, room.end.y - 48.0), Color("#65442e"), 3.0)
	_draw_crystal(room.get_center() + Vector2(-112.0, -10.0), Color("#67dce8"))
	_draw_crystal(room.get_center() + Vector2(116.0, -4.0), Color("#e5b64f"))
	_draw_lantern(room.get_center() + Vector2(0.0, -24.0))

func _draw_church(room: Rect2) -> void:
	var altar := Rect2(Vector2(room.get_center().x - 38.0, room.position.y + 72.0), Vector2(76.0, 34.0))
	draw_rect(altar, Color("#d7b875"))
	draw_rect(altar, Color("#714b39"), false, 3.0)
	draw_circle(Vector2(room.get_center().x, altar.position.y - 16.0), 12.0, Color("#8dd7dd"))
	draw_line(Vector2(room.get_center().x, altar.position.y - 27.0), Vector2(room.get_center().x, altar.position.y - 5.0), Color("#f6e6a2"), 3.0)
	draw_line(Vector2(room.get_center().x - 11.0, altar.position.y - 16.0), Vector2(room.get_center().x + 11.0, altar.position.y - 16.0), Color("#f6e6a2"), 3.0)
	for row in range(3):
		var y := room.position.y + 142.0 + float(row) * 48.0
		_draw_pew(Vector2(room.get_center().x - 122.0, y))
		_draw_pew(Vector2(room.get_center().x + 122.0, y))
	_draw_rug(room.get_center() + Vector2(0.0, 110.0), Color("#6f4f9b"))

func _draw_bed(pos: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2(32.0, 44.0), Vector2(64.0, 88.0)), Color("#63485d"))
	draw_rect(Rect2(pos - Vector2(25.0, 34.0), Vector2(50.0, 56.0)), Color("#b7d4d4"))
	draw_rect(Rect2(pos - Vector2(25.0, 34.0), Vector2(50.0, 22.0)), Color("#e6d39b"))
	draw_rect(Rect2(pos - Vector2(32.0, 44.0), Vector2(64.0, 88.0)), Color("#3d2b3d"), false, 3.0)

func _draw_table(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(48.0, 18.0), Vector2(96.0, 36.0)), color)
	draw_rect(Rect2(pos - Vector2(48.0, 18.0), Vector2(96.0, 36.0)), Color("#4c3024"), false, 3.0)
	draw_line(pos + Vector2(-32.0, 18.0), pos + Vector2(-32.0, 38.0), Color("#5d3826"), 5.0)
	draw_line(pos + Vector2(32.0, 18.0), pos + Vector2(32.0, 38.0), Color("#5d3826"), 5.0)
	draw_circle(pos + Vector2(-20.0, -8.0), 7.0, Color("#cf6e55"))
	draw_circle(pos + Vector2(20.0, 5.0), 7.0, Color("#7fc56d"))

func _draw_chest(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(32.0, 20.0), Vector2(64.0, 40.0)), color)
	draw_rect(Rect2(pos - Vector2(32.0, 20.0), Vector2(64.0, 40.0)), Color("#4a3024"), false, 3.0)
	draw_line(pos + Vector2(-32.0, -2.0), pos + Vector2(32.0, -2.0), Color("#f0d27b"), 2.0)
	draw_rect(Rect2(pos - Vector2(4.0, 4.0), Vector2(8.0, 10.0)), Color("#6d4828"))

func _draw_shelves(pos: Vector2, color: Color) -> void:
	for row in range(3):
		var y := pos.y + float(row) * 26.0
		draw_line(Vector2(pos.x - 44.0, y), Vector2(pos.x + 44.0, y), color, 7.0)
		for column in range(4):
			var item_color := Color("#d75555") if column % 2 == 0 else Color("#6ebd77")
			draw_rect(Rect2(pos.x - 34.0 + float(column) * 22.0, y - 18.0, 12.0, 15.0), item_color)

func _draw_crates(pos: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos - Vector2(24.0, 20.0), Vector2(48.0, 40.0)), color)
	draw_rect(Rect2(pos - Vector2(24.0, 20.0), Vector2(48.0, 40.0)), Color("#4c3024"), false, 3.0)
	draw_line(pos - Vector2(19.0, 16.0), pos + Vector2(19.0, 16.0), Color(0.25, 0.16, 0.12, 0.55), 2.0)
	draw_line(pos + Vector2(-19.0, 16.0), pos + Vector2(19.0, -16.0), Color(0.25, 0.16, 0.12, 0.55), 2.0)

func _draw_pot(pos: Vector2) -> void:
	draw_circle(pos, 25.0, Color("#5a6475"))
	draw_circle(pos + Vector2(0.0, -3.0), 18.0, Color("#d7834e"))
	draw_circle(pos + Vector2(0.0, -7.0), 12.0, Color("#f1c35e"))
	draw_line(pos + Vector2(-22.0, 10.0), pos + Vector2(-32.0, 28.0), Color("#4b3024"), 5.0)
	draw_line(pos + Vector2(22.0, 10.0), pos + Vector2(32.0, 28.0), Color("#4b3024"), 5.0)

func _draw_forge(pos: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2(38.0, 28.0), Vector2(76.0, 56.0)), Color("#6e4a3d"))
	draw_rect(Rect2(pos - Vector2(28.0, 22.0), Vector2(56.0, 42.0)), Color("#d06440"))
	draw_circle(pos + Vector2(0.0, -12.0), 19.0, Color("#ffb83e"))
	draw_circle(pos + Vector2(0.0, -12.0), 10.0, Color("#fff1a0"))
	draw_circle(pos + Vector2(0.0, -58.0), 10.0, Color(0.60, 0.66, 0.72, 0.30))
	draw_circle(pos + Vector2(4.0, -74.0), 7.0, Color(0.60, 0.66, 0.72, 0.20))

func _draw_anvil(pos: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2(34.0, 6.0), Vector2(68.0, 16.0)), Color("#7c8490"))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-20.0, 10.0), pos + Vector2(20.0, 10.0), pos + Vector2(12.0, 38.0), pos + Vector2(-12.0, 38.0)]), Color("#4b5360"))
	draw_line(pos + Vector2(-34.0, -6.0), pos + Vector2(34.0, -6.0), Color("#cfd9df"), 3.0)

func _draw_rack(pos: Vector2) -> void:
	draw_line(pos + Vector2(-40.0, 32.0), pos + Vector2(-40.0, -42.0), Color("#75442e"), 5.0)
	draw_line(pos + Vector2(40.0, 32.0), pos + Vector2(40.0, -42.0), Color("#75442e"), 5.0)
	draw_line(pos + Vector2(-40.0, -38.0), pos + Vector2(40.0, -38.0), Color("#75442e"), 5.0)
	draw_line(pos + Vector2(-27.0, -32.0), pos + Vector2(-12.0, 2.0), Color("#dbe6ef"), 5.0)
	draw_line(pos + Vector2(0.0, -32.0), pos + Vector2(12.0, 5.0), Color("#dbe6ef"), 5.0)
	draw_line(pos + Vector2(27.0, -32.0), pos + Vector2(18.0, 3.0), Color("#dbe6ef"), 5.0)

func _draw_lantern(pos: Vector2) -> void:
	draw_line(pos + Vector2(0.0, -30.0), pos + Vector2(0.0, 24.0), Color("#8a5d37"), 3.0)
	draw_circle(pos + Vector2(0.0, -34.0), 10.0, Color("#f4c45b"))
	draw_circle(pos + Vector2(0.0, -34.0), 20.0, Color(1.0, 0.78, 0.28, 0.16))

func _draw_crystal(pos: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0.0, -34.0), pos + Vector2(18.0, -8.0),
		pos + Vector2(12.0, 28.0), pos + Vector2(-12.0, 28.0),
		pos + Vector2(-18.0, -8.0)
	]), color)
	draw_line(pos + Vector2(0.0, -29.0), pos + Vector2(2.0, 18.0), Color(1.0, 1.0, 1.0, 0.50), 3.0)

func _draw_pew(pos: Vector2) -> void:
	draw_rect(Rect2(pos - Vector2(62.0, 9.0), Vector2(124.0, 18.0)), Color("#6e493a"))
	draw_rect(Rect2(pos - Vector2(62.0, 9.0), Vector2(124.0, 18.0)), Color("#d0a56e"), false, 2.0)
	draw_line(pos + Vector2(-48.0, -11.0), pos + Vector2(-48.0, 11.0), Color("#d0a56e"), 3.0)
	draw_line(pos + Vector2(48.0, -11.0), pos + Vector2(48.0, 11.0), Color("#d0a56e"), 3.0)

func _draw_rug(pos: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(32):
		var angle: float = float(index) * TAU / 32.0
		points.append(pos + Vector2(cos(angle) * 82.0, sin(angle) * 32.0))
	draw_colored_polygon(points, color)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, Color(0.10, 0.07, 0.10, 0.75), 3.0)
