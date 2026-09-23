extends Node2D

const LAMP_POSITIONS: Array[Vector2] = [
	Vector2(-96, -96), Vector2(96, -96), Vector2(-96, 96), Vector2(96, 96),
	Vector2(-64, -480), Vector2(64, -480),
	Vector2(-480, -64), Vector2(-480, 64),
	Vector2(480, -64), Vector2(480, 64),
]

var _lamps: Array[PointLight2D] = []

func _ready() -> void:
	var glow_texture := _make_glow_texture()
	for index in range(LAMP_POSITIONS.size()):
		var lamp := PointLight2D.new()
		lamp.name = "VillageLampGlow_%02d" % (index + 1)
		lamp.position = LAMP_POSITIONS[index]
		lamp.texture = glow_texture
		lamp.texture_scale = 2.2
		lamp.color = Color("#ffc66f")
		lamp.energy = 0.0
		lamp.enabled = false
		lamp.shadow_enabled = false
		lamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(lamp)
		_lamps.append(lamp)

	if not EventBus.time_changed.is_connected(_on_time_changed):
		EventBus.time_changed.connect(_on_time_changed)
	_apply_time(float(GameManager.game_time_hours))

func _make_glow_texture() -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var uv := Vector2(float(x) - 63.5, float(y) - 63.5) / 63.5
			var falloff := clampf(1.0 - uv.length(), 0.0, 1.0)
			var alpha := pow(falloff, 1.65) * 0.36
			image.set_pixel(x, y, Color(1.0, 0.78, 0.46, alpha))
	return ImageTexture.create_from_image(image)

func _on_time_changed(hour: int, minute: int) -> void:
	_apply_time(float(hour) + float(minute) / 60.0)

func _apply_time(hour: float) -> void:
	var evening := _smooth_ramp(17.5, 20.0, hour)
	var morning := 1.0 - _smooth_ramp(5.0, 7.0, hour)
	var night_strength := clampf(evening * morning, 0.0, 1.0)
	for lamp in _lamps:
		if not is_instance_valid(lamp):
			continue
		lamp.energy = night_strength * 1.15
		lamp.enabled = night_strength > 0.02

func _smooth_ramp(start: float, finish: float, value: float) -> float:
	var weight := clampf((value - start) / (finish - start), 0.0, 1.0)
	return weight * weight * (3.0 - 2.0 * weight)
