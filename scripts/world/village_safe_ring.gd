class_name VillageSafeRing
extends Node2D

@export var ring_center: Vector2 = Vector2.ZERO
@export var ring_radius: float = 500.0

func _ready() -> void:
	z_as_relative = false
	z_index = 4
	set_process(false)
	queue_redraw()

func _draw() -> void:
	if ring_radius <= 0.0:
		return
	draw_arc(ring_center, ring_radius + 7.0, 0.0, TAU, 144, Color(0.62, 0.90, 0.48, 0.18), 12.0)
	draw_arc(ring_center, ring_radius, 0.0, TAU, 144, Color("#e2f28d"), 6.0)
	draw_arc(ring_center, ring_radius - 11.0, 0.0, TAU, 144, Color(0.35, 0.66, 0.40, 0.62), 2.0)

	for i in range(32):
		var angle: float = float(i) * TAU / 32.0
		var marker_position: Vector2 = ring_center + Vector2.RIGHT.rotated(angle) * (ring_radius + 3.0)
		draw_circle(marker_position, 3.5, Color("#f7df78"))

	# Four shield-like gate markers make the protected village boundary legible.
	var gate_angles: Array[float] = [0.0, PI / 2.0, PI, PI * 1.5]
	for angle: float in gate_angles:
		var gate_position: Vector2 = ring_center + Vector2.RIGHT.rotated(angle) * ring_radius
		draw_circle(gate_position, 8.0, Color("#a8d968"))
		draw_circle(gate_position, 4.0, Color("#f5e58a"))
