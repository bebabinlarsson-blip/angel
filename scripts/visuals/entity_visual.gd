class_name CustomDraw2D
extends Node2D

## High-Quality 30 FPS Procedural Character Models, Textures & Animation System

enum EntityType {
	PLAYER,
	SLIME,
	CAMPFIRE,
	HOUSE,
	TREE,
	ROCK,
	FLOWER,
	RUIN,
	WAYSTONE,
	NPC_ELDER,
	NPC_CARPENTER,
	NPC_COOK,
	NPC_MINER,
	ANIMAL_RABBIT,
	ANIMAL_DEER,
	ANIMAL_BIRD,
	ORE_VEIN,
	ITEM_WOOD,
	ITEM_HERB,
	ITEM_MUSHROOM,
	ITEM_ORE
}

@export var entity_type: EntityType = EntityType.TREE
@export var custom_color: Color = Color.WHITE
@export var anim_time: float = 0.0

var parent_node: Node2D = null
var is_animated: bool = false
var anim_frame: int = 0
var frame_timer: float = 0.0

# 30 FPS target interval (1/30 = 0.03333 seconds)
const FPS_30_INTERVAL: float = 0.03333

func _ready() -> void:
	parent_node = get_parent() as Node2D
	# Only dynamic living characters, monsters, campfire, and waystone need per-frame ticking
	is_animated = entity_type in [
		EntityType.PLAYER,
		EntityType.SLIME,
		EntityType.CAMPFIRE,
		EntityType.WAYSTONE,
		EntityType.NPC_ELDER,
		EntityType.NPC_CARPENTER,
		EntityType.NPC_COOK,
		EntityType.NPC_MINER,
		EntityType.ANIMAL_RABBIT,
		EntityType.ANIMAL_DEER,
		EntityType.ANIMAL_BIRD
	]
	
	if not is_animated:
		set_process(false) # Disables 800+ static trees, rocks, flowers, ores, and items from the process loop
	
	# Initial draw
	queue_redraw()

func _process(delta: float) -> void:
	if not is_animated:
		return
	
	anim_time += delta
	frame_timer += delta
	
	# Always animate player smoothly
	if entity_type == EntityType.PLAYER:
		if frame_timer >= FPS_30_INTERVAL:
			frame_timer = fmod(frame_timer, FPS_30_INTERVAL)
			anim_frame = (anim_frame + 1) % 3600
			queue_redraw()
		return
	
	# Distance culling for other entities: do not redraw if player is not ready or if entity is off-screen
	if GameManager.player == null or not is_instance_valid(GameManager.player):
		return
	
	var dist_sq: float = global_position.distance_squared_to(GameManager.player.global_position)
	if dist_sq > 1440000.0: # 1200^2 pixels
		return
	
	# 30 FPS update tick
	if frame_timer >= FPS_30_INTERVAL:
		frame_timer = fmod(frame_timer, FPS_30_INTERVAL)
		anim_frame = (anim_frame + 1) % 3600
		queue_redraw()

func _draw() -> void:
	match entity_type:
		EntityType.PLAYER:
			_draw_player()
		EntityType.SLIME:
			_draw_slime()
		EntityType.CAMPFIRE:
			_draw_campfire()
		EntityType.HOUSE:
			_draw_house()
		EntityType.TREE:
			_draw_tree()
		EntityType.ROCK:
			_draw_rock()
		EntityType.FLOWER:
			_draw_flower()
		EntityType.RUIN:
			_draw_ruin()
		EntityType.WAYSTONE:
			_draw_waystone()
		EntityType.NPC_ELDER:
			_draw_npc_elder()
		EntityType.NPC_CARPENTER:
			_draw_npc_carpenter()
		EntityType.NPC_COOK:
			_draw_npc_cook()
		EntityType.NPC_MINER:
			_draw_npc_miner()
		EntityType.ANIMAL_RABBIT:
			_draw_rabbit()
		EntityType.ANIMAL_DEER:
			_draw_deer()
		EntityType.ANIMAL_BIRD:
			_draw_bird()
		EntityType.ORE_VEIN:
			_draw_ore_vein()
		EntityType.ITEM_WOOD:
			_draw_item_wood()
		EntityType.ITEM_HERB:
			_draw_item_herb()
		EntityType.ITEM_MUSHROOM:
			_draw_item_mushroom()
		EntityType.ITEM_ORE:
			_draw_item_ore()

