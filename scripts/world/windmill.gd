extends StaticBody2D

var blade_angle: float = 0.0

func _ready() -> void:
	add_to_group("windmills")
	var collision := CollisionShape2D.new()
	collision.name = "TowerFootprint"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 28)
	collision.shape = shape
	collision.position = Vector2(0, -10)
	add_child(collision)

func _process(delta: float) -> void:
	blade_angle = fposmod(blade_angle + delta * 0.45, TAU)
	queue_redraw()

func _draw() -> void:
	draw_set_transform(Vector2(0, 3), 0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, 42, Color(0.12, 0.18, 0.12, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([Vector2(-28, 0), Vector2(-19, -96), Vector2(19, -96), Vector2(28, 0)]), Color("#cbb993"))
	draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(10, -96), Vector2(19, -96), Vector2(28, 0)]), Color("#a79576"))
	for y in range(-84, 0, 16):
		draw_line(Vector2(-20, y), Vector2(20, y), Color("#ac9e80"), 2)
	draw_colored_polygon(PackedVector2Array([Vector2(-28, -94), Vector2(0, -119), Vector2(28, -94)]), Color("#854b3a"))
	draw_rect(Rect2(-9, -24, 18, 24), Color("#554631"))
	draw_rect(Rect2(-5, -69, 10, 16), Color("#384951"))
	draw_line(Vector2(-7, -61), Vector2(7, -61), Color("#d6c69d"), 2)
	for i in range(4):
		draw_set_transform(Vector2(0, -83), blade_angle + i * PI * 0.5)
		draw_rect(Rect2(0, -3, 63, 6), Color("#62513b"))
		draw_rect(Rect2(20, -17, 39, 14), Color("#ece0bd"))
		for x in range(22, 60, 8):
			draw_line(Vector2(x, -17), Vector2(x, -3), Color("#a69978"), 1)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, -83), 7, Color("#62513b"))
	draw_circle(Vector2(0, -83), 3, Color("#bca777"))
