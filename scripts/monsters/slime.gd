class_name SlimeMonster
extends "res://scripts/monsters/base_monster.gd"

@export var jump_interval: float = 2.0
@export var jump_force: float = 150.0

var jump_timer: float = 0.0
var is_jumping: bool = false

func _ready() -> void:
	base_hp = 60.0
	base_attack = 12.0
	base_speed = 85.0
	detection_range = 280.0
	attack_range = 30.0
	coin_drop_min = 2
	coin_drop_max = 6
	exp_drop = 30
	super._ready()
	jump_timer = randf_range(0.5, jump_interval)

func _physics_process(delta: float) -> void:
	if GameManager.player and is_instance_valid(GameManager.player):
		if global_position.distance_squared_to(GameManager.player.global_position) > 2250000.0:
			return
	super._physics_process(delta)
	_handle_jump(delta)

func _handle_jump(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	jump_timer -= delta
	if jump_timer <= 0:
		jump_timer = jump_interval
		_do_jump()

func _do_jump() -> void:
	is_jumping = true
	
	# Jump toward target or random direction
	var jump_dir: Vector2
	if target and global_position.distance_to(target.global_position) <= detection_range:
		jump_dir = (target.global_position - global_position).normalized()
	else:
		jump_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	
	velocity = jump_dir * jump_force
	
	# Scale up and down for jump visual
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.1)
		tween.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.15)
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)
		tween.tween_callback(func():
			is_jumping = false
		)
