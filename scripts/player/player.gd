extends CharacterBody2D

# Movement
const WALK_SPEED := 280.0
const DASH_SPEED := 650.0
const DASH_DURATION := 0.22
const SWIM_SPEED := 160.0
const CHARGE_TIME := 0.5
const ATTACK_COOLDOWN := 0.35
const KNOCKBACK_FORCE := 350.0

# State
enum State { IDLE, RUNNING, DASHING, SWIMMING, ATTACKING, CHARGING, DEAD }
var current_state: State = State.IDLE

# Stats and inventory
var stats: PlayerStats = PlayerStats.new()
var inventory: PlayerInventory = PlayerInventory.new()

# Movement vars
var direction: Vector2 = Vector2.ZERO
var look_direction: Vector2 = Vector2.DOWN
var facing_direction: String = "down"
var is_swimming: bool = false
# Overlapping water zones counter (fixes exit-one-while-still-inside-another bug)
var swim_zone_count: int = 0

# Dash vars
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

# Combat vars
var attack_timer: float = 0.0
var charge_timer: float = 0.0
var is_charging: bool = false
var attack_is_charged: bool = false
var attack_hit_confirmed: bool = false

# Stamina regen
var stamina_regen_cooldown: float = 0.0

# Interaction
var nearby_interactable: Node = null

@onready var sprite: AnimatedSprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape")
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_shape: CollisionShape2D = get_node_or_null("AttackArea/AttackShape")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var hurtbox: Area2D = get_node_or_null("Hurtbox")

var visual_renderer: CustomDraw2D = null
var sword_visual: SwordVisual = null

# Camera feel: smoothing + trauma-based shake
var camera: Camera2D = null
var cam_trauma: float = 0.0
const CAM_SHAKE_MAX := 16.0

func _ready() -> void:
	GameManager.player = self
	add_to_group("player")

	camera = get_node_or_null("Camera2D") as Camera2D
	if camera:
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 7.0
		camera.drag_horizontal_enabled = true
		camera.drag_vertical_enabled = true
		camera.drag_left_margin = 0.12
		camera.drag_right_margin = 0.12
		camera.drag_top_margin = 0.12
		camera.drag_bottom_margin = 0.12
		call_deferred("_setup_camera_limits")
	
	# Procedural renderer removed in favor of AnimatedSprite2D
	sword_visual = SwordVisual.new()
	sword_visual.name = "SwordVisual"
	sword_visual.position = Vector2(0, -8)
	sword_visual.z_index = 8
	add_child(sword_visual)
	
	stats.current_hp = stats.get_max_hp()
	stats.current_stamina = stats.get_max_stamina()
	
	if attack_area:
		attack_area.monitoring = false
	
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)
		interaction_area.area_entered.connect(_on_interaction_area_area_entered)
		interaction_area.area_exited.connect(_on_interaction_area_area_exited)
	
	EventBus.player_health_changed.emit(stats.current_hp, stats.get_max_hp())
	EventBus.player_stamina_changed.emit(stats.current_stamina, stats.get_max_stamina())
	EventBus.player_money_changed.emit(stats.money)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain:
		if not terrain.is_inside_playable_area(global_position):
			global_position = terrain.clamp_to_playable_area(global_position)
			velocity = Vector2.ZERO
		set_swimming(terrain.is_water(global_position + Vector2(0, 8)))
	_update_active_interactable()
	_handle_input()
	_update_timers(delta)
	_update_state(delta)
	_update_animation()
	_update_camera_shake(delta)
	move_and_slide()

func _handle_input() -> void:
	# Movement direction
	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		look_direction = direction
		if absf(direction.x) > absf(direction.y):
			facing_direction = "right" if direction.x > 0 else "left"
		else:
			facing_direction = "down" if direction.y > 0 else "up"
	
	# Dash
	if Input.is_action_just_pressed("dash") and current_state != State.DASHING:
		_try_dash()
	
	# Attack / Charge attack
	if Input.is_action_just_pressed("attack") and current_state not in [State.DASHING, State.DEAD]:
		if inventory.equipped_weapon.is_empty():
			EventBus.show_notification.emit("Equip your sword from the backpack first.")
			return
		var mouse_pos := get_global_mouse_position()
		var aim_dir := (mouse_pos - global_position).normalized()
		if aim_dir != Vector2.ZERO:
			look_direction = aim_dir
			if absf(aim_dir.x) > absf(aim_dir.y):
				facing_direction = "right" if aim_dir.x > 0 else "left"
			else:
				facing_direction = "down" if aim_dir.y > 0 else "up"
		is_charging = true
		charge_timer = 0.0
	
	if Input.is_action_just_released("attack") and is_charging:
		if charge_timer >= CHARGE_TIME:
			_charge_attack()
		else:
			_normal_attack()
		is_charging = false
		charge_timer = 0.0
	
	# Interact
	if Input.is_action_just_pressed("interact") and nearby_interactable:
		if nearby_interactable.has_method("interact"):
			nearby_interactable.interact(self)

