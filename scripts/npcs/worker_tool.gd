class_name WorkerTool
extends Node2D

@export var job: String = "idle"
var active: bool = false
var motion: float = 0.0

func _ready() -> void:
	# The tool is dormant outside the work phase; do not redraw ten idle tools.
	set_process(false)

func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	motion = 0.0
	if not active:
		rotation = 0.0
	set_process(active)
	queue_redraw()

func _process(delta: float) -> void:
	motion += delta * 7.0
	rotation = sin(motion) * 0.18
	queue_redraw()

func _draw() -> void:
	if not active or job == "idle":
		return
	var tool_color := Color("#85512f")
	var metal := Color("#c7d1d2")
	match job:
		"farmer":
			draw_line(Vector2(2, 2), Vector2(18, -16), tool_color, 3.0)
			draw_line(Vector2(13, -17), Vector2(24, -14), metal, 3.0)
		"carpenter", "builder":
			draw_line(Vector2(2, 1), Vector2(17, -13), tool_color, 4.0)
			draw_rect(Rect2(13, -19, 10, 6), metal)
		"miner":
			draw_line(Vector2(2, 1), Vector2(18, -15), tool_color, 4.0)
			draw_line(Vector2(13, -18), Vector2(23, -12), metal, 3.0)
		"blacksmith":
			draw_line(Vector2(2, 2), Vector2(17, -14), tool_color, 4.0)
			draw_rect(Rect2(12, -20, 11, 6), metal)
			draw_line(Vector2(8, 5), Vector2(24, 5), Color("#6f7a80"), 4.0)
		"fisher":
			draw_line(Vector2(1, 1), Vector2(18, -22), tool_color, 2.0)
			draw_arc(Vector2(18, -22), 5.0, 0.0, PI, 8, Color("#dcecf1"), 1.5)
		"merchant", "herbalist":
			draw_circle(Vector2(14, -8), 6.0, Color("#d87d4a"))
			draw_line(Vector2(2, 2), Vector2(12, -5), tool_color, 3.0)
		_:
			draw_line(Vector2(2, 1), Vector2(17, -14), tool_color, 3.0)
