class_name MainMenuBackground
extends Control

## Clean, atmospheric title background

var anim_time: float = 0.0

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func _draw() -> void:
	var screen_size := get_viewport_rect().size
	if screen_size.x <= 0 or screen_size.y <= 0:
		screen_size = Vector2(1280, 720)
	
	# 1. Sky Gradient (Deep Indigo to Twilight Navy)
	var sky_poly := PackedVector2Array([
		Vector2(0, 0), Vector2(screen_size.x, 0),
		Vector2(screen_size.x, screen_size.y * 0.65), Vector2(0, screen_size.y * 0.65)
	])
	draw_colored_polygon(sky_poly, Color(0.06, 0.08, 0.15))
	
	# Horizon twilight band
	var horizon_y: float = screen_size.y * 0.62
	var twilight_poly := PackedVector2Array([
		Vector2(0, horizon_y - 80), Vector2(screen_size.x, horizon_y - 80),
		Vector2(screen_size.x, horizon_y + 10), Vector2(0, horizon_y + 10)
	])
	draw_colored_polygon(twilight_poly, Color(0.14, 0.16, 0.28, 0.75))
	
	# 2. Distant Clean Island Mountain Silhouette
	var mountain_pts := PackedVector2Array([
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
	draw_colored_polygon(mountain_pts, Color(0.08, 0.10, 0.18))
	
	# Ancient Waystone Beacon Glow on Peak
	var way_pos := Vector2(640, horizon_y - 130)
	var pulse: float = (sin(anim_time * 2.5) + 1.0) * 0.5
	draw_circle(way_pos, 14.0 + pulse * 4.0, Color(0.2, 0.65, 0.95, 0.3))
	draw_circle(way_pos, 4.0, Color(0.5, 0.85, 1.0, 0.9))
	
	# 3. Ocean Water
	var water_y: float = horizon_y + 10.0
	draw_rect(Rect2(0, water_y, screen_size.x, screen_size.y - water_y), Color(0.04, 0.07, 0.14))
	
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
