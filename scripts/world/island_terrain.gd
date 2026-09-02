class_name IslandTerrain
extends Node2D

## High-performance procedural terrain renderer for the 15x starting island

var base_island_radius: float = 16800.0
var beach_radius: float = 18500.0
var water_rim_radius: float = 19800.0
var ocean_extent: float = 35000.0
var village_radius: float = 800.0

# Precomputed cached geometry for ultra-fast GPU drawing without per-frame recalculation
var cached_beach_pts: PackedVector2Array
var cached_water_rim_pts: PackedVector2Array
var cached_grass_pts: PackedVector2Array
var cached_river_pts: PackedVector2Array
var cached_cliff_pts: PackedVector2Array
var cached_mouth_pts: PackedVector2Array

func _ready() -> void:
	z_index = -100
	z_as_relative = false
	set_process(false) # Static terrain does not need per-frame process ticking
	_load_layout_config()
	_precompute_geometry()
	queue_redraw()

func _load_layout_config() -> void:
	if FileAccess.file_exists("res://data/island_layout.json"):
		var file := FileAccess.open("res://data/island_layout.json", FileAccess.READ)
		if file:
			var json_str := file.get_as_text()
			var json = JSON.parse_string(json_str)
			if json and typeof(json) == TYPE_DICTIONARY:
				var settings: Dictionary = json.get("island_settings", {})
				base_island_radius = settings.get("base_radius", 16800.0)
				beach_radius = settings.get("beach_radius", 18500.0)
				water_rim_radius = settings.get("water_rim_radius", 19800.0)
				ocean_extent = settings.get("ocean_boundary", 35000.0)
				village_radius = settings.get("village_radius", 800.0)

func _precompute_geometry() -> void:
	cached_beach_pts = _generate_island_polygon(beach_radius, 48, 12345)
	cached_water_rim_pts = _generate_island_polygon(water_rim_radius, 48, 12345)
	cached_grass_pts = _generate_island_polygon(base_island_radius, 48, 12345)
	
	cached_river_pts = PackedVector2Array([
		Vector2(1000, -7200),
		Vector2(2400, -4500),
		Vector2(3800, -1500),
		Vector2(5500, 2500), # Enters Great Lake
		Vector2(7500, 5000),
		Vector2(11500, 8500),
		Vector2(18500, 11000) # Reaches Ocean
	])
	
	var center := Vector2(0, -8000)
	cached_cliff_pts = PackedVector2Array([
		center + Vector2(-2800, 400),
		center + Vector2(-2200, -900),
		center + Vector2(-1100, -1800),
		center + Vector2(0, -2200),
		center + Vector2(1100, -1800),
		center + Vector2(2200, -900),
		center + Vector2(2800, 400),
		center + Vector2(1800, 600),
		center + Vector2(-1800, 600)
	])
	
	cached_mouth_pts = PackedVector2Array([
		center + Vector2(-280, 520),
		center + Vector2(-220, -100),
		center + Vector2(0, -320),
		center + Vector2(220, -100),
		center + Vector2(280, 520)
	])

func reload_terrain() -> void:
	_load_layout_config()
	_precompute_geometry()
	queue_redraw()

func _draw() -> void:
	# Deep Ocean background (single giant quad)
	draw_rect(Rect2(-ocean_extent, -ocean_extent, ocean_extent * 2.0, ocean_extent * 2.0), Color(0.10, 0.32, 0.62))
	
	# Outer Sand Beach Contour
	if not cached_beach_pts.is_empty():
		draw_colored_polygon(cached_beach_pts, Color(0.88, 0.78, 0.52)) # Golden Sand
	
	# Shallow water coastal tide rim
	if not cached_water_rim_pts.is_empty():
		draw_polyline(cached_water_rim_pts, Color(0.35, 0.75, 0.90, 0.45), 24.0)
	
	# Grass Landmass
	if not cached_grass_pts.is_empty():
		draw_colored_polygon(cached_grass_pts, Color(0.26, 0.56, 0.30)) # Lush emerald grass
	
	# Vast Village clearing
	draw_circle(Vector2.ZERO, village_radius, Color(0.68, 0.54, 0.38)) # Village dirt ground
	draw_circle(Vector2.ZERO, 380.0, Color(0.58, 0.46, 0.32)) # Cobblestone central plaza
	draw_arc(Vector2.ZERO, village_radius, 0, TAU, 32, Color(0.46, 0.36, 0.24), 8.0)
	
	# Cobblestone Highway Network
	_draw_highways()
	
	# Lakes and Ponds
	_draw_water_body(Vector2(5500, 2500), 1200.0, Color(0.18, 0.48, 0.80)) # Eastern Great Lake
	_draw_water_body(Vector2(-5000, 3500), 900.0, Color(0.18, 0.48, 0.80)) # Western Pond
	_draw_water_body(Vector2(3000, 9000), 1100.0, Color(0.16, 0.46, 0.78)) # Southern Lagoon
	_draw_water_body(Vector2(550, 320), 120.0, Color(0.20, 0.50, 0.82)) # Village East Pond
	_draw_water_body(Vector2(-600, 480), 100.0, Color(0.20, 0.50, 0.82)) # Village South Pond
	
	# Winding River Network
	if not cached_river_pts.is_empty():
		draw_polyline(cached_river_pts, Color(0.75, 0.68, 0.48), 120.0) # Riverbanks
		draw_polyline(cached_river_pts, Color(0.22, 0.55, 0.85), 90.0)  # Water
		draw_polyline(cached_river_pts, Color(0.55, 0.85, 1.0, 0.5), 18.0) # Highlights
	
	# Southern Ancient Ruins Plaza
	_draw_ruins_ground(Vector2(-2000, 8000), 1800.0)
	
	# Northern Mountain Range & Cave Mouth
	_draw_cave_mountain(Vector2(0, -8000))

