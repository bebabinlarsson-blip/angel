class_name VillageService
extends StaticBody2D

const ITEM_ICON_SCRIPT = preload("res://scripts/ui/item_icon.gd")

## Small, reusable village services keep the settlement useful between quests.
## Market and blacksmith trades are atomic; the fountain has a short cooldown.

var service_id: String = ""
var display_name: String = "Village Service"
var service_type: String = "market"
var description: String = ""
var service_layer: CanvasLayer = null
var service_panel: PanelContainer = null
var status_label: Label = null
var player_ref: Player = null
var last_fountain_use_ms: int = -10000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("village_services")
	collision_layer = 1
	collision_mask = 0
	if get_node_or_null("CollisionShape2D") == null:
		var collision := CollisionShape2D.new()
		collision.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 32.0
		collision.shape = shape
		add_child(collision)
	queue_redraw()

func configure(new_id: String, new_name: String, new_type: String, new_description: String) -> void:
	service_id = new_id
	display_name = new_name
	service_type = new_type
	description = new_description
	queue_redraw()

func interact(player: Player) -> void:
	if player == null or not is_instance_valid(player) or player.stats == null:
		return
	if service_type == "fountain":
		_use_fountain(player)
	else:
		_open_service_ui(player)

func _use_fountain(player: Player) -> void:
	var now := Time.get_ticks_msec()
	if now - last_fountain_use_ms < 1500:
		return
	last_fountain_use_ms = now
	player.stats.heal(30.0)
	player.stats.current_stamina = minf(player.stats.get_max_stamina(), player.stats.current_stamina + 20.0)
	EventBus.player_stamina_changed.emit(player.stats.current_stamina, player.stats.get_max_stamina())
	EventBus.show_notification.emit("The Village Fountain restores your strength.")

func _open_service_ui(player: Player) -> void:
	if service_layer != null and is_instance_valid(service_layer):
		_close_service()
		return
	player_ref = player
	service_layer = CanvasLayer.new()
	service_layer.name = "VillageServiceLayer"
	service_layer.layer = 57
	service_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(service_layer)

	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	service_layer.add_child(root)

	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.01, 0.02, 0.04, 0.72)
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_service()
	)
	root.add_child(dimmer)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	service_panel = PanelContainer.new()
	service_panel.name = "ServicePanel"
	service_panel.custom_minimum_size = Vector2(480.0, 390.0)
	service_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("#d59a4e"), Color("#111a28")))
	center.add_child(service_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	service_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = display_name
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("#ffe08a"))
	header.add_child(title)
	var badge := Label.new()
	badge.text = service_type.to_upper()
	badge.add_theme_color_override("font_color", Color("#8dd7dd"))
	header.add_child(badge)
	vbox.add_child(header)

	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", Color("#cbd8e3"))
	vbox.add_child(detail)

	status_label = Label.new()
	status_label.text = _service_status()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#b8f08a"))
	vbox.add_child(status_label)

	if service_type == "market":
		_add_trade_option(vbox, "wood", 5, 10, "Trade a timber bundle")
		_add_trade_option(vbox, "berry", 3, 8, "Trade a berry basket")
		_add_trade_option(vbox, "apple", 2, 12, "Trade an apple crate")
	else:
		_add_trade_option(vbox, "iron_ore", 2, 25, "Trade refined iron ore")
		_add_trade_option(vbox, "coal", 3, 18, "Trade a coal shipment")
		_add_trade_option(vbox, "gold_ore", 1, 40, "Trade a gold fragment")

	var close_btn := Button.new()
	close_btn.text = "Close  [F / Esc]"
	close_btn.custom_minimum_size = Vector2(0.0, 38.0)
	close_btn.pressed.connect(_close_service)
	UITheme.style_button(close_btn)
	vbox.add_child(close_btn)

	UITheme.style_recursive(service_panel)
	_on_viewport_resized()
	GameManager.set_state(GameManager.GameState.PAUSED)
	UIAnim.pop_in(service_panel, 0.18)

