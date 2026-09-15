class_name QuestTracker
extends Control

var _refresh_timer: float = 0.0
var _quest_system: QuestSystem = null
var _interior_context: bool = false

const PANEL_SIZE := Vector2(340.0, 118.0)
const PANEL_BG := Color(0.035, 0.07, 0.10, 0.90)
const PANEL_EDGE := Color("#6e8790")
const TEXT := Color("#edf3ef")
const MUTED := Color("#a8c0c5")
const GOLD := Color("#ffd36a")
const PINK := Color("#ef8ac7")

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = PANEL_SIZE
    size = PANEL_SIZE
    _connect_once(EventBus.quest_accepted, _on_quest_changed)
    _connect_once(EventBus.quest_updated, _on_quest_changed)
    _connect_once(EventBus.quest_completed, _on_quest_changed)
    queue_redraw()

func set_interior_context(active: bool) -> void:
    _interior_context = active
    queue_redraw()

func refresh_now() -> void:
    _refresh_timer = 0.0
    queue_redraw()

func _process(delta: float) -> void:
    _refresh_timer -= delta
    if _refresh_timer > 0.0:
        return
    _refresh_timer = 0.18
    var hud := get_parent()
    if hud and hud.get("big_map") is Control and (hud.get("big_map") as Control).visible:
        visible = false
        return
    _quest_system = get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
    var has_quest := _quest_system != null and not _quest_system.get_active_quest_id().is_empty()
    visible = has_quest
    queue_redraw()

func _on_quest_changed(_quest_id: String = "") -> void:
    _refresh_timer = 0.0
    queue_redraw()

func _connect_once(signal_value: Signal, handler: Callable) -> void:
    if not signal_value.is_connected(handler):
        signal_value.connect(handler)

func _shorten(value: String, max_length: int) -> String:
    if value.length() <= max_length:
        return value
    return value.substr(0, maxi(1, max_length - 3)) + "..."

func _text(text_position: Vector2, value: String, font_size: int, color: Color, max_width: float = -1.0) -> void:
    draw_string_outline(ThemeDB.fallback_font, text_position, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, 3, Color(0.01, 0.02, 0.03, 0.95))
    draw_string(ThemeDB.fallback_font, text_position, value, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size, color)

func _draw_direction_arrow(center: Vector2, direction: Vector2, color: Color) -> void:
    draw_circle(center, 19.0, Color("#16242d"))
    draw_arc(center, 19.0, 0.0, TAU, 24, color, 2.0)
    var normalized := direction.normalized() if direction.length_squared() > 0.001 else Vector2.UP
    var side := normalized.orthogonal() * 7.0
    draw_colored_polygon(PackedVector2Array([
        center + normalized * 13.0,
        center - normalized * 8.0 + side,
        center - normalized * 8.0 - side,
    ]), color)

func _draw() -> void:
    if _quest_system == null:
        return
    var quest := _quest_system.get_active_quest()
    if quest.is_empty():
        return
    draw_rect(Rect2(Vector2.ZERO, PANEL_SIZE), PANEL_BG)
    draw_rect(Rect2(Vector2.ZERO, PANEL_SIZE), PANEL_EDGE, false, 1.5)
    draw_line(Vector2(12, 28), Vector2(PANEL_SIZE.x - 12, 28), Color("#334851"), 1.0)
    _text(Vector2(12, 19), "ACTIVE QUEST", 11, GOLD)
    _text(Vector2(12, 51), _shorten(str(quest.get("title", "Quest")), 31), 17, TEXT, 255.0)
    var current := int(quest.get("current_count", 0))
    var required := maxi(1, int(quest.get("target_count", 1)))
    var complete := current >= required
    var objective := str(quest.get("objective", "Track your objective"))
    _text(Vector2(12, 70), _shorten(objective, 43), 11, MUTED, 300.0)
    var bar_rect := Rect2(12, 82, 250, 11)
    draw_rect(bar_rect, Color("#1c2b32"))
    draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clampf(float(current) / float(required), 0.0, 1.0), bar_rect.size.y)), GOLD if complete else PINK)
    _text(Vector2(12, 108), "%d / %d" % [current, required], 11, TEXT)

    if _interior_context:
        _text(Vector2(278, 91), "Inside", 11, MUTED)
        return

    var waypoint: Dictionary = _quest_system.get_active_waypoint()
    var target_value: Variant = waypoint.get("position", Vector2.ZERO)
    var waypoint_valid := bool(waypoint.get("valid", false))
    if not waypoint.has("valid"):
        waypoint_valid = target_value is Vector2 and target_value != Vector2.ZERO
    if target_value is Vector2 and waypoint_valid and is_instance_valid(GameManager.player):
        var target_position: Vector2 = target_value
        var direction := target_position - GameManager.player.global_position
        _draw_direction_arrow(Vector2(303, 47), direction, GOLD if complete else PINK)
        var distance := int(round(direction.length() / 32.0))
        _text(Vector2(278, 91), "%d m" % distance, 11, MUTED)
