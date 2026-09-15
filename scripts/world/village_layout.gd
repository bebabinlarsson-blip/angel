class_name VillageLayout
extends Node2D

## Lightweight, procedural village dressing. It sits above the authored ground
## layer and below characters, so roads and civic landmarks remain readable as
## the camera moves while the existing tile art stays the source of truth.

var village_center: Vector2 = Vector2.ZERO
var safe_radius: float = 500.0
var _clock: float = 0.0

const ROAD_EDGE := Color("#4b3a32")
const ROAD_FILL := Color("#b98b5d")
const ROAD_HIGHLIGHT := Color("#d8b57d")
const STONE := Color("#6f6a65")
const STONE_LIGHT := Color("#a89b88")
const ROOF := Color("#9d4f45")
const WOOD := Color("#694a35")
const WATER := Color("#58c9d0")

func _ready() -> void:
    z_index = -88
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group("village_layout")
    queue_redraw()

func configure(center: Vector2, radius: float) -> void:
    village_center = center
    safe_radius = radius
    queue_redraw()

func _process(delta: float) -> void:
    _clock += delta
    if _clock >= 0.18:
        _clock = 0.0
        queue_redraw()

func _road(points: PackedVector2Array) -> void:
    draw_polyline(points, ROAD_EDGE, 62.0, true)
    draw_polyline(points, ROAD_FILL, 48.0, true)
    draw_polyline(points, ROAD_HIGHLIGHT, 3.0, true)

func _draw_house(center: Vector2, tint: Color = Color("#d1a267")) -> void:
    draw_rect(Rect2(center + Vector2(-46, -28), Vector2(92, 56)), Color("#2a2528"))
    draw_rect(Rect2(center + Vector2(-41, -24), Vector2(82, 50)), tint)
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-52, -23), center + Vector2(0, -60), center + Vector2(52, -23)
    ]), ROOF)
    draw_rect(Rect2(center + Vector2(-10, 2), Vector2(20, 24)), WOOD)
    draw_rect(Rect2(center + Vector2(-30, -10), Vector2(15, 14)), WATER.darkened(0.25))
    draw_rect(Rect2(center + Vector2(15, -10), Vector2(15, 14)), WATER.darkened(0.25))

func _draw_stall(center: Vector2, accent: Color) -> void:
    draw_rect(Rect2(center + Vector2(-34, -15), Vector2(68, 30)), Color("#2a2528"))
    draw_rect(Rect2(center + Vector2(-30, -12), Vector2(60, 24)), WOOD)
    draw_colored_polygon(PackedVector2Array([
        center + Vector2(-38, -12), center + Vector2(0, -34), center + Vector2(38, -12)
    ]), accent)
    draw_circle(center + Vector2(-15, 2), 4.0, Color("#eac45c"))
    draw_circle(center + Vector2(0, 2), 4.0, Color("#8fd36a"))
    draw_circle(center + Vector2(15, 2), 4.0, Color("#e98c6d"))

func _draw_lamp(pos: Vector2) -> void:
    draw_line(pos + Vector2(0, 16), pos + Vector2(0, -14), WOOD, 5.0)
    draw_circle(pos + Vector2(0, -19), 8.0, Color(1.0, 0.80, 0.35, 0.14))
    draw_circle(pos + Vector2(0, -19), 4.0, Color("#ffe18a"))

func _draw() -> void:
    # A small road network connects each cardinal approach to a readable plaza.
    _road(PackedVector2Array([
        village_center + Vector2(-1040, 360), village_center + Vector2(-520, 240),
        village_center + Vector2(-180, 72), village_center + Vector2(0, 0)
    ]))
    _road(PackedVector2Array([
        village_center + Vector2(1040, 300), village_center + Vector2(520, 210),
        village_center + Vector2(180, 72), village_center + Vector2(0, 0)
    ]))
    _road(PackedVector2Array([
        village_center + Vector2(-220, -1040), village_center + Vector2(-150, -520),
        village_center + Vector2(-72, -180), village_center + Vector2(0, 0)
    ]))
    _road(PackedVector2Array([
        village_center + Vector2(260, 1040), village_center + Vector2(170, 520),
        village_center + Vector2(72, 180), village_center + Vector2(0, 0)
    ]))

    # Civic plaza and fountain, kept clear of the cooking hearth at the square.
    draw_circle(village_center + Vector2(0, -220), 86.0, Color("#3a3535"))
    draw_circle(village_center + Vector2(0, -220), 76.0, STONE_LIGHT)
    draw_circle(village_center + Vector2(0, -220), 58.0, Color("#4b9aa4"))
    draw_circle(village_center + Vector2(0, -220), 44.0, Color("#63cbd0"))
    var fountain_pulse := 2.0 + sin(_clock * 5.0) * 1.5
    draw_line(village_center + Vector2(0, -220), village_center + Vector2(0, -258 - fountain_pulse), WATER, 5.0)
    draw_circle(village_center + Vector2(0, -262 - fountain_pulse), 5.0, Color("#d7ffff"))

    # Four small homes and two market stalls make the safe ring legible without
    # adding physics bodies or per-frame processing to the village.
    _draw_house(village_center + Vector2(-270, -90))
    _draw_house(village_center + Vector2(260, -70), Color("#c78f66"))
    _draw_house(village_center + Vector2(-260, 220), Color("#c2a06f"))
    _draw_house(village_center + Vector2(250, 230), Color("#b98f70"))
    _draw_stall(village_center + Vector2(-112, -50), Color("#bd684d"))
    _draw_stall(village_center + Vector2(112, -50), Color("#4e8d89"))

    for lamp_pos in [Vector2(-180, -160), Vector2(180, -160), Vector2(-190, 160), Vector2(190, 160)]:
        _draw_lamp(village_center + lamp_pos)

    # Short fence sections visually reinforce the boundary while the world and
    # monster systems enforce the safe-zone and hostile-spawn rules.
    for side in [-1.0, 1.0]:
        var fence_y: float = village_center.y + float(side) * 410.0
        draw_line(Vector2(village_center.x - 260.0, fence_y), Vector2(village_center.x - 80.0, fence_y), WOOD, 5.0)
        draw_line(Vector2(village_center.x + 80.0, fence_y), Vector2(village_center.x + 260.0, fence_y), WOOD, 5.0)
        for x in [-250.0, -160.0, -90.0, 90.0, 160.0, 250.0]:
            draw_line(Vector2(village_center.x + x, fence_y - 10.0), Vector2(village_center.x + x, fence_y + 10.0), WOOD, 4.0)
