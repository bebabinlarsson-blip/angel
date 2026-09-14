class_name ItemIcon
extends Control

## Small procedural item artwork used by every inventory and cooking recipe slot.
## It keeps the UI readable even when a new material has no imported texture yet.
@export var item_id: String = ""
@export var item_type: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(48.0, 48.0)
	queue_redraw()

func _draw() -> void:
	var draw_size: float = minf(size.x, size.y)
	if draw_size <= 0.0:
		return
	var icon_scale: float = draw_size / 64.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * icon_scale)
	draw_circle(Vector2(0.0, 24.0), 15.0, Color(0.01, 0.03, 0.05, 0.42))

	if item_type == 1:
		_draw_sword()
	elif item_type == 2:
		_draw_shield()
	elif item_type == 3:
		_draw_dish()
	elif item_type == 4:
		_draw_potion()
	elif item_type == 6:
		_draw_relic()
	else:
		match item_id:
			"wood":
				_draw_log()
			"stone", "iron_ore", "gold_ore", "coal", "ore":
				_draw_rock(Color("#8b929b"), Color("#dce7ef"))
			"crystal", "crystal_shard", "ancient_shard":
				_draw_crystal()
			"herb", "fiber", "moon_petal":
				_draw_herb()
			"plant", "reeds":
				_draw_plant()
			"flower":
				_draw_flower(Color("#f29ac2"))
			"clover":
				_draw_clover()
			"apple":
				_draw_fruit(Color("#e9584f"), "apple")
			"orange":
				_draw_fruit(Color("#f39a42"), "orange")
			"pear":
				_draw_fruit(Color("#c9d95b"), "pear")
			"banana":
				_draw_banana()
			"grapes":
				_draw_grapes()
			"tomato":
				_draw_fruit(Color("#d84d49"), "tomato")
			"coconut":
				_draw_fruit(Color("#8d5e3d"), "coconut")
			"watermelon":
				_draw_fruit(Color("#5cae61"), "watermelon")
			"carrot":
				_draw_carrot()
			"wheat":
				_draw_plant()
			"mint":
				_draw_herb()
			"lavender":
				_draw_flower(Color("#a681d6"))
			"rose":
				_draw_flower(Color("#e74f67"))
			"mushroom":
				_draw_mushroom()
			"berry":
				_draw_berries()
			_:
				_draw_material_fallback()

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_log() -> void:
	draw_rect(Rect2(-23.0, -10.0, 46.0, 20.0), Color("#8a522d"), true)
	draw_rect(Rect2(-23.0, -10.0, 46.0, 20.0), Color("#d49a55"), false, 2.0)
	draw_circle(Vector2(-23.0, 0.0), 10.0, Color("#c47d41"))
	draw_circle(Vector2(-23.0, 0.0), 5.0, Color("#6e3f2a"))
	draw_line(Vector2(-9.0, -7.0), Vector2(19.0, -7.0), Color("#e3ad61"), 2.0)
	draw_line(Vector2(-5.0, 4.0), Vector2(16.0, 4.0), Color("#633a27"), 2.0)

func _draw_rock(base_color: Color, highlight: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-24.0, 13.0), Vector2(-18.0, -13.0), Vector2(0.0, -23.0),
		Vector2(22.0, -12.0), Vector2(25.0, 10.0), Vector2(8.0, 22.0),
		Vector2(-13.0, 21.0)
	])
	draw_colored_polygon(points, base_color)
	draw_polyline(PackedVector2Array([
		Vector2(-24.0, 13.0), Vector2(-18.0, -13.0), Vector2(0.0, -23.0),
		Vector2(22.0, -12.0), Vector2(25.0, 10.0), Vector2(8.0, 22.0),
		Vector2(-13.0, 21.0), Vector2(-24.0, 13.0)
	]), Color("#303a45"), 2.0)
	draw_line(Vector2(-10.0, -11.0), Vector2(6.0, -15.0), highlight, 4.0)
	draw_circle(Vector2(11.0, 2.0), 3.0, highlight)