func _add_trade_option(parent: VBoxContainer, item_id: String, amount: int, gold: int, action_text: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 48.0)
	var icon := ITEM_ICON_SCRIPT.new() as Control
	icon.name = "TradeIcon"
	icon.set("item_id", item_id)
	icon.set("item_type", 0)
	icon.custom_minimum_size = Vector2(42.0, 42.0)
	icon.size = Vector2(42.0, 42.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	var label := Label.new()
	label.text = "%s\n%d × %s  →  %d Gold" % [action_text, amount, item_id.replace("_", " ").capitalize(), gold]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button := Button.new()
	button.text = "Trade"
	button.custom_minimum_size = Vector2(92.0, 36.0)
	button.pressed.connect(_trade.bind(item_id, amount, gold))
	UITheme.style_button(button)
	row.add_child(button)
	parent.add_child(row)

func _trade(item_id: String, amount: int, gold: int) -> void:
	if player_ref == null or not is_instance_valid(player_ref) or player_ref.inventory == null:
		return
	if not player_ref.inventory.remove_item(item_id, amount):
		EventBus.show_notification.emit("You need %d %s." % [amount, item_id.replace("_", " ").capitalize()])
		return
	player_ref.stats.add_money(gold)
	if status_label:
		status_label.text = _service_status()
	EventBus.show_notification.emit("Trade complete: +%d Gold." % gold)

func _service_status() -> String:
	if player_ref == null or not is_instance_valid(player_ref) or player_ref.inventory == null:
		return "Approach the counter to trade."
	return "Your stock: %d materials in the backpack." % player_ref.inventory.get_items_by_type(PlayerInventory.ItemType.MATERIAL).size()

func _on_viewport_resized() -> void:
	if service_panel:
		UITheme.fit_modal(service_panel, Vector2(480.0, 390.0))

func _close_service() -> void:
	if service_layer != null and is_instance_valid(service_layer):
		service_layer.queue_free()
	service_layer = null
	service_panel = null
	status_label = null
	player_ref = null
	if GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.set_state(GameManager.GameState.PLAYING)

func _input(event: InputEvent) -> void:
	if service_layer == null or not is_instance_valid(service_layer):
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_close_service()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") or event.is_action_pressed("quest") or event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()

func _draw() -> void:
	_draw_shadow()
	match service_type:
		"fountain":
			_draw_fountain()
		"blacksmith":
			_draw_blacksmith()
		_:
			_draw_market()

func _draw_shadow() -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := float(i) * TAU / 24.0
		points.append(Vector2(cos(angle) * 36.0, 10.0 + sin(angle) * 11.0))
	draw_colored_polygon(points, Color(0.02, 0.04, 0.06, 0.34))

func _draw_fountain() -> void:
	draw_circle(Vector2(0.0, 4.0), 31.0, Color("#6f7886"))
	draw_circle(Vector2(0.0, -1.0), 24.0, Color("#2d8fa4"))
	draw_circle(Vector2(0.0, -3.0), 17.0, Color("#79d8df"))
	draw_rect(Rect2(-5.0, -45.0, 10.0, 40.0), Color("#c0c9d2"))
	draw_circle(Vector2(0.0, -50.0), 9.0, Color("#e4c76b"))
	draw_line(Vector2(-5.0, -42.0), Vector2(-16.0, -25.0), Color("#9be9eb"), 3.0)
	draw_line(Vector2(5.0, -42.0), Vector2(16.0, -25.0), Color("#9be9eb"), 3.0)
	draw_circle(Vector2(-16.0, -24.0), 3.0, Color("#d4ffff"))
	draw_circle(Vector2(16.0, -24.0), 3.0, Color("#d4ffff"))

func _draw_market() -> void:
	draw_rect(Rect2(-40.0, -18.0, 80.0, 30.0), Color("#92502f"))
	draw_rect(Rect2(-52.0, -46.0, 104.0, 28.0), Color("#d36a50"))
	draw_colored_polygon(PackedVector2Array([Vector2(-52.0, -46.0), Vector2(0.0, -60.0), Vector2(52.0, -46.0)]), Color("#e7a24f"))
	draw_line(Vector2(-36.0, 12.0), Vector2(-36.0, 34.0), Color("#613a27"), 5.0)
	draw_line(Vector2(36.0, 12.0), Vector2(36.0, 34.0), Color("#613a27"), 5.0)
	draw_circle(Vector2(-22.0, -4.0), 7.0, Color("#cb5b66"))
	draw_circle(Vector2(0.0, -2.0), 7.0, Color("#76bf67"))
	draw_circle(Vector2(21.0, -3.0), 7.0, Color("#e6b14c"))

func _draw_blacksmith() -> void:
	draw_rect(Rect2(-34.0, -16.0, 68.0, 30.0), Color("#554b5c"))
	draw_circle(Vector2(0.0, -18.0), 20.0, Color("#df7440"))
	draw_circle(Vector2(0.0, -18.0), 11.0, Color("#ffe17a"))
	draw_rect(Rect2(-48.0, 10.0, 96.0, 10.0), Color("#747e8a"))
	draw_rect(Rect2(-48.0, 10.0, 96.0, 10.0), Color("#c5d5db"), false, 2.0)
	draw_line(Vector2(-18.0, 20.0), Vector2(-20.0, 38.0), Color("#4b392e"), 6.0)
	draw_line(Vector2(18.0, 20.0), Vector2(20.0, 38.0), Color("#4b392e"), 6.0)
	draw_line(Vector2(25.0, -10.0), Vector2(42.0, -36.0), Color("#74482d"), 4.0)
	draw_line(Vector2(36.0, -38.0), Vector2(50.0, -32.0), Color("#c5d5db"), 5.0)
