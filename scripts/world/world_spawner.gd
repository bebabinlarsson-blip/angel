class_name WorldSpawner
extends Node2D

@export var monster_scene: PackedScene
@export var spawn_count: int = 10
@export var spawn_radius: float = 900.0
@export var respawn_time: float = 12.0
@export var min_distance_from_village: float = 380.0

var spawned_monsters: Array[BaseMonster] = []
var respawn_timer: float = 0.0
var village_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	village_center = GameManager.village_spawn_point
	call_deferred("_initial_spawn")

func _process(delta: float) -> void:
	respawn_timer -= delta
	if respawn_timer <= 0:
		respawn_timer = 2.0
		spawned_monsters = spawned_monsters.filter(func(m): return is_instance_valid(m))
		if spawned_monsters.size() < spawn_count:
			_spawn_monster()
			respawn_timer = respawn_time

func _initial_spawn() -> void:
	for i in range(spawn_count):
		_spawn_monster()

func _spawn_monster() -> void:
	if monster_scene == null:
		return
	
	var spawn_pos := _get_valid_spawn_position()
	var monster: BaseMonster = monster_scene.instantiate()
	monster.global_position = spawn_pos
	var parent_node := get_parent()
	if parent_node:
		parent_node.add_child.call_deferred(monster)
	else:
		add_child.call_deferred(monster)
	spawned_monsters.append(monster)

func clear_all_monsters() -> void:
	for m in spawned_monsters:
		if is_instance_valid(m):
			m.queue_free()
	spawned_monsters.clear()

func _get_valid_spawn_position() -> Vector2:
	var attempts := 0
	while attempts < 25:
		var angle := randf() * TAU
		var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
		var outer: float = terrain.radius - 240.0 if terrain else spawn_radius
		var dist := randf_range(maxf(600.0, min_distance_from_village), outer)
		var pos := global_position + Vector2(cos(angle), sin(angle)) * dist
		
		if pos.distance_to(village_center) < min_distance_from_village:
			attempts += 1
			continue
		if _is_in_water(pos):
			attempts += 1
			continue
		return pos
	
	# Fallback south outskirts
	return global_position + Vector2(0, 550)

func _is_in_water(pos: Vector2) -> bool:
	var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain:
		return not terrain.is_clear(pos, 40.0)
	# Eastern Lake
	if pos.distance_to(Vector2(670, 32)) < 200.0:
		return true
	# Outer Ocean
	if pos.length() > 950.0:
		return true
	# On Bridge
	if absf(pos.y - 32.0) < 24.0 and pos.x > 480.0 and pos.x < 880.0:
		return true
	return false
