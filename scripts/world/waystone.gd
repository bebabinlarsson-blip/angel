class_name Waystone
extends StaticBody2D

const WAYPOINT_VISUAL_SCRIPT = preload("res://scripts/world/waypoint_visual.gd")

@export var waystone_id: String = "village"
@export var display_name: String = "Village Waystone"
@export var is_unlocked: bool = false

var fast_travel_layer: CanvasLayer = null
var fast_travel_popup: PanelContainer = null

func _ready() -> void:
	# Fast travel is a modal screen-space UI and must remain interactive while
	# the gameplay tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("waystones")
	if get_node_or_null("WaypointVisual") == null:
		var waypoint_visual := WAYPOINT_VISUAL_SCRIPT.new()
		waypoint_visual.name = "WaypointVisual"
		add_child(waypoint_visual)
	
	if is_unlocked or GameManager.is_waystone_unlocked(waystone_id):
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
		_close_fast_travel()
		return

	# Screen-space modal centered on screen: the old world-space Panel
	# drifted with the camera and clipped off-screen near map edges.
	fast_travel_layer = CanvasLayer.new()
	fast_travel_layer.name = "FastTravelLayer"
	fast_travel_layer.layer = 60
	fast_travel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fast_travel_layer)
	for overlay_name: String in ["BigMap", "InventoryUI", "QuestMenu", "PauseMenu", "CookingUILayer"]:
		_hide_overlay(overlay_name)
	get_tree().paused = true
	GameManager.is_paused = true

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
		var destination_name: String = str(w_data.get("name", w_id))
		var btn := Button.new()
		btn.text = destination_name
		if w_id == waystone_id:
			btn.text += " (Current)"
			btn.disabled = true
		else:
			var target_id: String = w_id
			btn.pressed.connect(_on_destination_pressed.bind(target_id, destination_name))
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
	if GameManager.current_state == GameManager.GameState.PLAYING and not _has_other_overlay():
		get_tree().paused = false
		GameManager.is_paused = false

func _on_destination_pressed(target_id: String, destination_name: String) -> void:
	GameManager.fast_travel_to(target_id)
	EventBus.show_notification.emit("Teleported to " + destination_name + "!")
	_close_fast_travel()

func _hide_overlay(node_name: String) -> void:
	var overlay := get_tree().root.find_child(node_name, true, false)
	if overlay is Control:
		(overlay as Control).visible = false
	elif overlay is CanvasLayer:
		(overlay as CanvasLayer).visible = false

func _has_other_overlay() -> bool:
	for node_name: String in ["BigMap", "InventoryUI", "QuestMenu", "PauseMenu", "CookingUILayer"]:
		var overlay := get_tree().root.find_child(node_name, true, false)
		if overlay is Control and (overlay as Control).visible:
			return true
		if overlay is CanvasLayer and (overlay as CanvasLayer).visible:
			return true
	return false

func _process(_delta: float) -> void:
	# Auto-close the popup if the player walks away (prevents orphaned UI).
	if fast_travel_layer and is_instance_valid(fast_travel_layer):
		var p := GameManager.player
		if p and is_instance_valid(p) and (p as Node2D).global_position.distance_to(global_position) > 180.0:
			_close_fast_travel()
