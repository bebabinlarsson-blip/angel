class_name InteriorVisual
extends Node2D

@export var theme_kind: String = "house"
@export var room_size: Vector2 = Vector2(960, 640)
var _clock: float = 0.0

func _ready() -> void:
    z_index = -20
    process_mode = Node.PROCESS_MODE_ALWAYS
    queue_redraw()

func _process(delta: float) -> void:
    _clock += delta
    if _clock >= 0.2:
        _clock = 0.0
        queue_redraw()

func _draw_floor(base: Color, alternate: Color) -> void:
    var rect := Rect2(-room_size * 0.5, room_size)
    draw_rect(rect.grow(28.0), Color("#171b24"))
    draw_rect(rect, base)
    var tile := 48.0
    var columns := int(ceil(room_size.x / tile))
    var rows := int(ceil(room_size.y / tile))
    for y in range(rows):
        for x in range(columns):
            if (x + y) % 2 == 0:
                var p := Vector2(rect.position.x + x * tile, rect.position.y + y * tile)
                draw_rect(Rect2(p, Vector2(tile - 2, tile - 2)), alternate)
    draw_rect(rect, Color("#d2b27b"), false, 6.0)

func _draw_mine() -> void:
    _draw_floor(Color("#3b3840"), Color("#443e46"))
    for x in [-330.0, 330.0]:
        draw_rect(Rect2(x - 18, -210, 36, 420), Color("#574038"))
        draw_line(Vector2(x - 14, -210), Vector2(x - 14, 210), Color("#8a6146"), 5.0)
        draw_line(Vector2(x + 14, -210), Vector2(x + 14, 210), Color("#2a2528"), 5.0)
    for ore_pos in [Vector2(-370, -235), Vector2(370, -160), Vector2(-370, 170), Vector2(370, 240)]:
        draw_circle(ore_pos, 20.0, Color("#172833"))
        draw_colored_polygon(PackedVector2Array([
            ore_pos + Vector2(-15, 8), ore_pos + Vector2(-9, -14), ore_pos + Vector2(6, -22),
            ore_pos + Vector2(18, -4), ore_pos + Vector2(12, 16), ore_pos + Vector2(-8, 20)
        ]), Color("#6cc8d8"))
    draw_rect(Rect2(-170, 110, 340, 18), Color("#5a3d2c"))
    draw_circle(Vector2(-158, 119), 24.0, Color("#25252a"), false, 7.0)
    draw_circle(Vector2(158, 119), 24.0, Color("#25252a"), false, 7.0)
    _draw_torch(Vector2(-420, -80))
    _draw_torch(Vector2(420, -80))

func _draw_torch(pos: Vector2) -> void:
    draw_line(pos + Vector2(0, 18), pos + Vector2(0, -8), Color("#68452f"), 6.0)
    draw_circle(pos + Vector2(0, -16), 11.0, Color(1.0, 0.60, 0.25, 0.16))
    draw_circle(pos + Vector2(0, -16), 5.0 + sin(_clock * 6.0) * 1.0, Color("#ffd879"))

func _draw_church() -> void:
    _draw_floor(Color("#4b4853"), Color("#554f5c"))
    draw_rect(Rect2(-250, -250, 500, 130), Color("#6b3e52"))
    draw_circle(Vector2(0, -185), 46.0, Color("#66c9d0"))
    draw_circle(Vector2(0, -185), 34.0, Color("#bce9de"), false, 6.0)
    for row in range(3):
        var y := -75.0 + row * 85.0
        for x in [-190.0, -70.0, 70.0, 190.0]:
            draw_rect(Rect2(x - 35, y - 12, 70, 24), Color("#4c332c"))
            draw_line(Vector2(x, y - 12), Vector2(x, y + 12), Color("#926448"), 3.0)
    draw_rect(Rect2(-72, -235, 144, 70), Color("#4d312c"))
    draw_rect(Rect2(-55, -222, 110, 46), Color("#a96b56"))
    draw_line(Vector2(0, -215), Vector2(0, -178), Color("#f0d59d"), 5.0)
    draw_line(Vector2(-14, -204), Vector2(14, -204), Color("#f0d59d"), 5.0)
    _draw_torch(Vector2(-410, -170))
    _draw_torch(Vector2(410, -170))

func _draw_house() -> void:
    _draw_floor(Color("#73563f"), Color("#806249"))
    draw_rect(Rect2(-150, -105, 300, 210), Color("#ab7b53"))
    draw_rect(Rect2(-120, -75, 240, 150), Color("#c59a68"))
    draw_circle(Vector2(-250, -160), 48.0, Color("#2a2428"))
    draw_circle(Vector2(-250, -160), 35.0, Color("#e9824f"))
    draw_rect(Rect2(-330, 120, 180, 42), Color("#4b312d"))
    draw_rect(Rect2(150, 120, 180, 42), Color("#4b312d"))
    draw_circle(Vector2(0, 0), 72.0, Color("#a57a58"), false, 5.0)
    draw_circle(Vector2(0, 0), 52.0, Color("#c99c6b"), false, 3.0)

func _draw() -> void:
    match theme_kind:
        "mine": _draw_mine()
        "church": _draw_church()
        _: _draw_house()
