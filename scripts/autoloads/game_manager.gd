extends Node

enum GameState { MAIN_MENU, PLAYING, PAUSED, GAME_OVER, LOADING }

var current_state: GameState = GameState.MAIN_MENU
var is_paused: bool = false

# Time system
var game_time_hours: float = 8.0  # Start at 8 AM
var day_count: int = 1
var time_scale: float = 60.0  # 1 real second = 1 game minute
var is_night: bool = false
var admin_freeze_time: bool = false
var admin_god_mode: bool = false
var admin_no_clip: bool = false
var admin_free_camera: bool = false

# Player reference
var player: CharacterBody2D = null
var village_spawn_point: Vector2 = Vector2(0, 0)

# Scene-transfer state. The overworld is intentionally rebuilt when entering
# an interior, so these compact snapshots carry the player, quest and streamed
# world state across the scene boundary without keeping two gameplay trees
# alive at once.
var pending_player_data: Dictionary = {}
var pending_quest_data: Dictionary = {}
var pending_world_data: Dictionary = {}
var return_scene_path: String = "res://scenes/game.tscn"
var return_position: Vector2 = Vector2.ZERO
var current_interior_id: String = ""
var current_location_name: String = "Angel Village"
var is_interior: bool = false

# Waystones
var unlocked_waystones: Dictionary = {}
# A save can be loaded from the main menu before the overworld waystone nodes
# exist. Keep the IDs separately until those nodes register their world-space
# positions; otherwise Continue silently loses every unlocked stone except the
# one that happens to be present while the save is read.
var pending_waystone_ids: Dictionary = {}
var opened_caches: Array = []
const MAX_SAVED_WAYSTONES := 32
const MAX_OPENED_CACHES := 512

# Throttle time_changed: only emit when the displayed minute actually changes
var _last_emit_hour: int = -1
var _last_emit_minute: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if current_state not in [GameState.PLAYING, GameState.PAUSED]:
		return
	if event.is_action_pressed("pause"):
		if _close_modal_overlay():
			if current_state == GameState.PLAYING:
				set_state(GameState.PLAYING)
			get_viewport().set_input_as_handled()
			return
		# A custom modal can consume Escape in its own _input callback before
		# this autoload reaches _unhandled_input. If it already closed, the
		# gameplay state is still PLAYING while the tree remains paused.
		if current_state == GameState.PLAYING and get_tree().paused:
			set_state(GameState.PLAYING)
			get_viewport().set_input_as_handled()
			return
		EventBus.pause_toggled.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if current_state == GameState.PAUSED or _has_modal_overlay():
			get_viewport().set_input_as_handled()
			return
		EventBus.inventory_toggled.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quest"):
		if current_state == GameState.PAUSED or _has_modal_overlay():
			get_viewport().set_input_as_handled()
			return
		EventBus.quest_menu_toggled.emit()
		get_viewport().set_input_as_handled()

func _is_visible_overlay(node: Node) -> bool:
	if node is Control:
		return (node as Control).visible
	if node is CanvasLayer:
		return (node as CanvasLayer).visible
	return false

func _has_modal_overlay() -> bool:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and npc.has_method("_close_dialogue") and bool(npc.get("is_dialogue_open")):
			return true
	for overlay_name: String in ["CookingUILayer", "FastTravelLayer", "BigMap", "InventoryUI", "QuestMenu"]:
		var overlay := get_tree().root.find_child(overlay_name, true, false)
		if overlay != null and _is_visible_overlay(overlay):
			return true
	return false

func _close_modal_overlay() -> bool:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc) and npc.has_method("_close_dialogue") and bool(npc.get("is_dialogue_open")):
			npc.call("_close_dialogue")
			return true
	for overlay_data: Array in [["CookingUILayer", "_close_cooking"], ["FastTravelLayer", "_close_fast_travel"], ["BigMap", "close_map_modal"], ["InventoryUI", "_toggle"], ["QuestMenu", "_toggle"]]:
		var overlay := get_tree().root.find_child(str(overlay_data[0]), true, false)
		if overlay == null or not _is_visible_overlay(overlay):
			continue
		var owner_node := overlay.get_parent()
		if overlay.has_method(str(overlay_data[1])):
			overlay.call(str(overlay_data[1]))
			return true
		if owner_node != null and owner_node.has_method(str(overlay_data[1])):
			owner_node.call(str(overlay_data[1]))
			return true
	return false

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	if get_tree().paused:
		return
	if admin_freeze_time:
		return
	_update_time(delta)

func set_admin_time(hours: float) -> void:
	game_time_hours = fposmod(hours, 24.0)
	var hour := int(game_time_hours)
	var minute := int((game_time_hours - hour) * 60.0)
	_last_emit_hour = hour
	_last_emit_minute = minute
	time_changed.emit(hour, minute)
	var was_night := is_night
	is_night = hour >= 20 or hour < 6
	if was_night != is_night:
		day_night_changed.emit(is_night)

