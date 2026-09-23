class_name WorldDirector
extends Node2D

## Streams a large, deterministic ecosystem around the player. The world is
## intentionally data-driven here so adding a material or enemy family does
## not require hand-placing hundreds of scene nodes.

const RESOURCE_SCRIPT = preload("res://scripts/world/resource_node.gd")
const SLIME_SCENE = preload("res://scenes/monsters/slime.tscn")
const MAX_RESOURCE_QUANTITY := 999999999

@export var starting_resources: int = 160
@export var starting_enemies: int = 60
@export var max_resources: int = 360
@export var max_enemies: int = 140
@export var remote_resources: int = 40
@export var remote_enemies: int = 24
@export var respawn_interval: float = 2.5
@export var local_resource_target: int = 22
@export var local_enemy_target: int = 10
@export var world_seed: int = 0xA11CE2026

# Dynamic content is kept as compact records. Scene nodes exist only in the
# camera neighborhood, which prevents the expanded island from creating a
# frame-rate cost proportional to the full map size.
@export var stream_load_radius: float = 720.0
@export var stream_unload_radius: float = 1120.0
@export var stream_padding: float = 260.0
@export var stream_update_interval: float = 0.35
@export var enemy_respawn_time: float = 45.0
const SEED_BATCH_SIZE := 24

var terrain: IslandWorld = null
var resource_parent: Node2D = null
var enemy_parent: Node2D = null
var rng := RandomNumberGenerator.new()
var population_timer: float = 0.0
var stream_timer: float = 0.0
var initialized: bool = false
var occupied_positions: Array[Vector2] = []
var resource_records: Array[Dictionary] = []
var enemy_records: Array[Dictionary] = []
var authored_stream_records: Array[Dictionary] = []

const RESOURCE_CATALOG: Array[Dictionary] = [
	{"id": "wood", "name": "Wood", "weight": 20.0, "min": 1, "max": 3, "type": 0},
	{"id": "herb", "name": "Herb", "weight": 14.0, "min": 1, "max": 3, "type": 0},
	{"id": "mushroom", "name": "Mushroom", "weight": 11.0, "min": 1, "max": 2, "type": 0},
	{"id": "stone", "name": "Stone", "weight": 13.0, "min": 1, "max": 4, "type": 0},
	{"id": "fiber", "name": "Fiber", "weight": 10.0, "min": 2, "max": 5, "type": 0},
	{"id": "plant", "name": "Wild Plant", "weight": 8.0, "min": 1, "max": 2, "type": 0},
	{"id": "flower", "name": "Wildflower", "weight": 7.0, "min": 1, "max": 3, "type": 0},
	{"id": "clover", "name": "Clover", "weight": 6.0, "min": 1, "max": 3, "type": 0},
	{"id": "apple", "name": "Apple", "weight": 7.0, "min": 1, "max": 2, "type": 0},
	{"id": "orange", "name": "Orange", "weight": 5.0, "min": 1, "max": 2, "type": 0},
	{"id": "pear", "name": "Pear", "weight": 4.0, "min": 1, "max": 2, "type": 0},
	{"id": "banana", "name": "Banana", "weight": 3.0, "min": 1, "max": 2, "type": 0},
	{"id": "grapes", "name": "Grapes", "weight": 4.0, "min": 1, "max": 2, "type": 0},
	{"id": "tomato", "name": "Tomato", "weight": 5.0, "min": 1, "max": 3, "type": 0},
	{"id": "carrot", "name": "Carrot", "weight": 4.5, "min": 1, "max": 3, "type": 0},
	{"id": "coconut", "name": "Coconut", "weight": 2.5, "min": 1, "max": 2, "type": 0},
	{"id": "watermelon", "name": "Watermelon", "weight": 2.0, "min": 1, "max": 1, "type": 0},
	{"id": "wheat", "name": "Wheat", "weight": 3.5, "min": 1, "max": 3, "type": 0},
	{"id": "mint", "name": "Mint", "weight": 4.5, "min": 1, "max": 3, "type": 0},
	{"id": "lavender", "name": "Lavender", "weight": 3.5, "min": 1, "max": 2, "type": 0},
	{"id": "rose", "name": "Rose", "weight": 3.5, "min": 1, "max": 2, "type": 0},
	{"id": "reeds", "name": "River Reeds", "weight": 4.0, "min": 1, "max": 3, "type": 0},
	{"id": "berry", "name": "Wild Berries", "weight": 8.0, "min": 2, "max": 5, "type": 0},
	{"id": "iron_ore", "name": "Iron Ore", "weight": 5.0, "min": 1, "max": 2, "type": 0},
	{"id": "coal", "name": "Coal", "weight": 4.0, "min": 1, "max": 2, "type": 0},
	{"id": "gold_ore", "name": "Gold Ore", "weight": 2.0, "min": 1, "max": 1, "type": 0},
	{"id": "crystal", "name": "Blue Crystal", "weight": 2.5, "min": 1, "max": 1, "type": 6},
	{"id": "sunstone", "name": "Sunstone", "weight": 1.5, "min": 1, "max": 1, "type": 6},
	{"id": "moon_petal", "name": "Moon Petal", "weight": 1.5, "min": 1, "max": 2, "type": 6},
	{"id": "ancient_shard", "name": "Ancient Shard", "weight": 0.5, "min": 1, "max": 1, "type": 6},
]

