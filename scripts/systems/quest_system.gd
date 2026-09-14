class_name QuestSystem
extends Node

var all_quests: Dictionary = {}
var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}

func _ready() -> void:
	_init_quests()

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
	}

func accept_quest(quest_id: String) -> bool:
	if not all_quests.has(quest_id) or active_quests.has(quest_id) or completed_quests.has(quest_id):
		return false
	var quest_value: Variant = all_quests.get(quest_id, {})
	if not (quest_value is Dictionary):
		return false
	active_quests[quest_id] = (quest_value as Dictionary).duplicate(true)
	EventBus.quest_accepted.emit(quest_id)
	EventBus.show_notification.emit("Quest accepted: " + str(active_quests[quest_id].get("title", "Quest")))
	return true
func update_quest_progress(quest_type: String, target: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	for quest_id in active_quests:
		var quest_value: Variant = active_quests.get(quest_id, {})
		if not (quest_value is Dictionary):
			continue
		var quest: Dictionary = quest_value
		if str(quest.get("type", "")) != quest_type:
			continue
		var q_target: String = str(quest.get("target", ""))
		var is_wildcard: bool = q_target == "any_dish" and quest_type == "cook"
		if q_target != target and not is_wildcard:
			continue
		var target_count: int = maxi(1, int(quest.get("target_count", 1)))
		var old_count: int = clampi(int(quest.get("current_count", 0)), 0, target_count)
		var new_count: int = mini(target_count, old_count + amount)
		quest["current_count"] = new_count
		EventBus.quest_updated.emit(str(quest_id))
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
	if GameManager.player and GameManager.player.stats:
		if rewards.has("money"):
			GameManager.player.stats.add_money(int(rewards.get("money", 0)))
		if rewards.has("exp"):
			GameManager.player.stats.add_exp(int(rewards.get("exp", 0)))

	completed_quests[quest_id] = quest.duplicate(true)
	active_quests.erase(quest_id)
	EventBus.quest_completed.emit(quest_id)
	EventBus.show_notification.emit("Quest completed: " + str(quest.get("title", "Quest")))
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

func get_save_data() -> Dictionary:
	return {
		"active": active_quests.duplicate(true),
		"completed": completed_quests.duplicate(true),
	}
func _copy_quest_map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	var source: Dictionary = value
	for quest_id in source:
		var quest_value: Variant = source.get(quest_id, {})
		if quest_value is Dictionary:
			result[str(quest_id)] = (quest_value as Dictionary).duplicate(true)
	return result

func load_save_data(data: Dictionary) -> void:
	active_quests = _copy_quest_map(data.get("active", {}))
	completed_quests = _copy_quest_map(data.get("completed", {}))