func _update_timers(delta: float) -> void:
	stats.update_buffs(delta)
	if attack_timer > 0:
		attack_timer -= delta
	if dash_timer > 0:
		dash_timer -= delta
		if dash_timer <= 0:
			current_state = State.IDLE if not is_swimming else State.SWIMMING
	if is_charging:
		charge_timer += delta
	
	# Stamina regen
	if stamina_regen_cooldown > 0:
		stamina_regen_cooldown -= delta
	else:
		stats.regen_stamina(delta)
	
	# Swimming stamina drain (3 stamina per sec)
	if is_swimming and current_state != State.DEAD:
		if not stats.use_stamina(stats.SWIM_STAMINA_PER_SEC * delta):
			# Out of stamina while swimming - take drowning damage
			stats.take_damage(6.0 * delta)
			if stats.current_hp <= 0:
				die()
		stamina_regen_cooldown = stats.STAMINA_REGEN_DELAY

func _update_state(delta: float) -> void:
	match current_state:
		State.DASHING:
			velocity = dash_direction * DASH_SPEED * stats.get_speed_multiplier()
		State.ATTACKING:
			velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)
			if attack_timer <= 0:
				current_state = State.IDLE if not is_swimming else State.SWIMMING
				if attack_area:
					attack_area.monitoring = false
		_:
			if direction != Vector2.ZERO:
				var speed: float = SWIM_SPEED if is_swimming else WALK_SPEED
				velocity = direction.normalized() * speed * stats.get_speed_multiplier()
				current_state = State.SWIMMING if is_swimming else State.RUNNING
			else:
				velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
				if velocity.length() < 10:
					current_state = State.SWIMMING if is_swimming else State.IDLE

func _update_animation() -> void:
	if sword_visual:
		sword_visual.visible = not inventory.equipped_weapon.is_empty()
		sword_visual.swinging = current_state == State.ATTACKING
		sword_visual.charged = is_charging or attack_is_charged
		sword_visual.hit_confirmed = attack_hit_confirmed
		sword_visual.rotation = look_direction.angle()
	if attack_area:
		attack_area.position = look_direction.normalized() * 34
		attack_area.rotation = look_direction.angle()
	
	if sprite and sprite.sprite_frames:
		sprite.flip_h = false
		match current_state:
			State.ATTACKING:
				var anim := "attack_" + facing_direction
				if sprite.sprite_frames.has_animation(anim):
					sprite.play(anim)
				else:
					sprite.play("attack")
			State.DASHING:
				if sprite.sprite_frames.has_animation("dash"):
					sprite.play("dash")
				else:
					sprite.play("walk_" + facing_direction)
			State.RUNNING:
				var anim := "walk_" + facing_direction
				if sprite.sprite_frames.has_animation(anim):
					sprite.play(anim)
				else:
					sprite.play("walk")
			State.DEAD:
				if sprite.sprite_frames.has_animation("hurt"):
					sprite.play("hurt")
			_: # IDLE / SWIMMING
				var anim := "idle_" + facing_direction
				if sprite.sprite_frames.has_animation(anim):
					sprite.play(anim)
				else:
					sprite.play("idle")

