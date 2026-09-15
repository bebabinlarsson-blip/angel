extends Node

const SAVE_DIR := "user://saves/"
const SAVE_FILE := "save_slot_%d.json"
const MAX_SLOTS := 3
const MAX_SAVE_BYTES := 8 * 1024 * 1024

func _ready() -> void:
	var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if err != OK:
		push_warning("SaveManager: could not create save dir (%s)" % error_string(err))

func save_game(slot: int = 0) -> bool:
	slot = clampi(slot, 0, MAX_SLOTS - 1)
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	var quest_data: Dictionary = quest_system.get_save_data() if quest_system else GameManager.pending_quest_data.duplicate(true)
	var player_data := _get_player_save_data()
	if GameManager.is_interior and not player_data.is_empty():
		# A save can be created from a paused interior, but the next load starts
		# in game.tscn. Store the safe doorway position instead of an interior
		# coordinate that would place the player in the overworld ocean/terrain.
		player_data["position"] = {"x": GameManager.return_position.x, "y": GameManager.return_position.y}
	var world_data: Dictionary = _get_world_save_data()

	var save_data := {
		"version": 3,
		"timestamp": Time.get_datetime_string_from_system(),
		"game_manager": GameManager.get_save_data(),
		"player": player_data,
		"quests": quest_data,
		"world": world_data,
	}
	var json_string := JSON.stringify(save_data, "\t")
	if json_string.to_utf8_buffer().size() > MAX_SAVE_BYTES:
		push_error("Save data exceeds the %d-byte safety limit" % MAX_SAVE_BYTES)
		return false

	var path := SAVE_DIR + SAVE_FILE % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file: " + path)
		return false
	
	file.store_string(json_string)
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		push_error("Failed to write save file: " + path)
		return false
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
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		push_error("Save file is too large: " + path)
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
		GameManager.load_save_data(game_manager_value as Dictionary)
	var quest_value: Variant = save_data.get("quests", {})
	if quest_value is Dictionary:
		GameManager.cache_quest_transfer(quest_value)
	var world_value: Variant = save_data.get("world", {})
	if world_value is Dictionary:
		var world_data: Dictionary = (world_value as Dictionary).duplicate(true)
		var director := get_tree().root.find_child("WorldDirector", true, false)
		if director and director.has_method("load_save_data"):
			director.load_save_data(world_data)
		else:
			GameManager.pending_world_data = world_data
	var player_value: Variant = save_data.get("player", {})
	if player_value is Dictionary:
		_load_player_save_data(player_value as Dictionary)
	
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system and quest_value is Dictionary:
		quest_system.load_save_data(quest_value as Dictionary)
		GameManager.pending_quest_data.clear()
	
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
	if file.get_length() > MAX_SAVE_BYTES:
		file.close()
		return {}
	var json := JSON.new()
	var result := json.parse(file.get_as_text())
	file.close()
	if result != OK:
		return {}
	if not (json.data is Dictionary):
		return {}
	var data: Dictionary = json.data
	var game_manager_info: Dictionary = data.get("game_manager", {}) if data.get("game_manager", {}) is Dictionary else {}
	return {
		"timestamp": data.get("timestamp", "Unknown"),
		"day": game_manager_info.get("day_count", 1),
	}

func _get_player_save_data() -> Dictionary:
	var player := GameManager.player
	if player == null or not is_instance_valid(player) or not player.has_method("get_save_data"):
		return {}
	return player.get_save_data()

func _get_world_save_data() -> Dictionary:
	var director := get_tree().root.find_child("WorldDirector", true, false)
	if director and director.has_method("get_save_data"):
		var value: Variant = director.get_save_data()
		if value is Dictionary:
			return value
	return GameManager.pending_world_data.duplicate(true)

func _load_player_save_data(data: Dictionary) -> void:
	var player := GameManager.player
	if player != null and is_instance_valid(player) and player.has_method("load_save_data"):
		player.load_save_data(data)
