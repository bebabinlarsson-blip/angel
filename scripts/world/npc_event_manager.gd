class_name NPCEventManager
extends Node

## Low-frequency director for ambient NPC life.
##
## NPCs keep their visible miniature scene and dialogue logic. This manager
## only makes bounded decisions, then asks nearby NPCs to move to a shared
## point and use an ambient action. Distant NPC scripts are tick-slept by the
## LOD pass, and no event creates a second AI tree or a permanent crowd node.

const EVENT_TICK_SECONDS := 1.5
const FULL_SIMULATION_RADIUS := 1150.0
const EVENT_DISCOVERY_RADIUS := 940.0
const MAX_ACTIVE_EVENTS := 2
const MAX_PARTICIPANTS := 6

const EVENT_DEFINITIONS: Array[Dictionary] = [
	{"id": "campfire_gathering", "label": "Chatting around the fire", "window": "evening", "anchor": "campfire", "min": 2, "max": 5, "duration": 52.0, "weight": 4.0, "action": "conversation"},
	{"id": "shared_meal", "label": "Sharing a late meal", "window": "evening", "anchor": "campfire", "min": 2, "max": 4, "duration": 44.0, "weight": 2.2, "action": "eating"},
	{"id": "evening_drinks", "label": "Sharing a quiet drink", "window": "evening", "anchor": "campfire", "min": 2, "max": 4, "duration": 38.0, "weight": 0.9, "action": "drinking"},
	{"id": "laughter", "label": "Laughing over a village story", "window": "day_or_evening", "anchor": "square", "min": 2, "max": 4, "duration": 30.0, "weight": 1.0, "action": "laughing"},
	{"id": "night_ritual", "label": "Taking part in a quiet night ritual", "window": "night", "anchor": "campfire", "min": 3, "max": 5, "duration": 58.0, "weight": 0.45, "rare": true, "action": "ritual"},
	{"id": "dancing", "label": "Dancing to an unheard tune", "window": "evening", "anchor": "square", "min": 2, "max": 5, "duration": 40.0, "weight": 0.8, "rare": true, "action": "dancing"},
	{"id": "small_game", "label": "Playing a small game", "window": "day_or_evening", "anchor": "square", "min": 2, "max": 4, "duration": 36.0, "weight": 1.1, "action": "playing"},
	{"id": "passing_greeting", "label": "Stopping to greet a passerby", "window": "any", "anchor": "player", "min": 2, "max": 2, "duration": 22.0, "weight": 2.0, "action": "greeting", "close_pair": true},
	{"id": "work_break", "label": "Taking a short work break", "window": "day", "anchor": "square", "min": 2, "max": 3, "duration": 30.0, "weight": 1.4, "action": "conversation"},
	{"id": "argument", "label": "Having a small argument", "window": "day_or_evening", "anchor": "square", "min": 2, "max": 3, "duration": 28.0, "weight": 0.55, "rare": true, "action": "arguing"},
	{"id": "sunset_watch", "label": "Watching the last light", "window": "sunset", "anchor": "sunset", "min": 2, "max": 4, "duration": 42.0, "weight": 1.1, "action": "watching"},
	{"id": "strange_inspection", "label": "Inspecting something unusual", "window": "any", "anchor": "square", "min": 2, "max": 4, "duration": 46.0, "weight": 0.28, "rare": true, "action": "investigating"},
	{"id": "solitary_rest", "label": "Resting alone near the fire", "window": "night", "anchor": "campfire", "min": 1, "max": 1, "duration": 34.0, "weight": 0.8, "action": "resting"},
	{"id": "rain_shelter", "label": "Rushing together for shelter", "window": "rain", "anchor": "shelter", "min": 2, "max": 5, "duration": 48.0, "weight": 3.0, "action": "sheltering"},
	{"id": "celebration", "label": "Starting a tiny town celebration", "window": "evening", "anchor": "campfire", "min": 3, "max": 6, "duration": 64.0, "weight": 0.18, "rare": true, "action": "celebrating"},
	{"id": "mourning", "label": "Gathering quietly together", "window": "night", "anchor": "campfire", "min": 2, "max": 4, "duration": 50.0, "weight": 0.12, "rare": true, "action": "mourning"}
]

var _timer: Timer
var _rng := RandomNumberGenerator.new()
var _active_events: Array[Dictionary] = []
var _rare_events_seen: Dictionary = {}
var _start_cooldown: float = 0.0
var _last_day: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("npc_event_manager")
	_rng.seed = 0xA11CEFE
	_timer = Timer.new()
	_timer.name = "AmbientDecisionTimer"
	_timer.wait_time = EVENT_TICK_SECONDS
	_timer.one_shot = false
	_timer.process_callback = Timer.TIMER_PROCESS_IDLE
	_timer.timeout.connect(_on_decision_tick)
	add_child(_timer)
	_timer.start()
	call_deferred("_refresh_simulation_lod")

