class_name ResourceNode
extends Area2D

## Collectable ground material. Its visible icon is taken from the shared
## environment TileSet; this script only owns pickup, respawn and feedback.

const ENVIRONMENT_TILESET = preload("res://assets/tilesets/angel_environment_tileset.tres")
const RESOURCE_TILE_SOURCES := {
    "wood": 21,
    "herb": 22,
    "fiber": 22,
    "mint": 22,
    "lavender": 22,
    "moon_petal": 22,
    "mushroom": 23,
    "iron_ore": 24,
    "gold_ore": 24,
    "coal": 24,
    "stone": 25,
    "crystal": 25,
    "sunstone": 25,
    "ancient_shard": 25,
    "flower": 26,
    "clover": 26,
    "rose": 26,
}

@export var item_id: String = "wood"
@export var item_name: String = "Wood"
@export var quantity: int = 1
@export var item_type: int = 0
@export var respawn_time: float = 75.0
@export var respawn_enabled: bool = true
@export var pickup_radius: float = 64.0
@export var pickup_hint_radius: float = 124.0

var is_collected: bool = false
var respawn_timer: float = 0.0
var bob_time: float = 0.0
var redraw_timer: float = 0.0
var proximity_timer: float = 0.0
var visibility_timer: float = 0.0
var near_player: bool = false
var camera_visible: bool = false
var collision: CollisionShape2D = null
var visual: Sprite2D = null
var pickup_label: Label = null

func _ready() -> void:
    add_to_group("resource_nodes")
    add_to_group("collectables")
    body_entered.connect(_on_body_entered)
    collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision == null:
        collision = CollisionShape2D.new()
        collision.name = "CollisionShape2D"
        var shape := CircleShape2D.new()
        shape.radius = 18.0
        collision.shape = shape
        add_child(collision)

    visual = get_node_or_null("MaterialTile") as Sprite2D
    if visual == null:
        visual = Sprite2D.new()
        visual.name = "MaterialTile"
        visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        add_child(visual)
    _apply_environment_tile(visual)

    # Labels are created only while the player is close enough to read them.
    # Keeping dormant resources as lightweight Area2Ds removes hundreds of
    # idle Control nodes without changing the pickup experience.
    queue_redraw()

func _apply_environment_tile(target: Sprite2D) -> void:
    var source_id := int(RESOURCE_TILE_SOURCES.get(item_id, 25))
    var source := ENVIRONMENT_TILESET.get_source(source_id) as TileSetAtlasSource
    if source == null:
        return
    target.texture = source.texture
    target.region_enabled = true
    target.region_rect = Rect2(0, 0, 32, 32)
    target.centered = true
    if item_id == "gold_ore":
        target.modulate = Color(1.18, 0.98, 0.52)

func _ensure_pickup_label() -> void:
    if pickup_label != null:
        return
    pickup_label = Label.new()
    pickup_label.name = "PickupLabel"
    pickup_label.custom_minimum_size = Vector2(144, 24)
    pickup_label.position = Vector2(-72, -54)
    pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    pickup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    pickup_label.visible = true
    pickup_label.add_theme_color_override("font_color", Color("#f8e6a1"))
    pickup_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
    pickup_label.add_theme_constant_override("outline_size", 4)
    pickup_label.add_theme_font_size_override("font_size", 12)
    pickup_label.text = "%s  x%d" % [item_name, quantity]
    add_child(pickup_label)

func _is_visible_to_camera() -> bool:
    var camera := get_viewport().get_camera_2d()
    if camera == null or not is_instance_valid(camera):
        return true
    var zoom := camera.zoom
    var half_size := get_viewport_rect().size * 0.5
    half_size = Vector2(
        half_size.x / maxf(zoom.x, 0.01),
        half_size.y / maxf(zoom.y, 0.01)
    )
    var camera_rect := Rect2(camera.global_position - half_size, half_size * 2.0)
    return camera_rect.grow(160.0).has_point(global_position)

