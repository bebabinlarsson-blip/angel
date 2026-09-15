class_name WaypointVisual
extends Node2D

var _clock: float = 0.0
var _waystone: Waystone = null

func _ready() -> void:
    add_to_group("waypoint_visuals")
    _waystone = get_parent() as Waystone
    z_index = 3
    process_mode = Node.PROCESS_MODE_ALWAYS
    queue_redraw()

func _process(delta: float) -> void:
    _clock += delta
    if _clock >= 0.12:
        _clock = 0.0
        queue_redraw()

func _draw() -> void:
    var unlocked := _waystone != null and _waystone.is_unlocked
    var gem := Color("#4ef3e6") if unlocked else Color("#77848b")
    var pulse := 1.0 + sin(_clock * 4.0) * 0.10
    draw_circle(Vector2(0, 3), 28.0 * pulse, Color(gem, 0.08 if unlocked else 0.04))
    draw_arc(Vector2(0, 3), 24.0 * pulse, 0.0, TAU, 24, Color(gem, 0.55 if unlocked else 0.25), 2.0)
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, -34), Vector2(16, -8), Vector2(10, 27), Vector2(-10, 27), Vector2(-16, -8)
    ]), Color("#26313b"))
    draw_colored_polygon(PackedVector2Array([
        Vector2(0, -27), Vector2(9, -7), Vector2(6, 20), Vector2(-6, 20), Vector2(-9, -7)
    ]), gem)
    draw_line(Vector2(-5, -12), Vector2(0, -20), Color("#d9ffff"), 2.0)
    draw_line(Vector2(0, -20), Vector2(5, -12), Color("#d9ffff"), 2.0)
