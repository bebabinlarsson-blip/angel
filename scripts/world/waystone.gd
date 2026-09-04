class_name Waystone
extends StaticBody2D

@export var waystone_id: String = "village"
@export var display_name: String = "Village Waystone"
@export var is_unlocked: bool = false

var visual: CanvasItem = null
var sprite: Sprite2D = null
var fast_travel_layer: CanvasLayer = null
var fast_travel_popup: PanelContainer = null

func _ready() -> void:
	add_to_group("waystones")
	
	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = load("res://assets/sprites/world/waystone.png")
		add_child(sprite)
	visual = sprite
	
	if is_unlocked or waystone_id in GameManager.unlocked_waystones:
		is_unlocked = true
		GameManager.register_waystone(waystone_id, global_position, display_name)

func interact(_player: CharacterBody2D) -> void:
	if not is_unlocked:
		is_unlocked = true
		GameManager.register_waystone(waystone_id, global_position, display_name)
		EventBus.show_notification.emit("Waystone activated: " + display_name)
	else:
		_show_fast_travel_ui()

func _show_fast_travel_ui() -> void:
	if fast_travel_layer and is_instance_valid(fast_travel_layer):
		fast_travel_layer.queue_free()
		fast_travel_layer = null
		fast_travel_popup = null
		return

	# Screen-space modal centered on screen: the old world-space Panel
	# drifted with the camera and clipped off-screen near map edges.
	fast_travel_layer = CanvasLayer.new()
	fast_travel_layer.name = "FastTravelLayer"
	fast_travel_layer.layer = 60
	fast_travel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fast_travel_layer)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fast_travel_layer.add_child(center)

	fast_travel_popup = PanelContainer.new()
	fast_travel_popup.name = "FastTravelPanel"
	fast_travel_popup.custom_minimum_size = Vector2(300, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.97)
	style.border_color = Color(0.35, 0.7, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	fast_travel_popup.add_theme_stylebox_override("panel", style)
	center.add_child(fast_travel_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	fast_travel_popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Fast Travel Destinations:"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	for w_id in GameManager.unlocked_waystones:
		var w_data: Dictionary = GameManager.unlocked_waystones[w_id]
		var btn := Button.new()
		btn.text = w_data.get("name", w_id)
		if w_id == waystone_id:
			btn.text += " (Current)"
			btn.disabled = true
		else:
			var target_id: String = w_id
			btn.pressed.connect(func():
				GameManager.fast_travel_to(target_id)
				EventBus.show_notification.emit("Teleported to " + w_data.get("name", target_id) + "!")
				_close_fast_travel()
			)
		vbox.add_child(btn)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_fast_travel)
	vbox.add_child(close_btn)

	UIAnim.pop_in(fast_travel_popup, 0.18)
	for b in vbox.get_children():
		if b is Button:
			UIAnim.hook_button_sounds(b as Button)

func _close_fast_travel() -> void:
	if fast_travel_layer and is_instance_valid(fast_travel_layer):
		fast_travel_layer.queue_free()
	fast_travel_layer = null
	fast_travel_popup = null

func _process(_delta: float) -> void:
	# Auto-close the popup if the player walks away (prevents orphaned UI).
	if fast_travel_layer and is_instance_valid(fast_travel_layer):
		var p := GameManager.player
		if p and is_instance_valid(p) and (p as Node2D).global_position.distance_to(global_position) > 180.0:
			_close_fast_travel()