const GUARANTEED_STARTER_MATERIALS: Array[String] = [
	"herb",
	"berry",
	"apple",
	"plant",
	"flower",
	"mushroom",
	"orange",
	"pear",
	"banana",
	"grapes",
	"tomato",
	"carrot",
	"coconut",
	"watermelon",
	"wheat",
	"mint",
	"lavender",
	"rose"
]

func _catalog_entry(resource_id: String) -> Dictionary:
	for entry: Dictionary in RESOURCE_CATALOG:
		if str(entry.get("id", "")) == resource_id:
			return entry
	return RESOURCE_CATALOG[0]

func _ready() -> void:
	add_to_group("world_director")
	rng.seed = world_seed
	call_deferred("_initialize")

func _initialize() -> void:
	if initialized:
		return
	terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain == null:
		return

	resource_parent = Node2D.new()
	resource_parent.name = "GeneratedResources"
	resource_parent.y_sort_enabled = true
	add_child(resource_parent)

	enemy_parent = Node2D.new()
	enemy_parent.name = "GeneratedEnemies"
	enemy_parent.y_sort_enabled = true
	add_child(enemy_parent)
	_index_authored_stream_nodes()

	# Seed the complete procedural ecosystem as data only. The records are
	# cheap, preserve deterministic world locations, and are activated below
	# only when the player approaches them.
	for i in range(starting_resources):
		var resource_pos := _find_position(650.0, 10500.0, 48.0)
		if resource_pos != Vector2.ZERO:
			if _register_resource_record(resource_pos, _pick_resource_at(resource_pos)).is_empty():
				_release_occupied_position(resource_pos)
		if i > 0 and i % SEED_BATCH_SIZE == 0:
			# Give the first playable frame back to the renderer between batches.
			# Records remain deterministic; only their bookkeeping is spread over
			# several frames so low-end CPUs do not look hung during scene entry.
			await get_tree().process_frame
			if not is_inside_tree():
				return

	# Guarantee a useful first foraging loop just outside the village. These
	# records are still streamed like every other resource, but the player can
	# reliably find herbs, fruit, flowers and plants instead of waiting for a
	# random catalog roll.
	for resource_id: String in GUARANTEED_STARTER_MATERIALS:
		var starter_pos := _find_position_near(
			terrain.village_center,
			terrain.village_radius + 120.0,
			terrain.village_radius + 420.0,
			52.0
		)
		if starter_pos == Vector2.ZERO:
			continue
		var starter_record := _register_resource_record(starter_pos, _catalog_entry(resource_id))
		if starter_record.is_empty():
			_release_occupied_position(starter_pos)

	for i in range(starting_enemies):
		var enemy_pos := _find_position(900.0, 14500.0, 72.0)
		if enemy_pos != Vector2.ZERO:
			if _register_enemy_record(enemy_pos).is_empty():
				_release_occupied_position(enemy_pos)
		if i > 0 and i % SEED_BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return

	# Keep remote content as records instead of constructing off-screen
	# Area2D/CharacterBody2D trees at startup.
	for i in range(remote_resources):
		var remote_resource_pos := _find_position(12000.0, terrain.expanded_radius * 0.88, 64.0)
		if remote_resource_pos != Vector2.ZERO:
			if _register_resource_record(remote_resource_pos, _pick_resource_at(remote_resource_pos)).is_empty():
				_release_occupied_position(remote_resource_pos)
		if i > 0 and i % SEED_BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	for i in range(remote_enemies):
		var remote_enemy_pos := _find_position(10000.0, terrain.expanded_radius * 0.88, 82.0)
		if remote_enemy_pos != Vector2.ZERO:
			if _register_enemy_record(remote_enemy_pos).is_empty():
				_release_occupied_position(remote_enemy_pos)
		if i > 0 and i % SEED_BATCH_SIZE == 0:
			await get_tree().process_frame
			if not is_inside_tree():
				return

	initialized = true
	if not GameManager.pending_world_data.is_empty():
		var saved_world := GameManager.pending_world_data.duplicate(true)
		GameManager.pending_world_data.clear()
		load_save_data(saved_world)
	# Fill the local target on the first available frame, after the player and
	# camera have finished entering the scene.
	population_timer = respawn_interval

