class_name NPCCombatEffect
extends Node2D

## Small, pooled-by-cap procedural effects for the rare NPC combat event.
## These are effects only; NPC character models remain authored in their scenes.

const EFFECT_BLOOD := 0
const EFFECT_MUZZLE_SMOKE := 1
const EFFECT_TRACER := 2

var effect_kind: int = EFFECT_BLOOD
var effect_direction: Vector2 = Vector2.RIGHT
var effect_distance: float = 32.0
var age: float = 0.0
var lifetime: float = 0.7
var _particles: Array[Dictionary] = []

func setup(kind: int, direction: Vector2 = Vector2.RIGHT, distance: float = 32.0) -> NPCCombatEffect:
	effect_kind = kind
	effect_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	effect_distance = maxf(8.0, distance)
	_particles.clear()
	scale = Vector2.ONE
	match effect_kind:
		EFFECT_BLOOD:
			lifetime = 0.72
			for index in range(9):
				var angle := randf_range(-PI, PI)
				var speed := randf_range(24.0, 92.0)
				_particles.append({
					"offset": Vector2.ZERO,
					"velocity": Vector2.RIGHT.rotated(angle) * speed,
					"radius": randf_range(1.4, 3.0),
					"delay": randf_range(0.0, 0.045),
					"duration": randf_range(0.38, 0.66),
					"dark": index % 3 == 0
				})
		EFFECT_MUZZLE_SMOKE:
			lifetime = 0.52
			for index in range(6):
				_particles.append({
					"offset": effect_direction * randf_range(8.0, 15.0) + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)),
					"velocity": Vector2(randf_range(-8.0, 8.0), randf_range(-28.0, -10.0)),
					"radius": randf_range(2.6, 5.0),
					"delay": float(index) * 0.018,
					"duration": randf_range(0.30, 0.50),
					"dark": index % 2 == 0
				})
		EFFECT_TRACER:
			lifetime = 0.09
		queue_redraw()
	return self

func _ready() -> void:
	add_to_group("npc_combat_fx")
	z_index = 82

func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	for index in range(_particles.size()):
		var particle: Dictionary = _particles[index]
		var delay := float(particle.get("delay", 0.0))
		if age < delay:
			continue
		var offset: Vector2 = particle.get("offset", Vector2.ZERO)
		var particle_velocity: Vector2 = particle.get("velocity", Vector2.ZERO)
		offset += particle_velocity * delta
		particle["offset"] = offset
		if effect_kind == EFFECT_BLOOD:
			particle_velocity += Vector2(0.0, 170.0) * delta
		else:
			particle_velocity *= 0.985
		particle["velocity"] = particle_velocity
		_particles[index] = particle
	queue_redraw()

func _draw() -> void:
	var fade := 1.0 - clampf(age / lifetime, 0.0, 1.0)
	match effect_kind:
		EFFECT_BLOOD:
			for particle: Dictionary in _particles:
				var delay := float(particle.get("delay", 0.0))
				var duration := maxf(0.05, float(particle.get("duration", lifetime)))
				var particle_age := age - delay
				if particle_age <= 0.0 or particle_age >= duration:
					continue
				var particle_fade := 1.0 - clampf(particle_age / duration, 0.0, 1.0)
				var color := Color("#9c2028") if bool(particle.get("dark", false)) else Color("#d94742")
				color.a = particle_fade * fade
				draw_circle(particle.get("offset", Vector2.ZERO), float(particle.get("radius", 2.0)), color)
		EFFECT_MUZZLE_SMOKE:
			for particle: Dictionary in _particles:
				var delay := float(particle.get("delay", 0.0))
				var duration := maxf(0.05, float(particle.get("duration", lifetime)))
				var particle_age := age - delay
				if particle_age <= 0.0 or particle_age >= duration:
					continue
				var particle_fade := 1.0 - clampf(particle_age / duration, 0.0, 1.0)
				var radius := float(particle.get("radius", 3.0)) * (1.0 + particle_age * 1.8)
				var smoke_color := Color(0.16, 0.17, 0.19, 0.16 * particle_fade * fade)
				if bool(particle.get("dark", false)):
					smoke_color = Color(0.08, 0.09, 0.10, 0.13 * particle_fade * fade)
				draw_circle(particle.get("offset", Vector2.ZERO), radius, smoke_color)
				draw_circle(particle.get("offset", Vector2.ZERO) + Vector2(-0.8, -0.8), radius * 0.62, Color(0.55, 0.57, 0.60, smoke_color.a * 0.34))
		EFFECT_TRACER:
			var tracer_color := Color(1.0, 0.86, 0.48, fade * 0.9)
			draw_line(Vector2.ZERO, effect_direction * effect_distance, tracer_color, 1.5, true)
