class_name ResourceNode
extends Area2D

## A lightweight, procedural material/collectible node used by WorldDirector.
## It deliberately draws its own icon so the expanded world does not need a
## separate scene or a new texture for every resource type.

@export var item_id: String = "wood"
@export var item_name: String = "Wood"
@export var quantity: int = 1
@export var item_type: int = 0
@export var respawn_time: float = 75.0
@export var pickup_radius: float = 52.0

var is_collected: bool = false
var respawn_timer: float = 0.0
var bob_time: float = 0.0
var collision: CollisionShape2D = null

func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("collectables")
	body_entered.connect(_on_body_entered)
	collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 15.0
		collision.shape = shape
		add_child(collision)
	queue_redraw()

func _process(delta: float) -> void:
	if is_collected:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return
	var player := GameManager.player
	if player and is_instance_valid(player):
		if global_position.distance_squared_to(player.global_position) <= pickup_radius * pickup_radius:
			_give_to_player(player)
			if is_collected:
				return
	bob_time += delta
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
		respawn_timer = respawn_time
		set_deferred("monitoring", false)
		if collision:
			collision.set_deferred("disabled", true)
		EventBus.show_notification.emit("Collected %s x%d" % [item_name, quantity])

func _respawn() -> void:
	is_collected = false
	set_deferred("monitoring", true)
	if collision:
		collision.set_deferred("disabled", false)

func _draw() -> void:
	if is_collected:
		return
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