# ==============================================================================
# 1. PLAYER CHARACTER (4-Directional, Multi-State 30 FPS Animator)
# ==============================================================================
func _draw_player() -> void:
	var is_moving: bool = false
	var is_dashing: bool = false
	var is_attacking: bool = false
	var is_charging: bool = false
	var is_swimming: bool = false
	var is_dead: bool = false
	var look_dir: Vector2 = Vector2.DOWN
	var move_spd: float = 0.0
	
	if parent_node:
		if "velocity" in parent_node:
			var vel := parent_node.velocity as Vector2
			move_spd = vel.length()
			is_moving = move_spd > 10.0
		if "current_state" in parent_node:
			var state = parent_node.current_state
			is_dashing = (state == 2) # DASHING
			is_swimming = (state == 3) # SWIMMING
			is_attacking = (state == 4) # ATTACKING
			is_charging = (state == 5) or ("is_charging" in parent_node and parent_node.is_charging)
			is_dead = (state == 6) # DEAD
		if "look_direction" in parent_node:
			look_dir = (parent_node.look_direction as Vector2).normalized()
	
	# Determine primary facing: 0=Down, 1=Up, 2=Left, 3=Right
	var facing: int = 0
	if absf(look_dir.x) > absf(look_dir.y):
		facing = 2 if look_dir.x < 0 else 3
	else:
		facing = 0 if look_dir.y >= 0 else 1
	
	var flip: float = -1.0 if facing == 2 else 1.0
	
	# --- SWIMMING WATER RIPPLES ---
	if is_swimming:
		var wave_phase: float = sin(anim_time * 6.0) * 4.0
		draw_arc(Vector2(0, 8), 20.0 + wave_phase, 0, TAU, 24, Color(0.4, 0.8, 1.0, 0.7), 2.5)
		draw_circle(Vector2(0, 8), 16.0 + wave_phase * 0.5, Color(0.2, 0.6, 0.9, 0.35))
		draw_arc(Vector2(0, 8), 28.0 + sin(anim_time * 4.0) * 5.0, 0, TAU, 20, Color(0.5, 0.85, 1.0, 0.4), 1.5)
	
	# --- DASH MOTION BLUR TRAIL ---
	if is_dashing:
		var dash_trail_offset := -look_dir * 14.0
		draw_circle(dash_trail_offset, 14.0, Color(0.3, 0.85, 1.0, 0.45))
		draw_circle(dash_trail_offset * 1.8, 10.0, Color(0.3, 0.85, 1.0, 0.25))
		# Speed streaks
		draw_line(dash_trail_offset + Vector2(-8, -6), dash_trail_offset + Vector2(-22, -6), Color(1, 1, 1, 0.6), 2.0)
		draw_line(dash_trail_offset + Vector2(-6, 8), dash_trail_offset + Vector2(-20, 8), Color(1, 1, 1, 0.6), 2.0)
	
	# --- CHARGING ATTACK ENERGY AURA ---
	if is_charging:
		var charge_glow: float = (sin(anim_time * 16.0) + 1.0) * 0.5
		var aura_r: float = 24.0 + charge_glow * 6.0
		draw_arc(Vector2.ZERO, aura_r, 0, TAU, 32, Color(1.0, 0.85, 0.2, 0.8), 2.5)
		draw_circle(Vector2.ZERO, aura_r * 0.75, Color(1.0, 0.9, 0.3, 0.22))
		# Orbiting charge motes
		for m in range(4):
			var m_ang: float = anim_time * 8.0 + float(m) * (TAU / 4.0)
			var m_pos := Vector2(cos(m_ang) * (aura_r + 4.0), sin(m_ang) * (aura_r + 4.0))
			draw_circle(m_pos, 3.0, Color(1.0, 0.95, 0.5, 0.9))
	
	# --- GROUND SHADOW ---
	if not is_swimming and not is_dead:
		var shadow_w: float = 14.0 if not is_dashing else 18.0
		draw_set_transform(Vector2(0, 14), 0, Vector2(shadow_w / 10.0, 0.6))
		draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# 30 FPS Walk cycle & Breathing parameters
	var walk_bob: float = absf(sin(anim_time * 12.0)) * 2.5 if is_moving else sin(anim_time * 3.5) * 0.8
	var step_left: float = sin(anim_time * 12.0) * 5.0 if is_moving else 0.0
	var step_right: float = -sin(anim_time * 12.0) * 5.0 if is_moving else 0.0
	
	# Dead collapse animation
	if is_dead:
		draw_set_transform(Vector2(0, 10), -PI / 2.0, Vector2.ONE)
	
	# --- LEGS & BOOTS (When not swimming) ---
	if not is_swimming:
		var boot_col := Color(0.28, 0.18, 0.12)
		var boot_high := Color(0.42, 0.28, 0.18)
		if facing == 0 or facing == 1: # Down or Up
			# Left boot
			draw_rect(Rect2(-7, 6 + step_left, 5, 8), boot_col)
			draw_rect(Rect2(-7, 12 + step_left, 5, 2), boot_high)
			# Right boot
			draw_rect(Rect2(2, 6 + step_right, 5, 8), boot_col)
			draw_rect(Rect2(2, 12 + step_right, 5, 2), boot_high)
		else: # Side (Left/Right)
			draw_rect(Rect2(-4 * flip - 3, 6 + step_left, 6, 8), boot_col)
			draw_rect(Rect2(2 * flip - 3, 6 + step_right, 6, 8), boot_col)
	
	# --- BODY / HERO TUNIC ---
	var tunic_y: float = -8.0 + walk_bob
	var tunic_col := Color(0.18, 0.48, 0.90) # Hero Azure Blue
	var tunic_dark := Color(0.12, 0.35, 0.70)
	var tunic_trim := Color(0.95, 0.82, 0.25) # Gold embroidery
	
	if facing == 1: # Facing Up (Back view)
		draw_rect(Rect2(-8, tunic_y, 16, 14 if not is_swimming else 8), tunic_dark)
		draw_rect(Rect2(-8, tunic_y + 11, 16, 3), Color(0.35, 0.22, 0.12)) # Belt
		# Scabbard strap across back
		draw_line(Vector2(-7, tunic_y + 2), Vector2(7, tunic_y + 12), Color(0.4, 0.25, 0.15), 2.5)
	elif facing == 0: # Facing Down (Front view)
		draw_rect(Rect2(-8, tunic_y, 16, 14 if not is_swimming else 8), tunic_col)
		draw_rect(Rect2(-8, tunic_y + 10, 16, 3), Color(0.45, 0.28, 0.15)) # Belt
		draw_rect(Rect2(-2, tunic_y + 9, 4, 5), tunic_trim) # Belt Buckle
		# Tunic collar V-neck
		draw_line(Vector2(-4, tunic_y), Vector2(0, tunic_y + 4), tunic_trim, 1.5)
		draw_line(Vector2(4, tunic_y), Vector2(0, tunic_y + 4), tunic_trim, 1.5)
	else: # Facing Side (Left / Right)
		draw_rect(Rect2(-6 * flip - 4, tunic_y, 12, 14 if not is_swimming else 8), tunic_col)
		draw_rect(Rect2(-6 * flip - 4, tunic_y + 10, 12, 3), Color(0.45, 0.28, 0.15))
		draw_rect(Rect2(3 * flip - 2, tunic_y + 9, 4, 5), tunic_trim)
	
	# --- HEAD, HAIR & FACE ---
	var head_center := Vector2(0, -16.0 + walk_bob)
	var skin_col := Color(0.98, 0.86, 0.74)
	var hair_col := Color(0.42, 0.25, 0.14) # Chestnut brown
	var hair_high := Color(0.58, 0.36, 0.20)
	
	# Head base
	draw_circle(head_center, 8.0, skin_col)
	
	if facing == 1: # Up (Back hair)
		draw_circle(head_center, 8.5, hair_col)
		draw_rect(Rect2(-7, head_center.y - 4, 14, 10), hair_col)
		draw_circle(head_center + Vector2(0, -3), 7.0, hair_high)
	elif facing == 0: # Down (Front face)
		# Hair crown & bangs
		draw_circle(head_center + Vector2(0, -3), 8.5, hair_col)
		draw_rect(Rect2(-8, head_center.y - 8, 16, 6), hair_col)
		# Hair bangs strands
		draw_line(head_center + Vector2(-6, -4), head_center + Vector2(-3, 0), hair_col, 2.5)
		draw_line(head_center + Vector2(6, -4), head_center + Vector2(3, 0), hair_col, 2.5)
		draw_line(head_center + Vector2(0, -5), head_center + Vector2(1, -1), hair_high, 2.0)
		# Eyes (Blink cycle at 30 FPS)
		var is_blinking: bool = (anim_frame % 90) > 85
		if not is_blinking and not is_dead:
			draw_rect(Rect2(-4, head_center.y - 1, 2, 3), Color(0.12, 0.12, 0.15))
			draw_rect(Rect2(2, head_center.y - 1, 2, 3), Color(0.12, 0.12, 0.15))
			draw_circle(Vector2(-3.5, head_center.y - 0.5), 0.7, Color(1, 1, 1))
			draw_circle(Vector2(2.5, head_center.y - 0.5), 0.7, Color(1, 1, 1))
		else:
			draw_line(Vector2(-5, head_center.y), Vector2(-2, head_center.y), Color(0.15, 0.15, 0.18), 1.5)
			draw_line(Vector2(2, head_center.y), Vector2(5, head_center.y), Color(0.15, 0.15, 0.18), 1.5)
	else: # Side (Left / Right)
		draw_circle(head_center + Vector2(-2 * flip, -3), 8.5, hair_col)
		draw_rect(Rect2(-8, head_center.y - 8, 16, 6), hair_col)
		# Side tuft
		draw_line(head_center + Vector2(2 * flip, -4), head_center + Vector2(6 * flip, 1), hair_col, 3.0)
		# Eye
		var eye_x: float = head_center.x + 4.0 * flip
		if not is_dead and (anim_frame % 90) <= 85:
			draw_rect(Rect2(eye_x - 1, head_center.y - 1, 2, 3), Color(0.12, 0.12, 0.15))
			draw_circle(Vector2(eye_x, head_center.y - 0.5), 0.6, Color(1, 1, 1))
		else:
			draw_line(Vector2(eye_x - 1.5, head_center.y), Vector2(eye_x + 1.5, head_center.y), Color(0.15, 0.15, 0.18), 1.5)
	
	# --- SWORD & COMBAT ATTACK ANIMATION ---
	var hand_pos := Vector2(9.0 * flip, -4.0 + walk_bob)
	var sword_blade_col := Color(0.92, 0.95, 1.0)
	var guard_col := Color(0.95, 0.82, 0.25)
	
	if is_attacking:
		# Attack slash thrust with dynamic swinging blade
		var slash_dir := look_dir
		var sword_tip := slash_dir * 32.0
		# Sword thrust
		draw_line(Vector2.ZERO, sword_tip, sword_blade_col, 3.5)
		draw_line(Vector2.ZERO, slash_dir * 12.0, guard_col, 5.0)
		
		# Glowing crescent slash trail arc
		var slash_col := Color(1.0, 1.0, 1.0, 0.85)
		var slash_rim := Color(0.3, 0.8, 1.0, 0.9)
		draw_arc(slash_dir * 14.0, 22.0, slash_dir.angle() - 1.2, slash_dir.angle() + 1.2, 16, slash_rim, 5.0)
		draw_arc(slash_dir * 14.0, 22.0, slash_dir.angle() - 0.9, slash_dir.angle() + 0.9, 12, slash_col, 2.5)
	elif is_charging:
		# Sword held high gathering power
		var sword_top := hand_pos + Vector2(0, -22)
		draw_line(hand_pos, sword_top, Color(1.0, 0.95, 0.5), 4.0)
		draw_line(hand_pos + Vector2(-3, -2), hand_pos + Vector2(3, -2), guard_col, 4.0)
	else:
		# Rested / Walking sword
		var sword_tip := hand_pos + Vector2(4.0 * flip, -14.0)
		draw_line(hand_pos, sword_tip, sword_blade_col, 2.5)
		draw_line(hand_pos + Vector2(-2 * flip, 1), hand_pos + Vector2(2 * flip, -3), guard_col, 3.5)
	
	if is_dead:
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# ==============================================================================
# 2. SLIME MONSTER (Organic Jelly 30 FPS Hop & Squash Animator)
# ==============================================================================
func _draw_slime() -> void:
	var is_hurt: bool = false
	var is_jumping: bool = false
	var is_dead: bool = false
	var vel_len: float = 0.0
	
	if parent_node:
		if "current_state" in parent_node:
			var s = parent_node.current_state
			is_hurt = (s == 4) # HURT
			is_dead = (s == 5) # DEAD
		if "is_jumping" in parent_node:
			is_jumping = parent_node.is_jumping
		if "velocity" in parent_node:
			vel_len = (parent_node.velocity as Vector2).length()
	
	# 30 FPS Organic Wobble / Hop Cycle
	var hop_cycle: float = fmod(anim_time * 4.0, 1.0)
	var squash: float = 1.0
	var stretch: float = 1.0
	var y_lift: float = 0.0
	
	if is_jumping or vel_len > 40.0:
		# Active leap cycle
		if hop_cycle < 0.2: # Anticipation squash
			squash = 1.35
			stretch = 0.7
			y_lift = 2.0
		elif hop_cycle < 0.65: # Airborne stretch
			squash = 0.8
			stretch = 1.35
			y_lift = -sin((hop_cycle - 0.2) / 0.45 * PI) * 12.0
		else: # Landing squash
			squash = 1.25
			stretch = 0.8
			y_lift = 0.0
	else:
		# Idle jelly breathing
		var wobble: float = sin(anim_time * 5.0) * 0.12
		squash = 1.0 + wobble
		stretch = 1.0 - wobble * 0.9
	
	# Shadow
	draw_set_transform(Vector2(0, 8), 0, Vector2(squash * 1.2, 0.45))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Slime Colors (Emerald Jelly / Hurt Crimson)
	var main_col := Color(1.0, 0.35, 0.35, 0.9) if is_hurt else Color(0.28, 0.88, 0.38, 0.88)
	var dark_col := Color(0.85, 0.2, 0.2, 1.0) if is_hurt else Color(0.16, 0.68, 0.26, 1.0)
	var core_col := Color(1.0, 0.7, 0.7, 0.75) if is_hurt else Color(0.12, 0.55, 0.22, 0.85)
	
	# Jelly Dome Polygon
	var pts := PackedVector2Array()
	var center := Vector2(0, 2.0 + y_lift)
	var segments: int = 18
	for i in range(segments + 1):
		var ang: float = PI + (PI * float(i) / float(segments))
		var rx: float = 15.0 * squash
		var ry: float = 13.0 * stretch
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	# Base curve
	pts.append(Vector2(15.0 * squash, 6.0 + y_lift))
	pts.append(Vector2(0, 7.5 + y_lift))
	pts.append(Vector2(-15.0 * squash, 6.0 + y_lift))
	
	draw_colored_polygon(pts, main_col)
	draw_polyline(pts, dark_col, 2.0)
	
	# Internal floating jelly nucleus / core
	var core_wobble := Vector2(sin(anim_time * 7.0) * 2.0, -1.0 + y_lift + cos(anim_time * 6.0) * 1.5)
	draw_circle(core_wobble, 5.0 * minf(squash, stretch), core_col)
	
	# Specular Shine Highlights
	draw_circle(Vector2(-6.0 * squash, -4.0 * stretch + y_lift), 3.5, Color(1, 1, 1, 0.75))
	draw_circle(Vector2(-3.0 * squash, -7.0 * stretch + y_lift), 2.0, Color(1, 1, 1, 0.6))
	# Cool rim light along the upper-left dome edge
	draw_arc(center + Vector2(0, -1.0), 14.2 * squash, PI * 1.05, PI * 1.55, 12, Color(0.75, 1.0, 0.85, 0.5), 2.0)
	# Grounded base band so the jelly sits in the scene
	draw_arc(center, 13.5 * squash, PI * 0.15, PI * 0.85, 12, Color(dark_col, 0.55), 2.5)
	
	# Cute / Expressive Eyes
	var eye_y: float = 0.5 + y_lift
	if is_hurt:
		# Hurt > < eyes
		draw_line(Vector2(-7, eye_y - 2), Vector2(-3, eye_y + 2), Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(-7, eye_y + 2), Vector2(-3, eye_y - 2), Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(3, eye_y - 2), Vector2(7, eye_y + 2), Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(3, eye_y + 2), Vector2(7, eye_y - 2), Color(0.1, 0.1, 0.1), 2.0)
	else:
		draw_circle(Vector2(-5.0 * squash, eye_y), 2.8, Color(0.1, 0.12, 0.15))
		draw_circle(Vector2(5.0 * squash, eye_y), 2.8, Color(0.1, 0.12, 0.15))
		# Highlights in eyes
		draw_circle(Vector2(-4.2 * squash, eye_y - 0.8), 1.1, Color(1, 1, 1))
		draw_circle(Vector2(5.8 * squash, eye_y - 0.8), 1.1, Color(1, 1, 1))

