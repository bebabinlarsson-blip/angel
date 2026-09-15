class_name BaseMonster
extends CharacterBody2D

@export var base_hp: float = 50.0
@export var base_attack: float = 10.0
@export var base_speed: float = 80.0
@export var detection_range: float = 200.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var exp_drop: int = 25

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

var current_hp: float
var scaled_attack: float
var scaled_speed: float

var target: CharacterBody2D = null
var terrain: IslandWorld = null
var attack_timer: float = 0.0
var attack_windup: float = 0.0
var attack_has_landed: bool = false
var wander_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var hurt_timer: float = 0.0
var facing_direction: String = "down"
var lod_tick: float = 0.0
var is_far_lod: bool = false

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

var visual_renderer: CustomDraw2D = null

func _ready() -> void:
	add_to_group("monsters")
	terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
	_scale_to_player_level()
	current_hp = base_hp

	if health_bar:
		health_bar.max_value = base_hp
		health_bar.value = current_hp
		health_bar.visible = false

	wander_timer = randf_range(1.0, 4.0)

func _scale_to_player_level() -> void:
	var player_level: int = 0
	if GameManager.player != null and is_instance_valid(GameManager.player) and GameManager.player.stats != null:
		player_level = GameManager.player.stats.level
	base_hp = base_hp * (1.0 + player_level * 0.12)
	base_attack = base_attack * (1.0 + player_level * 0.10)
	scaled_speed = base_speed * (1.0 + player_level * 0.03)
	scaled_attack = base_attack
	exp_drop = int(float(exp_drop) * (1.0 + player_level * 0.08))

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	is_far_lod = false
	if GameManager.player and is_instance_valid(GameManager.player):
		var dist_sq: float = global_position.distance_squared_to(GameManager.player.global_position)
		if dist_sq > 2250000.0:
			# Distant enemies remain spawned and keep their identity, but do
			# not spend a full physics tick while they are off-screen.
			is_far_lod = true
			lod_tick += delta
			if lod_tick < 0.2:
				return
			lod_tick = 0.0
			wander_timer = randf_range(2.0, 5.0)
			return

	if not is_instance_valid(terrain):
		terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
	if _enforce_village_boundary():
		_update_animation()
		return

	_update_timers(delta)
	_update_ai(delta)
	_apply_knockback(delta)
	_update_animation()

	if not is_instance_valid(terrain):
		terrain = get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain and velocity.length_squared() > 1.0 and terrain.is_water(global_position + velocity.normalized() * 28.0):
		velocity = Vector2.ZERO
		wander_direction = -wander_direction
	move_and_slide()
	_enforce_village_boundary()

func _enforce_village_boundary() -> bool:
	if not is_instance_valid(terrain) or current_state == State.DEAD:
		return false
	if not terrain.is_inside_village_safe_zone(global_position, 24.0):
		return false

	target = null
	current_state = State.IDLE
	attack_windup = 0.0
	attack_has_landed = true
	velocity = Vector2.ZERO
	var escape_direction: Vector2 = global_position - terrain.village_center
	if escape_direction.length_squared() <= 0.001:
		escape_direction = Vector2.UP
	var boundary_radius: float = maxf(32.0, terrain.village_radius + 32.0)
	global_position = terrain.village_center + escape_direction.normalized() * boundary_radius
	return true

func _update_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer = maxf(0.0, attack_timer - delta)
	if attack_windup > 0.0:
		attack_windup = maxf(0.0, attack_windup - delta)
		if attack_windup <= 0.0 and not attack_has_landed and current_state == State.ATTACK:
			attack_has_landed = true
			_perform_attack()
	if hurt_timer > 0.0:
		hurt_timer = maxf(0.0, hurt_timer - delta)
		if hurt_timer <= 0.0 and current_state == State.HURT:
			current_state = State.IDLE

func _update_ai(delta: float) -> void:
	if current_state == State.HURT:
		return
	if current_state == State.ATTACK:
		if attack_timer > 0.0:
			return
		current_state = State.IDLE

	target = GameManager.player
	if target == null or not is_instance_valid(target) or target.current_state == target.State.DEAD:
		target = null
	if target:
		var player_in_village: bool = is_instance_valid(terrain) and terrain.is_inside_village_safe_zone(target.global_position)
		if player_in_village or (not is_instance_valid(terrain) and target.global_position.length() < 450.0):
			target = null

	if target:
		var dist_to_target: float = global_position.distance_to(target.global_position)
		if dist_to_target <= attack_range:
			_try_attack()
		elif dist_to_target <= detection_range:
			_chase_target()
		else:
			_wander(delta)
	else:
		_wander(delta)

func _chase_target() -> void:
	current_state = State.CHASE
	var dir: Vector2 = (target.global_position - global_position).normalized()
	velocity = dir * scaled_speed