func _process(delta: float) -> void:
	if not initialized or terrain == null:
		return
	var player_value: Variant = GameManager.player
	if not (player_value is Node2D) or not is_instance_valid(player_value):
		return
	var player: Node2D = player_value

	# Stream at a higher cadence than population maintenance so crossing into a
	# new area loads nearby records promptly without spawning every frame.
	stream_timer -= delta
	if stream_timer <= 0.0:
		stream_timer = stream_update_interval
		_maintain_stream(player.global_position)

	population_timer += delta
	if population_timer < respawn_interval:
		return
	population_timer = 0.0
	_top_up_local_population(player.global_position)

func _camera_stream_radius() -> float:
	var radius: float = stream_load_radius
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null and is_instance_valid(camera):
		var half_size: Vector2 = get_viewport_rect().size * 0.5
		var zoom: Vector2 = camera.zoom
		half_size = Vector2(
			half_size.x / maxf(zoom.x, 0.01),
			half_size.y / maxf(zoom.y, 0.01)
		)
		# Use the camera diagonal plus a safety margin to prevent pop-in at
		# the corners while still keeping distant scenes unloaded.
		radius = maxf(radius, half_size.length() + stream_padding)
	return radius

func _maintain_stream(center: Vector2) -> void:
	var load_radius: float = _camera_stream_radius()
	var unload_radius: float = maxf(stream_unload_radius, load_radius + stream_padding * 0.75)
	var load_radius_sq: float = load_radius * load_radius
	var unload_radius_sq: float = unload_radius * unload_radius
	var now: float = float(Time.get_ticks_msec()) / 1000.0

	for record: Dictionary in resource_records:
		_update_resource_record(record, center, load_radius_sq, unload_radius_sq, now)
	for record: Dictionary in enemy_records:
		_update_enemy_record(record, center, load_radius_sq, unload_radius_sq, now)
	_refresh_authored_stream(center, load_radius_sq)

func _index_authored_stream_nodes() -> void:
	authored_stream_records.clear()
	if not is_instance_valid(terrain):
		return
	var world_node: Node = terrain.get_parent()
	if world_node == null:
		return

	# These nodes are authored in game.tscn rather than generated from
	# records. Keep their map positions and gameplay intact, but do not spend
	# physics/processing time on them while they are far outside the camera.
	for container_name: String in ["Collectables", "Monsters", "MiningArea"]:
		var container: Node = world_node.get_node_or_null(container_name)
		if container == null:
			continue
		for child: Node in container.get_children():
			if not (child is Node2D):
				continue
			var node: Node2D = child as Node2D
			var collision_states: Array[Dictionary] = []
			for node_child: Node in node.get_children():
				if node_child is CollisionShape2D:
					var shape: CollisionShape2D = node_child as CollisionShape2D
					collision_states.append({
						"node": shape,
						"disabled": shape.disabled
					})
			var state: Dictionary = {
				"node": node,
				"visible": node.visible,
				"process_mode": node.process_mode,
				"collision_states": collision_states,
				"active": true
			}
			if node is Area2D:
				state["monitoring"] = (node as Area2D).monitoring
			authored_stream_records.append(state)