func _update_time(delta: float) -> void:
	game_time_hours += (delta * time_scale) / 3600.0
	if game_time_hours >= 24.0:
		game_time_hours -= 24.0
		day_count += 1

	var hour := int(game_time_hours)
	var minute := int((game_time_hours - hour) * 60)
	# Perf: was emitting every frame (~60/s) -> HUD + CanvasModulate redo.
	# Now only emit when the visible minute flips (~1/min game-time).
	if hour != _last_emit_hour or minute != _last_emit_minute:
		_last_emit_hour = hour
		_last_emit_minute = minute
		EventBus.time_changed.emit(hour, minute)

	var was_night := is_night
	is_night = hour >= 20 or hour < 6
	if is_night != was_night:
		EventBus.day_night_changed.emit(is_night)

func set_state(new_state: GameState) -> void:
	current_state = new_state
	match new_state:
		GameState.MAIN_MENU:
			get_tree().paused = false
			is_paused = false
		GameState.LOADING:
			get_tree().paused = false
			is_paused = false
		GameState.PAUSED:
			get_tree().paused = true
			is_paused = true
		GameState.PLAYING:
			get_tree().paused = false
			is_paused = false
		GameState.GAME_OVER:
			get_tree().paused = true
			is_paused = true

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		set_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		set_state(GameState.PLAYING)

func game_over() -> void:
	if current_state == GameState.GAME_OVER:
		return
	set_state(GameState.GAME_OVER)
	EventBus.player_died.emit()

func respawn_player() -> void:
	if player and is_instance_valid(player):
		player.global_position = village_spawn_point
		player.respawn()
	set_state(GameState.PLAYING)
	EventBus.player_respawned.emit()

func register_waystone(id: String, position: Vector2, display_name: String) -> void:
	if id.is_empty():
		return
	pending_waystone_ids.erase(id)
	unlocked_waystones[id] = {"position": position, "name": display_name}
	EventBus.waystone_activated.emit(id)

func is_waystone_unlocked(id: String) -> bool:
	return id in unlocked_waystones or id in pending_waystone_ids

func fast_travel_to(waystone_id: String) -> void:
	if is_interior or current_state != GameState.PLAYING:
		return
	if waystone_id in unlocked_waystones:
		var data: Dictionary = unlocked_waystones[waystone_id]
		if player and is_instance_valid(player):
			player.global_position = data["position"] + Vector2(0, 44)
			player.velocity = Vector2.ZERO
			if is_instance_valid(player.camera):
				player.camera.reset_smoothing()
		EventBus.fast_travel_requested.emit(waystone_id)

func get_time_string() -> String:
	var hour := int(game_time_hours)
	var minute := int((game_time_hours - hour) * 60)
	return "%02d:%02d" % [hour, minute]

func get_save_data() -> Dictionary:
	var saved_waystone_ids: Array = unlocked_waystones.keys()
	for pending_id in pending_waystone_ids:
		if pending_id not in saved_waystone_ids:
			saved_waystone_ids.append(pending_id)
	return {
		"game_time_hours": game_time_hours,
		"day_count": day_count,
		"unlocked_waystones": saved_waystone_ids,
		"opened_caches": opened_caches.duplicate(),
		# Saves always resume in the overworld. If the player saved inside a
		# building, SaveManager replaces the player position with return_position.
		"location": "interior" if is_interior else "overworld",
		"return_scene_path": return_scene_path,
		"return_position": {"x": return_position.x, "y": return_position.y},
	}

func load_save_data(data: Dictionary) -> void:
	var saved_time := float(data.get("game_time_hours", 8.0))
	game_time_hours = 8.0 if is_nan(saved_time) or is_inf(saved_time) else clampf(saved_time, 0.0, 23.999)
	day_count = maxi(1, int(data.get("day_count", 1)))
	var saved: Variant = data.get("unlocked_waystones", [])
	var ids: Array = saved.keys() if saved is Dictionary else (saved if saved is Array else [])
	unlocked_waystones.clear()
	pending_waystone_ids.clear()
	pending_waystone_ids["village"] = true
	for raw_id in ids:
		if pending_waystone_ids.size() >= MAX_SAVED_WAYSTONES:
			break
		var saved_id := str(raw_id)
		if saved_id.length() <= 64 and not saved_id.is_empty():
			pending_waystone_ids[saved_id] = true
	for stone: Node in get_tree().get_nodes_in_group("waystones"):
		stone.is_unlocked = stone.waystone_id == "village" or is_waystone_unlocked(stone.waystone_id)
		if stone.is_unlocked:
			register_waystone(stone.waystone_id, stone.global_position, stone.display_name)
	var saved_caches: Variant = data.get("opened_caches", [])
	opened_caches.clear()
	if saved_caches is Array:
		for raw_cache_id in saved_caches:
			if opened_caches.size() >= MAX_OPENED_CACHES:
				break
			var cache_id := str(raw_cache_id)
			if cache_id.length() <= 64 and not cache_id.is_empty() and cache_id not in opened_caches:
				opened_caches.append(cache_id)
	# Loading from the main menu always targets the overworld, even if the
	# previous save was made while the player stood in an interior.
	is_interior = false
	current_interior_id = ""
	current_location_name = "Angel Village"
	_last_emit_hour = -1
	_last_emit_minute = -1