# ==============================================================================
# 3. CAMPFIRE (30 FPS Animated Multi-Layer Flame & Embers)
# ==============================================================================
func _draw_campfire() -> void:
	# Cobblestone ring
	for i in range(8):
		var ang: float = float(i) * (TAU / 8.0)
		var stone_p := Vector2(cos(ang) * 16.0, sin(ang) * 11.0)
		draw_circle(stone_p, 4.5, Color(0.48, 0.48, 0.52))
		draw_circle(stone_p + Vector2(-1, -1), 2.0, Color(0.65, 0.65, 0.70))
	
	# Charred Wooden logs
	draw_line(Vector2(-12, 5), Vector2(12, -5), Color(0.36, 0.22, 0.12), 6.0)
	draw_line(Vector2(-10, -5), Vector2(10, 5), Color(0.30, 0.18, 0.09), 6.0)
	draw_line(Vector2(0, -7), Vector2(0, 7), Color(0.42, 0.25, 0.15), 5.0)
	
	# Glowing ember heart
	draw_circle(Vector2(0, 0), 10.0, Color(1.0, 0.35, 0.05, 0.85))
	draw_circle(Vector2(0, 0), 6.0, Color(1.0, 0.75, 0.15, 0.95))
	
	# 30 FPS Dynamic Fire Tongues
	var t1: float = sin(anim_time * 16.0) * 3.5
	var t2: float = cos(anim_time * 20.0) * 3.0
	var t3: float = sin(anim_time * 24.0 + 1.2) * 2.5
	
	# Outer Crimson flame
	draw_circle(Vector2(-4 + t1 * 0.4, -7), 8.0, Color(0.95, 0.25, 0.1, 0.85))
	draw_circle(Vector2(4 - t2 * 0.4, -9), 7.5, Color(0.95, 0.25, 0.1, 0.85))
	draw_circle(Vector2(t1 * 0.3, -16 + t2 * 0.5), 6.0, Color(1.0, 0.45, 0.1, 0.9))
	
	# Middle Amber flame
	draw_circle(Vector2(-2 + t2 * 0.3, -8), 6.0, Color(1.0, 0.65, 0.15, 0.9))
	draw_circle(Vector2(2 - t1 * 0.3, -11), 5.5, Color(1.0, 0.75, 0.2, 0.95))
	
	# Inner White-Gold core
	draw_circle(Vector2(0, -5), 4.5, Color(1.0, 0.95, 0.4, 0.98))
	draw_circle(Vector2(t3 * 0.2, -12), 3.0, Color(1.0, 1.0, 0.7, 0.98))
	
	# Rising floating spark embers
	for s in range(3):
		var s_t := fmod(anim_time * 2.5 + float(s) * 0.33, 1.0)
		var s_pos := Vector2(sin(float(s) * 3.0 + anim_time * 4.0) * 10.0, -14.0 - s_t * 22.0)
		var s_alpha: float = (1.0 - s_t) * 0.9
		draw_circle(s_pos, 1.8, Color(1.0, 0.8, 0.2, s_alpha))

