class_name WorldDirector
extends Node2D

## Streams a large, deterministic ecosystem around the player. The world is
## intentionally data-driven here so adding a material or enemy family does
## not require hand-placing hundreds of scene nodes.

const RESOURCE_SCRIPT = preload("res://scripts/world/resource_node.gd")
const SLIME_SCENE = preload("res://scenes/monsters/slime.tscn")

@export var starting_resources: int = 110
@export var starting_enemies: int = 42
@export var max_resources: int = 260
@export var max_enemies: int = 100
@export var remote_resources: int = 30
@export var remote_enemies: int = 16
@export var respawn_interval: float = 2.5
@export var local_resource_target: int = 22
@export var local_enemy_target: int = 10
@export var world_seed: int = 0xA11CE2026

var terrain: IslandWorld = null
var resource_parent: Node2D = null
var enemy_parent: Node2D = null
var rng := RandomNumberGenerator.new()
var population_timer: float = 0.0
var initialized: bool = false
var occupied_positions: Array[Vector2] = []

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

func _ready() -> void:
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

    # A generous inner ring makes gathering and combat feel alive immediately.
    for i in range(starting_resources):
        var resource_pos := _find_position(650.0, 10500.0, 48.0)
        if resource_pos != Vector2.ZERO:
            _spawn_resource(resource_pos, _pick_resource_at(resource_pos))
    for i in range(starting_enemies):
        var enemy_pos := _find_position(900.0, 14500.0, 72.0)
        if enemy_pos != Vector2.ZERO:
            _spawn_enemy(enemy_pos)

    # Remote landmarks make the 100x border meaningful before streaming fills it.
    for i in range(remote_resources):
        var remote_resource_pos := _find_position(12000.0, terrain.expanded_radius * 0.88, 64.0)
        if remote_resource_pos != Vector2.ZERO:
            _spawn_resource(remote_resource_pos, _pick_resource_at(remote_resource_pos))
    for i in range(remote_enemies):
        var remote_enemy_pos := _find_position(10000.0, terrain.expanded_radius * 0.88, 82.0)
        if remote_enemy_pos != Vector2.ZERO:
            _spawn_enemy(remote_enemy_pos)

    initialized = true

func _process(delta: float) -> void:
    if not initialized or terrain == null or GameManager.player == null:
        return
    population_timer += delta
    if population_timer < respawn_interval:
        return
    population_timer = 0.0

    var player_pos: Vector2 = GameManager.player.global_position
    var resource_nodes := get_tree().get_nodes_in_group("resource_nodes")
    var monsters := get_tree().get_nodes_in_group("monsters")
    var resource_count := resource_nodes.size()
    var enemy_count := monsters.size()
    var nearby_resources := _count_near_nodes(resource_nodes, player_pos, 3600.0)
    var nearby_enemies := _count_near_nodes(monsters, player_pos, 4200.0)

    if resource_count < max_resources:
        var global_resource_budget := mini(6, max_resources - resource_count)
        var local_resource_budget := maxi(0, local_resource_target - nearby_resources)
        var resource_to_spawn := mini(global_resource_budget, maxi(1, local_resource_budget))
        for i in range(resource_to_spawn):
            var new_resource_pos := _find_position_near(player_pos, 550.0, 3000.0, 52.0)
            if new_resource_pos != Vector2.ZERO:
                _spawn_resource(new_resource_pos, _pick_resource_at(new_resource_pos))

    if enemy_count < max_enemies:
        var global_enemy_budget := mini(3, max_enemies - enemy_count)
        var local_enemy_budget := maxi(0, local_enemy_target - nearby_enemies)
        var enemies_to_spawn := mini(global_enemy_budget, maxi(1, local_enemy_budget))
        for i in range(enemies_to_spawn):
            var new_enemy_pos := _find_position_near(player_pos, 1000.0, 3600.0, 82.0)
            if new_enemy_pos != Vector2.ZERO:
                _spawn_enemy(new_enemy_pos)

func _count_near_nodes(nodes: Array, center: Vector2, radius: float) -> int:
    var count := 0
    var radius_sq := radius * radius
    for node in nodes:
        if node is Node2D and (node as Node2D).global_position.distance_squared_to(center) <= radius_sq:
            count += 1
    return count

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
            if resource_id in ["wood", "herb", "fiber", "mushroom", "berry", "moon_petal", "apple", "orange", "pear", "banana", "grapes", "plant", "flower", "clover"]:
                weight *= 2.0
        "shore":
            if resource_id in ["stone", "berry", "sunstone", "reeds", "flower", "orange"]:
                weight *= 1.8
        "meadow":
            if resource_id in ["plant", "flower", "clover", "apple", "pear", "herb"]:
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
    if terrain == null or not terrain.is_inside_playable_area(pos) or not terrain.is_clear(pos, separation):
        return false
    if pos.length() < 600.0:
        return false
    for other: Vector2 in occupied_positions:
        if pos.distance_squared_to(other) < separation * separation:
            return false
    return true

func _spawn_resource(pos: Vector2, data: Dictionary) -> void:
    if resource_parent == null or pos == Vector2.ZERO:
        return
    if not terrain.is_inside_playable_area(pos) or not terrain.is_clear(pos, 32.0):
        return
    var node := RESOURCE_SCRIPT.new() as ResourceNode
    if node == null:
        return
    node.item_id = str(data["id"])
    node.item_name = str(data["name"])
    node.quantity = rng.randi_range(int(data["min"]), int(data["max"]))
    node.item_type = int(data["type"])
    node.respawn_time = rng.randf_range(55.0, 105.0)
    node.position = pos
    resource_parent.add_child(node)

func _spawn_enemy(pos: Vector2) -> void:
    if enemy_parent == null or pos == Vector2.ZERO:
        return
    if not terrain.is_inside_playable_area(pos) or not terrain.is_clear(pos, 48.0):
        return
    var enemy := SLIME_SCENE.instantiate() as SlimeMonster
    if enemy == null:
        return
    var variants := ["slime", "moss", "ember", "crystal"]
    enemy.set_meta("variant", variants[rng.randi_range(0, variants.size() - 1)])
    enemy.position = pos
    enemy_parent.add_child(enemy)
