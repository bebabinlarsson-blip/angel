extends CanvasModulate

# Time-of-day color gradient
var time_colors: Array[Dictionary] = [
	{"hour": 0, "color": Color(0.1, 0.1, 0.2)},      # Midnight
	{"hour": 5, "color": Color(0.2, 0.15, 0.3)},     # Pre-dawn
	{"hour": 6, "color": Color(0.8, 0.5, 0.3)},      # Sunrise
	{"hour": 7, "color": Color(0.9, 0.8, 0.7)},      # Early morning
	{"hour": 8, "color": Color(1.0, 1.0, 1.0)},      # Morning
	{"hour": 12, "color": Color(1.0, 1.0, 0.95)},    # Noon
	{"hour": 17, "color": Color(1.0, 0.9, 0.8)},     # Afternoon
	{"hour": 18, "color": Color(0.9, 0.6, 0.3)},     # Sunset
	{"hour": 19, "color": Color(0.5, 0.3, 0.4)},     # Dusk
	{"hour": 20, "color": Color(0.15, 0.1, 0.25)},   # Night
	{"hour": 24, "color": Color(0.1, 0.1, 0.2)},     # Midnight (wrap)
]

func _ready() -> void:
	EventBus.time_changed.connect(_on_time_changed)

func _on_time_changed(hour: int, minute: int) -> void:
	var time_float := hour + minute / 60.0
	color = _get_color_for_time(time_float)

func _get_color_for_time(time: float) -> Color:
	# Find the two surrounding time points
	for i in range(time_colors.size() - 1):
		var t1: float = time_colors[i]["hour"]
		var t2: float = time_colors[i + 1]["hour"]
		if time >= t1 and time < t2:
			var t := (time - t1) / (t2 - t1)
			return time_colors[i]["color"].lerp(time_colors[i + 1]["color"], t)
	return time_colors[0]["color"]