# ==============================================================================
# 4. WAYSTONE (Hovering Magic Crystal & Orbiting Runes)
# ==============================================================================
func _draw_waystone() -> void:
	var pulse: float = (sin(anim_time * 4.0) + 1.0) * 0.5
	var hover_y: float = sin(anim_time * 3.0) * 3.0
	
	# Ground magical beacon circle
	draw_circle(Vector2(0, 8), 18.0 + pulse * 4.0, Color(0.2, 0.7, 1.0, 0.35 + pulse * 0.25))
	draw_circle(Vector2(0, 8), 12.0, Color(0, 0, 0, 0.35))
	
	# Carved Pedestal Base
	draw_rect(Rect2(-10, 0, 20, 10), Color(0.38, 0.42, 0.48))
	draw_rect(Rect2(-12, 6, 24, 4), Color(0.28, 0.32, 0.38))
	
	# Floating Crystal Shard
	var crystal_pts := PackedVector2Array([
		Vector2(0, -38 + hover_y),
		Vector2(7, -22 + hover_y),
		Vector2(5, -6 + hover_y),
		Vector2(0, -2 + hover_y),
		Vector2(-5, -6 + hover_y),
		Vector2(-7, -22 + hover_y)
	])
	draw_colored_polygon(crystal_pts, Color(0.35, 0.82, 1.0, 0.92))
	draw_polyline(crystal_pts, Color(0.75, 0.95, 1.0), 2.0)
	
	# Inner Crystal Core facet
	var core_pts := PackedVector2Array([
		Vector2(0, -34 + hover_y),
		Vector2(3, -22 + hover_y),
		Vector2(0, -8 + hover_y),
		Vector2(-3, -22 + hover_y)
	])
	draw_colored_polygon(core_pts, Color(0.85, 0.98, 1.0, 0.85 + pulse * 0.15))
	
	# 4 Orbiting Magical Glyphs
	for g in range(4):
		var g_ang: float = anim_time * 2.0 + float(g) * (TAU / 4.0)
		var g_pos := Vector2(cos(g_ang) * 16.0, sin(g_ang) * 8.0 - 20.0 + hover_y)
		draw_circle(g_pos, 2.5, Color(0.6, 0.95, 1.0, 0.9))

