class_name InteriorEntrance
extends Area2D

## Reusable door trigger. The manager owns the modal and return position.

var manager: Node = null
var interior_id: String = ""
var display_name: String = "Interior"
var interior_kind: String = "house"
var description: String = ""
var entrance_label: Label = null
var tile_visual: Sprite2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("interior_entrances")
	_ensure_tile_visual()
	collision_layer = 1
	collision_mask = 0
	monitorable = true
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 48.0
		collision.shape = shape
		add_child(collision)
	entrance_label = Label.new()
	entrance_label.name = "EntranceLabel"
	entrance_label.position = Vector2(-100.0, -72.0)
	entrance_label.custom_minimum_size = Vector2(200.0, 22.0)
	entrance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entrance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entrance_label.visible = false
	entrance_label.add_theme_color_override("font_color", Color("#ffe08a"))
	entrance_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
	entrance_label.add_theme_constant_override("outline_size", 4)
	add_child(entrance_label)
	queue_redraw()

func configure(new_id: String, new_name: String, new_kind: String, new_description: String) -> void:
	interior_id = new_id
	display_name = new_name
	interior_kind = new_kind
	description = new_description
	_ensure_tile_visual()
	if entrance_label:
		entrance_label.text = display_name + "  [F]"
	queue_redraw()

func interact(_player: CharacterBody2D) -> void:
	if manager != null and manager.has_method("enter_interior"):
		manager.call("enter_interior", interior_id, global_position)

func show_interaction_hint() -> void:
	if entrance_label:
		entrance_label.visible = true

func hide_interaction_hint() -> void:
	if entrance_label:
		entrance_label.visible = false


func _tile_source_for_kind() -> int:
    match interior_kind:
        "cook":
            return 30 # house_chef from the shared atlas
        "smith":
            return 34 # house_stone from the shared atlas
        "market":
            return 29 # house_carpenter from the shared atlas
        "church":
            return 36 # cottage_stone from the shared atlas
        "mine":
            return 39 # rock_cluster from the shared atlas
        _:
            return 28 # house_blue from the shared atlas

func _ensure_tile_visual() -> void:
    if tile_visual == null:
        tile_visual = Sprite2D.new()
        tile_visual.name = "TileSetVisual"
        tile_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        tile_visual.z_index = -1
        add_child(tile_visual)
    var world_tileset := load("res://assets/tilesets/angel_world_tileset.tres") as TileSet
    if world_tileset == null:
        return
    var source := world_tileset.get_source(_tile_source_for_kind()) as TileSetAtlasSource
    if source == null or source.texture == null:
        return
    var atlas_texture := AtlasTexture.new()
    atlas_texture.atlas = source.texture
    atlas_texture.region = Rect2(Vector2.ZERO, source.texture.get_size())
    tile_visual.texture = atlas_texture
    if interior_kind == "mine":
        tile_visual.position = Vector2(0.0, -8.0)
        tile_visual.scale = Vector2(2.1, 2.1)
    else:
        tile_visual.position = Vector2(0.0, -40.0)
        tile_visual.scale = Vector2(0.72, 0.72)
    tile_visual.visible = true

func _draw() -> void:
    if interior_kind == "mine":
        draw_ellipse_shadow(Vector2(0.0, 20.0), Vector2(42.0, 12.0), Color(0.02, 0.04, 0.06, 0.40))
        draw_colored_polygon(PackedVector2Array([
            Vector2(-34.0, 16.0), Vector2(-30.0, -10.0), Vector2(-18.0, -30.0),
            Vector2(0.0, -38.0), Vector2(18.0, -30.0), Vector2(30.0, -10.0),
            Vector2(34.0, 16.0)
        ]), Color("#242b39"))
        draw_arc(Vector2(0.0, 12.0), 29.0, PI, TAU, 24, Color("#b98651"), 4.0)
        draw_rect(Rect2(-18.0, 8.0, 36.0, 20.0), Color("#10161d"))
        draw_circle(Vector2(0.0, -14.0), 5.0, Color("#f6c84f"))
        return
    if tile_visual == null or not tile_visual.visible:
        # Keep a visible fallback for minimal/test scenes if an imported
        # atlas cannot be loaded.
        draw_ellipse_shadow(Vector2(0.0, 16.0), Vector2(30.0, 10.0), Color(0.02, 0.04, 0.06, 0.34))
        draw_rect(Rect2(-24.0, -26.0, 48.0, 44.0), Color("#6b432f"))
        draw_rect(Rect2(-20.0, -22.0, 40.0, 40.0), Color("#a86b42"))
        draw_rect(Rect2(-21.0, -23.0, 42.0, 42.0), Color("#f0cb77"), false, 2.0)
        var roof := PackedVector2Array([Vector2(-31.0, -23.0), Vector2(0.0, -48.0), Vector2(31.0, -23.0)])
        draw_colored_polygon(roof, Color("#8d4d45"))
        draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), Color("#492d2a"), 2.0)
    draw_ellipse_shadow(Vector2(0.0, 14.0), Vector2(27.0, 8.0), Color(0.02, 0.04, 0.06, 0.30))
    draw_rect(Rect2(-8.0, -9.0, 16.0, 18.0), Color("#51352d"))
    draw_circle(Vector2(4.0, -1.0), 2.0, Color("#ffe18a"))
func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := float(i) * TAU / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