func _update_camera_shake(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	if cam_trauma > 0.0:
		cam_trauma = maxf(0.0, cam_trauma - delta * 1.6)
		var strength: float = cam_trauma * cam_trauma * CAM_SHAKE_MAX
		camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

func add_trauma(amount: float) -> void:
	cam_trauma = clampf(cam_trauma + amount, 0.0, 1.0)

var nearby_interactables: Array[Node] = []

func get_effective_attack() -> float:
	var base_atk := stats.get_attack()
	var weapon_bonus: float = inventory.equipped_weapon.get("attack_bonus", 0.0)
	return base_atk + weapon_bonus + stats.get_attack_buff()

func get_effective_defense() -> float:
	# Supports both "defense" and legacy "defense_bonus" keys, plus food buffs.
	var armor_defense: float = 0.0
	if not inventory.equipped_armor.is_empty():
		armor_defense = float(inventory.equipped_armor.get("defense", inventory.equipped_armor.get("defense_bonus", 0.0)))
	return armor_defense + stats.get_defense_buff()

func enter_water() -> void:
	swim_zone_count += 1
	set_swimming(true)

func exit_water() -> void:
	swim_zone_count = maxi(0, swim_zone_count - 1)
	if swim_zone_count == 0:
		set_swimming(false)

func _try_dash() -> void:
	if stats.use_stamina(stats.DASH_STAMINA_COST):
		current_state = State.DASHING
		dash_timer = DASH_DURATION
		dash_direction = direction.normalized() if direction != Vector2.ZERO else look_direction
		stamina_regen_cooldown = stats.STAMINA_REGEN_DELAY
		VFX.dash_trail(self)

func _normal_attack() -> void:
	if attack_timer > 0.0:
		return
	attack_is_charged = false
	attack_hit_confirmed = false
	current_state = State.ATTACKING
	attack_timer = ATTACK_COOLDOWN
	if attack_area:
		attack_area.monitoring = true
		await get_tree().physics_frame
		if not is_instance_valid(attack_area):
			return
	var hits := _deal_damage_to_area(get_effective_attack(), false)
	attack_hit_confirmed = hits > 0
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(self):
		if attack_area and is_instance_valid(attack_area):
			attack_area.monitoring = false
		attack_hit_confirmed = false
		if current_state == State.ATTACKING:
			current_state = State.IDLE if not is_swimming else State.SWIMMING

func _charge_attack() -> void:
	if attack_timer > 0.0:
		return
	attack_is_charged = true
	attack_hit_confirmed = false
	current_state = State.ATTACKING
	attack_timer = ATTACK_COOLDOWN * 1.5
	if attack_area:
		attack_area.monitoring = true
		await get_tree().physics_frame
		if not is_instance_valid(attack_area):
			return
	var charge_damage: float = get_effective_attack() * 2.0
	var hits := _deal_damage_to_area(charge_damage, true)
	attack_hit_confirmed = hits > 0
	await get_tree().create_timer(0.25).timeout
	if is_instance_valid(self):
		if attack_area and is_instance_valid(attack_area):
			attack_area.monitoring = false
		attack_is_charged = false
		attack_hit_confirmed = false
		if current_state == State.ATTACKING:
			current_state = State.IDLE if not is_swimming else State.SWIMMING

func _deal_damage_to_area(damage: float, is_charge: bool = false) -> int:
	if attack_area == null:
		return 0
	var hit_targets: Array[Node] = []
	var hit_count := 0

	for body in attack_area.get_overlapping_bodies():
		if body != self and body not in hit_targets and body.has_method("take_damage"):
			hit_targets.append(body)
			var knockback_dir: Vector2 = (body.global_position - global_position).normalized()
			body.take_damage(damage, knockback_dir * KNOCKBACK_FORCE)
			EventBus.damage_dealt.emit(body, damage)
			add_trauma(0.45 if is_charge else 0.25)
			hit_count += 1

	for area in attack_area.get_overlapping_areas():
		var parent: Node = area.get_parent()
		if parent and parent != self and parent not in hit_targets and parent.has_method("take_damage"):
			hit_targets.append(parent)
			var knockback_dir: Vector2 = (parent.global_position - global_position).normalized() if parent is Node2D else Vector2.ZERO
			parent.take_damage(damage, knockback_dir * KNOCKBACK_FORCE)
			EventBus.damage_dealt.emit(parent, damage)
			add_trauma(0.45 if is_charge else 0.25)
			hit_count += 1
		elif area != self and area not in hit_targets and area.has_method("take_damage"):
			hit_targets.append(area)
			var knockback_dir: Vector2 = (area.global_position - global_position).normalized()
			area.take_damage(damage, knockback_dir * KNOCKBACK_FORCE)
			EventBus.damage_dealt.emit(area, damage)
			add_trauma(0.45 if is_charge else 0.25)
			hit_count += 1
	return hit_count

func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DASHING or current_state == State.DEAD:
		return # Invincible while dashing
	var defense: float = get_effective_defense()
	var final_dmg := maxf(1.0, amount - defense)
	stats.take_damage(final_dmg)
	stamina_regen_cooldown = stats.STAMINA_REGEN_DELAY
	add_trauma(0.45)
	if sprite:
		VFX.flash_hit(sprite)
	velocity += knockback
	if stats.current_hp <= 0:
		die()

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	velocity = Vector2.ZERO
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self):
		return
	GameManager.game_over()

