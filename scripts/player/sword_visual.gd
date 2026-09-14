class_name SwordVisual
extends Node2D

## Small procedural sword attached to the player. It makes the equipped
## weapon visible during exploration and gives attacks a readable silhouette.

var swinging: bool = false
var pulse: float = 0.0

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var reach := 29.0 if not swinging else 36.0 + sin(pulse * 18.0) * 3.0
	var lift := -4.0 if not swinging else -8.0
	# shadow and blade
	draw_line(Vector2(7, 4), Vector2(reach, lift + 4), Color(0, 0, 0, 0.35), 7.0)
	draw_line(Vector2(7, 0), Vector2(reach, lift), Color("#d9e6e8"), 5.0)
	draw_line(Vector2(9, -1), Vector2(reach - 3, lift - 1), Color("#ffffff"), 2.0)
	# guard, grip and pommel
	draw_line(Vector2(5, -7), Vector2(5, 7), Color("#d9a944"), 4.0)
	draw_line(Vector2(0, 0), Vector2(7, 0), Color("#633a28"), 5.0)
	draw_circle(Vector2(-2, 0), 3.0, Color("#e0b951"))