func _refresh_authored_stream(center: Vector2, load_radius_sq: float) -> void:
	var index: int = 0
	while index < authored_stream_records.size():
		var state: Dictionary = authored_stream_records[index]
		var node_value: Variant = state.get("node", null)
		if not (node_value is Node2D) or not is_instance_valid(node_value):
			authored_stream_records.remove_at(index)
			continue

		var node: Node2D = node_value as Node2D
		var should_be_active: bool = node.global_position.distance_squared_to(center) <= load_radius_sq
		var is_active: bool = bool(state.get("active", true))
		if should_be_active == is_active:
			index += 1
			continue

		node.visible = should_be_active and bool(state.get("visible", true))
		# Stateful authored pickups/rocks still need their respawn timers to
		# advance while off-screen. They have no AI and are only a handful of
		# nodes, so keeping their lightweight process loop costs less than
		# freezing the gameplay clock when the player walks away.
		var keep_background_process := node is CollectableItem or node is MiningRock
		node.process_mode = (int(state.get("process_mode", Node.PROCESS_MODE_INHERIT)) as Node.ProcessMode) if should_be_active or keep_background_process else Node.PROCESS_MODE_DISABLED

		var collision_value: Variant = state.get("collision_states", [])
		if collision_value is Array:
			for raw_collision in collision_value:
				if not (raw_collision is Dictionary):
					continue
				var collision_state: Dictionary = raw_collision
				var shape_value: Variant = collision_state.get("node", null)
				if shape_value is CollisionShape2D and is_instance_valid(shape_value):
					var shape: CollisionShape2D = shape_value as CollisionShape2D
					var original_disabled: bool = bool(collision_state.get("disabled", false))
					shape.set_deferred("disabled", original_disabled if should_be_active else true)

		if node is Area2D:
			var area: Area2D = node as Area2D
			var original_monitoring: bool = bool(state.get("monitoring", true))
			area.set_deferred("monitoring", original_monitoring if should_be_active else false)

		state["active"] = should_be_active
		authored_stream_records[index] = state
		index += 1

func _update_resource_record(record: Dictionary, center: Vector2, load_radius_sq: float, unload_radius_sq: float, now: float) -> void:
	var node: Node2D = _node_from_record(record)
	var pos: Vector2 = _record_position(record)
	if node != null:
		if node is ResourceNode:
			var resource: ResourceNode = node as ResourceNode
			record["collected"] = resource.is_collected
			if pos.distance_squared_to(center) > unload_radius_sq:
				_unload_resource_record(record, resource, now)
		return

	# The node may have been freed by a one-shot pickup; clear the stale
	# reference before considering it for reactivation.
	record["node"] = null
	if bool(record.get("collected", false)):
		if not bool(record.get("respawn_enabled", true)):
			return
		if now < float(record.get("respawn_at", 0.0)):
			return
		record["collected"] = false
		record["respawn_at"] = 0.0
	if pos.distance_squared_to(center) <= load_radius_sq:
		_activate_resource_record(record)

func _update_enemy_record(record: Dictionary, center: Vector2, load_radius_sq: float, unload_radius_sq: float, now: float) -> void:
	var node: Node2D = _node_from_record(record)
	var pos: Vector2 = _record_position(record)
	if node != null:
		if node is BaseMonster:
			var monster: BaseMonster = node as BaseMonster
			if monster.current_state == BaseMonster.State.DEAD:
				if not bool(record.get("defeated", false)):
					record["defeated"] = true
					record["respawn_at"] = now + enemy_respawn_time
				return
			record["hp"] = monster.current_hp
		if pos.distance_squared_to(center) > unload_radius_sq:
			_unload_enemy_record(record, node)
		return

	record["node"] = null
	if bool(record.get("defeated", false)):
		if now < float(record.get("respawn_at", 0.0)):
			return
		record["defeated"] = false
		record["respawn_at"] = 0.0
		record["hp"] = -1.0
	if pos.distance_squared_to(center) <= load_radius_sq:
		_activate_enemy_record(record)

