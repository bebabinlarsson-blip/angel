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
	if quest_id in all_quests and quest_id not in active_quests and quest_id not in completed_quests:
		active_quests[quest_id] = all_quests[quest_id].duplicate(true)
		EventBus.quest_accepted.emit(quest_id)
		EventBus.show_notification.emit("Quest accepted: " + active_quests[quest_id]["title"])
		return true
	return false

func update_quest_progress(quest_type: String, target: String, amount: int = 1) -> void:
	for quest_id in active_quests:
		var quest: Dictionary = active_quests[quest_id]
		if quest.get("type", "") != quest_type:
			continue
		var q_target: String = str(quest.get("target", ""))
		# "any_dish" is only a wildcard for cook quests, not collect/kill.
		var is_wildcard: bool = q_target == "any_dish" and quest_type == "cook"
		if q_target == target or is_wildcard:
			quest["current_count"] = mini(quest.get("current_count", 0) + amount, quest.get("target_count", 1))
			EventBus.quest_updated.emit(quest_id)
			
			if quest["current_count"] >= quest["target_count"]:
				EventBus.show_notification.emit("Quest ready to complete: " + quest["title"])

func try_complete_quest(quest_id: String) -> bool:
	if quest_id in active_quests:
		var quest: Dictionary = active_quests[quest_id]
		if quest["current_count"] >= quest["target_count"]:
			# Give rewards
			var rewards: Dictionary = quest.get("rewards", {})
			if GameManager.player:
				if rewards.has("money"):
					GameManager.player.stats.add_money(rewards["money"])
				if rewards.has("exp"):
					GameManager.player.stats.add_exp(rewards["exp"])
			
			completed_quests[quest_id] = quest
			active_quests.erase(quest_id)
			EventBus.quest_completed.emit(quest_id)
			EventBus.show_notification.emit("Quest completed: " + quest["title"])
			return true
	return false

func is_quest_active(quest_id: String) -> bool:
	return quest_id in active_quests

func is_quest_complete(quest_id: String) -> bool:
	if quest_id in active_quests:
		var quest: Dictionary = active_quests[quest_id]
		return quest["current_count"] >= quest["target_count"]
	return false

func is_quest_done(quest_id: String) -> bool:
	return quest_id in completed_quests

func get_save_data() -> Dictionary:
	return {
		"active": active_quests,
		"completed": completed_quests,
	}

func load_save_data(data: Dictionary) -> void:
	active_quests = data.get("active", {})
	completed_quests = data.get("completed", {})
