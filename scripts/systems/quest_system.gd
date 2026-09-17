class_name QuestSystem
extends Node

var all_quests: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}
const MAX_SAVED_QUESTS := 32

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("quest_system")
	_init_quests()
	_connect_once(EventBus.monster_killed, _on_monster_killed)
	_connect_once(EventBus.item_collected, _on_item_collected)
	_connect_once(EventBus.cooking_finished, _on_cooking_finished)

func _init_quests() -> void:
	# Define starter quests
	all_quests = {
		"slay_slimes": {
			"id": "slay_slimes",
			"title": "Slime Problem",
			"description": "The village elder wants you to clear out some slimes near the village.",
			"objective": "Defeat 5 slimes",
			"type": "kill",
			"target": "slime",
			"target_count": 5,
			"current_count": 0,
			"rewards": {"money": 50, "exp": 100},
			"npc_id": "elder",
		},
		"gather_wood": {
			"id": "gather_wood",
			"title": "Wood Needed",
			"description": "The carpenter needs wood to repair the village fence.",
			"objective": "Gather 10 Wood",
			"type": "collect",
			"target": "wood",
			"target_count": 10,
			"current_count": 0,
			"rewards": {"money": 30, "exp": 75},
			"npc_id": "carpenter",
		},
		"first_meal": {
			"id": "first_meal",
			"title": "Cook's Request",
			"description": "The village cook wants you to make your first dish.",
			"objective": "Cook 1 dish at the campfire",
			"type": "cook",
			"target": "any_dish",
			"target_count": 1,
			"current_count": 0,
			"rewards": {"money": 25, "exp": 50},
			"npc_id": "cook",
		},
		"explore_cave": {
			"id": "explore_cave",
			"title": "Cave Exploration",
			"description": "Miner Torvald asks you to explore the northern mountain cave and mine ores.",
			"objective": "Mine 3 Iron Ores from the northern mountain quarries",
			"type": "collect",
			"target": "iron_ore",
			"target_count": 3,
			"current_count": 0,
			"rewards": {"money": 75, "exp": 150},
			"npc_id": "miner",
		},
		# Every additional scene-authored village NPC has a distinct quest. The
		# existing single-active-quest rule remains intact, but no NPC is left as
		# a purely decorative talk target.
		"farmer_seed": {
			"id": "farmer_seed",
			"title": "Field Fences",
			"description": "Anika needs sturdy wood to keep the seedlings safe.",
			"objective": "Gather 6 Wood",
			"type": "collect",
			"target": "wood",
			"target_count": 6,
			"current_count": 0,
			"rewards": {"money": 24, "exp": 60},
			"npc_id": "farmer",
		},
		"guard_patrol": {
			"id": "guard_patrol",
			"title": "Eastern Patrol",
			"description": "Rook wants the eastern road cleared before the next patrol.",
			"objective": "Defeat 2 Slimes",
			"type": "kill",
			"target": "slime",
			"target_count": 2,
			"current_count": 0,
			"rewards": {"money": 32, "exp": 72},
			"npc_id": "guard",
		},
		"merchant_trade": {
			"id": "merchant_trade",
			"title": "Market Bundle",
			"description": "Lio is preparing a fragrant bundle for visiting traders.",
			"objective": "Gather 3 Herbs",
			"type": "collect",
			"target": "herb",
			"target_count": 3,
			"current_count": 0,
			"rewards": {"money": 34, "exp": 68},
			"npc_id": "merchant",
		},
		"fisher_morning": {
			"id": "fisher_morning",
			"title": "Lake Bait",
			"description": "Mira needs mushrooms for a patient morning by the lake.",
			"objective": "Gather 2 Mushrooms",
			"type": "collect",
			"target": "mushroom",
			"target_count": 2,
			"current_count": 0,
			"rewards": {"money": 28, "exp": 64},
			"npc_id": "fisher",
		},
		"herbalist_remedy": {
			"id": "herbalist_remedy",
			"title": "Village Remedy",
			"description": "Elin is gathering enough herbs for the evening remedy.",
			"objective": "Gather 4 Herbs",
			"type": "collect",
			"target": "herb",
			"target_count": 4,
			"current_count": 0,
			"rewards": {"money": 38, "exp": 78},
			"npc_id": "herbalist",
		},
		"builder_repairs": {
			"id": "builder_repairs",
			"title": "Square Repairs",
			"description": "Oskar needs wood to finish the village square repairs.",
			"objective": "Gather 8 Wood",
			"type": "collect",
			"target": "wood",
			"target_count": 8,
			"current_count": 0,
			"rewards": {"money": 42, "exp": 88},
			"npc_id": "builder",
		},
		"gardener_bloom": {
			"id": "gardener_bloom",
			"title": "Compost Bloom",
			"description": "Suri wants mushrooms to enrich the west garden beds.",
			"objective": "Gather 3 Mushrooms",
			"type": "collect",
			"target": "mushroom",
			"target_count": 3,
			"current_count": 0,
			"rewards": {"money": 30, "exp": 70},
			"npc_id": "gardener",
		},
		"watch_clearance": {
			"id": "watch_clearance",
			"title": "Northern Watch",
			"description": "Bram spotted a few slimes beyond the northern road.",
			"objective": "Defeat 3 Slimes",
			"type": "kill",
			"target": "slime",
			"target_count": 3,
			"current_count": 0,
			"rewards": {"money": 45, "exp": 96},
			"npc_id": "watch",
		},
		"trader_balance": {
			"id": "trader_balance",
			"title": "Bright Ledger",
			"description": "Nia needs gold ore to balance the village market ledger.",
			"objective": "Gather 2 Gold Ore",
			"type": "collect",
			"target": "gold_ore",
			"target_count": 2,
			"current_count": 0,
			"rewards": {"money": 55, "exp": 110},
			"npc_id": "trader",
		},
		"apothecary_tonic": {
			"id": "apothecary_tonic",
			"title": "Tonic Base",
			"description": "Tala is testing a new tonic made from a cooked dish.",
			"objective": "Cook 1 Dish",
			"type": "cook",
			"target": "any_dish",
			"target_count": 1,
			"current_count": 0,
			"rewards": {"money": 36, "exp": 82},
			"npc_id": "apothecary",
		},
		"blacksmith_ore": {
			"id": "blacksmith_ore",
			"title": "Forge Iron",
			"description": "Gunnar needs iron to make a shared village tool.",
			"objective": "Gather 3 Iron Ore",
			"type": "collect",
			"target": "iron_ore",
			"target_count": 3,
			"current_count": 0,
			"rewards": {"money": 48, "exp": 105},
			"npc_id": "blacksmith",
		},
		"traveler_route": {
			"id": "traveler_route",
			"title": "Old Road Proof",
			"description": "Sable wants proof that the eastern ruins route is still safe.",
			"objective": "Gather 1 Mushroom",
			"type": "collect",
			"target": "mushroom",
			"target_count": 1,
			"current_count": 0,
			"rewards": {"money": 40, "exp": 90},
			"npc_id": "traveler",
		},
	}

