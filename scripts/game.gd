extends Node2D

@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var quest_system: QuestSystem = get_node_or_null("QuestSystem")
@onready var cooking_system: CookingSystem = get_node_or_null("CookingSystem")

func _ready() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.village_spawn_point = Vector2(0, 0)
	
	# Spawn island world elements if generator isn't present
	if get_node_or_null("World/WorldGenerator") == null:
		var world_node := get_node_or_null("World")
		if world_node == null:
			world_node = Node2D.new()
			world_node.name = "World"
			add_child(world_node)
			move_child(world_node, 0)
		
		var gen := WorldGenerator.new()
		gen.name = "WorldGenerator"
		world_node.add_child(gen)
	
	# Connect monster kills & item pickups to quest system
	EventBus.monster_killed.connect(_on_monster_killed)
	EventBus.item_collected.connect(_on_item_collected)
	
	# Initial player equipment and starter items
	if player and player.inventory and player.inventory.items.is_empty():
		var starter_sword := {
			"id": "wooden_sword",
			"name": "Wooden Sword",
			"type": 1, # WEAPON
			"quantity": 1,
			"stackable": false,
			"description": "A basic training sword. Better than bare hands!"
		}
		player.inventory.add_item(starter_sword)
		player.inventory.equip_weapon(starter_sword)
		
		var starter_potions := {
			"id": "stamina_tonic",
			"name": "Stamina Tonic",
			"type": 4, # POTION
			"quantity": 2,
			"heal": 15.0,
			"stamina_restore": 25.0,
			"stackable": true,
			"description": "Restores 15 HP and 25 Stamina."
		}
		player.inventory.add_item(starter_potions)
	
	# Emit initial UI state
	if player and player.stats:
		EventBus.player_health_changed.emit(player.stats.current_hp, player.stats.get_max_hp())
		EventBus.player_stamina_changed.emit(player.stats.current_stamina, player.stats.get_max_stamina())
		EventBus.player_money_changed.emit(player.stats.money)
		EventBus.show_notification.emit("Welcome to Angel! Explore, fight slimes, level up, and cook!")

func _on_monster_killed(_monster: Node, _position: Vector2) -> void:
	if quest_system:
		quest_system.update_quest_progress("kill", "slime", 1)

func _on_item_collected(item_data: Dictionary) -> void:
	if quest_system:
		quest_system.update_quest_progress("collect", item_data.get("id", ""), item_data.get("quantity", 1))