func _generate_island_polygon(base_radius: float, segments: int, seed_val: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var angle: float = (TAU * float(i)) / float(segments)
		var noise_var: float = sin(angle * 3.0 + float(seed_val)) * (base_radius * 0.06) + cos(angle * 6.0) * (base_radius * 0.03)
		var r: float = base_radius + noise_var
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts

func _draw_highways() -> void:
	# North Highway to Northern Cave Mountain
	draw_line(Vector2(0, -600), Vector2(0, -7500), Color(0.62, 0.48, 0.34), 65.0)
	# South Highway to Ancient Ruins
	draw_line(Vector2(0, 600), Vector2(-1900, 7800), Color(0.62, 0.48, 0.34), 60.0)
	# East Highway to Eastern Forest and Coast
	draw_line(Vector2(600, 0), Vector2(9200, 4800), Color(0.62, 0.48, 0.34), 60.0)
	# West Highway to Western Cliffs
	draw_line(Vector2(-600, 0), Vector2(-7400, -950), Color(0.62, 0.48, 0.34), 60.0)

func _draw_water_body(center: Vector2, radius: float, col: Color) -> void:
	# Sandy Shore rim
	draw_circle(center, radius + 25.0, Color(0.78, 0.72, 0.52))
	# Water surface
	draw_circle(center, radius, col)
	# Wave shimmer lines
	draw_line(center + Vector2(-radius * 0.5, -radius * 0.15), center + Vector2(radius * 0.5, -radius * 0.15), Color(0.55, 0.85, 1.0, 0.55), 6.0)
	draw_line(center + Vector2(-radius * 0.35, radius * 0.15), center + Vector2(radius * 0.35, radius * 0.15), Color(0.55, 0.85, 1.0, 0.55), 6.0)

func _draw_ruins_ground(center: Vector2, radius: float) -> void:
	draw_circle(center, radius, Color(0.38, 0.42, 0.44)) # Ancient weathered stone
	draw_circle(center, radius * 0.5, Color(0.48, 0.52, 0.56)) # Central dais
	draw_arc(center, radius, 0, TAU, 24, Color(0.26, 0.28, 0.30), 8.0)

func _draw_cave_mountain(center: Vector2) -> void:
	if not cached_cliff_pts.is_empty():
		draw_colored_polygon(cached_cliff_pts, Color(0.40, 0.42, 0.46))
		draw_polyline(cached_cliff_pts, Color(0.25, 0.27, 0.30), 12.0)
	
	if not cached_mouth_pts.is_empty():
		draw_colored_polygon(cached_mouth_pts, Color(0.06, 0.06, 0.08)) # Black abyss
	
	# Stalactites
	draw_line(center + Vector2(-100, -180), center + Vector2(-90, 0), Color(0.32, 0.34, 0.38), 12.0)
	draw_line(center + Vector2(100, -200), center + Vector2(90, -20), Color(0.32, 0.34, 0.38), 12.0)
	
	# Cave Entrance Torches
	draw_circle(center + Vector2(-340, 200), 12.0, Color(0.95, 0.5, 0.1))
	draw_circle(center + Vector2(-340, 200), 38.0, Color(1.0, 0.7, 0.2, 0.35))
	draw_circle(center + Vector2(340, 200), 12.0, Color(0.95, 0.5, 0.1))
	draw_circle(center + Vector2(340, 200), 38.0, Color(1.0, 0.7, 0.2, 0.35))
