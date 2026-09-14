extends Node

enum GameState { MAIN_MENU, PLAYING, PAUSED, GAME_OVER, LOADING }

var current_state: GameState = GameState.MAIN_MENU
var is_paused: bool = false

# Time system
var game_time_hours: float = 8.0  # Start at 8 AM
var day_count: int = 1
var time_scale: float = 60.0  # 1 real second = 1 game minute
var is_night: bool = false

# Player reference
var player: CharacterBody2D = null
var village_spawn_point: Vector2 = Vector2(0, 0)

# Waystones
var unlocked_waystones: Dictionary = {}
var opened_caches: Array = []

# Throttle time_changed: only emit when the displayed minute actually changes
var _last_emit_hour: int = -1
var _last_emit_minute: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if current_state == GameState.MAIN_MENU or current_state == GameState.GAME_OVER or current_state == GameState.LOADING:
		return
	if event.is_action_pressed("pause"):
		EventBus.pause_toggled.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		EventBus.inventory_toggled.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quest"):
		EventBus.quest_menu_toggled.emit()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	if get_tree().paused:
		return
	_update_time(delta)

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
	if player:
		player.global_position = village_spawn_point
		player.respawn()
	set_state(GameState.PLAYING)
	EventBus.player_respawned.emit()

func register_waystone(id: String, position: Vector2, display_name: String) -> void:
	if id.is_empty():
		return
	unlocked_waystones[id] = {"position": position, "name": display_name}
	EventBus.waystone_activated.emit(id)

func fast_travel_to(waystone_id: String) -> void:
	if not unlocked_waystones.has(waystone_id):
		return
	var data_value: Variant = unlocked_waystones.get(waystone_id, {})
	if not (data_value is Dictionary):
		return
	var data: Dictionary = data_value
	if player and is_instance_valid(player):
		var destination_value: Variant = data.get("position", Vector2.ZERO)
		var destination: Vector2 = destination_value if destination_value is Vector2 else Vector2.ZERO
		player.global_position = destination + Vector2(0, 44)
		player.velocity = Vector2.ZERO
		if is_instance_valid(player.camera):
			player.camera.reset_smoothing()
	EventBus.fast_travel_requested.emit(waystone_id)

func get_time_string() -> String:
	var hour := int(game_time_hours)
	var minute := int((game_time_hours - hour) * 60)
	return "%02d:%02d" % [hour, minute]

func get_save_data() -> Dictionary:
	return {
		"game_time_hours": game_time_hours,
		"day_count": day_count,
		"unlocked_waystones": unlocked_waystones.keys(),
		"opened_caches": opened_caches.duplicate(),
	}

func load_save_data(data: Dictionary) -> void:
	var saved_hours: float = float(data.get("game_time_hours", 8.0))
	game_time_hours = fmod(maxf(saved_hours, 0.0), 24.0)
	day_count = maxi(1, int(data.get("day_count", 1)))

	var ids: Array[String] = []
	var saved_waystones: Variant = data.get("unlocked_waystones", [])
	if saved_waystones is Dictionary:
		for key in (saved_waystones as Dictionary).keys():
			var waystone_id := str(key)
			if not waystone_id.is_empty() and not ids.has(waystone_id):
				ids.append(waystone_id)
	elif saved_waystones is Array:
		for raw_id in saved_waystones:
			var waystone_id := str(raw_id)
			if not waystone_id.is_empty() and not ids.has(waystone_id):
				ids.append(waystone_id)

	unlocked_waystones.clear()
	for stone_value in get_tree().get_nodes_in_group("waystones"):
		if not (stone_value is Waystone):
			continue
		var stone: Waystone = stone_value as Waystone
		stone.is_unlocked = stone.waystone_id == "village" or ids.has(stone.waystone_id)
		if stone.is_unlocked:
			register_waystone(stone.waystone_id, stone.global_position, stone.display_name)

	opened_caches.clear()
	var saved_caches: Variant = data.get("opened_caches", [])
	if saved_caches is Array:
		for raw_cache_id in saved_caches:
			var cache_id := str(raw_cache_id)
			if not cache_id.is_empty() and not opened_caches.has(cache_id):
				opened_caches.append(cache_id)
	_last_emit_hour = -1
	_last_emit_minute = -1