func _count_active_near(records: Array[Dictionary], center: Vector2, radius: float) -> int:
	var count: int = 0
	var radius_sq: float = radius * radius
	for record: Dictionary in records:
		var node: Node2D = _node_from_record(record)
		if node != null and _record_position(record).distance_squared_to(center) <= radius_sq:
			count += 1
	return count

func _top_up_local_population(center: Vector2) -> void:
	var load_radius: float = _camera_stream_radius()
	var active_resources: int = _count_active_near(resource_records, center, load_radius)
	var active_enemies: int = _count_active_near(enemy_records, center, load_radius)

	var resource_need: int = maxi(0, local_resource_target - active_resources)
	var resource_budget: int = mini(6, maxi(0, max_resources - resource_records.size()))
	var resource_min_distance: float = 620.0
	var resource_max_distance: float = maxf(resource_min_distance + 80.0, minf(1450.0, load_radius - 40.0))
	for i in range(mini(resource_need, resource_budget)):
		var new_resource_pos := _find_position_near(center, resource_min_distance, resource_max_distance, 52.0)
		if new_resource_pos != Vector2.ZERO:
			var record := _register_resource_record(new_resource_pos, _pick_resource_at(new_resource_pos))
			if not record.is_empty():
				_activate_resource_record(record)
			else:
				_release_occupied_position(new_resource_pos)

	var enemy_need: int = maxi(0, local_enemy_target - active_enemies)
	var enemy_budget: int = mini(3, maxi(0, max_enemies - enemy_records.size()))
	var enemy_min_distance: float = 700.0
	var enemy_max_distance: float = maxf(enemy_min_distance + 60.0, minf(1300.0, load_radius - 40.0))
	for i in range(mini(enemy_need, enemy_budget)):
		var new_enemy_pos := _find_position_near(center, enemy_min_distance, enemy_max_distance, 82.0)
		if new_enemy_pos != Vector2.ZERO:
			var record := _register_enemy_record(new_enemy_pos)
			if not record.is_empty():
				_activate_enemy_record(record)
			else:
				_release_occupied_position(new_enemy_pos)

func _node_from_record(record: Dictionary) -> Node2D:
	var value: Variant = record.get("node", null)
	if value is Node2D and is_instance_valid(value):
		return value as Node2D
	return null

func _record_position(record: Dictionary) -> Vector2:
	var value: Variant = record.get("position", Vector2.ZERO)
	if value is Vector2:
		return value
	return Vector2.ZERO

func _finite_float(value: Variant, fallback: float) -> float:
	var parsed := float(value)
	return fallback if is_nan(parsed) or is_inf(parsed) else parsed

func _pick_resource_at(pos: Vector2) -> Dictionary:
	var biome := ""
	if terrain and terrain.has_method("get_biome_at"):
		biome = str(terrain.get_biome_at(pos))
	return _pick_resource(biome)

func _pick_resource(biome: String = "") -> Dictionary:
	var total := 0.0
	for entry: Dictionary in RESOURCE_CATALOG:
		total += _resource_weight(entry, biome)
	var roll := rng.randf_range(0.0, total)
	for entry: Dictionary in RESOURCE_CATALOG:
		roll -= _resource_weight(entry, biome)
		if roll <= 0.0:
			return entry
	return RESOURCE_CATALOG[0]

func _resource_weight(entry: Dictionary, biome: String) -> float:
	var weight := float(entry["weight"])
	var resource_id := str(entry["id"])
	match biome:
		"quarry":
			if resource_id in ["stone", "iron_ore", "coal", "gold_ore", "crystal"]:
				weight *= 2.4
		"grove":
			if resource_id in ["wood", "herb", "fiber", "mushroom", "berry", "moon_petal", "apple", "orange", "pear", "banana", "grapes", "tomato", "carrot", "coconut", "watermelon", "wheat", "mint", "lavender", "rose", "plant", "flower", "clover"]:
				weight *= 2.0
		"shore":
			if resource_id in ["stone", "berry", "sunstone", "reeds", "flower", "orange", "coconut", "watermelon"]:
				weight *= 1.8
		"meadow":
			if resource_id in ["plant", "flower", "clover", "apple", "pear", "herb", "tomato", "carrot", "wheat", "mint", "lavender", "rose"]:
				weight *= 1.45
	return weight

