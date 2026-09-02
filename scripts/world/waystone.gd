class_name Waystone
extends StaticBody2D

@export var waystone_id: String = "village"
@export var display_name: String = "Village Waystone"
@export var is_unlocked: bool = false

var visual: CustomDraw2D = null
var fast_travel_popup: Panel = null

func _ready() -> void:
	add_to_group("waystones")
	
	visual = get_node_or_null("CustomDraw2D") as CustomDraw2D
	if visual == null:
		visual = CustomDraw2D.new()
		visual.name = "CustomDraw2D"
		visual.entity_type = CustomDraw2D.EntityType.WAYSTONE
		add_child(visual)
	
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
	if fast_travel_popup and is_instance_valid(fast_travel_popup):
		fast_travel_popup.queue_free()
		fast_travel_popup = null
		return
	
	fast_travel_popup = Panel.new()
	fast_travel_popup.position = Vector2(-120, -180)
	fast_travel_popup.custom_minimum_size = Vector2(240, 160)
	
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.custom_minimum_size = Vector2(220, 140)
	
	var title := Label.new()
	title.text = "Fast Travel Destinations:"
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
				if fast_travel_popup:
					fast_travel_popup.queue_free()
					fast_travel_popup = null
			)
		vbox.add_child(btn)
	
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func():
		if fast_travel_popup:
			fast_travel_popup.queue_free()
			fast_travel_popup = null
	)
	vbox.add_child(close_btn)
	
	fast_travel_popup.add_child(vbox)
	add_child(fast_travel_popup)
