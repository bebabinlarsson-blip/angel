class_name CollectableItem
extends Area2D

@export var item_id: String = "wood"
@export var item_name: String = "Wood"
@export var item_type: int = 0 # 0=MATERIAL
@export var quantity: int = 1
@export var respawn_time: float = 45.0
@export var pickup_radius: float = 64.0
@export var pickup_hint_radius: float = 124.0

var is_collected: bool = false
var respawn_timer: float = 0.0
var near_player: bool = false
var collision: CollisionShape2D = null
var visual: CanvasItem = null
var pickup_label: Label = null

func _ready() -> void:
	add_to_group("collectables")
	body_entered.connect(_on_body_entered)

	if has_node("CollisionShape2D"):
		collision = get_node("CollisionShape2D") as CollisionShape2D

	if has_node("Sprite2D"):
		visual = get_node("Sprite2D") as CanvasItem
	else:
		var spr := Sprite2D.new()
		spr.name = "Sprite2D"
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		match item_id:
			"wood":
				spr.texture = load("res://assets/sprites/items/item_wood.png")
			"herb":
				spr.texture = load("res://assets/sprites/items/item_herb.png")
			"mushroom":
				spr.texture = load("res://assets/sprites/items/item_mushroom.png")
			"iron_ore", "gold_ore":
				spr.texture = load("res://assets/sprites/items/item_ore.png")
			_:
				spr.texture = load("res://assets/sprites/items/item_herb.png")
		add_child(spr)
		visual = spr

	pickup_label = Label.new()
	pickup_label.name = "PickupLabel"
	pickup_label.custom_minimum_size = Vector2(144, 24)
	pickup_label.position = Vector2(-72, -44)
	pickup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_label.visible = false
	pickup_label.add_theme_color_override("font_color", Color("#f8e6a1"))
	pickup_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
	pickup_label.add_theme_constant_override("outline_size", 4)
	pickup_label.add_theme_font_size_override("font_size", 12)
	add_child(pickup_label)

func _process(delta: float) -> void:
	if is_collected:
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
	if was_near != near_player and visual:
		visual.modulate = Color(1.0, 0.9, 0.55) if near_player else Color.WHITE

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
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
	if not is_collected and player and player.inventory:
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
		"description": "A natural material found across the island."
	}
	if player.inventory.add_item(item_data):
		VFX.pickup_sparkle(self)
		_collect()

func _collect() -> void:
	is_collected = true
	respawn_timer = respawn_time
	set_process(true)
	near_player = false
	if pickup_label:
		pickup_label.visible = false
	if visual:
		visual.visible = false
	if collision:
		collision.set_deferred("disabled", true)
	EventBus.show_notification.emit("Collected %s x%d" % [item_name, quantity])

func _respawn() -> void:
	is_collected = false
	near_player = false
	set_process(true)
	if visual:
		visual.visible = true
	if collision:
		collision.set_deferred("disabled", false)
