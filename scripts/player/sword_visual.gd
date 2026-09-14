class_name SwordVisual
extends Node2D

## Procedural sword with a readable slash arc, charged glow, and a hit flash.
## It keeps combat expressive without requiring another texture pack.

var swinging: bool = false
var charged: bool = false
var hit_confirmed: bool = false
var pulse: float = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var charge_color := Color("#ffd45c") if charged else Color("#d9e6e8")
	var reach := 29.0 if not swinging else 36.0 + sin(pulse * 18.0) * 3.0
	var lift := -4.0 if not swinging else -8.0

	if charged:
		var glow := (sin(pulse * 8.0) + 1.0) * 0.5
		draw_circle(Vector2(18, -2), 20.0 + glow * 5.0, Color(1.0, 0.72, 0.22, 0.10))
	if swinging:
		var slash_color := Color("#fff1a3") if not charged else Color("#ffb84c")
		draw_arc(Vector2(7, 0), reach + 3.0, -1.05, 1.05, 20, Color(slash_color.r, slash_color.g, slash_color.b, 0.50), 4.0)
		draw_arc(Vector2(7, 0), reach + 8.0, -0.82, 0.82, 16, Color(slash_color.r, slash_color.g, slash_color.b, 0.18), 3.0)
	if hit_confirmed:
		draw_circle(Vector2(reach, lift), 7.0, Color(1.0, 0.95, 0.55, 0.82))

	draw_line(Vector2(7, 4), Vector2(reach, lift + 4), Color(0, 0, 0, 0.35), 7.0)
	draw_line(Vector2(7, 0), Vector2(reach, lift), charge_color, 5.0)
	draw_line(Vector2(9, -1), Vector2(reach - 3, lift - 1), Color("#ffffff"), 2.0)
	draw_line(Vector2(5, -7), Vector2(5, 7), Color("#d9a944"), 4.0)
	draw_line(Vector2(0, 0), Vector2(7, 0), Color("#633a28"), 5.0)
	draw_circle(Vector2(-2, 0), 3.0, Color("#e0b951"))
