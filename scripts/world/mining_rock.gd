class_name MiningRock
extends StaticBody2D

const TILESET_VISUAL_SCRIPT = preload("res://scripts/world/tileset_visual.gd")

@export var max_hits: int = 4
@export var ore_type: String = "iron_ore"
@export var ore_name: String = "Iron Ore"
@export var ore_count: int = 2

var current_hits: int = 0
var is_depleted: bool = false
var respawn_time: float = 45.0
var respawn_timer: float = 0.0

@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
var visual: CanvasItem = null
var sprite: Sprite2D = null

func _ready() -> void:
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = load("res://assets/sprites/world/ore_vein.png")
		if ore_type == "gold_ore":
			sprite.modulate = Color(1.2, 0.95, 0.5)
		else:
			sprite.modulate = Color(0.9, 1.0, 1.1)
		add_child(sprite)
	var atlas_texture := TILESET_VISUAL_SCRIPT.texture_for_item("ore_vein")
	if atlas_texture != null:
		sprite.texture = atlas_texture
	visual = sprite

	# Minimal/test scenes may omit the authored collider. Keep the interaction
	# contract intact by creating the same small footprint used by the scene.
	if collision == null:
		collision = CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 22.0
		collision.shape = shape
		add_child(collision)
	set_process(false)

func _process(delta: float) -> void:
	if is_depleted:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_respawn()

func take_damage(_amount: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	if is_depleted:
		return
	
	current_hits += 1
	VFX.mine_sparks(self)
	VFX.flash_hit(visual)
	var tween := create_tween()
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.2, 0.8), 0.05)
		tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.05)
	
	if current_hits >= max_hits:
		_deplete()

func interact(_player: CharacterBody2D) -> void:
	if not is_depleted:
		take_damage(25.0)
		EventBus.show_notification.emit("Mined " + ore_name + " rock!")

func _deplete() -> void:
	# Award the ore before hiding the node. If the bag is full, leave one hit
	# remaining so the player can make room and try again without losing loot.
	var player := GameManager.player
	if player == null or not is_instance_valid(player) or player.inventory == null:
		current_hits = maxi(0, max_hits - 1)
		EventBus.show_notification.emit("Mining unavailable — no inventory found.")
		return

	var item_data := {
		"id": ore_type,
		"name": ore_name,
		"type": 0, # MATERIAL
		"quantity": ore_count,
		"stackable": true,
		"description": "Raw ore mined from rocks. Used in crafting and cooking."
	}
	if not player.inventory.can_add_item(item_data) or not player.inventory.add_item(item_data):
		current_hits = maxi(0, max_hits - 1)
		EventBus.show_notification.emit("Inventory full — make room for the ore.")
		return

	is_depleted = true
	respawn_timer = respawn_time
	set_process(true)
	if visual:
		visual.visible = false
	if collision:
		collision.set_deferred("disabled", true)
	EventBus.show_notification.emit("Obtained %s x%d!" % [ore_name, ore_count])
		


func _respawn() -> void:
	is_depleted = false
	current_hits = 0
	set_process(false)
	if visual:
		visual.visible = true
	if collision:
		collision.set_deferred("disabled", false)
