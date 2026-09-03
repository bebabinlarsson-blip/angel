class_name CollectableItem
extends Area2D

@export var item_id: String = "wood"
@export var item_name: String = "Wood"
@export var item_type: int = 0 # 0=MATERIAL
@export var quantity: int = 1
@export var respawn_time: float = 45.0

var is_collected: bool = false
var respawn_timer: float = 0.0

@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
var visual: CustomDraw2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	visual = get_node_or_null("CustomDraw2D") as CustomDraw2D
	if visual == null:
		visual = CustomDraw2D.new()
		visual.name = "CustomDraw2D"
		match item_id:
			"wood":
				visual.entity_type = CustomDraw2D.EntityType.ITEM_WOOD
			"herb":
				visual.entity_type = CustomDraw2D.EntityType.ITEM_HERB
			"mushroom":
				visual.entity_type = CustomDraw2D.EntityType.ITEM_MUSHROOM
			"iron_ore", "gold_ore":
				visual.entity_type = CustomDraw2D.EntityType.ITEM_ORE
			_:
				visual.entity_type = CustomDraw2D.EntityType.ITEM_HERB
	set_process(false)

func _process(delta: float) -> void:
	if is_collected:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_respawn()

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
	
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system:
		quest_system.update_quest_progress("collect", item_id, quantity)

func _respawn() -> void:
	is_collected = false
	set_process(false)
	if visual:
		visual.visible = true
	if collision:
		collision.set_deferred("disabled", false)
