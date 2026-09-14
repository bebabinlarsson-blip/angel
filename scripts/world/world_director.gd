class_name WorldDirector
extends Node2D

## Keeps the enlarged world populated without baking hundreds of nodes into
## game.tscn. Content is deterministic per run, but new local content appears
## as the player travels so the outer island never feels like an empty shell.

const RESOURCE_SCRIPT = preload("res://scripts/world/resource_node.gd")
const SLIME_SCENE = preload("res://scenes/monsters/slime.tscn")

@export var starting_resources: int = 82
@export var starting_enemies: int = 28
@export var max_resources: int = 190
@export var max_enemies: int = 72

var terrain: IslandWorld = null
var resource_parent: Node2D = null
var enemy_parent: Node2D = null
var rng := RandomNumberGenerator.new()
var population_timer: float = 0.0
var initialized: bool = false
var occupied_positions: Array[Vector2] = []

const RESOURCE_CATALOG: Array[Dictionary] = [
	{"id": "wood", "name": "Wood", "weight": 24.0, "min": 1, "max": 3, "type": 0},
	{"id": "herb", "name": "Herb", "weight": 19.0, "min": 1, "max": 3, "type": 0},
	{"id": "mushroom", "name": "Mushroom", "weight": 14.0, "min": 1, "max": 2, "type": 0},
	{"id": "stone", "name": "Stone", "weight": 15.0, "min": 1, "max": 4, "type": 0},
	{"id": "fiber", "name": "Fiber", "weight": 12.0, "min": 2, "max": 5, "type": 0},
	{"id": "berry", "name": "Wild Berries", "weight": 8.0, "min": 2, "max": 5, "type": 6},
	{"id": "coal", "name": "Coal", "weight": 4.0, "min": 1, "max": 2, "type": 0},
	{"id": "crystal", "name": "Blue Crystal", "weight": 2.5, "min": 1, "max": 1, "type": 6},
	{"id": "sunstone", "name": "Sunstone", "weight": 1.5, "min": 1, "max": 1, "type": 6},
	{"id": "ancient_shard", "name": "Ancient Shard", "weight": 0.5, "min": 1, "max": 1, "type": 6},
]

func _ready() -> void:
	rng.seed = 0xA11CE2026
	call_deferred("_initialize")

func _initialize() -> void:
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

	# A dense, useful ring around the village makes the first few minutes fun.
	for i in range(starting_resources):
		_spawn_resource(_find_position(650.0, 10500.0, 48.0), _pick_resource())
	for i in range(starting_enemies):
		_spawn_enemy(_find_position(900.0, 14500.0, 72.0))
	# A few remote deposits and hunting grounds prove that the expanded border
	# is real even before the player reaches them.
	for i in range(18):
		_spawn_resource(_find_position(12000.0, terrain.expanded_radius * 0.88, 64.0), _pick_resource())
	for i in range(10):
		_spawn_enemy(_find_position(10000.0, terrain.expanded_radius * 0.88, 82.0))
	initialized = true

func _process(delta: float) -> void:
	if not initialized or terrain == null or GameManager.player == null:
		return
	population_timer += delta
	if population_timer < 3.0:
		return
	population_timer = 0.0
	# Replenish around the explorer. This keeps long journeys populated while
	# capping the total number of live nodes for Chromebook/Web performance.
	var player_pos: Vector2 = GameManager.player.global_position
	var resource_count := get_tree().get_nodes_in_group("resource_nodes").size()
	var enemy_count := get_tree().get_nodes_in_group("monsters").size()
	if resource_count < max_resources:
		for i in range(mini(5, max_resources - resource_count)):
			_spawn_resource(_find_position_near(player_pos, 550.0, 3000.0, 52.0), _pick_resource())
	if enemy_count < max_enemies:
		for i in range(mini(2, max_enemies - enemy_count)):
			_spawn_enemy(_find_position_near(player_pos, 1000.0, 3600.0, 82.0))

func _pick_resource() -> Dictionary:
	var total := 0.0
	for entry: Dictionary in RESOURCE_CATALOG:
		total += float(entry["weight"])
	var roll := rng.randf_range(0.0, total)
	for entry: Dictionary in RESOURCE_CATALOG:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return entry
	return RESOURCE_CATALOG[0]

func _find_position(min_radius: float, max_radius: float, separation: float) -> Vector2:
	var pos := Vector2.ZERO
	for attempt in range(80):
		var radius := sqrt(rng.randf_range(min_radius * min_radius, max_radius * max_radius))
		pos = Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * radius
		if _valid_position(pos, separation):
			occupied_positions.append(pos)
			return pos
	return pos

func _find_position_near(center: Vector2, min_radius: float, max_radius: float, separation: float) -> Vector2:
	for attempt in range(60):
		var pos := center + Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU)) * rng.randf_range(min_radius, max_radius)
		if _valid_position(pos, separation):
			occupied_positions.append(pos)
			return pos
	return center + Vector2.RIGHT * max_radius

func _valid_position(pos: Vector2, separation: float) -> bool:
	if not terrain.is_inside_playable_area(pos) or not terrain.is_clear(pos, separation):
		return false
	if pos.length() < 600.0:
		return false
	for other: Vector2 in occupied_positions:
		if pos.distance_squared_to(other) < separation * separation:
			return false
	return true

func _spawn_resource(pos: Vector2, data: Dictionary) -> void:
	if resource_parent == null or not terrain.is_clear(pos, 32.0):
		return
	var node := RESOURCE_SCRIPT.new() as ResourceNode
	node.item_id = str(data["id"])
	node.item_name = str(data["name"])
	node.quantity = rng.randi_range(int(data["min"]), int(data["max"]))
	node.item_type = int(data["type"])
	node.respawn_time = rng.randf_range(55.0, 105.0)
	node.position = pos
	resource_parent.add_child(node)

func _spawn_enemy(pos: Vector2) -> void:
	if enemy_parent == null or not terrain.is_clear(pos, 48.0):
		return
	var enemy := SLIME_SCENE.instantiate() as SlimeMonster
	if enemy == null:
		return
	var variants := ["slime", "moss", "ember", "crystal"]
	enemy.set_meta("variant", variants[rng.randi_range(0, variants.size() - 1)])
	enemy.position = pos
	enemy_parent.add_child(enemy)
