class_name QuestWaypointMarker
extends Node2D

## World-space waypoint shared by quest objectives and return-to-giver targets.
## The minimap still renders its own cached marker; this node gives the player a
## readable animated beacon when exploring the actual island.

var quest_system: QuestSystem = null
var waypoint_position: Vector2 = Vector2.ZERO
var waypoint_name: String = ""
var is_return_waypoint: bool = false
var has_waypoint: bool = false
var custom_waypoint: Dictionary = {}
var anim_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not EventBus.quest_accepted.is_connected(_on_quest_changed):
		EventBus.quest_accepted.connect(_on_quest_changed)
	if not EventBus.quest_completed.is_connected(_on_quest_changed):
		EventBus.quest_completed.connect(_on_quest_changed)
	if not EventBus.quest_updated.is_connected(_on_quest_changed):
		EventBus.quest_updated.connect(_on_quest_changed)
	call_deferred("_refresh_waypoint")

func set_custom_waypoint(position: Vector2, label: String, return_target: bool = false) -> void:
	custom_waypoint = {
		"position": position,
		"name": label,
		"is_return": return_target
	}
	_refresh_waypoint()

func clear_custom_waypoint() -> void:
	custom_waypoint.clear()
	_refresh_waypoint()

func _on_quest_changed(_quest_id: String) -> void:
	_refresh_waypoint()

func _refresh_waypoint() -> void:
	if not custom_waypoint.is_empty():
		_apply_waypoint(custom_waypoint)
		return
	if not is_instance_valid(quest_system):
		quest_system = get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if not is_instance_valid(quest_system):
		has_waypoint = false
		visible = false
		return
	var next_waypoint: Dictionary = quest_system.get_active_waypoint()
	if next_waypoint.is_empty():
		has_waypoint = false
		visible = false
		queue_redraw()
		return
	_apply_waypoint(next_waypoint)

func _apply_waypoint(waypoint: Dictionary) -> void:
	var raw_position: Variant = waypoint.get("position", Vector2.ZERO)
	if not (raw_position is Vector2):
		has_waypoint = false
		visible = false
		return
	waypoint_position = raw_position
	waypoint_name = str(waypoint.get("name", "Quest objective"))
	is_return_waypoint = bool(waypoint.get("is_return", false))
	global_position = waypoint_position
	has_waypoint = true
	visible = true
	queue_redraw()

func _process(delta: float) -> void:
	if not has_waypoint:
		return
	anim_time += delta
	queue_redraw()

func _draw() -> void:
	if not has_waypoint:
		return
	var pulse := (sin(anim_time * 4.0) + 1.0) * 0.5
	var marker_color := Color("#86efac") if is_return_waypoint else Color("#f6c84f")
	var dark := Color("#15202a")
	draw_circle(Vector2(0.0, 8.0), 28.0 + pulse * 7.0, Color(marker_color, 0.08))
	draw_arc(Vector2(0.0, 8.0), 22.0 + pulse * 4.0, 0.0, TAU, 32, Color(marker_color, 0.62), 2.0)
	draw_line(Vector2(0.0, 6.0), Vector2(0.0, -26.0 - pulse * 8.0), Color(marker_color, 0.38), 2.0)
	var outer := PackedVector2Array([
		Vector2(0.0, -42.0 - pulse * 5.0), Vector2(13.0, -29.0),
		Vector2(0.0, -16.0), Vector2(-13.0, -29.0)
	])
	var inner := PackedVector2Array([
		Vector2(0.0, -37.0 - pulse * 5.0), Vector2(7.0, -29.0),
		Vector2(0.0, -21.0), Vector2(-7.0, -29.0)
	])
	draw_colored_polygon(outer, dark)
	draw_colored_polygon(inner, marker_color)
	if waypoint_name.is_empty():
		return
	var player_value: Variant = GameManager.player
	if player_value is Node2D and is_instance_valid(player_value):
		if global_position.distance_squared_to((player_value as Node2D).global_position) > 1600000.0:
			return
	draw_string_outline(ThemeDB.fallback_font, Vector2(18.0, -29.0), waypoint_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, 4, Color("#101820"))
	draw_string(ThemeDB.fallback_font, Vector2(18.0, -29.0), waypoint_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, marker_color)