func _on_decision_tick() -> void:
	if _last_day != GameManager.day_count:
		_last_day = GameManager.day_count
		_rare_events_seen.clear()
	_start_cooldown = maxf(0.0, _start_cooldown - EVENT_TICK_SECONDS)
	_advance_active_events()
	_refresh_simulation_lod()

	if GameManager.current_state != GameManager.GameState.PLAYING or get_tree().paused:
		return
	if GameManager.is_interior or not (GameManager.player is Node2D):
		return
	if _active_events.size() >= MAX_ACTIVE_EVENTS or _start_cooldown > 0.0:
		return
	# The timer is deliberately probabilistic so the town does not perform the
	# same visible event at a fixed real-time interval every day.
	if _rng.randf() > 0.38:
		return
	_try_start_event()

func _refresh_simulation_lod() -> void:
	var player_value: Variant = GameManager.player
	var player_position := Vector2.ZERO
	if player_value is Node2D and is_instance_valid(player_value):
		player_position = (player_value as Node2D).global_position
	var radius_sq := FULL_SIMULATION_RADIUS * FULL_SIMULATION_RADIUS
	for raw_npc: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := raw_npc as QuestNPC
		if npc == null or not is_instance_valid(npc):
			continue
		var event_active := npc.has_ambient_event()
		var nearby := npc.global_position.distance_squared_to(player_position) <= radius_sq
		npc.set_ambient_simulation_active(event_active or nearby)

func _advance_active_events() -> void:
	for index in range(_active_events.size() - 1, -1, -1):
		var event: Dictionary = _active_events[index]
		event["remaining"] = float(event.get("remaining", 0.0)) - EVENT_TICK_SECONDS
		var participants_value: Variant = event.get("participants", [])
		var living_participants := 0
		if participants_value is Array:
			for raw_npc in participants_value:
				var npc := raw_npc as QuestNPC
				if npc != null and is_instance_valid(npc):
					living_participants += 1
		if living_participants == 0 or float(event.get("remaining", 0.0)) <= 0.0:
			_finish_event(event)
			_active_events.remove_at(index)
		else:
			_active_events[index] = event

func _try_start_event() -> void:
	var definition := _choose_event_definition()
	if definition.is_empty():
		return
	var player := GameManager.player as Node2D
	if player == null or not is_instance_valid(player):
		return
	var anchor := _event_anchor(str(definition.get("anchor", "square")), player.global_position)
	var candidates := _nearby_candidates(anchor, player.global_position, bool(definition.get("close_pair", false)))
	var participants := _select_participants(candidates, definition, anchor)
	var minimum := clampi(int(definition.get("min", 2)), 1, MAX_PARTICIPANTS)
	if participants.size() < minimum:
		return
	_begin_event(definition, participants, anchor)

func _choose_event_definition() -> Dictionary:
	var eligible: Array[Dictionary] = []
	var total_weight := 0.0
	for definition: Dictionary in EVENT_DEFINITIONS:
		if not _event_allowed(definition):
			continue
		var event_id := str(definition.get("id", ""))
		if _event_is_active(event_id):
			continue
		if bool(definition.get("rare", false)) and int(_rare_events_seen.get(event_id, -1)) == GameManager.day_count:
			continue
		var weight := maxf(0.01, float(definition.get("weight", 1.0)))
		eligible.append(definition)
		total_weight += weight
	if eligible.is_empty():
		return {}
	var roll := _rng.randf_range(0.0, total_weight)
	for definition: Dictionary in eligible:
		roll -= maxf(0.01, float(definition.get("weight", 1.0)))
		if roll <= 0.0:
			return definition
	return eligible[eligible.size() - 1]

func _event_allowed(definition: Dictionary) -> bool:
	var hour := fposmod(GameManager.game_time_hours, 24.0)
	var window := str(definition.get("window", "any"))
	match window:
		"night":
			return hour >= 20.0 or hour < 6.0
		"evening":
			return hour >= 17.0 and hour < 22.0
		"day":
			return hour >= 7.0 and hour < 18.0
		"day_or_evening":
			return hour >= 7.0 and hour < 22.0
		"sunset":
			return hour >= 17.0 and hour < 20.5
		"rain":
			return _weather_is_raining()
		_:
			return true

func _weather_is_raining() -> bool:
	# The current project has no weather director. This hook lets a future
	# weather system set the metadata without adding a second NPC scheduler.
	return str(GameManager.get_meta("weather_state", "")).to_lower() in ["rain", "storm"]

func _event_is_active(event_id: String) -> bool:
	for event: Dictionary in _active_events:
		if str(event.get("id", "")) == event_id:
			return true
	return false

func _nearby_candidates(anchor: Vector2, player_position: Vector2, close_pair: bool) -> Array[QuestNPC]:
	var candidates: Array[QuestNPC] = []
	var discovery_sq := EVENT_DISCOVERY_RADIUS * EVENT_DISCOVERY_RADIUS
	for raw_npc: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := raw_npc as QuestNPC
		if npc == null or not is_instance_valid(npc) or npc.is_dialogue_open or npc.has_ambient_event():
			continue
		if npc.global_position.distance_squared_to(player_position) > discovery_sq:
			continue
		if npc.global_position.distance_to(anchor) > 760.0:
			continue
		if close_pair and npc.global_position.distance_to(player_position) > 620.0:
			continue
		candidates.append(npc)
	return candidates