func _draw_crystal() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, -28.0), Vector2(15.0, -8.0), Vector2(11.0, 22.0),
		Vector2(-7.0, 27.0), Vector2(-17.0, -8.0)
	])
	draw_colored_polygon(points, Color("#65dbe5"))
	draw_polyline(PackedVector2Array([
		Vector2(0.0, -28.0), Vector2(15.0, -8.0), Vector2(11.0, 22.0),
		Vector2(-7.0, 27.0), Vector2(-17.0, -8.0), Vector2(0.0, -28.0)
	]), Color("#d5ffff"), 2.0)
	draw_line(Vector2(0.0, -24.0), Vector2(2.0, 17.0), Color("#c0f9ff"), 3.0)

func _draw_herb() -> void:
	draw_line(Vector2(0.0, 23.0), Vector2(-3.0, -18.0), Color("#62a957"), 4.0)
	draw_line(Vector2(-2.0, 7.0), Vector2(-18.0, -4.0), Color("#8bd26e"), 4.0)
	draw_line(Vector2(-2.0, -3.0), Vector2(15.0, -16.0), Color("#8bd26e"), 4.0)
	draw_ellipse_leaf(Vector2(-16.0, -5.0), 8.0, Color("#4e9b58"))
	draw_ellipse_leaf(Vector2(16.0, -17.0), 8.0, Color("#68bd65"))
	draw_circle(Vector2(-3.0, -20.0), 5.0, Color("#d4ef87"))

func _draw_plant() -> void:
	draw_line(Vector2(-11.0, 23.0), Vector2(-11.0, -18.0), Color("#4f9b57"), 4.0)
	draw_line(Vector2(0.0, 23.0), Vector2(3.0, -26.0), Color("#69b85c"), 4.0)
	draw_line(Vector2(11.0, 23.0), Vector2(16.0, -12.0), Color("#3f804e"), 4.0)
	draw_ellipse_leaf(Vector2(-17.0, -8.0), 7.0, Color("#6fc66a"))
	draw_ellipse_leaf(Vector2(10.0, -2.0), 8.0, Color("#82d26f"))
	draw_ellipse_leaf(Vector2(18.0, -18.0), 7.0, Color("#579d59"))

func _draw_carrot() -> void:
	draw_line(Vector2(0.0, -1.0), Vector2(0.0, -20.0), Color("#4f9b4c"), 4.0)
	draw_line(Vector2(0.0, -13.0), Vector2(-8.0, -20.0), Color("#6db25d"), 3.0)
	draw_line(Vector2(0.0, -13.0), Vector2(8.0, -20.0), Color("#6db25d"), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -2.0), Vector2(11.0, -2.0), Vector2(5.0, 20.0),
		Vector2(0.0, 26.0), Vector2(-5.0, 20.0)
	]), Color("#e88943"))
	draw_line(Vector2(-4.0, 4.0), Vector2(4.0, 15.0), Color("#ffd08a"), 2.0)

func _draw_flower(petal_color: Color) -> void:
	draw_line(Vector2(0.0, 24.0), Vector2(0.0, -7.0), Color("#5aa556"), 3.0)
	draw_ellipse_leaf(Vector2(-8.0, 10.0), 6.0, Color("#6dbd62"))
	for i in range(5):
		var angle: float = float(i) * TAU / 5.0
		var petal_position: Vector2 = Vector2.RIGHT.rotated(angle) * 10.0 + Vector2(0.0, -13.0)
		draw_circle(petal_position, 7.0, petal_color)
	draw_circle(Vector2(0.0, -13.0), 4.0, Color("#ffd45f"))

func _draw_clover() -> void:
	draw_line(Vector2(0.0, 24.0), Vector2(0.0, -9.0), Color("#55a45f"), 3.0)
	var leaf_positions: Array[Vector2] = [Vector2(-8.0, -14.0), Vector2(8.0, -14.0), Vector2(0.0, -23.0)]
	for offset: Vector2 in leaf_positions:
		draw_circle(offset, 8.0, Color("#6acb69"))
	draw_circle(Vector2(0.0, -14.0), 4.0, Color("#d8f28a"))