func respawn() -> void:
	stats.current_hp = stats.get_max_hp()
	stats.current_stamina = stats.get_max_stamina()
	current_state = State.IDLE
	is_swimming = false
	swim_zone_count = 0
	attack_is_charged = false
	attack_hit_confirmed = false
	EventBus.player_health_changed.emit(stats.current_hp, stats.get_max_hp())
	EventBus.player_stamina_changed.emit(stats.current_stamina, stats.get_max_stamina())

func set_swimming(swimming: bool) -> void:
	if is_swimming == swimming:
		return
	is_swimming = swimming
	if swimming and current_state != State.DEAD and current_state != State.DASHING:
		current_state = State.SWIMMING
	elif not swimming and current_state == State.SWIMMING:
		current_state = State.IDLE

func _update_active_interactable() -> void:
	nearby_interactables = nearby_interactables.filter(func(n): return is_instance_valid(n))
	if nearby_interactables.is_empty():
		if nearby_interactable != null:
			nearby_interactable = null
			EventBus.interaction_unavailable.emit()
		return
	
	# Pick the closest one
	var closest: Node = null
	var min_d_sq: float = INF
	for item in nearby_interactables:
		if item is Node2D:
			var d_sq: float = global_position.distance_squared_to((item as Node2D).global_position)
			if d_sq < min_d_sq:
				min_d_sq = d_sq
				closest = item
		else:
			closest = item
	if nearby_interactable != closest:
		nearby_interactable = closest
		EventBus.interaction_available.emit(nearby_interactable)

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body != self and body.has_method("interact"):
		if body not in nearby_interactables:
			nearby_interactables.append(body)
		_update_active_interactable()

func _on_interaction_area_body_exited(body: Node2D) -> void:
	nearby_interactables.erase(body)
	_update_active_interactable()

func _on_interaction_area_area_entered(area: Area2D) -> void:
	var target: Node = area
	if not area.has_method("interact") and area.get_parent() and area.get_parent().has_method("interact"):
		target = area.get_parent()
	if target != self and target.has_method("interact"):
		if target not in nearby_interactables:
			nearby_interactables.append(target)
		_update_active_interactable()

func _on_interaction_area_area_exited(area: Area2D) -> void:
	var target: Node = area
	if not area.has_method("interact") and area.get_parent() and area.get_parent().has_method("interact"):
		target = area.get_parent()
	nearby_interactables.erase(target)
	_update_active_interactable()

func get_save_data() -> Dictionary:
	var data: Dictionary = stats.get_save_data()
	data["inventory"] = inventory.get_save_data()
	data["position"] = {"x": global_position.x, "y": global_position.y}
	return data

func load_save_data(data: Dictionary) -> void:
	stats.load_save_data(data)
	var inventory_value: Variant = data.get("inventory", {})
	if inventory_value is Dictionary:
		inventory.load_save_data(inventory_value)
	var position_value: Variant = data.get("position", {})
	if position_value is Dictionary:
		var saved_position: Dictionary = position_value
		global_position = Vector2(
			float(saved_position.get("x", global_position.x)),
			float(saved_position.get("y", global_position.y))
		)
	var terrain := get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain:
		global_position = terrain.clamp_to_playable_area(global_position)
	EventBus.player_health_changed.emit(stats.current_hp, stats.get_max_hp())
	EventBus.player_stamina_changed.emit(stats.current_stamina, stats.get_max_stamina())
	EventBus.player_money_changed.emit(stats.money)

func _setup_camera_limits() -> void:
	if not is_instance_valid(camera):
		return
	var island: IslandWorld = get_tree().get_first_node_in_group("island_world") as IslandWorld
	if island and island.bounds.size != Vector2.ZERO:
		var margin := 400.0
		camera.limit_left = int(island.bounds.position.x - margin)
		camera.limit_top = int(island.bounds.position.y - margin)
		camera.limit_right = int(island.bounds.end.x + margin)
		camera.limit_bottom = int(island.bounds.end.y + margin)
