extends Node2D

const VILLAGER_SCENE = preload("res://scenes/npcs/villager.tscn")

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
    var layout_config: Dictionary = _load_layout_config()
    terrain.rebuild(world_node, layout_config)
    _spawn_additional_villagers(world_node)
    _confine_village_npcs(world_node, layout_config)
    var director := world_node.get_node_or_null("WorldDirector") as WorldDirector
    if director == null:
        director = WorldDirector.new()
        director.name = "WorldDirector"
        world_node.add_child(director)

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

func _spawn_additional_villagers(world_node: Node2D) -> void:
    var village := world_node.get_node_or_null("VillageNPCs") as Node2D
    if village == null:
        return
    var villagers := [
        {"id": "farmer", "name": "Anika the Farmer", "job": "farmer", "pos": Vector2(-380, 160), "greeting": "The fields feed everyone in Angel Village."},
        {"id": "guard", "name": "Rook the Gatekeeper", "job": "guard", "pos": Vector2(400, 80), "greeting": "Keep your eyes open beyond the village markers."},
        {"id": "merchant", "name": "Lio the Trader", "job": "merchant", "pos": Vector2(360, -144), "greeting": "I buy rare finds and sell stories from distant shores."},
        {"id": "fisher", "name": "Mira the Fisher", "job": "fisher", "pos": Vector2(320, 300), "greeting": "The lake has been generous this morning."},
        {"id": "herbalist", "name": "Elin the Herbalist", "job": "herbalist", "pos": Vector2(-360, 240), "greeting": "The island grows medicine for those who know where to look."},
        {"id": "builder", "name": "Oskar the Builder", "job": "builder", "pos": Vector2(320, 160), "greeting": "There is always another roof, fence or bridge to repair."},
        {"id": "gardener", "name": "Suri the Gardener", "job": "farmer", "pos": Vector2(-230, 300), "greeting": "Every seed is a promise that tomorrow can be better."},
        {"id": "watch", "name": "Bram the Watch", "job": "guard", "pos": Vector2(-420, -40), "greeting": "The ring is safe, but the roads beyond it still need watching."},
        {"id": "trader", "name": "Nia the Trader", "job": "merchant", "pos": Vector2(220, -260), "greeting": "A healthy village is built on fair trades and good timing."},
        {"id": "apothecary", "name": "Tala the Apothecary", "job": "herbalist", "pos": Vector2(-240, -260), "greeting": "Bring me mint, lavender and flowers; I can turn them into calm."}
    ]
    for data: Dictionary in villagers:
        var node_name := "NPC_" + str(data["id"]).capitalize()
        if village.get_node_or_null(node_name) != null:
            continue
        var npc := VILLAGER_SCENE.instantiate() as QuestNPC
        if npc == null:
            continue
        npc.name = node_name
        npc.npc_id = str(data["id"])
        npc.npc_name = str(data["name"])
        npc.job = str(data["job"])
        npc.stays_in_village = true
        npc.greeting_text = str(data["greeting"])
        npc.position = data["pos"]
        village.add_child(npc)

func _confine_village_npcs(world_node: Node2D, layout_config: Dictionary) -> void:
	var village := world_node.get_node_or_null("VillageNPCs") as Node2D
	if village == null:
		return
	var anchors: Dictionary = {}
	var village_value: Variant = layout_config.get("village", {})
	if village_value is Dictionary:
		var village_data: Dictionary = village_value
		var npc_value: Variant = village_data.get("npcs", [])
		if npc_value is Array:
			for raw_npc in npc_value:
				if not (raw_npc is Dictionary):
					continue
				var npc_data: Dictionary = raw_npc
				var pos_value: Variant = npc_data.get("pos", {})
				if pos_value is Dictionary:
					var pos_data: Dictionary = pos_value
					anchors[str(npc_data.get("id", ""))] = Vector2(
						float(pos_data.get("x", 0.0)),
						float(pos_data.get("y", 0.0))
					)
	for child in village.get_children():
		if not (child is QuestNPC):
			continue
		var npc: QuestNPC = child as QuestNPC
		npc.stays_in_village = true
		var anchor_value: Variant = anchors.get(npc.npc_id, null)
		if anchor_value is Vector2:
			npc.set_village_anchor(anchor_value)
		else:
			npc.call("_configure_village_bounds")

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
