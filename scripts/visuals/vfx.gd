class_name VFX
extends RefCounted

## Lightweight juice: pooled-ish one-shot CPUParticles2D + hit flashes.
## CPUParticles2D is used (not GPU) so Web/GL-Compatibility stays fast.

static func burst(parent: Node, pos: Vector2, color: Color, amount: int = 12, speed: float = 120.0, lifetime: float = 0.5, gravity: Vector2 = Vector2(0, 200)) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	# Cap live bursts so machine-gun hits can't spawn hundreds of nodes.
	var live := 0
	for c in parent.get_children():
		if c is CPUParticles2D and (c as CPUParticles2D).emitting:
			live += 1
			if live > 12:
				return
	var p := CPUParticles2D.new()
	if parent is Node2D:
		p.position = (parent as Node2D).to_local(pos)
	else:
		p.position = pos
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = gravity
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.z_index = 50
	parent.add_child(p)
	p.emitting = true
	# Free after emission finishes (lifetime + render tail).
	var tree := parent.get_tree()
	if tree:
		tree.create_timer(lifetime + 0.6).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)

static func dash_trail(player: Node2D) -> void:
	burst(player.get_parent(), player.global_position, Color(0.5, 0.85, 1.0, 0.9), 10, 60.0, 0.35, Vector2.ZERO)

static func slime_pop(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	burst(node.get_parent(), node.global_position, Color(0.4, 0.9, 0.4, 0.9), 16, 160.0, 0.5)

static func mine_sparks(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	burst(node.get_parent(), node.global_position + Vector2(0, -8), Color(1.0, 0.8, 0.3, 0.95), 8, 140.0, 0.4)

static func pickup_sparkle(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	burst(node.get_parent(), node.global_position, Color(1.0, 0.95, 0.5, 0.9), 6, 80.0, 0.35, Vector2.ZERO)

static func campfire_embers(campfire: Node2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "Embers"
	p.position = Vector2(0, -10)
	p.amount = 24
	p.lifetime = 1.2
	p.preprocess = 1.2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 8.0
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, -30)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(1.0, 0.55, 0.15, 0.9)
	campfire.add_child(p)
	p.emitting = true
	return p

static func flash_hit(node: CanvasItem) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.modulate = Color(1.6, 0.6, 0.6)
	var tween := node.create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, 0.18)
