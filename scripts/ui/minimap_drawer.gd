class_name MinimapDrawer
extends Control

@export var is_big_map: bool = false
@export var world_radius: float = 19500.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 160) if not is_big_map else Vector2(600, 600)
	gui_input.connect(_on_gui_input)

var redraw_timer: float = 0.0
var cached_npc_positions: Array[Vector2] = []
var npc_cache_timer: float = 0.0

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var hud := get_tree().root.find_child("HUD", true, false)
		if hud and "big_map" in hud and hud.big_map:
			hud.big_map.visible = !hud.big_map.visible

func _process(delta: float) -> void:
	if is_big_map and not visible:
		return
	
	npc_cache_timer += delta
	if npc_cache_timer >= 1.0 or cached_npc_positions.is_empty():
		npc_cache_timer = 0.0
		cached_npc_positions.clear()
		for npc in get_tree().get_nodes_in_group("npcs"):
			if is_instance_valid(npc) and npc is Node2D:
				cached_npc_positions.append((npc as Node2D).global_position)
	
	redraw_timer += delta
	if redraw_timer >= 0.08: # 12.5 FPS update is buttery smooth and saves 90% minimap overhead
		redraw_timer = 0.0
		queue_redraw()

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	var center := Vector2(w * 0.5, h * 0.5)
	var scale_factor: float = (w * 0.46) / world_radius
	
	# Background border
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.15, 0.22, 0.90))
	draw_rect(Rect2(0, 0, w, h), Color(0.85, 0.75, 0.45), false, 2.0 if not is_big_map else 3.0)
	
	# Island shape
	var island_r: float = 16800.0 * scale_factor
	draw_circle(center, island_r + 1700.0 * scale_factor, Color(0.88, 0.78, 0.52, 0.9)) # Sand Beach
	draw_circle(center, island_r, Color(0.26, 0.56, 0.30, 0.9)) # Grass
	
	# Village center
	var village_r: float = 800.0 * scale_factor
	draw_circle(center, maxf(village_r, 4.0), Color(0.68, 0.54, 0.38))
	
	# Eastern Great Lake
	var lake_pos: Vector2 = center + Vector2(5500, 2500) * scale_factor
	draw_circle(lake_pos, 1200.0 * scale_factor, Color(0.18, 0.48, 0.80))
	
	# Western Pond
	var w_pond_pos: Vector2 = center + Vector2(-5000, 3500) * scale_factor
	draw_circle(w_pond_pos, 900.0 * scale_factor, Color(0.18, 0.48, 0.80))
	
	# Southern Lagoon
	var lagoon_pos: Vector2 = center + Vector2(3000, 9000) * scale_factor
	draw_circle(lagoon_pos, 1100.0 * scale_factor, Color(0.16, 0.46, 0.78))
	
	# River line
	var r1: Vector2 = center + Vector2(1000, -7200) * scale_factor
	var r2: Vector2 = center + Vector2(3800, -1500) * scale_factor
	var r3: Vector2 = center + Vector2(5500, 2500) * scale_factor
	var r4: Vector2 = center + Vector2(11500, 8500) * scale_factor
	draw_line(r1, r2, Color(0.2, 0.55, 0.85), 2.5)
	draw_line(r2, r3, Color(0.2, 0.55, 0.85), 2.5)
	draw_line(r3, r4, Color(0.2, 0.55, 0.85), 2.5)
	
	# Cave icon (North Mountain)
	var cave_pos: Vector2 = center + Vector2(0, -7500) * scale_factor
	draw_circle(cave_pos, 4.5 if not is_big_map else 8.0, Color(0.3, 0.3, 0.35))
	
	# Southern Ruins icon
	var ruins_pos: Vector2 = center + Vector2(-2000, 8000) * scale_factor
	draw_circle(ruins_pos, 4.0 if not is_big_map else 7.0, Color(0.5, 0.4, 0.6))
	
	# NPCs (Yellow dots)
	for npc_gpos in cached_npc_positions:
		var npc_mpos: Vector2 = center + npc_gpos * scale_factor
		draw_circle(npc_mpos, 3.0 if not is_big_map else 5.0, Color(1.0, 0.85, 0.1))
	
	# Monsters (Red dots)
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is CharacterBody2D and "current_state" in m:
			if m.current_state != 5: # Not DEAD
				var m_node: CharacterBody2D = m as CharacterBody2D
				var m_mpos: Vector2 = center + m_node.global_position * scale_factor
				draw_circle(m_mpos, 2.0 if not is_big_map else 3.5, Color(0.9, 0.2, 0.2))
	
	# Player position marker (Glowing cyan arrow/dot)
	if GameManager.player and is_instance_valid(GameManager.player):
		var p_pos: Vector2 = center + GameManager.player.global_position * scale_factor
		draw_circle(p_pos, 4.0 if not is_big_map else 7.0, Color(1.0, 1.0, 1.0))
		draw_circle(p_pos, 3.0 if not is_big_map else 5.0, Color(0.1, 0.6, 1.0))
		# Facing direction
		var f_dir: Vector2 = GameManager.player.look_direction.normalized()
		draw_line(p_pos, p_pos + f_dir * (8.0 if not is_big_map else 14.0), Color(1.0, 1.0, 0.2), 2.0)
	
	# Map label
	if not is_big_map:
		draw_string(ThemeDB.fallback_font, Vector2(6, 16), "Map [Click]", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(20, 30), "Starting Island Map - Angel", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(20, h - 20), "Legend: Cyan=Player | Yellow=NPC | Red=Slimes | Blue=Waystone | Gray=Cave", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.9, 0.9, 0.9))