func _draw_fruit(fruit_color: Color, shape: String) -> void:
	if shape == "pear":
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8.0, -20.0), Vector2(9.0, -18.0), Vector2(15.0, -3.0),
			Vector2(10.0, 18.0), Vector2(-10.0, 20.0), Vector2(-15.0, 0.0)
		]), fruit_color)
	else:
		draw_circle(Vector2(0.0, 2.0), 18.0, fruit_color)
	if shape == "watermelon":
		draw_circle(Vector2(0.0, 2.0), 11.0, Color("#e86565"))
		draw_arc(Vector2(0.0, 2.0), 15.0, 0.3, 2.8, 18, Color("#2d7548"), 2.0)
	draw_line(Vector2(0.0, -17.0), Vector2(4.0, -26.0), Color("#6d4329"), 3.0)
	draw_ellipse_leaf(Vector2(10.0, -23.0), 7.0, Color("#77bd5d"))
	draw_circle(Vector2(-6.0, -4.0), 4.0, Color(1.0, 1.0, 1.0, 0.35))

func _draw_banana() -> void:
	draw_arc(Vector2(0.0, 0.0), 21.0, -0.8, 2.5, 24, Color("#f4d153"), 9.0)
	draw_arc(Vector2(0.0, 0.0), 21.0, -0.8, 2.5, 24, Color("#fff09a"), 3.0)
	draw_circle(Vector2(-15.0, -15.0), 4.0, Color("#74462e"))
	draw_circle(Vector2(-13.0, 18.0), 4.0, Color("#74462e"))

func _draw_grapes() -> void:
	draw_line(Vector2(0.0, -23.0), Vector2(0.0, -13.0), Color("#70442e"), 3.0)
	draw_ellipse_leaf(Vector2(10.0, -20.0), 8.0, Color("#68b95b"))
	for row in range(4):
		var count: int = row + 1
		for column in range(count):
			var grape_position: Vector2 = Vector2(float(column - row) * 9.0, float(row) * 9.0 - 5.0)
			draw_circle(grape_position, 8.0, Color("#8153b9"))
			draw_circle(grape_position + Vector2(-2.0, -2.0), 2.0, Color("#e1bdff"))

func _draw_mushroom() -> void:
	draw_rect(Rect2(-7.0, -1.0, 14.0, 23.0), Color("#f0d6a6"), true)
	draw_ellipse_leaf(Vector2(0.0, -10.0), 15.0, Color("#c9655b"))
	draw_arc(Vector2(0.0, -10.0), 15.0, PI, TAU, 20, Color("#f0a17f"), 3.0)
	draw_circle(Vector2(-7.0, -13.0), 3.0, Color("#ffe8bd"))
	draw_circle(Vector2(6.0, -8.0), 2.5, Color("#ffe8bd"))

func _draw_berries() -> void:
	draw_line(Vector2(0.0, 23.0), Vector2(-2.0, -14.0), Color("#5a9a53"), 3.0)
	draw_ellipse_leaf(Vector2(-13.0, -17.0), 8.0, Color("#69b85d"))
	var berry_positions: Array[Vector2] = [Vector2(-9.0, -5.0), Vector2(8.0, -7.0), Vector2(0.0, 7.0), Vector2(13.0, 6.0)]
	for offset: Vector2 in berry_positions:
		draw_circle(offset, 8.0, Color("#b94b8c"))
		draw_circle(offset + Vector2(-2.0, -2.0), 2.0, Color("#ffc8ea"))

