class_name WorldSpawner
extends Node2D

@export var monster_scene: PackedScene
@export var spawn_count: int = 35
@export var spawn_radius: float = 14000.0
@export var respawn_time: float = 12.0
@export var min_distance_from_village: float = 950.0

var spawned_monsters: Array[BaseMonster] = []
var respawn_timer: float = 0.0
var village_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Find village center (assume it's at origin or set by parent)
	village_center = GameManager.village_spawn_point
	_initial_spawn()

func _process(delta: float) -> void:
	respawn_timer -= delta
	if respawn_timer <= 0:
		respawn_timer = 2.0
		# Clean up dead references periodically
		spawned_monsters = spawned_monsters.filter(func(m): return is_instance_valid(m))
		
		# Respawn if needed
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

func _get_valid_spawn_position() -> Vector2:
	var attempts := 0
	while attempts < 20:
		var angle := randf() * TAU
		var dist := randf_range(spawn_radius * 0.3, spawn_radius)
		var pos := global_position + Vector2(cos(angle), sin(angle)) * dist
		
		# Make sure it's far enough from village
		if pos.distance_to(village_center) >= min_distance_from_village:
			return pos
		attempts += 1
	
	# Fallback
	return global_position + Vector2(spawn_radius, 0).rotated(randf() * TAU)