func _find_position(min_radius: float, max_radius: float, separation: float) -> Vector2:
	for attempt in range(100):
		var radius := sqrt(rng.randf_range(min_radius * min_radius, max_radius * max_radius))
		var pos := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * radius
		if _valid_position(pos, separation):
			occupied_positions.append(pos)
			return pos
	return Vector2.ZERO

func _find_position_near(center: Vector2, min_radius: float, max_radius: float, separation: float) -> Vector2:
	for attempt in range(80):
		var pos := center + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(min_radius, max_radius)
		if _valid_position(pos, separation):
			occupied_positions.append(pos)
			return pos
	return Vector2.ZERO

func _valid_position(pos: Vector2, separation: float) -> bool:
	if terrain == null or not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 24.0) or not terrain.is_clear(pos, separation):
		return false
	if terrain != null and pos.distance_to(terrain.village_center) < 600.0:
		return false
	return not _has_occupied_position(pos, separation)

func _has_occupied_position(pos: Vector2, separation: float) -> bool:
	var separation_sq := separation * separation
	for other: Vector2 in occupied_positions:
		if pos.distance_squared_to(other) < separation_sq:
			return true
	return false

func _release_occupied_position(pos: Vector2) -> void:
	if pos == Vector2.ZERO:
		return
	for record: Dictionary in resource_records:
		if _record_position(record) == pos:
			return
	for record: Dictionary in enemy_records:
		if _record_position(record) == pos:
			return
	occupied_positions.erase(pos)

func _register_resource_record(pos: Vector2, data: Dictionary) -> Dictionary:
	if resource_parent == null or pos == Vector2.ZERO:
		return {}
	if terrain == null or not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 30.0) or not terrain.is_clear(pos, 32.0):
		return {}
	var min_quantity: int = clampi(int(data.get("min", 1)), 1, MAX_RESOURCE_QUANTITY)
	var max_quantity: int = clampi(int(data.get("max", min_quantity)), min_quantity, MAX_RESOURCE_QUANTITY)
	var record: Dictionary = {
		"position": pos,
		"data": data.duplicate(true),
		"quantity": clampi(rng.randi_range(min_quantity, max_quantity), 1, MAX_RESOURCE_QUANTITY),
		"respawn_time": rng.randf_range(55.0, 105.0),
		"respawn_enabled": true,
		"collected": false,
		"respawn_at": 0.0,
		"node": null
	}
	resource_records.append(record)
	return record

func _register_enemy_record(pos: Vector2) -> Dictionary:
	if enemy_parent == null or pos == Vector2.ZERO:
		return {}
	if terrain == null or not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 48.0) or not terrain.is_clear(pos, 48.0):
		return {}
	var variants: Array[String] = ["slime", "moss", "ember", "crystal"]
	var record: Dictionary = {
		"position": pos,
		"variant": variants[rng.randi_range(0, variants.size() - 1)],
		"hp": -1.0,
		"defeated": false,
		"respawn_at": 0.0,
		"node": null
	}
	enemy_records.append(record)
	return record

func _activate_resource_record(record: Dictionary) -> void:
	if resource_parent == null or _node_from_record(record) != null:
		return
	var data_value: Variant = record.get("data", {})
	if not (data_value is Dictionary):
		return
	var data: Dictionary = data_value
	var pos: Vector2 = _record_position(record)
	if pos == Vector2.ZERO or terrain == null or not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 30.0):
		return

	var node: ResourceNode = RESOURCE_SCRIPT.new() as ResourceNode
	if node == null:
		return
	node.item_id = str(data.get("id", "resource"))
	node.item_name = str(data.get("name", "Resource"))
	node.quantity = clampi(int(record.get("quantity", 1)), 1, MAX_RESOURCE_QUANTITY)
	node.item_type = int(data.get("type", 0))
	node.respawn_time = maxf(1.0, _finite_float(record.get("respawn_time", 75.0), 75.0))
	node.respawn_enabled = bool(record.get("respawn_enabled", true))
	node.position = pos
	resource_parent.add_child(node)
	record["node"] = node