func begin_interior_transfer(scene_path: String, destination_position: Vector2, source_player: Node, source_quest: Node, interior_id: String, location_name: String) -> bool:
	if is_interior or current_state != GameState.PLAYING:
		return false
	if source_player == null or not is_instance_valid(source_player):
		return false
	if not scene_path.begins_with("res://") or not ResourceLoader.exists(scene_path):
		push_error("GameManager: interior scene does not exist: " + scene_path)
		return false

	var snapshot: Dictionary = source_player.get_save_data() if source_player and source_player.has_method("get_save_data") else {}
	if snapshot.is_empty():
		return false
	pending_player_data = snapshot.duplicate(true)
	pending_player_data["position"] = {"x": destination_position.x, "y": destination_position.y}
	pending_quest_data = source_quest.get_save_data().duplicate(true) if source_quest and is_instance_valid(source_quest) and source_quest.has_method("get_save_data") else {}
	var director := get_tree().root.find_child("WorldDirector", true, false)
	pending_world_data = director.get_save_data().duplicate(true) if director and is_instance_valid(director) and director.has_method("get_save_data") else {}

	var current_scene := get_tree().current_scene
	if current_scene and not current_scene.scene_file_path.is_empty():
		return_scene_path = current_scene.scene_file_path
	if source_player is Node2D:
		return_position = (source_player as Node2D).global_position + Vector2(0, 72)
	else:
		return_position = village_spawn_point
	current_interior_id = interior_id
	current_location_name = location_name
	is_interior = true
	set_state(GameState.LOADING)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		_clear_transfer_state()
		set_state(GameState.PLAYING)
		push_error("GameManager: failed to enter interior (%s)" % error_string(err))
		return false
	return true

func exit_interior(source_player: Node, source_quest: Node) -> bool:
	if not is_interior or return_scene_path.is_empty() or not ResourceLoader.exists(return_scene_path):
		return false
	if source_player == null or not is_instance_valid(source_player):
		return false
	var snapshot: Dictionary = source_player.get_save_data() if source_player and source_player.has_method("get_save_data") else {}
	if snapshot.is_empty():
		return false
	var previous_interior_id := current_interior_id
	var previous_location_name := current_location_name
	pending_player_data = snapshot.duplicate(true)
	pending_player_data["position"] = {"x": return_position.x, "y": return_position.y}
	pending_quest_data = source_quest.get_save_data().duplicate(true) if source_quest and is_instance_valid(source_quest) and source_quest.has_method("get_save_data") else {}
	is_interior = false
	current_interior_id = ""
	current_location_name = "Angel Village"
	set_state(GameState.LOADING)
	var err := get_tree().change_scene_to_file(return_scene_path)
	if err != OK:
		is_interior = true
		current_interior_id = previous_interior_id
		current_location_name = previous_location_name
		set_state(GameState.PLAYING)
		push_error("GameManager: failed to exit interior (%s)" % error_string(err))
		return false
	return true

func consume_player_transfer(target: Node) -> bool:
	if pending_player_data.is_empty() or target == null or not is_instance_valid(target) or not target.has_method("load_save_data"):
		return false
	target.load_save_data(pending_player_data)
	pending_player_data.clear()
	return true

func consume_quest_transfer(target: Node) -> bool:
	if pending_quest_data.is_empty() or target == null or not is_instance_valid(target) or not target.has_method("load_save_data"):
		return false
	target.load_save_data(pending_quest_data)
	pending_quest_data.clear()
	return true

func consume_world_transfer(target: Node) -> bool:
	if pending_world_data.is_empty() or target == null or not is_instance_valid(target) or not target.has_method("load_save_data"):
		return false
	target.load_save_data(pending_world_data)
	pending_world_data.clear()
	return true

func cache_quest_transfer(data: Variant) -> void:
	if data is Dictionary:
		pending_quest_data = (data as Dictionary).duplicate(true)

func _clear_transfer_state() -> void:
	pending_player_data.clear()
	pending_quest_data.clear()
	pending_world_data.clear()
	current_interior_id = ""
	current_location_name = "Angel Village"
	is_interior = false