func _wander(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		if randf() > 0.4:
			wander_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			current_state = State.WANDER
		else:
			wander_direction = Vector2.ZERO
			current_state = State.IDLE

	if wander_direction != Vector2.ZERO:
		velocity = wander_direction * scaled_speed * 0.4
	else:
		velocity = Vector2.ZERO

func _try_attack() -> void:
	if attack_timer > 0.0 or current_state == State.ATTACK:
		return
	current_state = State.ATTACK
	attack_timer = attack_cooldown
	attack_windup = 0.22
	attack_has_landed = false
	velocity = Vector2.ZERO

func _perform_attack() -> void:
	if target and is_instance_valid(target) and target.has_method("take_damage"):
		var distance_to_target := global_position.distance_to(target.global_position)
		if distance_to_target <= attack_range * 1.35:
			var knockback_dir: Vector2 = (target.global_position - global_position).normalized()
			target.take_damage(scaled_attack, knockback_dir * 200.0)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return
	if amount <= 0.0:
		return

	current_hp -= amount
	knockback_velocity = knockback
	attack_windup = 0.0
	attack_has_landed = true
	current_state = State.HURT
	hurt_timer = 0.3
	_spawn_damage_number(amount)
	if sprite:
		VFX.flash_hit(sprite)

	if health_bar:
		health_bar.visible = true
		health_bar.value = maxf(current_hp, 0.0)

	if current_hp <= 0.0:
		die()

func _spawn_damage_number(amount: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var existing := get_tree().get_nodes_in_group("damage_numbers")
	if existing.size() > 24:
		var oldest: Node = existing[0]
		if is_instance_valid(oldest):
			oldest.queue_free()
	var label := Label.new()
	label.add_to_group("damage_numbers")
	label.text = "-%d" % int(amount)
	label.modulate = Color(1.0, 0.35, 0.25, 1.0)
	label.position = global_position + Vector2(-15, -35)
	label.z_index = 100
	parent.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(randf_range(-12, 12), -30), 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)

func _apply_knockback(delta: float) -> void:
	if knockback_velocity.length() > 5.0:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	velocity = Vector2.ZERO
	_drop_loot()
	var stream_record: Variant = get_meta("stream_record", null)
	if stream_record is Dictionary:
		stream_record["defeated"] = true
		stream_record["respawn_at"] = float(Time.get_ticks_msec()) / 1000.0 + float(get_meta("stream_respawn_seconds", 45.0))
	EventBus.monster_killed.emit(self, global_position)
	VFX.slime_pop(self)
	var tween := create_tween()
	if visual_renderer:
		tween.tween_property(visual_renderer, "modulate:a", 0.0, 0.4)
	elif sprite:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _drop_loot() -> void:
	# Monsters are an EXP source only. Materials and gold come from the
	# authored/generated world, quests, and supply caches.
	if GameManager.player != null and is_instance_valid(GameManager.player) and GameManager.player.stats != null:
		GameManager.player.stats.add_exp(exp_drop)
		EventBus.show_notification.emit("+%d EXP" % exp_drop)

func _update_facing() -> void:
	if velocity.length_squared() > 10.0:
		if absf(velocity.x) > absf(velocity.y):
			facing_direction = "right" if velocity.x > 0.0 else "left"
		else:
			facing_direction = "down" if velocity.y > 0.0 else "up"
	elif target and is_instance_valid(target):
		var to_target := target.global_position - global_position
		if to_target.length_squared() > 10.0:
			if absf(to_target.x) > absf(to_target.y):
				facing_direction = "right" if to_target.x > 0.0 else "left"
			else:
				facing_direction = "down" if to_target.y > 0.0 else "up"

func _update_animation() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	_update_facing()
	sprite.flip_h = false

	if current_state == State.HURT:
		if sprite.sprite_frames.has_animation("hurt") and sprite.animation != "hurt":
			sprite.play("hurt")
	elif current_state == State.ATTACK:
		var anim := "attack_" + facing_direction
		if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
			sprite.play(anim)
		elif sprite.sprite_frames.has_animation("attack") and sprite.animation != "attack":
			sprite.play("attack")
	elif (current_state == State.CHASE or current_state == State.WANDER) and velocity.length_squared() > 10.0:
		var move_anim := "move_" + facing_direction
		if sprite.sprite_frames.has_animation(move_anim) and sprite.animation != move_anim:
			sprite.play(move_anim)
		elif sprite.sprite_frames.has_animation("walk_" + facing_direction) and sprite.animation != "walk_" + facing_direction:
			sprite.play("walk_" + facing_direction)
		elif sprite.sprite_frames.has_animation("move") and sprite.animation != "move":
			sprite.play("move")
		elif sprite.sprite_frames.has_animation("walk") and sprite.animation != "walk":
			sprite.play("walk")
	else:
		var idle_anim := "idle_" + facing_direction
		if sprite.sprite_frames.has_animation(idle_anim) and sprite.animation != idle_anim:
			sprite.play(idle_anim)
		elif sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
			sprite.play("idle")
