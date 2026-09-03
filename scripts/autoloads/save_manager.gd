extends Node

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "save_slot_%d.json"
const MAX_SLOTS := 3

func _ready() -> void:
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_warning("SaveManager: could not create save dir (%s)" % error_string(err))

func save_game(slot: int = 0) -> bool:
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	var quest_data: Dictionary = quest_system.get_save_data() if quest_system else {}
	
	var save_data := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_manager": GameManager.get_save_data(),
		"player": _get_player_save_data(),
		"quests": quest_data,
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
	
	var save_data: Dictionary = json.data
	GameManager.load_save_data(save_data.get("game_manager", {}))
	_load_player_save_data(save_data.get("player", {}))
	
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system and save_data.has("quests"):
		quest_system.load_save_data(save_data["quests"])
	
	EventBus.game_loaded.emit()
	EventBus.show_notification.emit("Game loaded!")
	return true

func has_save(slot: int = 0) -> bool:
	var path := SAVE_DIR + SAVE_FILE % slot
	return FileAccess.file_exists(path)

func delete_save(slot: int = 0) -> void:
	var path := SAVE_DIR + SAVE_FILE % slot
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err != OK:
			push_warning("SaveManager: could not delete %s (%s)" % [path, error_string(err)])

func get_save_info(slot: int = 0) -> Dictionary:
	var path := SAVE_DIR + SAVE_FILE % slot
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"timestamp": data.get("timestamp", "Unknown"),
		"day": data.get("game_manager", {}).get("day_count", 1),
	}

func _get_player_save_data() -> Dictionary:
	var player := GameManager.player
	if player == null:
		return {}
	return player.get_save_data()

func _load_player_save_data(data: Dictionary) -> void:
	var player := GameManager.player
	if player:
		player.load_save_data(data)