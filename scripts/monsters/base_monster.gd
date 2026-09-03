class_name BaseMonster
extends CharacterBody2D

@export var base_hp: float = 50.0
@export var base_attack: float = 10.0
@export var base_speed: float = 80.0
@export var detection_range: float = 200.0
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.0
@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 5
@export var exp_drop: int = 25

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }
var current_state: State = State.IDLE

var current_hp: float
var scaled_attack: float
var scaled_speed: float

var target: CharacterBody2D = null
var attack_timer: float = 0.0
var wander_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var knockback_velocity: Vector2 = Vector2.ZERO
var hurt_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")

var visual_renderer: CustomDraw2D = null

func _ready() -> void:
	add_to_group("monsters")
	_scale_to_player_level()
	current_hp = base_hp
	
	# Procedural renderer removed in favor of AnimatedSprite2D
	
	if health_bar:
		health_bar.max_value = base_hp
		health_bar.value = current_hp
		health_bar.visible = false
	
	wander_timer = randf_range(1.0, 4.0)

func _scale_to_player_level() -> void:
	var player_level: int = 0
	if GameManager.player and GameManager.player.stats:
		player_level = GameManager.player.stats.level
	base_hp = base_hp * (1.0 + player_level * 0.12)
	base_attack = base_attack * (1.0 + player_level * 0.10)
	scaled_speed = base_speed * (1.0 + player_level * 0.03)
	scaled_attack = base_attack
	coin_drop_min += int(player_level * 0.5)
	coin_drop_max += player_level
	exp_drop = int(float(exp_drop) * (1.0 + player_level * 0.08))

var lod_tick: float = 0.0

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	# Distance LOD: if further than 1500px from player, sleep to eliminate off-screen physics collisions
	if GameManager.player and is_instance_valid(GameManager.player):
		var dist_sq: float = global_position.distance_squared_to(GameManager.player.global_position)
		if dist_sq > 2250000.0: # 1500^2 pixels
			lod_tick += delta
			if lod_tick >= 2.0:
				lod_tick = 0.0
				wander_timer = randf_range(2.0, 5.0)
			return
	
	_update_timers(delta)
	_update_ai(delta)
	_apply_knockback(delta)
	_update_animation()
	move_and_slide()

func _update_timers(delta: float) -> void:
	if attack_timer > 0:
		attack_timer -= delta
	if hurt_timer > 0:
		hurt_timer -= delta
		if hurt_timer <= 0 and current_state == State.HURT:
			current_state = State.IDLE

func _update_ai(delta: float) -> void:
	if current_state == State.HURT:
		return
	
	# Find player
	target = GameManager.player
	if target == null or target.current_state == target.State.DEAD:
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
	if wander_timer <= 0:
		wander_timer = randf_range(2.0, 5.0)
		if randf() > 0.4:
			wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			current_state = State.WANDER
		else:
			wander_direction = Vector2.ZERO
			current_state = State.IDLE
	
	if wander_direction != Vector2.ZERO:
		velocity = wander_direction * scaled_speed * 0.4
	else:
		velocity = Vector2.ZERO

func _try_attack() -> void:
	if attack_timer > 0:
		return
	current_state = State.ATTACK
	attack_timer = attack_cooldown
	velocity = Vector2.ZERO
	_perform_attack()

func _perform_attack() -> void:
	if target and target.has_method("take_damage"):
		var knockback_dir: Vector2 = (target.global_position - global_position).normalized()
		target.take_damage(scaled_attack, knockback_dir * 200.0)

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return
	
	current_hp -= amount
	knockback_velocity = knockback
	current_state = State.HURT
	hurt_timer = 0.3
	_spawn_damage_number(amount)
	if sprite:
		VFX.flash_hit(sprite)
	
	if health_bar:
		health_bar.visible = true
		health_bar.value = current_hp
	
	if current_hp <= 0:
		die()

func _spawn_damage_number(amount: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	# Pool cap: avoid Label + Tween spam when multi-hit / many slimes.
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
	if knockback_velocity.length() > 5:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 600.0 * delta)

func die() -> void:
	current_state = State.DEAD
	velocity = Vector2.ZERO
	_drop_loot()
	EventBus.monster_killed.emit(self, global_position)
	VFX.slime_pop(self)
	var tween := create_tween()
	if visual_renderer:
		tween.tween_property(visual_renderer, "modulate:a", 0.0, 0.4)
	elif sprite:
		tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _drop_loot() -> void:
	var coin_amount := randi_range(coin_drop_min, coin_drop_max)
	if GameManager.player and GameManager.player.stats:
		GameManager.player.stats.add_money(coin_amount)
		GameManager.player.stats.add_exp(exp_drop)
		EventBus.show_notification.emit("+%d Gold, +%d EXP" % [coin_amount, exp_drop])
		
		# Occasional bonus material drop (35% chance)
		if randf() < 0.35:
			var items_pool := ["herb", "mushroom"]
			var chosen: String = items_pool.pick_random()
			var drop_data := {
				"id": chosen,
				"name": chosen.capitalize(),
				"type": 0,
				"quantity": 1,
				"stackable": true,
				"description": "Dropped by a defeated slime."
			}
			if GameManager.player.inventory:
				GameManager.player.inventory.add_item(drop_data)
				EventBus.show_notification.emit("+1 %s dropped!" % chosen.capitalize())

func _update_animation() -> void:
	if sprite and sprite.sprite_frames:
		if velocity.x < 0:
			sprite.flip_h = true
		elif velocity.x > 0:
			sprite.flip_h = false
			
		if current_state == State.HURT:
			sprite.play("hurt")
		elif current_state == State.CHASE or current_state == State.WANDER:
			sprite.play("move")
		else:
			sprite.play("idle")
