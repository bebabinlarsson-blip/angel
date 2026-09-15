class_name InteriorEntry
extends Area2D

@export var interior_id: String = "interior"
@export var display_name: String = "Interior"
@export_file("*.tscn") var interior_scene_path: String = ""
@export var destination_spawn: Vector2 = Vector2(0, 180)

var prompt_label: Label = null
var _pulse: float = 0.0

func _ready() -> void:
    add_to_group("interior_entries")
    monitoring = true
    collision_layer = 1
    collision_mask = 1
    if get_node_or_null("CollisionShape2D") == null:
        var shape_node := CollisionShape2D.new()
        shape_node.name = "CollisionShape2D"
        var shape := CircleShape2D.new()
        shape.radius = 34.0
        shape_node.shape = shape
        add_child(shape_node)
    prompt_label = Label.new()
    prompt_label.name = "EntryPrompt"
    prompt_label.position = Vector2(-110, -72)
    prompt_label.custom_minimum_size = Vector2(220, 24)
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    prompt_label.add_theme_font_size_override("font_size", 10)
    prompt_label.add_theme_color_override("font_color", Color("#ffe39a"))
    prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
    prompt_label.add_theme_constant_override("outline_size", 3)
    prompt_label.visible = false
    add_child(prompt_label)
    z_index = 8
    queue_redraw()

func _process(delta: float) -> void:
    _pulse += delta
    var player := GameManager.player
    var near: bool = player != null and is_instance_valid(player) and player.global_position.distance_squared_to(global_position) <= 19600.0
    if prompt_label:
        prompt_label.visible = near and GameManager.current_state == GameManager.GameState.PLAYING
        prompt_label.text = "[F] Enter  %s" % display_name
    queue_redraw()

func interact(player: CharacterBody2D) -> void:
    if player == null or not is_instance_valid(player) or interior_scene_path.is_empty():
        return
    if GameManager.begin_interior_transfer(interior_scene_path, destination_spawn, player, _find_quest_system(), interior_id, display_name):
        EventBus.show_notification.emit("Entering %s" % display_name)

func _find_quest_system() -> Node:
    return get_tree().root.find_child("QuestSystem", true, false)

func _draw() -> void:
    var glow := 0.16 + (sin(_pulse * 3.0) + 1.0) * 0.05
    draw_circle(Vector2.ZERO, 38.0, Color(0.42, 0.85, 0.90, glow))
    draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 24, Color(0.60, 0.92, 0.94, 0.75), 2.0)
    draw_line(Vector2(-8, 2), Vector2(0, -6), Color("#ffe18a"), 2.0)
    draw_line(Vector2(0, -6), Vector2(8, 2), Color("#ffe18a"), 2.0)