# ==============================================================================
# 5. VILLAGE NPCS (Elder, Carpenter, Cook, Miner - Unique Models & Props)
# ==============================================================================
func _draw_npc_elder() -> void:
	var bob: float = sin(anim_time * 3.0) * 0.8
	draw_circle(Vector2(0, 10), 9.0, Color(0, 0, 0, 0.22))
	
	# Wizard Robe (Deep Astral Sapphire)
	var robe := PackedVector2Array([
		Vector2(-9, 10), Vector2(-5, -6 + bob), Vector2(5, -6 + bob), Vector2(9, 10)
	])
	draw_colored_polygon(robe, Color(0.18, 0.28, 0.65))
	draw_polyline(robe, Color(0.85, 0.75, 0.25), 1.5) # Golden Hem
	
	# Head & Silver Beard
	var head_pos := Vector2(0, -12 + bob)
	draw_circle(head_pos, 7.0, Color(0.96, 0.85, 0.72))
	# Long flowing beard
	var beard := PackedVector2Array([
		Vector2(-4, head_pos.y + 2), Vector2(0, head_pos.y + 12), Vector2(4, head_pos.y + 2)
	])
	draw_colored_polygon(beard, Color(0.92, 0.92, 0.95))
	# Wizard Cowl / Hood
	draw_circle(head_pos + Vector2(0, -3), 7.5, Color(0.15, 0.22, 0.55))
	# Kind Eyes
	draw_line(head_pos + Vector2(-3, -1), head_pos + Vector2(-1, -1), Color(0.1, 0.1, 0.1), 1.5)
	draw_line(head_pos + Vector2(1, -1), head_pos + Vector2(3, -1), Color(0.1, 0.1, 0.1), 1.5)
	
	# Arcane Crystal Staff
	var staff_base := Vector2(10, 8)
	var staff_top := Vector2(10, -26 + bob)
	draw_line(staff_base, staff_top, Color(0.48, 0.32, 0.18), 3.0)
	# Glowing Orb
	var orb_pulse: float = (sin(anim_time * 5.0) + 1.0) * 0.5
	draw_circle(staff_top, 5.0, Color(0.4, 0.85, 1.0, 0.95))
	draw_circle(staff_top, 8.0 + orb_pulse * 3.0, Color(0.4, 0.85, 1.0, 0.35))

func _draw_npc_carpenter() -> void:
	var bob: float = sin(anim_time * 3.5) * 0.8
	draw_circle(Vector2(0, 10), 9.0, Color(0, 0, 0, 0.22))
	
	# Flannel Shirt & Leather Apron
	draw_rect(Rect2(-8, -6 + bob, 16, 16), Color(0.85, 0.35, 0.15)) # Orange Flannel
	draw_rect(Rect2(-6, -2 + bob, 12, 12), Color(0.55, 0.35, 0.20)) # Brown Apron
	draw_rect(Rect2(-7, 4 + bob, 14, 2), Color(0.35, 0.20, 0.10)) # Tool Belt
	
	# Head & Cap
	var head_pos := Vector2(0, -12 + bob)
	draw_circle(head_pos, 7.0, Color(0.96, 0.85, 0.72))
	draw_rect(Rect2(-7, head_pos.y - 6, 14, 5), Color(0.35, 0.20, 0.10)) # Cap
	draw_line(head_pos + Vector2(-6, -2), head_pos + Vector2(7, -2), Color(0.35, 0.20, 0.10), 2.5) # Visor
	# Pencil behind ear
	draw_line(head_pos + Vector2(5, -4), head_pos + Vector2(9, -8), Color(0.9, 0.8, 0.1), 2.0)
	# Eyes & Smile
	draw_circle(head_pos + Vector2(-3, 0), 1.2, Color(0.1, 0.1, 0.1))
	draw_circle(head_pos + Vector2(3, 0), 1.2, Color(0.1, 0.1, 0.1))
	draw_arc(head_pos + Vector2(0, 2), 2.5, 0, PI, 8, Color(0.5, 0.2, 0.2), 1.5)
	
	# Waving Hammer
	var hammer_hand := Vector2(11, -4 + bob)
	var hammer_head := hammer_hand + Vector2(2, -12 + sin(anim_time * 4.0) * 3.0)
	draw_line(hammer_hand, hammer_head, Color(0.6, 0.4, 0.2), 2.5)
	draw_rect(Rect2(hammer_head.x - 4, hammer_head.y - 3, 8, 5), Color(0.65, 0.68, 0.72))

func _draw_npc_cook() -> void:
	var bob: float = sin(anim_time * 3.2) * 0.8
	draw_circle(Vector2(0, 10), 9.0, Color(0, 0, 0, 0.22))
	
	# White Chef Tunic & Red Neckerchief
	draw_rect(Rect2(-8, -6 + bob, 16, 16), Color(0.95, 0.95, 0.98))
	draw_rect(Rect2(-4, -6 + bob, 8, 4), Color(0.85, 0.20, 0.20)) # Red scarf
	# Double-breasted buttons
	draw_circle(Vector2(-3, 0 + bob), 1.0, Color(0.2, 0.2, 0.2))
	draw_circle(Vector2(3, 0 + bob), 1.0, Color(0.2, 0.2, 0.2))
	draw_circle(Vector2(-3, 5 + bob), 1.0, Color(0.2, 0.2, 0.2))
	draw_circle(Vector2(3, 5 + bob), 1.0, Color(0.2, 0.2, 0.2))
	
	# Head & Rosy Cheeks
	var head_pos := Vector2(0, -12 + bob)
	draw_circle(head_pos, 7.0, Color(0.98, 0.86, 0.74))
	draw_circle(head_pos + Vector2(-4, 2), 2.0, Color(1.0, 0.6, 0.6, 0.6)) # Rosy cheek
	draw_circle(head_pos + Vector2(4, 2), 2.0, Color(1.0, 0.6, 0.6, 0.6))
	# Tall Toque Blanche (Chef Hat)
	draw_rect(Rect2(-6, head_pos.y - 14, 12, 10), Color(0.98, 0.98, 1.0))
	draw_circle(Vector2(0, head_pos.y - 14), 7.0, Color(0.98, 0.98, 1.0))
	
	# Wooden Spoon & Pot
	var spoon_hand := Vector2(10, 0 + bob)
	draw_line(spoon_hand, spoon_hand + Vector2(4, -14), Color(0.7, 0.5, 0.3), 2.5)
	draw_circle(spoon_hand + Vector2(4, -14), 3.0, Color(0.7, 0.5, 0.3))