func _draw_dish() -> void:
	var dish_color: Color = Color("#e8b65e")
	match item_id:
		"orchard_pie":
			dish_color = Color("#d57b49")
		"tropical_fruit_bowl":
			dish_color = Color("#e38c47")
		"berry_compote":
			dish_color = Color("#b85a91")
		"herb_salad", "foragers_salad":
			dish_color = Color("#73c46c")
		"garden_soup":
			dish_color = Color("#d86b48")
		"fruit_punch":
			dish_color = Color("#e35b74")
		"root_roast":
			dish_color = Color("#b8794d")
		"lavender_tea":
			dish_color = Color("#ad83cf")
		"mushroom_stew", "herbalist_broth":
			dish_color = Color("#9d754f")
	draw_arc(Vector2(0.0, 3.0), 22.0, 0.0, PI, 24, Color("#f1ddae"), 8.0)
	draw_line(Vector2(-22.0, 3.0), Vector2(22.0, 3.0), Color("#6b4735"), 3.0)
	draw_circle(Vector2(-9.0, -5.0), 5.0, dish_color)
	draw_circle(Vector2(2.0, -9.0), 6.0, dish_color)
	draw_circle(Vector2(11.0, -3.0), 5.0, dish_color)
	draw_arc(Vector2(0.0, -2.0), 20.0, PI, TAU, 24, Color("#fff0b5"), 2.0)

func _draw_potion() -> void:
	var potion_color: Color = Color("#72d9e6")
	if item_id == "stamina_tonic":
		potion_color = Color("#d78ef3")
	elif item_id == "iron_brew":
		potion_color = Color("#a8866c")
	draw_rect(Rect2(-12.0, -3.0, 24.0, 25.0), potion_color, true)
	draw_rect(Rect2(-7.0, -17.0, 14.0, 15.0), Color("#d7edf2"), true)
	draw_rect(Rect2(-8.0, -20.0, 16.0, 5.0), Color("#8d5e3d"), true)
	draw_circle(Vector2(-5.0, 5.0), 3.0, Color(1.0, 1.0, 1.0, 0.4))

func _draw_sword() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, -27.0), Vector2(5.0, -27.0), Vector2(9.0, 12.0),
		Vector2(0.0, 23.0), Vector2(-9.0, 12.0)
	]), Color("#dceaf2"))
	draw_line(Vector2(-5.0, 11.0), Vector2(8.0, 11.0), Color("#e0a344"), 5.0)
	draw_line(Vector2(1.0, 12.0), Vector2(1.0, 24.0), Color("#7d492d"), 5.0)
	draw_circle(Vector2(1.0, 27.0), 4.0, Color("#e0a344"))

func _draw_shield() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-23.0, -19.0), Vector2(23.0, -19.0), Vector2(20.0, 10.0),
		Vector2(0.0, 27.0), Vector2(-20.0, 10.0)
	]), Color("#4776aa"))
	draw_polyline(PackedVector2Array([
		Vector2(-23.0, -19.0), Vector2(23.0, -19.0), Vector2(20.0, 10.0),
		Vector2(0.0, 27.0), Vector2(-20.0, 10.0), Vector2(-23.0, -19.0)
	]), Color("#d9b45b"), 3.0)
	draw_line(Vector2(0.0, -15.0), Vector2(0.0, 17.0), Color("#d9b45b"), 2.0)
	draw_line(Vector2(-13.0, 0.0), Vector2(13.0, 0.0), Color("#d9b45b"), 2.0)

func _draw_relic() -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var radius: float = 25.0 if i % 2 == 0 else 11.0
		var angle: float = -PI / 2.0 + float(i) * PI / 5.0
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	draw_colored_polygon(points, Color("#f5cf61"))
	var outline: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		outline.append(point)
	outline.append(points[0])
	draw_polyline(outline, Color("#fff2a8"), 2.0)

func _draw_material_fallback() -> void:
	draw_circle(Vector2(0.0, 0.0), 19.0, Color("#9cbe70"))
	draw_circle(Vector2(-6.0, -7.0), 5.0, Color("#e7f4a9"))
	draw_line(Vector2(0.0, 17.0), Vector2(0.0, 26.0), Color("#4e7b4a"), 3.0)

func draw_ellipse_leaf(center: Vector2, radius: float, color: Color) -> void:
	# A polygon avoids changing the parent draw transform mid-icon.
	var leaf_points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.35, -radius * 0.62),
		center + Vector2(radius * 0.75, -radius * 0.30),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.35, radius * 0.62),
		center + Vector2(-radius * 0.75, radius * 0.30)
	])
	draw_colored_polygon(leaf_points, color)
