extends Node2D

@onready var player: CharacterBody2D = get_node_or_null("Player")
@onready var quest_system: QuestSystem = get_node_or_null("QuestSystem")
@onready var cooking_system: CookingSystem = get_node_or_null("CookingSystem")

func _ready() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.village_spawn_point = Vector2(0, 0)
	_ensure_audio_manager()
	
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
	
	# Connect monster kills & item pickups to quest system.
	# EventBus persists across scene changes, so guard every connect
	# (re-entering game.tscn would otherwise stack duplicate handlers).
	_connect_once(EventBus.monster_killed, _on_monster_killed)
	_connect_once(EventBus.item_collected, _on_item_collected)
	# Juice: procedural SFX with no assets
	_connect_once(EventBus.damage_dealt, _on_damage_dealt)
	_connect_once(EventBus.cooking_finished, _on_cooking_finished)
	_connect_once(EventBus.player_leveled_up, _on_leveled_up)
	_connect_once(EventBus.player_died, _on_player_died)
	_connect_once(EventBus.item_collected, _on_pickup_sound)
	
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

func _connect_once(sig: Signal, handler: Callable) -> void:
	if not sig.is_connected(handler):
		sig.connect(handler)

func _on_monster_killed(_monster: Node, _position: Vector2) -> void:
	if quest_system:
		quest_system.update_quest_progress("kill", "slime", 1)

func _on_item_collected(item_data: Dictionary) -> void:
	if quest_system:
		quest_system.update_quest_progress("collect", item_data.get("id", ""), item_data.get("quantity", 1))

func _ensure_audio_manager() -> void:
	if get_tree().root.get_node_or_null("AudioManager") == null:
		var mgr := AudioManager.new()
		mgr.name = "AudioManager"
		get_tree().root.add_child.call_deferred(mgr)

func _audio() -> Node:
	return get_tree().root.get_node_or_null("AudioManager")

func _on_damage_dealt(_target: Node, _amount: float) -> void:
	var a := _audio()
	if a and a.has_method("play_hit"):
		a.call("play_hit")

func _on_pickup_sound(_item: Dictionary) -> void:
	var a := _audio()
	if a and a.has_method("play_pickup"):
		a.call("play_pickup")

func _on_cooking_finished(_result: Dictionary) -> void:
	var a := _audio()
	if a and a.has_method("play_cook"):
		a.call("play_cook")

func _on_leveled_up(_level: int) -> void:
	var a := _audio()
	if a and a.has_method("play_levelup"):
		a.call("play_levelup")

func _on_player_died() -> void:
	var a := _audio()
	if a and a.has_method("play_death"):
		a.call("play_death")