func _draw_npc_miner() -> void:
	var bob: float = sin(anim_time * 3.0) * 0.8
	draw_circle(Vector2(0, 10), 9.0, Color(0, 0, 0, 0.22))
	
	# Heavy Work Overalls
	draw_rect(Rect2(-8, -6 + bob, 16, 16), Color(0.35, 0.42, 0.52))
	draw_rect(Rect2(-6, -2 + bob, 12, 12), Color(0.28, 0.32, 0.40))
	
	# Head & Miner Hardhat
	var head_pos := Vector2(0, -12 + bob)
	draw_circle(head_pos, 7.0, Color(0.94, 0.82, 0.70))
	# Stubble Beard
	draw_arc(head_pos + Vector2(0, 2), 5.0, 0, PI, 8, Color(0.3, 0.25, 0.2), 2.0)
	# Bright Yellow Hardhat
	draw_circle(head_pos + Vector2(0, -3), 8.0, Color(0.95, 0.82, 0.15))
	draw_line(head_pos + Vector2(-8, -2), head_pos + Vector2(8, -2), Color(0.95, 0.82, 0.15), 3.0)
	# Glowing Headlamp Beam
	var lamp_pos := head_pos + Vector2(0, -4)
	draw_circle(lamp_pos, 3.0, Color(1.0, 0.95, 0.4))
	draw_circle(lamp_pos, 6.0, Color(1.0, 0.95, 0.4, 0.4))
	
	# Iron Pickaxe on Shoulder
	draw_line(Vector2(-10, 6), Vector2(-12, -22 + bob), Color(0.55, 0.35, 0.2), 3.0) # Handle
	draw_arc(Vector2(-12, -22 + bob), 8.0, -PI * 0.75, -PI * 0.25, 8, Color(0.7, 0.72, 0.78), 4.0) # Steel head

# ==============================================================================
# 6. WILDLIFE (Rabbit, Deer, Bird - 30 FPS Organic Gait Cycles)
# ==============================================================================
func _draw_rabbit() -> void:
	var hop_phase: float = fmod(anim_time * 5.0, 1.0)
	var hop_y: float = 0.0
	var squash: float = 1.0
	
	if hop_phase < 0.25:
		squash = 1.25
	elif hop_phase < 0.75:
		hop_y = -sin((hop_phase - 0.25) / 0.5 * PI) * 8.0
		squash = 0.85
	
	# Shadow
	draw_set_transform(Vector2(0, 4), 0, Vector2(squash, 0.5))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# Body
	var body_p := Vector2(0, -2.0 + hop_y)
	draw_circle(body_p, 5.5, Color(0.94, 0.90, 0.85))
	# Head
	var head_p := body_p + Vector2(4.5, -3.0)
	draw_circle(head_p, 4.0, Color(0.94, 0.90, 0.85))
	# Twitching Ears (30 FPS)
	var ear_twitch: float = sin(anim_time * 14.0) * 1.5
	draw_line(head_p + Vector2(-1, -2), head_p + Vector2(-2 + ear_twitch, -10), Color(0.94, 0.90, 0.85), 2.5)
	draw_line(head_p + Vector2(1, -2), head_p + Vector2(2 - ear_twitch, -10), Color(0.94, 0.90, 0.85), 2.5)
	draw_line(head_p + Vector2(-1, -2), head_p + Vector2(-2 + ear_twitch, -8), Color(1.0, 0.7, 0.75), 1.2) # Pink inner ear
	# Eye & Fluffy Tail
	draw_circle(head_p + Vector2(1.5, -0.5), 1.0, Color(0.85, 0.15, 0.25))
	draw_circle(body_p + Vector2(-5.0, 1.0), 2.2, Color(1, 1, 1))

func _draw_deer() -> void:
	var trot: float = sin(anim_time * 6.0)
	var bob: float = absf(sin(anim_time * 6.0)) * 2.0
	
	# Shadow
	draw_set_transform(Vector2(0, 8), 0, Vector2(1.4, 0.5))
	draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
	# 4 Stepping Legs
	var leg_col := Color(0.48, 0.30, 0.16)
	draw_line(Vector2(-7, 0 + bob), Vector2(-7 + trot * 4.0, 10), leg_col, 2.2)
	draw_line(Vector2(-3, 0 + bob), Vector2(-3 - trot * 4.0, 10), leg_col, 2.2)
	draw_line(Vector2(5, 0 + bob), Vector2(5 + trot * 4.0, 10), leg_col, 2.2)
	draw_line(Vector2(9, 0 + bob), Vector2(9 - trot * 4.0, 10), leg_col, 2.2)
	
	# Body (Chestnut with dappled white spots)
	draw_rect(Rect2(-9, -7 + bob, 18, 10), Color(0.72, 0.46, 0.25))
	draw_circle(Vector2(-3, -3 + bob), 1.0, Color(1, 1, 1, 0.8)) # Spots
	draw_circle(Vector2(2, -4 + bob), 1.0, Color(1, 1, 1, 0.8))
	draw_circle(Vector2(0, -1 + bob), 1.0, Color(1, 1, 1, 0.8))
	
	# Graceful Neck & Head
	var neck_top := Vector2(13, -16 + bob)
	draw_line(Vector2(8, -5 + bob), neck_top, Color(0.72, 0.46, 0.25), 4.0)
	draw_circle(neck_top, 4.0, Color(0.72, 0.46, 0.25))
	
	# Branching Antlers
	var antler_col := Color(0.40, 0.25, 0.12)
	draw_line(neck_top + Vector2(-1, -3), neck_top + Vector2(-3, -12), antler_col, 2.0)
	draw_line(neck_top + Vector2(1, -3), neck_top + Vector2(5, -12), antler_col, 2.0)
	draw_line(neck_top + Vector2(-2, -7), neck_top + Vector2(-6, -9), antler_col, 1.5)
	draw_line(neck_top + Vector2(3, -7), neck_top + Vector2(7, -9), antler_col, 1.5)

