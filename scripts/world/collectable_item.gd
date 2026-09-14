class_name CollectableItem
extends Area2D

@export var item_id: String = "wood"
@export var item_name: String = "Wood"
@export var item_type: int = 0 # 0=MATERIAL
@export var quantity: int = 1
@export var respawn_time: float = 45.0
@export var pickup_radius: float = 52.0

var is_collected: bool = false
var respawn_timer: float = 0.0

var collision: CollisionShape2D = null
var visual: CanvasItem = null

func _ready() -> void:
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
	set_process(true)

func _process(delta: float) -> void:
	if is_collected:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_respawn()
		return
	var player := GameManager.player
	if player and is_instance_valid(player) and global_position.distance_squared_to(player.global_position) <= pickup_radius * pickup_radius:
		_give_to_player(player)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body.has_method("get_save_data") and "inventory" in body:
		var player := body as CharacterBody2D
		if player and player.inventory:
			_give_to_player(player)

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
	if visual:
		visual.visible = false
	if collision:
		collision.set_deferred("disabled", true)
	EventBus.show_notification.emit("Collected %s x%d" % [item_name, quantity])
	


func _respawn() -> void:
	is_collected = false
	set_process(false)
	if visual:
		visual.visible = true
	if collision:
		collision.set_deferred("disabled", false)
