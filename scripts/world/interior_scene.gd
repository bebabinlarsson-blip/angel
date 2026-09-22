class_name InteriorScene
extends Node2D

@export var interior_id: String = "interior"
@export var display_name: String = "Interior"
@export var theme_kind: String = "house"
@export var room_size: Vector2 = Vector2(960, 640)

@onready var player: CharacterBody2D = get_node_or_null("Player") as CharacterBody2D
@onready var quest_system: QuestSystem = get_node_or_null("QuestSystem") as QuestSystem

func _ready() -> void:
    add_to_group("interior_scenes")
    # A scene launched directly by the editor has no transfer snapshot. Give
    # it the same location state as a normal doorway transition so save/exit
    # behavior remains deterministic in smoke tests and standalone previews.
    var gm := get_node_or_null("/root/GameManager")
    if gm:
        if not gm.get("is_interior"):
            gm.set("is_interior", true)
            gm.set("current_interior_id", interior_id)
            gm.set("current_location_name", display_name)
        get_tree().paused = false
        if gm.has_method("set_state"):
            gm.set_state(gm.GameState.PLAYING)
        if gm.has_method("consume_quest_transfer"):
            gm.consume_quest_transfer(quest_system)
    _ensure_room_bounds()
    if theme_kind == "mine":
        _ensure_mine_rocks()
    _setup_camera()
    var hud := get_node_or_null("HUD")
    if hud and hud.has_method("set_interior_context"):
        hud.call("set_interior_context", display_name)
    var bus := get_node_or_null("/root/EventBus")
    if bus and bus.has_signal("show_notification"):
        bus.show_notification.emit(display_name + "  ·  Explore safely")

func _ensure_room_bounds() -> void:
    var walls := get_node_or_null("RoomBounds") as Node2D
    if walls != null:
        return
    walls = Node2D.new()
    walls.name = "RoomBounds"
    add_child(walls)
    var thickness := 48.0
    var half := room_size * 0.5
    var wall_data := [
        {"name": "North", "position": Vector2(0, -half.y - thickness * 0.5), "size": Vector2(room_size.x + thickness * 2.0, thickness)},
        {"name": "South", "position": Vector2(0, half.y + thickness * 0.5), "size": Vector2(room_size.x + thickness * 2.0, thickness)},
        {"name": "West", "position": Vector2(-half.x - thickness * 0.5, 0), "size": Vector2(thickness, room_size.y)},
        {"name": "East", "position": Vector2(half.x + thickness * 0.5, 0), "size": Vector2(thickness, room_size.y)},
    ]
    for data: Dictionary in wall_data:
        var body := StaticBody2D.new()
        body.name = data["name"]
        body.position = data["position"]
        var collision := CollisionShape2D.new()
        var shape := RectangleShape2D.new()
        shape.size = data["size"]
        collision.shape = shape
        body.add_child(collision)
        walls.add_child(body)

func _ensure_mine_rocks() -> void:
    # Mining spots are authored StaticBody2D nodes in mine.tscn. Keeping this
    # check makes a malformed/minimal test scene obvious without silently
    # placing gameplay objects at runtime.
    if get_node_or_null("InteriorMining") == null:
        push_warning("MineInterior: no authored InteriorMining nodes found.")

func _setup_camera() -> void:
    if player == null or not is_instance_valid(player.camera):
        return
    var half := room_size * 0.5
    player.camera.limit_left = int(-half.x - 80.0)
    player.camera.limit_top = int(-half.y - 80.0)
    player.camera.limit_right = int(half.x + 80.0)
    player.camera.limit_bottom = int(half.y + 80.0)
    player.camera.reset_smoothing()
