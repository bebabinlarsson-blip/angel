class_name InteriorEntry
extends Area2D

@export var interior_id: String = "interior"
@export var display_name: String = "Interior"
@export_file("*.tscn") var interior_scene_path: String = ""
@export var destination_spawn: Vector2 = Vector2(0, 180)
@export_group("Authored Door Link")
@export var linked_layer_name: String = "HouseLayer"
@export var linked_house_id: String = ""

var prompt_label: Label = null
var _pulse: float = 0.0
var _redraw_timer: float = 0.0
var _near_player: bool = false

func _ready() -> void:
    add_to_group("interior_entries")
    add_to_group("authored_door_entrances")
    set_meta("linked_layer_name", linked_layer_name)
    set_meta("linked_house_id", linked_house_id)
    set_meta("door_anchor", "This node origin is the authored door center; ring and collision share it.")
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
    z_as_relative = false
    call_deferred("_attach_to_authored_layer")
    queue_redraw()

func _process(delta: float) -> void:
    var player := GameManager.player
    var near: bool = player != null and is_instance_valid(player) and player.global_position.distance_squared_to(global_position) <= 19600.0
    var prompt_should_show := near and GameManager.current_state == GameManager.GameState.PLAYING
    if prompt_label:
        if prompt_label.visible != prompt_should_show:
            prompt_label.visible = prompt_should_show
        if prompt_label.text.is_empty():
            prompt_label.text = "[F] Enter  %s" % display_name

    # Door rings retain their authored look, but distant entrances do not
    # rebuild their draw command every frame. Nearby doors keep a smooth 30 Hz
    # pulse, which is visually indistinguishable from a full-frame pulse.
    if near:
        _pulse += delta
        _redraw_timer -= delta
        if _redraw_timer <= 0.0:
            _redraw_timer = 1.0 / 30.0
            queue_redraw()
    elif _near_player:
        queue_redraw()
    _near_player = near

func _attach_to_authored_layer() -> void:
    if linked_layer_name.is_empty() or not is_inside_tree():
        return
    var world := _find_world_node()
    if world == null:
        return
    var layer := _find_linked_layer(world)
    if layer == null or get_parent() == layer:
        return

    # Keep the exact authored world-space door position while making the
    # trigger/ring a child of the layer that owns the visible house or cave.
    # The registry node in interior_entries.tscn remains as a compatibility
    # anchor for minimal scenes and legacy fallback creation.
    var authored_position := global_position
    reparent(layer, true)
    global_position = authored_position
    z_as_relative = false
    z_index = 8
    set_meta("authored_layer_path", str(layer.get_path()))
    queue_redraw()

func _find_world_node() -> Node:
    var scene_root := get_tree().current_scene
    if scene_root != null:
        var world := scene_root.get_node_or_null("World")
        if world != null:
            return world
    return get_tree().root.find_child("World", true, false)

func _find_linked_layer(world: Node) -> TileMapLayer:
    var candidates: Array[String] = [linked_layer_name]
    if linked_layer_name == "HouseLayer":
        candidates.append("BuildingLayer")
    elif linked_layer_name == "RoadLayer":
        candidates.append("PathLayer")
    var authored_root := world.get_node_or_null("AuthoredEnvironment")
    if authored_root != null:
        for candidate: String in candidates:
            var authored_layer := authored_root.get_node_or_null(candidate) as TileMapLayer
            if authored_layer != null:
                return authored_layer
    for candidate: String in candidates:
        var direct_layer := world.get_node_or_null(candidate) as TileMapLayer
        if direct_layer != null:
            return direct_layer
    return null

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