func _draw_bird() -> void:
	var flap: float = sin(anim_time * 22.0) * 4.5
	var bob: float = sin(anim_time * 8.0) * 1.5
	
	# Shadow on ground
	draw_circle(Vector2(0, 10), 3.5, Color(0, 0, 0, 0.15))
	
	# Plumage (Azure Bluebird)
	draw_circle(Vector2(0, bob), 4.5, Color(0.22, 0.65, 0.98))
	# Fluttering Wings (30 FPS)
	draw_line(Vector2(-2, bob), Vector2(-7, bob - 4.0 + flap), Color(0.12, 0.45, 0.85), 2.5)
	draw_line(Vector2(2, bob), Vector2(7, bob - 4.0 + flap), Color(0.12, 0.45, 0.85), 2.5)
	# Golden Beak & Tail
	draw_line(Vector2(3, bob), Vector2(7, bob + 1.0), Color(1.0, 0.75, 0.1), 2.0)
	draw_line(Vector2(-4, bob), Vector2(-8, bob + 2.0), Color(0.15, 0.50, 0.90), 2.0)
	draw_circle(Vector2(2, bob - 1.0), 1.0, Color(0, 0, 0))

# ==============================================================================
# 7. ENVIRONMENT & OBJECT PROPS (House, Tree, Rock, Flower, Ores, Items)
# ==============================================================================
func _draw_house() -> void:
	draw_rect(Rect2(-36, -20, 72, 54), Color(0, 0, 0, 0.22))
	# Plaster walls with timber frame
	draw_rect(Rect2(-32, -16, 64, 40), Color(0.82, 0.70, 0.55))
	draw_rect(Rect2(-32, -16, 64, 40), Color(0.45, 0.34, 0.25), false, 2.5)
	draw_line(Vector2(-32, -16), Vector2(32, 24), Color(0.45, 0.34, 0.25, 0.55), 2.0)
	draw_line(Vector2(32, -16), Vector2(-32, 24), Color(0.45, 0.34, 0.25, 0.55), 2.0)
	# Door with frame + step stone
	draw_rect(Rect2(-9, 3, 18, 21), Color(0.38, 0.22, 0.12))
	draw_rect(Rect2(-8, 4, 16, 20), Color(0.50, 0.30, 0.16))
	draw_line(Vector2(0, 4), Vector2(0, 24), Color(0.38, 0.22, 0.12), 1.5)
	draw_circle(Vector2(4, 14), 1.8, Color(0.95, 0.82, 0.2))
	draw_rect(Rect2(-11, 24, 22, 5), Color(0.60, 0.62, 0.66))
	# Windows with warm golden interior glow + cross frames
	draw_rect(Rect2(-26, -6, 12, 12), Color(1.0, 0.88, 0.50))
	draw_rect(Rect2(14, -6, 12, 12), Color(1.0, 0.88, 0.50))
	draw_rect(Rect2(-26, -6, 12, 12), Color(0.35, 0.25, 0.15), false, 1.5)
	draw_rect(Rect2(14, -6, 12, 12), Color(0.35, 0.25, 0.15), false, 1.5)
	draw_line(Vector2(-20, -6), Vector2(-20, 6), Color(0.35, 0.25, 0.15), 1.5)
	draw_line(Vector2(-26, 0), Vector2(-14, 0), Color(0.35, 0.25, 0.15), 1.5)
	draw_line(Vector2(20, -6), Vector2(20, 6), Color(0.35, 0.25, 0.15), 1.5)
	draw_line(Vector2(14, 0), Vector2(26, 0), Color(0.35, 0.25, 0.15), 1.5)
	# Red Terracotta Roof with ridge highlight
	var roof := PackedVector2Array([
		Vector2(-38, -15), Vector2(0, -38), Vector2(38, -15)
	])
	draw_colored_polygon(roof, Color(0.78, 0.30, 0.24))
	draw_polyline(roof, Color(0.52, 0.15, 0.13), 2.5)
	draw_line(Vector2(-19, -26.5), Vector2(0, -38), Color(0.92, 0.48, 0.38), 2.0)
	# Stone chimney
	draw_rect(Rect2(16, -34, 10, 16), Color(0.55, 0.55, 0.60))
	draw_rect(Rect2(16, -34, 10, 16), Color(0.38, 0.38, 0.43), false, 1.5)
	draw_rect(Rect2(15, -36, 12, 3), Color(0.42, 0.42, 0.47))

func _draw_tree() -> void:
	draw_circle(Vector2(0, 8), 16.0, Color(0, 0, 0, 0.25))
	# Per-tree hue variation so the forest isn't clone-stamped.
	# (Uses global position: every visual sits at its parent's origin.)
	var variation: float = fmod(absf(global_position.x * 0.37 + global_position.y * 0.73), 1.0)
	var leaf_dark := Color(0.15 + variation * 0.05, 0.50 + variation * 0.08, 0.22)
	var leaf_mid := Color(0.20 + variation * 0.05, 0.62 + variation * 0.08, 0.27)
	var leaf_light := Color(0.30 + variation * 0.05, 0.74 + variation * 0.06, 0.34)
	# Trunk with outline + sunlit edge
	draw_rect(Rect2(-5, -6, 10, 18), Color(0.46, 0.28, 0.16))
	draw_rect(Rect2(-5, -6, 10, 18), Color(0.30, 0.17, 0.09), false, 1.5)
	draw_line(Vector2(-2.5, -5), Vector2(-2.5, 10), Color(0.58, 0.38, 0.22), 2.0)
	# Wind sway, desynced per tree (was position.x == 0 for every tree,
	# so the whole forest swayed in perfect sync).
	var sway: float = sin(anim_time * 2.2 + global_position.x * 0.05 + global_position.y * 0.031) * 2.2
	# Dark outline shell first so canopy reads against bright grass
	draw_circle(Vector2(-9 + sway, -16), 15.2, Color(0.10, 0.34, 0.16))
	draw_circle(Vector2(9 + sway, -16), 15.2, Color(0.10, 0.34, 0.16))
	draw_circle(Vector2(sway, -26), 17.2, Color(0.10, 0.34, 0.16))
	draw_circle(Vector2(-9 + sway, -16), 14.0, leaf_dark)
	draw_circle(Vector2(9 + sway, -16), 14.0, leaf_dark)
	draw_circle(Vector2(sway, -26), 16.0, leaf_mid)
	draw_circle(Vector2(sway * 0.8 - 3, -23), 12.0, leaf_mid)
	draw_circle(Vector2(sway * 0.8 - 4, -25), 8.0, leaf_light) # Sunlit crown

