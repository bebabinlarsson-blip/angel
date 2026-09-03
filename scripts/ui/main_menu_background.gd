class_name MainMenuBackground
extends Control

## Clean, atmospheric title background

var anim_time: float = 0.0
var _frame_accum: float = 0.0
var _cached_size: Vector2 = Vector2.ZERO
var _cached_mountain: PackedVector2Array = PackedVector2Array()
var _cached_hills: PackedVector2Array = PackedVector2Array()
var _stars: PackedVector2Array = PackedVector2Array()
const REDRAW_INTERVAL := 1.0 / 30.0

func _ready() -> void:
	# Deterministic starfield baked once.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240
	_stars.clear()
	for i in range(110):
		_stars.append(Vector2(rng.randf(), rng.randf() * 0.55))

func _process(delta: float) -> void:
	anim_time += delta
	_frame_accum += delta
	# Was queue_redraw() every frame + rebuilding wave arrays per wave per frame.
	# Cap at 30 FPS and cache static mountain geometry.
	if _frame_accum >= REDRAW_INTERVAL:
		_frame_accum = 0.0
		queue_redraw()

func _get_mountain(screen_size: Vector2, horizon_y: float) -> PackedVector2Array:
	if _cached_mountain.is_empty() or _cached_size != screen_size:
		_cached_size = screen_size
		_cached_mountain = PackedVector2Array([
			Vector2(0, horizon_y),
			Vector2(180, horizon_y - 30),
			Vector2(380, horizon_y - 90),
			Vector2(520, horizon_y - 50),
			Vector2(640, horizon_y - 130),
			Vector2(780, horizon_y - 70),
			Vector2(960, horizon_y - 100),
			Vector2(1120, horizon_y - 25),
			Vector2(screen_size.x, horizon_y),
			Vector2(screen_size.x, screen_size.y),
			Vector2(0, screen_size.y)
		])
		_cached_hills = PackedVector2Array([
			Vector2(0, horizon_y),
			Vector2(240, horizon_y - 18),
			Vector2(470, horizon_y - 45),
			Vector2(700, horizon_y - 20),
			Vector2(950, horizon_y - 55),
			Vector2(1200, horizon_y - 15),
			Vector2(screen_size.x, horizon_y),
			Vector2(screen_size.x, screen_size.y),
			Vector2(0, screen_size.y)
		])
	return _cached_mountain

func _draw() -> void:
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1280, 720)
	
	# 1. Night sky: three bands from deep space to horizon glow
	var band_h: float = screen_size.y * 0.65
	draw_rect(Rect2(0, 0, screen_size.x, band_h * 0.45), Color(0.03, 0.04, 0.10))
	draw_rect(Rect2(0, band_h * 0.45, screen_size.x, band_h * 0.35), Color(0.06, 0.08, 0.17))
	draw_rect(Rect2(0, band_h * 0.80, screen_size.x, band_h * 0.20 + 12), Color(0.10, 0.12, 0.24))

	# Twinkling stars (upper sky only)
	for i in range(_stars.size()):
		var sp: Vector2 = _stars[i]
		var tw: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(anim_time * (2.0 + float(i % 5) * 0.5) + float(i)))
		var r: float = 1.0 + float(i % 3) * 0.6
		draw_circle(Vector2(sp.x * screen_size.x, sp.y * screen_size.y), r, Color(0.9, 0.93, 1.0, 0.75 * tw))

	# Low moon + halo
	var moon_pos := Vector2(screen_size.x * 0.82, screen_size.y * 0.16)
	draw_circle(moon_pos, 46.0, Color(0.85, 0.90, 1.0, 0.10))
	draw_circle(moon_pos, 30.0, Color(0.88, 0.92, 1.0, 0.16))
	draw_circle(moon_pos, 20.0, Color(0.92, 0.94, 0.98))
	draw_circle(moon_pos + Vector2(-6, -4), 4.0, Color(0.78, 0.81, 0.88, 0.8))
	draw_circle(moon_pos + Vector2(7, 6), 3.0, Color(0.78, 0.81, 0.88, 0.8))

	# Horizon twilight band
	var horizon_y: float = screen_size.y * 0.62
	var twilight_poly := PackedVector2Array([
		Vector2(0, horizon_y - 80), Vector2(screen_size.x, horizon_y - 80),
		Vector2(screen_size.x, horizon_y + 10), Vector2(0, horizon_y + 10)
	])
	draw_colored_polygon(twilight_poly, Color(0.16, 0.14, 0.28, 0.7))
	draw_line(Vector2(0, horizon_y - 78), Vector2(screen_size.x, horizon_y - 78), Color(0.95, 0.55, 0.35, 0.35), 2.0)

	# 2. Layered island silhouette: far hills, then near peaks (cached)
	var mountain_pts := _get_mountain(screen_size, horizon_y)
	draw_colored_polygon(_cached_hills, Color(0.11, 0.13, 0.24))
	draw_colored_polygon(mountain_pts, Color(0.07, 0.09, 0.17))
	
	# Ancient Waystone Beacon Glow on Peak
	var way_pos := Vector2(640, horizon_y - 130)
	var pulse: float = (sin(anim_time * 2.5) + 1.0) * 0.5
	draw_circle(way_pos, 14.0 + pulse * 4.0, Color(0.2, 0.65, 0.95, 0.3))
	draw_circle(way_pos, 4.0, Color(0.5, 0.85, 1.0, 0.9))
	
	# 3. Ocean Water with moonlight path
	var water_y: float = horizon_y + 10.0
	draw_rect(Rect2(0, water_y, screen_size.x, screen_size.y - water_y), Color(0.03, 0.06, 0.14))
	draw_rect(Rect2(0, water_y, screen_size.x, 26), Color(0.10, 0.16, 0.28, 0.8))
	# Moon glitter path
	var mx: float = screen_size.x * 0.82
	for g in range(5):
		var gy: float = water_y + 34.0 + float(g) * 26.0
		var gw: float = 26.0 + float(g) * 16.0 + sin(anim_time * 2.0 + float(g)) * 6.0
		draw_line(Vector2(mx - gw, gy), Vector2(mx + gw, gy), Color(0.75, 0.82, 0.95, 0.30 - float(g) * 0.04), 3.0)
	
	# Gentle ambient ocean wave lines
	for w in range(3):
		var wy: float = water_y + float(w) * 35.0 + 15.0
		var pts := PackedVector2Array()
		var spd: float = (float(w) + 1.0) * 1.2
		for x_step in range(0, int(screen_size.x) + 40, 30):
			var x_f := float(x_step)
			var y_f := wy + sin(x_f * 0.012 + anim_time * spd) * 4.0
			pts.append(Vector2(x_f, y_f))
		
		var wave_col := Color(0.18, 0.35, 0.55, 0.4 - float(w) * 0.1)
		draw_polyline(pts, wave_col, 2.0)
