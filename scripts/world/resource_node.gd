class_name ResourceNode
extends Area2D

## Procedural ground material. It can be collected by walking close to it or
## by pressing the normal interaction key, with a lightweight nearby prompt.

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
var near_player: bool = false
var collision: CollisionShape2D = null
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

	pickup_label = Label.new()
	pickup_label.name = "PickupLabel"
	pickup_label.custom_minimum_size = Vector2(144, 24)
	pickup_label.position = Vector2(-72, -54)
	pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_label.visible = false
	pickup_label.add_theme_color_override("font_color", Color("#f8e6a1"))
	pickup_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
	pickup_label.add_theme_constant_override("outline_size", 4)
	pickup_label.add_theme_font_size_override("font_size", 12)
	add_child(pickup_label)
	queue_redraw()

func _process(delta: float) -> void:
	if is_collected:
		if not respawn_enabled:
			return
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	var player := GameManager.player
	var was_near := near_player
	near_player = false
	if player and is_instance_valid(player):
		var distance_sq := global_position.distance_squared_to(player.global_position)
		near_player = distance_sq <= pickup_hint_radius * pickup_hint_radius
		if distance_sq <= pickup_radius * pickup_radius:
			_give_to_player(player)

	if pickup_label:
		pickup_label.visible = near_player and not is_collected
		pickup_label.text = "%s  x%d" % [item_name, quantity]

	bob_time += delta
	redraw_timer -= delta
	if redraw_timer <= 0.0 or was_near != near_player:
		redraw_timer = 0.08
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("get_save_data") and "inventory" in body:
		_give_to_player(body as CharacterBody2D)

func interact(player: CharacterBody2D) -> void:
	if player and not is_collected:
		_give_to_player(player)

func _give_to_player(player: CharacterBody2D) -> void:
	if player == null or player.inventory == null or is_collected:
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
		EventBus.show_notification.emit("Collected %s x%d" % [item_name, quantity])

func _respawn() -> void:
	is_collected = false
	near_player = false
	set_deferred("monitoring", true)
	if collision:
		collision.set_deferred("disabled", false)
	queue_redraw()

func _draw() -> void:
	if is_collected:
		return
	if near_player:
		var pulse := (sin(bob_time * 5.0) + 1.0) * 0.5
		draw_circle(Vector2(0, 5), 22.0 + pulse * 4.0, Color(0.98, 0.84, 0.35, 0.08))
		draw_arc(Vector2(0, 5), 24.0 + pulse * 4.0, 0.0, TAU, 24, Color(1.0, 0.88, 0.45, 0.75), 2.0)
	var bob := sin(bob_time * 2.4) * 1.5
	draw_ellipse(Vector2(0, 10), Vector2(14, 5), Color(0.04, 0.10, 0.08, 0.28))
	draw_set_transform(Vector2(0, bob))
	match item_id:
		"wood":
			draw_line(Vector2(-13, 5), Vector2(12, -7), Color("#563921"), 8.0)
			draw_line(Vector2(-12, 3), Vector2(13, -9), Color("#b8753c"), 5.0)
			draw_circle(Vector2(-13, 5), 5.0, Color("#d39554"))
		"stone", "iron_ore", "gold_ore", "coal":
			var rock_color := Color("#8b929b")
			if item_id == "iron_ore": rock_color = Color("#9b6870")
			elif item_id == "gold_ore": rock_color = Color("#e7bb48")
			elif item_id == "coal": rock_color = Color("#30363d")
			draw_colored_polygon(PackedVector2Array([Vector2(-13, 6), Vector2(-10, -7), Vector2(0, -13), Vector2(13, -5), Vector2(10, 7), Vector2(-3, 11)]), rock_color)
			draw_line(Vector2(-6, -3), Vector2(3, -7), Color(1, 1, 1, 0.35), 2.0)
		"herb", "fiber", "moon_petal":
			draw_line(Vector2(0, 10), Vector2(0, -8), Color("#367243"), 3.0)
			for side in [-1.0, 1.0]:
				draw_line(Vector2(0, 2), Vector2(side * 10, -4), Color("#61b75d"), 3.0)
				draw_line(Vector2(0, -3), Vector2(side * 7, -10), Color("#8ad66b"), 3.0)
			if item_id == "moon_petal":
				draw_circle(Vector2(0, -10), 5.0, Color("#b8a7ff"))
		"mushroom":
			draw_rect(Rect2(-3, -1, 6, 11), Color("#f0d8a1"))
			draw_circle(Vector2(0, -3), 10.0, Color("#c95d5d"))
			draw_circle(Vector2(-4, -6), 2.0, Color("#ffe8b8"))
			draw_circle(Vector2(4, -2), 2.0, Color("#ffe8b8"))
		"berry":
			draw_line(Vector2(0, 9), Vector2(0, -7), Color("#4f884b"), 3.0)
			draw_circle(Vector2(-6, -3), 5.0, Color("#c53d63"))
			draw_circle(Vector2(5, -6), 5.0, Color("#e15872"))
		"crystal", "sunstone", "ancient_shard":
			var crystal_color := Color("#65dbe8")
			if item_id == "sunstone": crystal_color = Color("#f4ae43")
			elif item_id == "ancient_shard": crystal_color = Color("#a77aff")
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 8), Vector2(-6, -9), Vector2(0, -15), Vector2(8, -7), Vector2(10, 8)]), crystal_color)
			draw_line(Vector2(-2, -9), Vector2(0, 5), Color(1, 1, 1, 0.65), 2.0)
		_:
			draw_circle(Vector2.ZERO, 9.0, Color("#8ed15d"))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO)