func accept_quest(quest_id: String) -> bool:
	if not all_quests.has(quest_id) or active_quests.has(quest_id) or completed_quests.has(quest_id):
		return false
	if not active_quests.is_empty():
		var current_id := get_active_quest_id()
		var current: Dictionary = get_active_quest()
		EventBus.show_notification.emit("Finish '%s' before taking another quest." % str(current.get("title", current_id)))
		return false
	var quest_value: Variant = all_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return false
	active_quests[quest_id] = _normalize_quest(quest_value as Dictionary)
	EventBus.quest_accepted.emit(quest_id)
	EventBus.show_notification.emit("Quest accepted: " + str(active_quests[quest_id].get("title", "Quest")))
	return true

func update_quest_progress(quest_type: String, target: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	var quest_id := get_active_quest_id()
	if quest_id.is_empty():
		return
	var quest_value: Variant = active_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return
	var quest: Dictionary = quest_value
	if str(quest.get("type", "")) != quest_type:
		return
	var q_target: String = str(quest.get("target", ""))
	var is_wildcard: bool = q_target == "any_dish" and quest_type == "cook"
	if q_target != target and not is_wildcard:
		return
	var target_count: int = maxi(1, int(quest.get("target_count", 1)))
	var old_count: int = clampi(int(quest.get("current_count", 0)), 0, target_count)
	var new_count: int = mini(target_count, old_count + amount)
	quest["current_count"] = new_count
	EventBus.quest_updated.emit(quest_id)
	if old_count < target_count and new_count >= target_count:
		EventBus.show_notification.emit("Quest ready to complete: " + str(quest.get("title", "Quest")))

func try_complete_quest(quest_id: String) -> bool:
	if not active_quests.has(quest_id):
		return false
	var quest_value: Variant = active_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return false
	var quest: Dictionary = quest_value
	var current_count: int = int(quest.get("current_count", 0))
	var target_count: int = maxi(1, int(quest.get("target_count", 1)))
	if current_count < target_count:
		return false

	var rewards_value: Variant = quest.get("rewards", {})
	var rewards: Dictionary = rewards_value if rewards_value is Dictionary else {}
	var player := GameManager.player
	if player != null and is_instance_valid(player) and player.stats != null:
		if rewards.has("money"):
			player.stats.add_money(int(rewards.get("money", 0)))
		if rewards.has("exp"):
			player.stats.add_exp(int(rewards.get("exp", 0)))

	var completed_quest := quest.duplicate(true)
	completed_quest["completed"] = true
	completed_quests[quest_id] = completed_quest
	active_quests.erase(quest_id)
	EventBus.quest_completed.emit(quest_id)
	EventBus.show_notification.emit("Quest completed: " + str(quest.get("title", "Quest")))
	return true

func debug_force_complete_active() -> bool:
	var quest_id := get_active_quest_id()
	if quest_id.is_empty():
		return false
	var quest_value: Variant = active_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return false
	var quest: Dictionary = quest_value
	quest["current_count"] = maxi(1, int(quest.get("target_count", 1)))
	return try_complete_quest(quest_id)

func debug_skip_active_objective() -> bool:
	var quest_id := get_active_quest_id()
	if quest_id.is_empty():
		return false
	var quest_value: Variant = active_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return false
	var quest: Dictionary = quest_value.duplicate(true)
	quest["completed"] = true
	completed_quests[quest_id] = quest
	active_quests.erase(quest_id)
	EventBus.quest_completed.emit(quest_id)
	EventBus.quest_updated.emit(quest_id)
	EventBus.show_notification.emit("Skipped quest objective: %s" % str(quest.get("title", quest_id)))
	return true

func is_quest_active(quest_id: String) -> bool:
	return active_quests.has(quest_id)
func is_quest_complete(quest_id: String) -> bool:
	if not active_quests.has(quest_id):
		return false
	var quest_value: Variant = active_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return false
	var quest: Dictionary = quest_value
	return int(quest.get("current_count", 0)) >= maxi(1, int(quest.get("target_count", 1)))
func is_quest_done(quest_id: String) -> bool:
	return quest_id in completed_quests

func get_active_quest_id() -> String:
	for quest_id in active_quests:
		return str(quest_id)
	return ""

func get_active_quest() -> Dictionary:
	var quest_id := get_active_quest_id()
	var value: Variant = active_quests.get(quest_id, {})
	return value as Dictionary if value is Dictionary else {}

func has_active_other_than(quest_id: String) -> bool:
	var active_id := get_active_quest_id()
	return not active_id.is_empty() and active_id != quest_id

func get_active_status_text() -> String:
	var quest := get_active_quest()
	if quest.is_empty():
		return ""
	var current := int(quest.get("current_count", 0))
	var required := maxi(1, int(quest.get("target_count", 1)))
	return "%s  %d/%d" % [str(quest.get("objective", "Track your objective")), current, required]

func get_active_waypoint() -> Dictionary:
	var quest := get_active_quest()
	if quest.is_empty():
		return {}
	var quest_id := get_active_quest_id()
	var target_position := _find_quest_target_position(quest)
	var is_complete := is_quest_complete(quest_id)
	var label := "Return to " + _quest_giver_name(str(quest.get("npc_id", ""))) if is_complete else str(quest.get("title", "Quest target"))
	return {
		"position": target_position,
		"valid": _has_quest_target(quest, target_position),
		"label": label,
		"kind": "return" if is_complete else "objective",
		"quest_id": quest_id,
	}

func _has_quest_target(quest: Dictionary, target_position: Vector2) -> bool:
	if target_position != Vector2.ZERO:
		return true
	var quest_id := str(quest.get("id", ""))
	if str(quest.get("type", "")) == "cook" and not get_tree().get_nodes_in_group("cooking_places").is_empty():
		return true
	if is_quest_complete(quest_id):
		var npc_id := str(quest.get("npc_id", ""))
		for npc in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(npc) and npc is Node2D and str(npc.get("npc_id")) == npc_id:
				return true
	return false

func _find_quest_target_position(quest: Dictionary) -> Vector2:
	var quest_id := str(quest.get("id", ""))
	var quest_type := str(quest.get("type", ""))
	var target := str(quest.get("target", ""))
	if is_quest_complete(quest_id):
		return _find_npc_position(str(quest.get("npc_id", "")), Vector2.ZERO)
	if quest_type == "cook":
		var cooking_places := get_tree().get_nodes_in_group("cooking_places")
		var nearest := _nearest_node_position(cooking_places)
		return nearest if nearest != Vector2.ZERO else Vector2.ZERO
	if quest_type == "kill":
		var monsters := get_tree().get_nodes_in_group("monsters")
		var nearest_monster := _nearest_living_position(monsters)
		return nearest_monster if nearest_monster != Vector2.ZERO else Vector2(-760.0, -520.0)
	if quest_type == "collect":
		var candidates := get_tree().get_nodes_in_group("collectables")
		var nearest_collectable := _nearest_matching_position(candidates, target)
		if nearest_collectable != Vector2.ZERO:
			return nearest_collectable
		if target == "iron_ore":
			return Vector2(-2080.0, -2240.0)
		if target == "wood":
			return Vector2(-1664.0, 1024.0)
		if target == "gold_ore":
			return Vector2(-2112.0, -1920.0)
		if target == "herb":
			return Vector2(-1376.0, 640.0)
		if target == "mushroom":
			return Vector2(1520.0, -1424.0)
	return Vector2.ZERO

func _find_npc_position(npc_id: String, fallback: Vector2) -> Vector2:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if str(npc.get("npc_id")) == npc_id and npc is Node2D:
			return (npc as Node2D).global_position
	return fallback

func _quest_giver_name(npc_id: String) -> String:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if str(npc.get("npc_id")) == npc_id:
			var name_value: Variant = npc.get("npc_name")
			return str(name_value) if name_value != null else npc_id.capitalize()
	return npc_id.capitalize()

func _nearest_node_position(nodes: Array) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	var player := GameManager.player
	for node in nodes:
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		var pos := (node as Node2D).global_position
		var distance := player.global_position.distance_squared_to(pos) if player and is_instance_valid(player) else pos.length_squared()
		if distance < best_distance:
			best_distance = distance
			best = pos
	return best

func _nearest_living_position(nodes: Array) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	var player := GameManager.player
	for node in nodes:
		if not (node is BaseMonster) or not is_instance_valid(node):
			continue
		if (node as BaseMonster).current_state == BaseMonster.State.DEAD:
			continue
		var pos := (node as Node2D).global_position
		var distance := player.global_position.distance_squared_to(pos) if player and is_instance_valid(player) else pos.length_squared()
		if distance < best_distance:
			best_distance = distance
			best = pos
	return best

func _nearest_matching_position(nodes: Array, target: String) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	var player := GameManager.player
	for node in nodes:
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		if bool(node.get("is_collected")):
			continue
		var item_id_value: Variant = node.get("item_id")
		if item_id_value != null and str(item_id_value) == target:
			var pos := (node as Node2D).global_position
			var distance := player.global_position.distance_squared_to(pos) if player and is_instance_valid(player) else pos.length_squared()
			if distance < best_distance:
				best_distance = distance
				best = pos
	return best

func get_save_data() -> Dictionary:
	return {
		"active": {get_active_quest_id(): get_active_quest().duplicate(true)} if not get_active_quest_id().is_empty() else {},
		"completed": completed_quests.duplicate(true),
	}

func _normalize_quest(quest: Dictionary, base: Dictionary = {}) -> Dictionary:
	var result := base.duplicate(true)
	for key in quest:
		result[key] = quest[key]
	result["id"] = str(result.get("id", ""))
	result["type"] = str(result.get("type", ""))
	result["target"] = str(result.get("target", ""))
	var target_count := maxi(1, int(result.get("target_count", 1)))
	result["target_count"] = target_count
	result["current_count"] = clampi(int(result.get("current_count", 0)), 0, target_count)
	if bool(result.get("completed", false)):
		result["completed"] = true
	var rewards: Variant = result.get("rewards", {})
	result["rewards"] = rewards.duplicate(true) if rewards is Dictionary else {}
	return result
func _copy_quest_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	var source: Dictionary = value
	var copied_count := 0
	for quest_id in source:
		if copied_count >= MAX_SAVED_QUESTS:
			break
		var quest_value: Variant = source.get(quest_id, {})
		if quest_value is Dictionary:
			result[str(quest_id)] = (quest_value as Dictionary).duplicate(true)
			copied_count += 1
	return result

func load_save_data(data: Dictionary) -> void:
	active_quests.clear()
	completed_quests.clear()
	var saved_completed := _copy_quest_map(data.get("completed", {}))
	for quest_id in saved_completed:
		if all_quests.has(quest_id):
			var completed_quest := _normalize_quest(saved_completed[quest_id], all_quests[quest_id])
			completed_quest["completed"] = true
			completed_quests[quest_id] = completed_quest
	var saved_active := _copy_quest_map(data.get("active", {}))
	# Legacy saves could contain several active quests. Keep only the first
	# stable dictionary entry so the current design remains single-objective.
	for quest_id in saved_active:
		if all_quests.has(quest_id) and not completed_quests.has(quest_id):
			active_quests[quest_id] = _normalize_quest(saved_active[quest_id], all_quests[quest_id])
			break

func _connect_once(signal_value: Signal, handler: Callable) -> void:
	if not signal_value.is_connected(handler):
		signal_value.connect(handler)

func _on_monster_killed(monster: Node, _position: Vector2) -> void:
	var target := "monster"
	if monster and monster.has_meta("quest_target"):
		target = str(monster.get_meta("quest_target"))
	elif monster is SlimeMonster:
		# Moss, ember and crystal variants are still slimes for quest purposes.
		target = "slime"
	elif monster and monster.has_meta("variant"):
		target = str(monster.get_meta("variant"))
	update_quest_progress("kill", target, 1)

func _on_item_collected(item_data: Dictionary) -> void:
	update_quest_progress("collect", str(item_data.get("id", "")), int(item_data.get("quantity", 1)))

func _on_cooking_finished(result: Dictionary) -> void:
	update_quest_progress("cook", str(result.get("id", "dish")), 1)