func _select_participants(candidates: Array[QuestNPC], definition: Dictionary, anchor: Vector2) -> Array[QuestNPC]:
	var selected: Array[QuestNPC] = []
	var maximum := clampi(int(definition.get("max", 4)), 1, MAX_PARTICIPANTS)
	var minimum := clampi(int(definition.get("min", 2)), 1, maximum)
	var leader: QuestNPC = null
	var leader_score := -1.0
	for npc: QuestNPC in candidates:
		var score := npc.get_ambient_personality_value("social") + _rng.randf_range(0.0, 0.18)
		if score > leader_score:
			leader_score = score
			leader = npc
	if leader == null:
		return selected
	selected.append(leader)

	while selected.size() < maximum:
		var best: QuestNPC = null
		var best_score := -1.0
		for npc: QuestNPC in candidates:
			if selected.has(npc):
				continue
			var score := _join_score(npc, definition, anchor, leader)
			score += _rng.randf_range(0.0, 0.24)
			if score > best_score:
				best_score = score
				best = npc
		if best == null:
			break
		if selected.size() >= minimum and _rng.randf() > clampf(best_score, 0.15, 0.88):
			break
		selected.append(best)
	return selected

func _join_score(npc: QuestNPC, definition: Dictionary, anchor: Vector2, leader: QuestNPC) -> float:
	var score := npc.get_ambient_event_join_score(str(definition.get("id", "")))
	var distance := npc.global_position.distance_to(anchor)
	score += clampf(1.0 - distance / 760.0, 0.0, 1.0) * 0.28
	if leader != null:
		score += npc.get_ambient_affinity_to(leader) * 0.28
	return clampf(score, 0.0, 1.0)

func _event_anchor(anchor_kind: String, player_position: Vector2) -> Vector2:
	var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
	var center := terrain.village_center if terrain != null else Vector2.ZERO
	var world := get_tree().current_scene.get_node_or_null("World") if get_tree().current_scene != null else null
	match anchor_kind:
		"campfire":
			if world != null:
				var campfire := world.get_node_or_null("Campfire") as Node2D
				if campfire != null:
					return campfire.global_position
			return center
		"sunset":
			return center + Vector2(230.0, -128.0)
		"shelter":
			var shelter_entries := get_tree().get_nodes_in_group("interior_entries")
			var best_position := center
			var best_distance := INF
			for raw_entry in shelter_entries:
				if not (raw_entry is Node2D) or not is_instance_valid(raw_entry):
					continue
				var entry := raw_entry as Node2D
				var distance := entry.global_position.distance_squared_to(center)
				if distance < best_distance:
					best_distance = distance
					best_position = entry.global_position
			return best_position
		"player":
			return player_position
		_:
			return center + Vector2(_rng.randf_range(-36.0, 36.0), _rng.randf_range(-36.0, 36.0))

func _begin_event(definition: Dictionary, participants: Array[QuestNPC], anchor: Vector2) -> void:
	var event_id := str(definition.get("id", "ambient_event"))
	var slots := _event_slots(participants.size())
	var event: Dictionary = {
		"id": event_id,
		"remaining": maxf(12.0, float(definition.get("duration", 36.0))),
		"participants": participants,
		"anchor": anchor
	}
	_active_events.append(event)
	if bool(definition.get("rare", false)):
		_rare_events_seen[event_id] = GameManager.day_count
	for index in range(participants.size()):
		var npc := participants[index]
		var role := "leader" if index == 0 else "participant"
		npc.set_ambient_simulation_active(true)
		npc.begin_ambient_event(
			event_id,
			str(definition.get("label", "Ambient activity")),
			anchor + slots[index],
			str(definition.get("action", "social")),
			role
		)
	_start_cooldown = _rng.randf_range(8.0, 15.0)
	EventBus.npc_ambient_event_started.emit(event_id, participants.size())

func _finish_event(event: Dictionary) -> void:
	var event_id := str(event.get("id", "ambient_event"))
	var participants_value: Variant = event.get("participants", [])
	if participants_value is Array:
		for raw_npc in participants_value:
			var npc := raw_npc as QuestNPC
			if npc != null and is_instance_valid(npc):
				npc.end_ambient_event()
	EventBus.npc_ambient_event_finished.emit(event_id)

func _event_slots(count: int) -> Array[Vector2]:
	var slots: Array[Vector2] = []
	if count <= 1:
		slots.append(Vector2.ZERO)
		return slots
	var radius := 34.0 if count <= 3 else 48.0
	for index in range(count):
		var angle := (TAU * float(index) / float(count)) + _rng.randf_range(-0.18, 0.18)
		slots.append(Vector2.RIGHT.rotated(angle) * radius)
	return slots
