class_name SlimeMonster
extends "res://scripts/monsters/base_monster.gd"

@export var jump_interval: float = 2.0
@export var jump_force: float = 150.0

var jump_timer: float = 0.0
var is_jumping: bool = false
var jump_lunge_timer: float = 0.0
var jump_lunge_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Keep the original slime as the baseline, but let WorldDirector create
	# stronger visual/stat variants across the enlarged island.
	var variant := str(get_meta("variant", "slime"))
	base_hp = 60.0
	base_attack = 12.0
	base_speed = 85.0
	detection_range = 280.0
	attack_range = 30.0
	coin_drop_min = 2
	coin_drop_max = 6
	exp_drop = 30
	match variant:
		"moss":
			base_hp = 92.0
			base_attack = 16.0
			base_speed = 68.0
		"ember":
			base_hp = 66.0
			base_attack = 24.0
			base_speed = 105.0
		"crystal":
			base_hp = 125.0
			base_attack = 20.0
			base_speed = 74.0
	super._ready()
	if sprite:
		match variant:
			"moss": sprite.modulate = Color("#6ba66a")
			"ember": sprite.modulate = Color("#e88b61")
			"crystal": sprite.modulate = Color("#8bd9e8")
	jump_timer = randf_range(0.5, jump_interval)

func _physics_process(delta: float) -> void:
	# LOD early-out lives in base; don't duplicate the distance check here.
	super._physics_process(delta)
	_handle_jump(delta)
	# Lunge persists briefly so base AI doesn't overwrite velocity next frame.
	# Skipped at LOD range so distant slimes stay asleep (perf).
	if jump_lunge_timer > 0.0 and current_state != State.DEAD and current_state != State.HURT:
		var p := GameManager.player
		if p and is_instance_valid(p) and global_position.distance_squared_to((p as Node2D).global_position) < 2250000.0:
			jump_lunge_timer -= delta
			velocity = jump_lunge_dir * jump_force
			move_and_slide()
		else:
			jump_lunge_timer = 0.0

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
	if target and is_instance_valid(target) and global_position.distance_to(target.global_position) <= detection_range:
		jump_dir = (target.global_position - global_position).normalized()
	else:
		jump_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		if jump_dir == Vector2.ZERO:
			jump_dir = Vector2.RIGHT
	
	jump_lunge_dir = jump_dir
	jump_lunge_timer = 0.35
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
