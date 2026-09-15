class_name InteriorExit
extends Area2D

@export var return_label: String = "Return to Angel Island"
var prompt_label: Label = null
var _pulse: float = 0.0

func _ready() -> void:
    add_to_group("interior_exits")
    monitoring = true
    collision_layer = 1
    collision_mask = 1
    if get_node_or_null("CollisionShape2D") == null:
        var shape_node := CollisionShape2D.new()
        shape_node.name = "CollisionShape2D"
        var shape := CircleShape2D.new()
        shape.radius = 36.0
        shape_node.shape = shape
        add_child(shape_node)
    prompt_label = Label.new()
    prompt_label.name = "ExitPrompt"
    prompt_label.position = Vector2(-130, -76)
    prompt_label.custom_minimum_size = Vector2(260, 24)
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
    var near: bool = player != null and is_instance_valid(player) and player.global_position.distance_squared_to(global_position) <= 22500.0
    if prompt_label:
        prompt_label.visible = near and GameManager.current_state == GameManager.GameState.PLAYING
        prompt_label.text = "[F] " + return_label
    queue_redraw()

func interact(player: CharacterBody2D) -> void:
    var source_player: CharacterBody2D = player
    if source_player == null or not is_instance_valid(source_player):
        source_player = GameManager.player if is_instance_valid(GameManager.player) else null
    if source_player == null or not is_instance_valid(source_player):
        return
    var root := get_tree().current_scene
    var quest_system := root.get_node_or_null("QuestSystem") if root else null
    if GameManager.exit_interior(source_player, quest_system):
        EventBus.show_notification.emit("Returning to Angel Island")

func _draw() -> void:
    var glow := 0.14 + (sin(_pulse * 3.0) + 1.0) * 0.06
    draw_circle(Vector2.ZERO, 40.0, Color(0.98, 0.75, 0.32, glow))
    draw_rect(Rect2(-30, -34, 60, 68), Color("#252631"))
    draw_rect(Rect2(-24, -28, 48, 62), Color("#8b6a4a"))
    draw_rect(Rect2(-13, 0, 26, 34), Color("#182734"))
    draw_line(Vector2(-16, -10), Vector2(16, -10), Color("#ffd979"), 3.0)
