extends Node

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "save_slot_%d.json"
const MAX_SLOTS := 3

func _ready() -> void:
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_warning("SaveManager: could not create save dir (%s)" % error_string(err))

func save_game(slot: int = 0) -> bool:
	slot = clampi(slot, 0, MAX_SLOTS - 1)
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	var quest_data: Dictionary = quest_system.get_save_data() if quest_system else {}
	
	var save_data := {
		"version": 2,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_manager": GameManager.get_save_data(),
		"player": _get_player_save_data(),
		"quests": quest_data,
		"world": _get_world_save_data(),
	}
	
	var path := SAVE_DIR + SAVE_FILE % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: " + path)
		return false
	
	var json_string := JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	EventBus.game_saved.emit()
	EventBus.show_notification.emit("Game saved!")
	return true

func load_game(slot: int = 0) -> bool:
	slot = clampi(slot, 0, MAX_SLOTS - 1)
	var path := SAVE_DIR + SAVE_FILE % slot
	if not FileAccess.file_exists(path):
		push_error("No save file found: " + path)
		return false
	
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var result := json.parse(json_string)
	if result != OK:
		push_error("Failed to parse save file")
		return false
	
	if not (json.data is Dictionary):
		push_error("Save file root is not a dictionary")
		return false
	var save_data: Dictionary = json.data
	var game_manager_value: Variant = save_data.get("game_manager", {})
	if game_manager_value is Dictionary:
		GameManager.load_save_data(game_manager_value)
	var player_value: Variant = save_data.get("player", {})
	if player_value is Dictionary:
		_load_player_save_data(player_value)

	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	var quest_value: Variant = save_data.get("quests", {})
	if quest_system and quest_value is Dictionary:
		quest_system.load_save_data(quest_value)

	var world_director := get_tree().root.find_child("WorldDirector", true, false) as WorldDirector
	var world_value: Variant = save_data.get("world", {})
	if world_director and world_value is Dictionary:
		world_director.load_save_data(world_value)
	
	EventBus.game_loaded.emit()
	EventBus.show_notification.emit("Game loaded!")
	return true

func has_save(slot: int = 0) -> bool:
	slot = clampi(slot, 0, MAX_SLOTS - 1)
	var path := SAVE_DIR + SAVE_FILE % slot
	return FileAccess.file_exists(path)

func delete_save(slot: int = 0) -> void:
	slot = clampi(slot, 0, MAX_SLOTS - 1)
	var path := SAVE_DIR + SAVE_FILE % slot
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_warning("SaveManager: could not delete %s (%s)" % [path, error_string(err)])

func get_save_info(slot: int = 0) -> Dictionary:
	slot = clampi(slot, 0, MAX_SLOTS - 1)
	var path := SAVE_DIR + SAVE_FILE % slot
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK or not (json.data is Dictionary):
		return {}
	var data: Dictionary = json.data
	var manager_value: Variant = data.get("game_manager", {})
	var day: int = 1
	if manager_value is Dictionary:
		day = maxi(1, int((manager_value as Dictionary).get("day_count", 1)))
	return {
		"timestamp": str(data.get("timestamp", "Unknown")),
		"day": day,
	}

func _get_player_save_data() -> Dictionary:
	var player := GameManager.player
	if player == null or not is_instance_valid(player):
		return {}
	return player.get_save_data()

func _load_player_save_data(data: Dictionary) -> void:
	var player := GameManager.player
	if player != null and is_instance_valid(player):
		player.load_save_data(data)
func _get_world_save_data() -> Dictionary:
	var director := get_tree().root.find_child("WorldDirector", true, false) as WorldDirector
	if director == null or not is_instance_valid(director) or not director.has_method("get_save_data"):
		return {}
	var value: Variant = director.call("get_save_data")
	if value is Dictionary:
		return value
	return {}