func _activate_enemy_record(record: Dictionary) -> void:
	if enemy_parent == null or _node_from_record(record) != null:
		return
	var pos: Vector2 = _record_position(record)
	if pos == Vector2.ZERO or terrain == null or not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 48.0):
		return

	var enemy := SLIME_SCENE.instantiate() as SlimeMonster
	if enemy == null:
		return
	enemy.set_meta("variant", str(record.get("variant", "slime")))
	enemy.set_meta("stream_record", record)
	enemy.set_meta("stream_respawn_seconds", enemy_respawn_time)
	enemy.position = pos
	enemy_parent.add_child(enemy)
	var saved_hp: float = float(record.get("hp", -1.0))
	if saved_hp > 0.0:
		enemy.current_hp = clampf(saved_hp, 1.0, enemy.base_hp)
		if enemy.health_bar:
			enemy.health_bar.value = enemy.current_hp
	record["node"] = enemy

func _unload_resource_record(record: Dictionary, node: ResourceNode, now: float) -> void:
	record["collected"] = node.is_collected
	record["respawn_enabled"] = node.respawn_enabled
	if node.is_collected and node.respawn_enabled:
		record["respawn_at"] = now + maxf(node.respawn_timer, 0.0)
	else:
		record["respawn_at"] = 0.0
	record["node"] = null
	node.queue_free()

func _unload_enemy_record(record: Dictionary, node: Node2D) -> void:
	if node is BaseMonster:
		record["hp"] = (node as BaseMonster).current_hp
	record["node"] = null
	node.queue_free()

# Kept as compatibility wrappers for any scene or test that calls the old
# internal spawn helpers.
func _spawn_resource(pos: Vector2, data: Dictionary) -> void:
	var record := _register_resource_record(pos, data)
	if not record.is_empty():
		_activate_resource_record(record)
	else:
		_release_occupied_position(pos)

func _spawn_enemy(pos: Vector2) -> void:
	var record := _register_enemy_record(pos)
	if not record.is_empty():
		_activate_enemy_record(record)
	else:
		_release_occupied_position(pos)

func debug_spawn_enemy_at(pos: Vector2, variant: String = "slime") -> Node:
	# Admin-spawned enemies are intentionally immediate and are not added to
	# the deterministic respawn records used by normal world streaming.
	if enemy_parent == null:
		return null
	var enemy := SLIME_SCENE.instantiate() as SlimeMonster
	if enemy == null:
		return null
	enemy.name = "AdminSpawned_" + variant.capitalize()
	enemy.set_meta("variant", variant)
	enemy.set_meta("admin_spawned", true)
	enemy.position = pos
	enemy_parent.add_child(enemy)
	return enemy

func get_save_data() -> Dictionary:
	var now := float(Time.get_ticks_msec()) / 1000.0
	var saved_resources: Array = []
	for record: Dictionary in resource_records:
		var node := _node_from_record(record)
		var collected := bool(record.get("collected", false))
		var remaining := maxf(0.0, float(record.get("respawn_at", 0.0)) - now)
		if node is ResourceNode:
			var resource := node as ResourceNode
			collected = resource.is_collected
			remaining = resource.respawn_timer if collected else 0.0
		var data_value: Variant = record.get("data", {})
		var resource_data: Dictionary = data_value.duplicate(true) if data_value is Dictionary else {}
		saved_resources.append({
			"position": _save_position(_record_position(record)),
			"data": resource_data,
			"quantity": int(record.get("quantity", 1)),
			"respawn_time": float(record.get("respawn_time", 75.0)),
			"respawn_enabled": bool(record.get("respawn_enabled", true)),
			"collected": collected,
			"respawn_remaining": remaining,
		})

	var saved_enemies: Array = []
	for record: Dictionary in enemy_records:
		var node := _node_from_record(record)
		var defeated := bool(record.get("defeated", false))
		var hp := float(record.get("hp", -1.0))
		if node is BaseMonster:
			var monster := node as BaseMonster
			defeated = monster.current_state == BaseMonster.State.DEAD or defeated
			hp = monster.current_hp
		saved_enemies.append({
			"position": _save_position(_record_position(record)),
			"variant": str(record.get("variant", "slime")),
			"hp": hp,
			"defeated": defeated,
			"respawn_remaining": maxf(0.0, float(record.get("respawn_at", 0.0)) - now),
		})
	return {"resources": saved_resources, "enemies": saved_enemies}

