class_name NPCPortrait
extends Control

## Deterministic procedural portraits give every named villager a distinct face
## without requiring a separate imported texture for each newly spawned job.
@export var npc_id: String = "villager"
@export var job: String = "idle"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(84.0, 84.0)
	queue_redraw()

func _draw() -> void:
	var draw_size: float = minf(size.x, size.y)
	if draw_size <= 0.0:
		return
	var portrait_scale: float = draw_size / 84.0
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * portrait_scale)
	draw_rect(Rect2(-40.0, -40.0, 80.0, 80.0), Color("#101a2a"), true)
	draw_rect(Rect2(-40.0, -40.0, 80.0, 80.0), Color("#e8bd62"), false, 2.0)

	var palette: Dictionary = _palette()
	var skin: Color = palette.get("skin", Color("#e6ad82"))
	var hair: Color = palette.get("hair", Color("#5b392d"))
	var clothes: Color = palette.get("clothes", Color("#47729d"))
	var accent: Color = palette.get("accent", Color("#d5a84f"))

	draw_colored_polygon(PackedVector2Array([
		Vector2(-32.0, 39.0), Vector2(-27.0, 18.0), Vector2(-13.0, 11.0),
		Vector2(13.0, 11.0), Vector2(27.0, 18.0), Vector2(32.0, 39.0)
	]), clothes)
	draw_line(Vector2(0.0, 13.0), Vector2(0.0, 39.0), accent, 3.0)
	draw_rect(Rect2(-7.0, 4.0, 14.0, 15.0), skin, true)
	draw_circle(Vector2(-25.0, -3.0), 7.0, skin)
	draw_circle(Vector2(25.0, -3.0), 7.0, skin)
	draw_circle(Vector2(0.0, -6.0), 25.0, skin)

	draw_arc(Vector2(0.0, -9.0), 24.0, PI, TAU, 28, hair, 9.0)
	draw_circle(Vector2(-18.0, -13.0), 9.0, hair)
	draw_circle(Vector2(18.0, -13.0), 9.0, hair)
	draw_circle(Vector2(-9.0, -11.0), 3.0, Color("#2c1b20"))
	draw_circle(Vector2(9.0, -11.0), 3.0, Color("#2c1b20"))
	draw_circle(Vector2(-8.0, -7.0), 2.0, Color("#faf1d0"))
	draw_circle(Vector2(10.0, -7.0), 2.0, Color("#faf1d0"))
	draw_line(Vector2(-7.0, 4.0), Vector2(7.0, 4.0), Color("#8d503e"), 2.0)
	draw_circle(Vector2(-1.0, -1.0), 2.0, Color("#c87862"))

	var effective_job: String = job if not job.is_empty() and job != "idle" else npc_id
	match effective_job:
		"farmer":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-28.0, -24.0), Vector2(28.0, -24.0), Vector2(18.0, -35.0),
				Vector2(-18.0, -35.0)
			]), Color("#d8ad55"))
			draw_line(Vector2(-18.0, -29.0), Vector2(18.0, -29.0), Color("#7e552d"), 3.0)
		"guard", "elder":
			draw_arc(Vector2(0.0, -10.0), 29.0, PI, TAU, 24, accent, 7.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-33.0, 15.0), Vector2(-20.0, 11.0), Vector2(-12.0, 31.0),
				Vector2(-30.0, 27.0)
			]), accent)
		"merchant":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-29.0, -22.0), Vector2(29.0, -22.0), Vector2(22.0, -35.0),
				Vector2(-16.0, -35.0)
			]), Color("#7e58a8"))
			draw_circle(Vector2(21.0, 18.0), 6.0, accent)
		"fisher":
			draw_arc(Vector2(0.0, -16.0), 27.0, PI, TAU, 24, Color("#5da5ad"), 8.0)
			draw_line(Vector2(-28.0, -18.0), Vector2(28.0, -18.0), Color("#8bd0cf"), 3.0)
		"herbalist":
			draw_circle(Vector2(0.0, -28.0), 10.0, Color("#8bc96d"))
			draw_line(Vector2(0.0, -31.0), Vector2(8.0, -39.0), Color("#4f9252"), 3.0)
			draw_ellipse_leaf(Vector2(13.0, -38.0), 6.0, Color("#75bb61"))
		"carpenter", "builder":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-29.0, -24.0), Vector2(29.0, -24.0), Vector2(21.0, -34.0),
				Vector2(-20.0, -34.0)
			]), accent)
			draw_line(Vector2(-11.0, 25.0), Vector2(16.0, 15.0), Color("#b8783d"), 4.0)
		"miner":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-30.0, -18.0), Vector2(30.0, -18.0), Vector2(21.0, -33.0),
				Vector2(-22.0, -33.0)
			]), Color("#e4b84f"))
			draw_line(Vector2(-18.0, -24.0), Vector2(18.0, -24.0), Color("#6a4b37"), 3.0)
		"cook", "chef":
			draw_arc(Vector2(0.0, -18.0), 25.0, PI, TAU, 24, Color("#f3f0e8"), 10.0)
			draw_circle(Vector2(0.0, 23.0), 6.0, Color("#db5b55"))
		_:
			draw_circle(Vector2(0.0, -27.0), 5.0, accent)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _palette() -> Dictionary:
	match npc_id:
		"elder":
			return {"skin": Color("#d19a77"), "hair": Color("#c5ccd0"), "clothes": Color("#625b86"), "accent": Color("#e4c46d")}
		"carpenter":
			return {"skin": Color("#d99b70"), "hair": Color("#623d2e"), "clothes": Color("#a76842"), "accent": Color("#e7bd5c")}
		"cook", "chef":
			return {"skin": Color("#efb68b"), "hair": Color("#8f4538"), "clothes": Color("#d55f59"), "accent": Color("#f3e7cc")}
		"miner":
			return {"skin": Color("#b77b5f"), "hair": Color("#342f39"), "clothes": Color("#596a78"), "accent": Color("#edc65b")}
		"farmer":
			return {"skin": Color("#d7956d"), "hair": Color("#5c3b29"), "clothes": Color("#668c57"), "accent": Color("#e1b555")}
		"guard":
			return {"skin": Color("#d19b78"), "hair": Color("#3f3444"), "clothes": Color("#4969a5"), "accent": Color("#d9575d")}
		"merchant":
			return {"skin": Color("#e3aa7c"), "hair": Color("#4e2e52"), "clothes": Color("#8056a1"), "accent": Color("#e6bd55")}
		"fisher":
			return {"skin": Color("#d4936e"), "hair": Color("#2f5660"), "clothes": Color("#4d8ca0"), "accent": Color("#e6d276")}
		"herbalist":
			return {"skin": Color("#efb184"), "hair": Color("#6b4c38"), "clothes": Color("#5d9a6a"), "accent": Color("#c989cf")}
		"builder":
			return {"skin": Color("#ce8d68"), "hair": Color("#5b382b"), "clothes": Color("#b46e43"), "accent": Color("#e4ae4f")}
		_:
			return {"skin": Color("#e2a77d"), "hair": Color("#544039"), "clothes": Color("#5477a2"), "accent": Color("#e1ba5b")}

func draw_ellipse_leaf(center: Vector2, radius: float, color: Color) -> void:
	var leaf_points: PackedVector2Array = PackedVector2Array([
		center + Vector2(-radius, 0.0),
		center + Vector2(-radius * 0.35, -radius * 0.62),
		center + Vector2(radius * 0.75, -radius * 0.30),
		center + Vector2(radius, 0.0),
		center + Vector2(radius * 0.35, radius * 0.62),
		center + Vector2(-radius * 0.75, radius * 0.30)
	])
	draw_colored_polygon(leaf_points, color)
