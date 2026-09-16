class_name DebugAnimal
extends CharacterBody2D

## Lightweight admin-only animal actor used by the debug spawner. It has no
## gameplay drops or combat logic; it simply wanders so the spawner is useful
## for testing populated areas without requiring a separate animal asset pack.

@export var species: String = "chicken"

var wander_direction := Vector2.ZERO
var wander_timer := 0.0

func _ready() -> void:
	add_to_group("animals")
	collision_layer = 0
	collision_mask = 0
	wander_timer = randf_range(0.5, 2.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.0, 3.0)
		wander_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if randf() < 0.35:
			wander_direction = Vector2.ZERO
	velocity = wander_direction * _speed()
	move_and_slide()
	queue_redraw()

func _speed() -> float:
	return 34.0 if species == "cow" else 52.0

func _draw() -> void:
	var body_color := Color("#f4eee0")
	var accent := Color("#d4a45c")
	var body_scale := Vector2(1.0, 0.7)
	match species:
		"cow":
			body_color = Color("#eee7d4")
			accent = Color("#6f4b3e")
			body_scale = Vector2(1.55, 0.86)
		"rabbit":
			body_color = Color("#d8d0df")
			accent = Color("#e8a1b2")
			body_scale = Vector2(0.82, 0.68)

	draw_set_transform(Vector2(0, 4), 0.0, body_scale)
	draw_circle(Vector2.ZERO, 10.0, body_color)
	draw_set_transform(Vector2.ZERO)
	draw_circle(Vector2(0, -6), 6.5, body_color)

	if species == "rabbit":
		draw_line(Vector2(-3, -10), Vector2(-5, -23), body_color, 4.0)
		draw_line(Vector2(3, -10), Vector2(5, -23), body_color, 4.0)
		draw_circle(Vector2(-2, -7), 1.2, Color("#302536"))
		draw_circle(Vector2(2, -7), 1.2, Color("#302536"))
	else:
		draw_circle(Vector2(-2, -7), 1.2, Color("#302536"))
		draw_circle(Vector2(2, -7), 1.2, Color("#302536"))
		draw_circle(Vector2(0, -3), 2.2, accent)
		if species == "chicken":
			draw_line(Vector2(0, -12), Vector2(0, -18), accent, 2.0)

	if species == "cow":
		draw_circle(Vector2(-5, 5), 3.0, accent)
		draw_circle(Vector2(5, 3), 3.0, accent)