func load_save_data(data: Dictionary) -> void:
	if not initialized:
		GameManager.pending_world_data = data.duplicate(true)
		return
	var saved_resources: Variant = data.get("resources", [])
	var saved_enemies: Variant = data.get("enemies", [])
	if not (saved_resources is Array or saved_enemies is Array):
		return
	for record: Dictionary in resource_records:
		var node := _node_from_record(record)
		if node:
			node.queue_free()
	for record: Dictionary in enemy_records:
		var node := _node_from_record(record)
		if node:
			node.queue_free()
	resource_records.clear()
	enemy_records.clear()
	occupied_positions.clear()
	var now := float(Time.get_ticks_msec()) / 1000.0
	var resource_count := 0
	if saved_resources is Array:
		for raw_record in saved_resources:
			if resource_count >= max_resources:
				break
			if not (raw_record is Dictionary):
				continue
			var raw: Dictionary = raw_record
			var pos := _load_position(raw.get("position", {}))
			var raw_data: Variant = raw.get("data", {})
			if pos == Vector2.ZERO or not (raw_data is Dictionary):
				continue
			if not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 30.0) or not terrain.is_clear(pos, 32.0) or _has_occupied_position(pos, 48.0):
				continue
			var record: Dictionary = {
				"position": pos,
				"data": (raw_data as Dictionary).duplicate(true),
				"quantity": clampi(int(raw.get("quantity", 1)), 1, MAX_RESOURCE_QUANTITY),
				"respawn_time": maxf(1.0, _finite_float(raw.get("respawn_time", 75.0), 75.0)),
				"respawn_enabled": bool(raw.get("respawn_enabled", true)),
				"collected": bool(raw.get("collected", false)),
				"respawn_at": now + maxf(0.0, _finite_float(raw.get("respawn_remaining", 0.0), 0.0)),
				"node": null,
			}
			occupied_positions.append(pos)
			resource_records.append(record)
			resource_count += 1
	var enemy_count := 0
	if saved_enemies is Array:
		for raw_record in saved_enemies:
			if enemy_count >= max_enemies:
				break
			if not (raw_record is Dictionary):
				continue
			var raw: Dictionary = raw_record
			var pos := _load_position(raw.get("position", {}))
			if pos == Vector2.ZERO:
				continue
			if not terrain.is_inside_playable_area(pos) or terrain.is_inside_village_safe_zone(pos, 48.0) or not terrain.is_clear(pos, 48.0) or _has_occupied_position(pos, 48.0):
				continue
			var defeated := bool(raw.get("defeated", false))
			var record: Dictionary = {
				"position": pos,
				"variant": str(raw.get("variant", "slime")),
				"hp": _finite_float(raw.get("hp", -1.0), -1.0),
				"defeated": defeated,
				"respawn_at": now + maxf(0.0, _finite_float(raw.get("respawn_remaining", 0.0), 0.0)),
				"node": null,
			}
			occupied_positions.append(pos)
			enemy_records.append(record)
			enemy_count += 1

func _save_position(pos: Vector2) -> Dictionary:
	return {"x": pos.x, "y": pos.y}

func _load_position(value: Variant) -> Vector2:
	if value is Dictionary:
		var point: Dictionary = value
		var x := float(point.get("x", 0.0))
		var y := float(point.get("y", 0.0))
		if is_nan(x) or is_inf(x) or is_nan(y) or is_inf(y):
			return Vector2.ZERO
		return Vector2(x, y)
	return Vector2.ZERO