func _draw_rock() -> void:
	draw_circle(Vector2(0, 4), 12.0, Color(0, 0, 0, 0.22))
	var rock_pts := PackedVector2Array([
		Vector2(-14, 2), Vector2(-11, -9), Vector2(0, -14),
		Vector2(12, -8), Vector2(15, 2), Vector2(5, 6), Vector2(-7, 6)
	])
	draw_colored_polygon(rock_pts, Color(0.56, 0.60, 0.65))
	draw_polyline(rock_pts, Color(0.38, 0.40, 0.45), 2.0)
	# Shaded facet
	var high_pts := PackedVector2Array([
		Vector2(-11, -9), Vector2(0, -14), Vector2(5, -5), Vector2(-5, -3)
	])
	draw_colored_polygon(high_pts, Color(0.72, 0.76, 0.82, 0.85))

func _draw_flower() -> void:
	# Static petals (no per-frame tick): bake per-flower variety from
	# global position so neighbours don't look stamped.
	var breeze: float = sin(global_position.x * 0.11 + global_position.y * 0.07) * 2.0
	var lean: float = sin(global_position.x * 0.05 - global_position.y * 0.09) * 1.5
	draw_line(Vector2(0, 0), Vector2(breeze + lean, 7), Color(0.22, 0.55, 0.20), 1.8)
	var col := custom_color if custom_color != Color.WHITE else Color(0.98, 0.35, 0.45)
	for i in range(5):
		var a: float = float(i) * (TAU / 5.0)
		var p_pos := Vector2(cos(a) * 4.5 + breeze, sin(a) * 4.5 - 2.0)
		draw_circle(p_pos, 3.0, col)
		draw_circle(p_pos + Vector2(-0.8, -0.8), 1.2, Color(1, 1, 1, 0.45))
	draw_circle(Vector2(breeze, -2), 2.5, Color(1.0, 0.88, 0.15))

func _draw_ruin() -> void:
	draw_circle(Vector2(0, 8), 18.0, Color(0, 0, 0, 0.22))
	draw_rect(Rect2(-18, -28, 9, 36), Color(0.62, 0.63, 0.68))
	draw_rect(Rect2(-18, -28, 9, 36), Color(0.42, 0.43, 0.47), false, 1.5)
	draw_rect(Rect2(-20, -30, 13, 5), Color(0.76, 0.76, 0.80))
	draw_rect(Rect2(9, -16, 9, 24), Color(0.62, 0.63, 0.68))
	draw_rect(Rect2(9, -16, 9, 24), Color(0.42, 0.43, 0.47), false, 1.5)
	draw_line(Vector2(-20, -30), Vector2(3, -30), Color(0.74, 0.74, 0.78), 6.0)
	# Carved rune groove + moss creeping up the base
	draw_line(Vector2(-15, -14), Vector2(-12, -2), Color(0.40, 0.62, 0.85, 0.8), 1.5)
	draw_line(Vector2(-12, -2), Vector2(-15, 6), Color(0.40, 0.62, 0.85, 0.8), 1.5)
	draw_circle(Vector2(-14, 6), 3.0, Color(0.30, 0.55, 0.28, 0.9))
	draw_circle(Vector2(13, 6), 2.5, Color(0.30, 0.55, 0.28, 0.9))
	draw_circle(Vector2(-9, 7), 2.0, Color(0.35, 0.60, 0.30, 0.9))

func _draw_ore_vein() -> void:
	draw_circle(Vector2(0, 5), 14.0, Color(0, 0, 0, 0.24))
	var rock := PackedVector2Array([
		Vector2(-16, 2), Vector2(-12, -12), Vector2(2, -16),
		Vector2(15, -7), Vector2(16, 5), Vector2(0, 9)
	])
	draw_colored_polygon(rock, Color(0.40, 0.36, 0.44))
	draw_polyline(rock, Color(0.25, 0.22, 0.29), 2.2)
	# Gem tint follows the node: gold ore glows amber, iron ore cold blue.
	var gem := Color(0.95, 0.68, 0.25)
	var gem_hi := Color(1.0, 0.90, 0.40)
	if custom_color != Color.WHITE:
		gem = custom_color
		gem_hi = custom_color.lightened(0.35)
	# 30 FPS Shimmering Gems / Ores
	var spark: float = (sin(anim_time * 6.0) + 1.0) * 0.5
	var a: float = 0.85 + spark * 0.15
	draw_circle(Vector2(-5, -5), 3.5, Color(gem, a))
	draw_circle(Vector2(6, -2), 3.0, Color(gem_hi, a))
	draw_circle(Vector2(-1, 4), 2.5, Color(gem, 0.9))
	draw_circle(Vector2(-6, -6), 1.2, Color(1, 1, 1, 0.85))

func _draw_item_wood() -> void:
	var bob: float = sin(anim_time * 4.0) * 2.5
	draw_circle(Vector2(0, 7), 7.0, Color(0, 0, 0, 0.22))
	draw_line(Vector2(-7, -1 + bob), Vector2(7, -1 + bob), Color(0.58, 0.36, 0.20), 6.0)
	draw_circle(Vector2(-7, -1 + bob), 3.0, Color(0.72, 0.52, 0.32))

func _draw_item_herb() -> void:
	var bob: float = sin(anim_time * 4.0 + 1.0) * 2.5
	draw_circle(Vector2(0, 7), 7.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2(-4, -2 + bob), 4.0, Color(0.22, 0.80, 0.32))
	draw_circle(Vector2(4, -2 + bob), 4.0, Color(0.22, 0.80, 0.32))
	draw_line(Vector2(0, 3 + bob), Vector2(0, -6 + bob), Color(0.16, 0.58, 0.22), 2.5)

func _draw_item_mushroom() -> void:
	var bob: float = sin(anim_time * 4.0 + 2.0) * 2.5
	draw_circle(Vector2(0, 7), 7.0, Color(0, 0, 0, 0.22))
	draw_rect(Rect2(-2.5, 0 + bob, 5, 7), Color(0.92, 0.90, 0.82))
	draw_circle(Vector2(0, 0 + bob), 7.0, Color(0.95, 0.22, 0.22))
	draw_circle(Vector2(-2.5, -2 + bob), 1.8, Color(1, 1, 1))
	draw_circle(Vector2(3.5, -1 + bob), 1.5, Color(1, 1, 1))

func _draw_item_ore() -> void:
	var bob: float = sin(anim_time * 4.0 + 3.0) * 2.5
	draw_circle(Vector2(0, 7), 7.0, Color(0, 0, 0, 0.22))
	draw_circle(Vector2(0, -1 + bob), 6.0, Color(0.75, 0.65, 0.35))
	draw_circle(Vector2(-1.5, -3 + bob), 2.5, Color(1.0, 0.95, 0.6))
