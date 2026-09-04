class_name Wildlife
extends CharacterBody2D

enum AnimalType { RABBIT, DEER, BIRD }
@export var animal_type: AnimalType = AnimalType.RABBIT
@export var move_speed: float = 60.0

var wander_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var sprite: AnimatedSprite2D = null

func _ready() -> void:
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "AnimatedSprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		match animal_type:
			AnimalType.RABBIT:
				sprite.sprite_frames = load("res://assets/sprites/wildlife/rabbit_frames.tres")
				move_speed = 70.0
			AnimalType.DEER:
				sprite.sprite_frames = load("res://assets/sprites/wildlife/deer_frames.tres")
				move_speed = 50.0
			AnimalType.BIRD:
				sprite.sprite_frames = load("res://assets/sprites/wildlife/bird_frames.tres")
				move_speed = 90.0
		sprite.play("idle")
		add_child(sprite)
	
	wander_timer = randf_range(1.0, 4.0)

var lod_tick: float = 0.0

func _physics_process(delta: float) -> void:
	# Distance LOD: sleep if far away from player to save 90% physics overhead
	if GameManager.player and is_instance_valid(GameManager.player):
		var dist_sq: float = global_position.distance_squared_to(GameManager.player.global_position)
		if dist_sq > 1690000.0: # 1300^2 pixels
			lod_tick += delta
			if lod_tick >= 2.5:
				lod_tick = 0.0
				wander_timer = randf_range(2.0, 5.0)
			return
	
	wander_timer -= delta
	
	# Flee from player if too close
	if GameManager.player and is_instance_valid(GameManager.player):
		var dist: float = global_position.distance_to(GameManager.player.global_position)
		if dist < 100.0:
			wander_dir = (global_position - GameManager.player.global_position).normalized()
			wander_timer = 2.0
	
	if wander_timer <= 0:
		wander_timer = randf_range(2.0, 6.0)
		if randf() > 0.5:
			wander_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		else:
			wander_dir = Vector2.ZERO
	
	if wander_dir != Vector2.ZERO:
		velocity = wander_dir * move_speed
		if sprite:
			sprite.flip_h = wander_dir.x < 0
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
	
	move_and_slide()
