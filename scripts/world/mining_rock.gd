class_name MiningRock
extends StaticBody2D

@export var max_hits: int = 4
@export var ore_type: String = "iron_ore"
@export var ore_name: String = "Iron Ore"
@export var ore_count: int = 2

var current_hits: int = 0
var is_depleted: bool = false
var respawn_time: float = 45.0
var respawn_timer: float = 0.0

@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
var visual: CustomDraw2D = null

func _ready() -> void:
	visual = get_node_or_null("CustomDraw2D") as CustomDraw2D
	if visual == null:
		visual = CustomDraw2D.new()
		visual.name = "CustomDraw2D"
		visual.entity_type = CustomDraw2D.EntityType.ORE_VEIN
		add_child(visual)
	set_process(false)

func _process(delta: float) -> void:
	if is_depleted:
		respawn_timer -= delta
		if respawn_timer <= 0:
			_respawn()

func take_damage(amount: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	if is_depleted:
		return
	
	current_hits += 1
	var tween := create_tween()
	if visual:
		tween.tween_property(visual, "scale", Vector2(1.2, 0.8), 0.05)
		tween.tween_property(visual, "scale", Vector2(1.0, 1.0), 0.05)
	
	if current_hits >= max_hits:
		_deplete()

func interact(player: CharacterBody2D) -> void:
	if not is_depleted:
		take_damage(25.0)
		EventBus.show_notification.emit("Mined " + ore_name + " rock!")

func _deplete() -> void:
	is_depleted = true
	respawn_timer = respawn_time
	set_process(true)
	if visual:
		visual.visible = false
	if collision:
		collision.set_deferred("disabled", true)
	
	# Give loot to player
	if GameManager.player and GameManager.player.inventory:
		var item_data := {
			"id": ore_type,
			"name": ore_name,
			"type": 0, # MATERIAL
			"quantity": ore_count,
			"stackable": true,
			"description": "Raw ore mined from rocks. Used in crafting and cooking."
		}
		GameManager.player.inventory.add_item(item_data)
		EventBus.show_notification.emit("Obtained %s x%d!" % [ore_name, ore_count])
		
		# Progress cave exploration quest if active
		var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
		if quest_system:
			quest_system.update_quest_progress("collect", ore_type, ore_count)

func _respawn() -> void:
	is_depleted = false
	current_hits = 0
	set_process(false)
	if visual:
		visual.visible = true
	if collision:
		collision.set_deferred("disabled", false)