func _process(delta: float) -> void:
    if is_collected:
        if not respawn_enabled:
            return
        respawn_timer -= delta
        if respawn_timer <= 0.0:
            _respawn()
        return

    # Collision signals handle the instant pickup case. This slower fallback
    # keeps auto-pickup reliable even if a physics frame is skipped.
    proximity_timer -= delta
    if proximity_timer <= 0.0:
        proximity_timer = 0.08
        var player := GameManager.player
        var was_near := near_player
        near_player = false
        if player and is_instance_valid(player):
            var distance_sq := global_position.distance_squared_to(player.global_position)
            near_player = distance_sq <= pickup_hint_radius * pickup_hint_radius
            if distance_sq <= pickup_radius * pickup_radius:
                _give_to_player(player)

        if near_player:
            _ensure_pickup_label()
        if pickup_label:
            pickup_label.visible = near_player and not is_collected
        if was_near != near_player:
            queue_redraw()

    # Camera visibility changes much more slowly than the frame rate. Cache it
    # so hundreds of resources do not each query the viewport every frame.
    visibility_timer -= delta
    if visibility_timer <= 0.0:
        visibility_timer = 0.15
        camera_visible = _is_visible_to_camera()

    # Only animate and redraw nodes in/near the camera view. Off-screen
    # resources remain fully available for pickup and respawn.
    if near_player or camera_visible:
        bob_time += delta
        if visual:
            visual.position.y = sin(bob_time * 2.4) * 1.5
        redraw_timer -= delta
        if redraw_timer <= 0.0:
            redraw_timer = 0.04
            queue_redraw()

func _on_body_entered(body: Node2D) -> void:
    var player := _player_from_body(body)
    if player != null:
        _give_to_player(player)

func _player_from_body(body: Node) -> CharacterBody2D:
    var player := body as CharacterBody2D
    if player == null or not player.has_method("get_save_data"):
        return null
    var inventory_value: Variant = player.get("inventory")
    if inventory_value is PlayerInventory:
        return player
    return null

func interact(player: CharacterBody2D) -> void:
    if player != null and is_instance_valid(player) and not is_collected:
        _give_to_player(player)

func _give_to_player(player: CharacterBody2D) -> void:
    if player == null or not is_instance_valid(player) or player.inventory == null or is_collected:
        return
    var item_data := {
        "id": item_id,
        "name": item_name,
        "type": item_type,
        "quantity": quantity,
        "stackable": true,
        "description": "A %s found in the wilds of Angel Island." % item_name.to_lower()
    }
    if player.inventory.add_item(item_data):
        VFX.pickup_sparkle(self)
        is_collected = true
        near_player = false
        if respawn_enabled:
            respawn_timer = respawn_time
        else:
            call_deferred("queue_free")
        set_deferred("monitoring", false)
        if collision:
            collision.set_deferred("disabled", true)
        if pickup_label:
            pickup_label.visible = false
        if visual:
            visual.visible = false
        EventBus.show_notification.emit("Collected %s x%d" % [item_name, quantity])

func _respawn() -> void:
    is_collected = false
    near_player = false
    set_deferred("monitoring", true)
    if collision:
        collision.set_deferred("disabled", false)
    if visual:
        visual.visible = true
    queue_redraw()

func _draw() -> void:
    if is_collected:
        return
    if near_player:
        var pulse := (sin(bob_time * 5.0) + 1.0) * 0.5
        draw_circle(Vector2(0, 5), 22.0 + pulse * 4.0, Color(0.98, 0.84, 0.35, 0.08))
        draw_arc(Vector2(0, 5), 24.0 + pulse * 4.0, 0.0, TAU, 24, Color(1.0, 0.88, 0.45, 0.75), 2.0)
    # The material sprite above is a real tile from the shared TileSet. This
    # parent draw only supplies a ground shadow and interaction highlight.
    _draw_ground_ellipse(Vector2(0, 10), Vector2(14, 5), Color(0.04, 0.10, 0.08, 0.28))

func _draw_ground_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
    draw_set_transform(center, 0.0, radii)
    draw_circle(Vector2.ZERO, 1.0, color)
    draw_set_transform(Vector2.ZERO)
