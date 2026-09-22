extends Node2D

const VILLAGE_LAYOUT_SCRIPT = preload("res://scripts/world/village_layout.gd")
const NPC_EVENT_MANAGER_SCRIPT = preload("res://scripts/world/npc_event_manager.gd")

@onready var player: CharacterBody2D = get_node_or_null("World/Player") as CharacterBody2D
@onready var quest_system: QuestSystem = get_node_or_null("QuestSystem")
@onready var cooking_system: CookingSystem = get_node_or_null("CookingSystem")

func _ready() -> void:
	get_tree().paused = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	GameManager.village_spawn_point = Vector2(0, 90)
	_ensure_audio_manager()

	# Initialize world map texture and collision bounds from authored scene layers
	var world_node := get_node_or_null("World")
	if world_node == null:
		world_node = Node2D.new()
		world_node.name = "World"
		add_child(world_node)
		move_child(world_node, 0)
	var terrain: IslandWorld = world_node.get_node_or_null("IslandWorld") as IslandWorld
	if terrain == null:
		terrain = IslandWorld.new()
		terrain.name = "IslandWorld"
		terrain.add_to_group("island_world")
		world_node.add_child(terrain)
	_ensure_cooking_place(world_node)
	_ensure_village_content(world_node)
	_strip_removed_village_structures(world_node)
	terrain.rebuild(world_node, _load_layout_config())
	# Scene transfers rebuild the overworld from scratch. Restore the compact
	# quest snapshot after the new QuestSystem child has initialized so an exit
	# from an interior never silently drops the player's active objective.
	if quest_system != null:
		GameManager.consume_quest_transfer(quest_system)
	var director := world_node.get_node_or_null("WorldDirector") as WorldDirector
	if director == null:
		director = WorldDirector.new()
		director.name = "WorldDirector"
		world_node.add_child(director)
	_ensure_npc_event_manager(world_node)

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
			"attack_bonus": 15.0,
			"description": "A sturdy starter sword. Keep it sharp and close when the slimes come."
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
	elif player and player.inventory and player.inventory.equipped_weapon.is_empty():
		# Existing saves from the fist-only prototype get a real sword too.
		var saved_sword := {
			"id": "wooden_sword",
			"name": "Wooden Sword",
			"type": 1,
			"quantity": 1,
			"stackable": false,
			"attack_bonus": 15.0,
			"description": "A sturdy starter sword. Keep it sharp and close when the slimes come."
		}
		if not player.inventory.has_item("wooden_sword"):
			player.inventory.add_item(saved_sword)
		player.inventory.equip_weapon(saved_sword)
	elif player and player.inventory and player.inventory.equipped_weapon.get("id", "") == "wooden_sword":
		# Migrate the old prototype sword so it has real weapon damage in saves
		# created before the explicit sword stats were added.
		player.inventory.equipped_weapon["attack_bonus"] = 15.0
		player.inventory.equipped_weapon["description"] = "A balanced iron-edged sword. Your trusted starting weapon."

	# Emit initial UI state
	if player and player.stats:
		EventBus.player_health_changed.emit(player.stats.current_hp, player.stats.get_max_hp())
		EventBus.player_stamina_changed.emit(player.stats.current_stamina, player.stats.get_max_stamina())
		EventBus.player_money_changed.emit(player.stats.money)
		EventBus.show_notification.emit("Welcome to Angel! Walk near materials to collect them, press E for your backpack, and keep your sword ready.")

func _ensure_cooking_place(world_node: Node2D) -> void:
	if world_node.get_node_or_null("Campfire") != null:
		return
	var hearth := CookingPot.new()
	hearth.name = "Campfire"
	hearth.position = Vector2.ZERO
	world_node.add_child(hearth)

func _strip_removed_village_structures(world_node: Node2D) -> void:
	# Village is now an open settlement. Keep reusable art resources in the
	# project, but remove every road, house, church, ruin, mine entrance and
	# mine prop from the playable scene before terrain indexes the map.
	for layer_path: String in [
		"RoadLayer",
		"HouseLayer",
		"StructuresLayer",
		"AuthoredEnvironment/RoadLayer",
		"AuthoredEnvironment/HouseLayer",
		"AuthoredEnvironment/StructureLayer",
	]:
		var layer := world_node.get_node_or_null(layer_path) as TileMapLayer
		if layer == null:
			continue
		layer.clear()
		layer.visible = false
		layer.enabled = false

	var interiors := world_node.get_node_or_null("Interiors")
	if interiors != null:
		interiors.visible = false
		interiors.process_mode = Node.PROCESS_MODE_DISABLED
		for entry in interiors.find_children("*", "Area2D", true, false):
			(entry as Area2D).monitoring = false
			for shape in (entry as Area2D).find_children("*", "CollisionShape2D", true, false):
				(shape as CollisionShape2D).disabled = true

	var mining_area := world_node.get_node_or_null("MiningArea")
	if mining_area != null:
		mining_area.visible = false
		mining_area.process_mode = Node.PROCESS_MODE_DISABLED
		for shape in mining_area.find_children("*", "CollisionShape2D", true, false):
			(shape as CollisionShape2D).disabled = true

	# Destinations whose landmarks no longer exist should not remain as hidden
	# fast-travel promises.
	for waystone_name: String in ["Waystone_Cave", "Waystone_Ruins"]:
		var waystone := world_node.get_node_or_null("Waystones/" + waystone_name)
		if waystone != null:
			waystone.queue_free()

func _ensure_village_content(world_node: Node2D) -> void:
	var layout := world_node.get_node_or_null("VillageLayout") as VillageLayout
	if layout == null:
		layout = VILLAGE_LAYOUT_SCRIPT.new() as VillageLayout
		layout.name = "VillageLayout"
		world_node.add_child(layout)
	layout.configure(Vector2.ZERO, 500.0)

	var interiors := world_node.get_node_or_null("Interiors") as Node2D
	if interiors == null:
		interiors = Node2D.new()
		interiors.name = "Interiors"
		interiors.y_sort_enabled = true
		world_node.add_child(interiors)
	# All door triggers are scene-authored in interior_entries.tscn and attach
	# themselves to the matching TileMapLayer. Never recreate removed or moved
	# entrances from code; a missing registry is an authoring error that should be
	# visible in the editor instead of silently creating duplicate geometry.
	if interiors.get_child_count() == 0:
		push_warning("Angel: no scene-authored interior entries were found.")


func _load_layout_config() -> Dictionary:
	var file := FileAccess.open("res://data/island_layout.json", FileAccess.READ)
	if file == null:
		push_warning("Angel: island layout config could not be opened.")
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Angel: island layout config could not be parsed.")
		return {}
	if not (json.data is Dictionary):
		push_warning("Angel: island layout config root is not a dictionary.")
		return {}
	return json.data

func _ensure_npc_event_manager(world_node: Node2D) -> void:
	var manager := world_node.get_node_or_null("NPCEventManager") as NPCEventManager
	if manager != null:
		return
	manager = NPC_EVENT_MANAGER_SCRIPT.new() as NPCEventManager
	manager.name = "NPCEventManager"
	world_node.add_child(manager)

func _connect_once(sig: Signal, handler: Callable) -> void:
	if not sig.is_connected(handler):
		sig.connect(handler)

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
