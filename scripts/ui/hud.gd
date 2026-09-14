extends CanvasLayer

@onready var health_bar: ProgressBar = $TopRight/HealthBar
@onready var stamina_bar: ProgressBar = $TopRight/StaminaBar
@onready var money_label: Label = $TopRight/MoneyLabel
@onready var weapon_label: Label = $TopRight/WeaponLabel
@onready var time_label: Label = $TopCenter/TimeLabel
@onready var day_label: Label = $TopCenter/DayLabel
@onready var minimap_container: Control = $TopLeft/MinimapContainer
@onready var big_map: Control = $BigMap
@onready var notification_label: Label = $NotificationLabel
@onready var exp_bar: ProgressBar = $TopRight/ExpBar
@onready var level_label: Label = $TopRight/LevelLabel
@onready var interaction_hint: Label = $InteractionHint
var controls_hint: Label = null
var buff_label: Label = null
var quest_tracker_panel: PanelContainer = null
var quest_tracker_label: Label = null
var quest_tracker_timer: float = 0.0

var notification_timer: float = 0.0
var _notif_tween: Tween = null
var _displayed_hp: float = -1.0
var _displayed_stam: float = -1.0
var big_draw_node: MinimapDrawer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.player_money_changed.connect(_on_money_changed)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.show_notification.connect(_on_show_notification)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	EventBus.player_exp_gained.connect(_on_exp_gained)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.quest_accepted.connect(_on_quest_changed)
	EventBus.quest_completed.connect(_on_quest_changed)
	EventBus.quest_updated.connect(_on_quest_changed)
	
	# Setup Small Minimap
	if minimap_container:
		var mini_draw := MinimapDrawer.new()
		mini_draw.is_big_map = false
		mini_draw.name = "MinimapDrawer"
		mini_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
		minimap_container.add_child(mini_draw)
	
	# Setup Big Map
	if big_map:
		big_map.visible = false
		var big_draw := MinimapDrawer.new()
		big_draw.is_big_map = true
		big_draw.name = "BigMapDrawer"
		big_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
		big_map.add_child(big_draw)
		big_draw_node = big_draw
		
		# Buttons container neatly placed in the ledger panel below the chart key
		var btn_container := VBoxContainer.new()
		btn_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		btn_container.anchor_left = 1.0
		btn_container.anchor_right = 1.0
		btn_container.offset_left = -195
		btn_container.offset_right = -15
		btn_container.name = "MapControls"
		btn_container.add_theme_constant_override("separation", 6)
		btn_container.offset_top = 280
		
		var close_btn := Button.new()
		close_btn.text = "Close Map [M]"
		UITheme.style_button(close_btn)
		close_btn.pressed.connect(func(): set_map_open(false))
		btn_container.add_child(close_btn)
		
		var center_btn := Button.new()
		center_btn.text = "Center on Player"
		UITheme.style_button(center_btn)
		center_btn.pressed.connect(big_draw.center_on_player)
		btn_container.add_child(center_btn)
		
		var zoom_in_btn := Button.new()
		zoom_in_btn.text = "Zoom In (+)"
		UITheme.style_button(zoom_in_btn)
		zoom_in_btn.pressed.connect(func(): big_draw.zoom_in())
		btn_container.add_child(zoom_in_btn)
		
		var zoom_out_btn := Button.new()
		zoom_out_btn.text = "Zoom Out (-)"
		UITheme.style_button(zoom_out_btn)
		zoom_out_btn.pressed.connect(func(): big_draw.zoom_out())
		btn_container.add_child(zoom_out_btn)
		
		var fit_btn := Button.new()
		fit_btn.name = "FitIsland"
		fit_btn.text = "Fit Island Detail"
		UITheme.style_button(fit_btn)
		fit_btn.pressed.connect(big_draw.fit_island)
		btn_container.add_child(fit_btn)

		var world_btn := Button.new()
		world_btn.name = "FitWorld"
		world_btn.text = "Full World / Ocean"
		UITheme.style_button(world_btn)
		world_btn.pressed.connect(big_draw.fit_world)
		btn_container.add_child(world_btn)
		
		for button: Button in btn_container.get_children():
			button.custom_minimum_size.y = 32
			UITheme.style_button(button)
		big_map.add_child(btn_container)
	
	if notification_label:
		notification_label.visible = false
	if interaction_hint:
		interaction_hint.visible = false
	_create_controls_hint()
	_create_buff_label()
	_create_quest_tracker()
	_on_inventory_changed()
	_refresh_quest_tracker()
	_apply_theme()

func _create_controls_hint() -> void:
	controls_hint = Label.new()
	controls_hint.name = "ControlsHint"
	controls_hint.position = Vector2(16, 214)
	controls_hint.custom_minimum_size = Vector2(280, 58)
	controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_hint.text = "WASD  Move    E  Backpack\nF  Interact    LMB / Space  Sword\nShift  Dash    Q  Quest Journal    M  Map"
	controls_hint.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92, 0.82))
	controls_hint.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.90))
	controls_hint.add_theme_constant_override("outline_size", 4)
	controls_hint.add_theme_font_size_override("font_size", 12)
	add_child(controls_hint)

func _create_quest_tracker() -> void:
	quest_tracker_panel = PanelContainer.new()
	quest_tracker_panel.name = "QuestTracker"
	quest_tracker_panel.position = Vector2(16.0, 326.0)
	quest_tracker_panel.custom_minimum_size = Vector2(330.0, 92.0)
	quest_tracker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker_panel.visible = false
	quest_tracker_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.EDGE, Color(0.05, 0.09, 0.13, 0.92)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	quest_tracker_panel.add_child(margin)

	quest_tracker_label = Label.new()
	quest_tracker_label.name = "QuestTrackerLabel"
	quest_tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_tracker_label.add_theme_color_override("font_color", Color("#eef3f6"))
	quest_tracker_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
	quest_tracker_label.add_theme_constant_override("outline_size", 3)
	quest_tracker_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(quest_tracker_label)
	add_child(quest_tracker_panel)

func _direction_arrow(direction: Vector2) -> String:
	if direction.length_squared() <= 1.0:
		return "•"
	var arrows: Array[String] = ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
	var index: int = posmod(int(round(direction.angle() / (PI / 4.0))), arrows.size())
	return arrows[index]

func _refresh_quest_tracker() -> void:
	if quest_tracker_panel == null or quest_tracker_label == null:
		return
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system == null:
		quest_tracker_panel.visible = false
		return
	var quest: Dictionary = quest_system.get_active_quest()
	var waypoint: Dictionary = quest_system.get_active_waypoint()
	if quest.is_empty() or waypoint.is_empty():
		quest_tracker_panel.visible = false
		return
	var raw_position: Variant = waypoint.get("position", Vector2.ZERO)
	var player := GameManager.player
	if not (raw_position is Vector2) or player == null or not is_instance_valid(player):
		quest_tracker_panel.visible = false
		return

	var target_position: Vector2 = raw_position
	var direction: Vector2 = target_position - player.global_position
	var distance: int = maxi(0, int(round(direction.length())))
	var progress: String = "%d/%d" % [
		int(quest.get("current_count", 0)),
		maxi(1, int(quest.get("target_count", 1)))
	]
	var is_return: bool = bool(waypoint.get("is_return", false))
	var phase: String = "RETURN TO GIVER" if is_return else "ACTIVE QUEST"
	var arrow: String = _direction_arrow(direction)
	quest_tracker_label.text = "%s  %s\n%s\n%s  %s  •  %dm" % [
		phase,
		str(quest.get("title", "Quest")),
		str(quest.get("objective", "Follow the waypoint.")),
		arrow,
		str(waypoint.get("name", "Quest objective")),
		distance
	]
	quest_tracker_panel.visible = big_map == null or not big_map.visible

func _on_quest_changed(_quest_id: String) -> void:
	_refresh_quest_tracker()

func _create_buff_label() -> void:
	buff_label = Label.new()
	buff_label.name = "FoodBuffStatus"
	buff_label.position = Vector2(16, 276)
	buff_label.custom_minimum_size = Vector2(300, 28)
	buff_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buff_label.visible = false
	buff_label.add_theme_color_override("font_color", Color("#b8f08a"))
	buff_label.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.06, 0.95))
	buff_label.add_theme_constant_override("outline_size", 4)
	buff_label.add_theme_font_size_override("font_size", 13)
	add_child(buff_label)


func _apply_theme() -> void:
	UITheme.style_bar(health_bar, UITheme.HP_FILL)
	UITheme.style_bar(stamina_bar, UITheme.STAM_FILL)
	UITheme.style_bar(exp_bar, UITheme.EXP_FILL)
	UITheme.outline_text(level_label, 18, UITheme.GOLD)
	UITheme.outline_text(money_label, 15)
	UITheme.outline_text(weapon_label, 14, UITheme.TEXT_DIM)
	UITheme.outline_text(time_label, 20)
	UITheme.outline_text(day_label, 14, UITheme.TEXT_DIM)
	UITheme.outline_text(notification_label, 22, UITheme.GOLD)
	UITheme.outline_text(interaction_hint, 18, Color(1.0, 0.95, 0.6))
	for c in get_children():
		if c is Button:
			UITheme.style_button(c as Button)
	if big_map and big_map is Panel:
		(big_map as Panel).add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.EDGE, Color(0.05, 0.07, 0.12, 0.85)))

func set_map_open(open: bool) -> void:
	# The HUD can receive an input event during a scene transition. Keep the
	# map toggle harmless until its panel has been created.
	if big_map == null:
		return
	if open:
		# Keep one modal at a time. Hidden menus are not toggled through their
		# public handlers here, so opening the map cannot accidentally unpause
		# the world halfway through a transition.
		_hide_overlay("InventoryUI")
		_hide_overlay("QuestMenu")
		_hide_overlay("PauseMenu")
		_hide_overlay("CookingUILayer")
		big_map.visible = true
		GameManager.set_state(GameManager.GameState.PAUSED)
		if interaction_hint:
			interaction_hint.visible = false
		if notification_label:
			notification_label.visible = false
		if is_instance_valid(big_draw_node):
			big_draw_node.grab_focus()
	else:
		big_map.visible = false
		if GameManager.current_state != GameManager.GameState.GAME_OVER and not _has_visible_overlay():
			GameManager.set_state(GameManager.GameState.PLAYING)

func _hide_overlay(node_name: String) -> void:
	var overlay := get_tree().root.find_child(node_name, true, false)
	if overlay is Control:
		(overlay as Control).visible = false
	elif overlay is CanvasLayer:
		(overlay as CanvasLayer).visible = false

func _has_visible_overlay() -> bool:
	for node_name: String in ["InventoryUI", "QuestMenu", "PauseMenu", "CookingUILayer"]:
		var overlay := get_tree().root.find_child(node_name, true, false)
		if overlay is Control and (overlay as Control).visible:
			return true
		if overlay is CanvasLayer and (overlay as CanvasLayer).visible:
			return true
	return false

func _input(event: InputEvent) -> void:
	if big_map == null:
		return
	if event.is_action_pressed("toggle_map") and (big_map.visible or not get_tree().paused):
		set_map_open(not big_map.visible)
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and big_map.visible:
		set_map_open(false)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_refresh_buff_label()
	quest_tracker_timer -= delta
	if quest_tracker_timer <= 0.0:
		quest_tracker_timer = 0.2
		_refresh_quest_tracker()
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0 and notification_label:
			if _notif_tween and _notif_tween.is_valid():
				_notif_tween.kill()
			_notif_tween = notification_label.create_tween()
			_notif_tween.tween_property(notification_label, "modulate:a", 0.0, 0.4)
			_notif_tween.tween_callback(func():
				if is_instance_valid(notification_label):
					notification_label.visible = false
			)
	# Smooth bar drain (juice without extra signals)
	if health_bar and _displayed_hp >= 0.0 and absf(health_bar.value - _displayed_hp) > 0.5:
		health_bar.value = lerpf(health_bar.value, _displayed_hp, minf(delta * 10.0, 1.0))
	if stamina_bar and _displayed_stam >= 0.0 and absf(stamina_bar.value - _displayed_stam) > 0.5:
		stamina_bar.value = lerpf(stamina_bar.value, _displayed_stam, minf(delta * 10.0, 1.0))

func _refresh_buff_label() -> void:
	if buff_label == null:
		return
	var current_player: Variant = GameManager.player
	if current_player == null or not is_instance_valid(current_player) or current_player.stats == null:
		buff_label.visible = false
		return
	var active_text: String = current_player.stats.get_active_buff_text()
	buff_label.visible = not active_text.is_empty()
	if buff_label.visible:
		buff_label.text = "Food buff: " + active_text


func _on_health_changed(current: float, maximum: float) -> void:
	_displayed_hp = current
	if health_bar:
		health_bar.max_value = maximum
		# Snap up instantly (heal), smooth down in _process (damage)
		if current >= health_bar.value:
			health_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	_displayed_stam = current
	if stamina_bar:
		stamina_bar.max_value = maximum
		if current >= stamina_bar.value:
			stamina_bar.value = current
		else:
			# Drain feels responsive: snap fast drains, smooth regen
			stamina_bar.value = current

func _on_money_changed(amount: int) -> void:
	if money_label:
		money_label.text = "Gold: %d" % amount

func _on_time_changed(hour: int, minute: int) -> void:
	if time_label:
		time_label.text = "%02d:%02d" % [hour, minute]
	if day_label:
		day_label.text = "Day %d" % GameManager.day_count

func _on_show_notification(text: String) -> void:
	if notification_label:
		if _notif_tween and _notif_tween.is_valid():
			_notif_tween.kill()
		notification_label.text = text
		var map_is_open: bool = big_map != null and big_map.visible
		notification_label.visible = not map_is_open
		notification_label.modulate.a = 0.0
		notification_label.scale = Vector2(0.9, 0.9)
		notification_label.pivot_offset = notification_label.size * 0.5
		_notif_tween = notification_label.create_tween()
		_notif_tween.set_parallel(true)
		_notif_tween.tween_property(notification_label, "modulate:a", 1.0, 0.18)
		_notif_tween.tween_property(notification_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		notification_timer = 3.0

func _on_inventory_changed() -> void:
	var player := GameManager.player
	if weapon_label and player != null and is_instance_valid(player) and player.inventory:
		var w: Dictionary = player.inventory.equipped_weapon
		if w.is_empty():
			weapon_label.text = "Weapon: Fist"
		else:
			weapon_label.text = "Weapon: %s" % w.get("name", "???")

func _on_leveled_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv. %d" % new_level
	_on_show_notification("Level Up! Now level %d" % new_level)

func _on_exp_gained(_amount: int, total: int, required: int) -> void:
	if exp_bar:
		exp_bar.max_value = required
		exp_bar.value = total

func _on_interaction_available(_interactable: Node) -> void:
	if interaction_hint == null or _interactable == null:
		return
	interaction_hint.visible = big_map == null or not big_map.visible
	var label := "Interact"
	if _interactable is QuestNPC:
		label = "Talk to " + _interactable.npc_name
	elif _interactable is Waystone:
		label = _interactable.display_name
	elif _interactable is CookingPot:
		label = "Cook at the hearth"
	elif _interactable is MiningRock:
		label = "Mine " + _interactable.ore_name
	elif _interactable is ResourceNode:
		label = "Collect " + _interactable.item_name
	elif _interactable is CollectableItem:
		label = "Collect " + _interactable.item_name
	elif _interactable.is_in_group("supply_caches"):
		label = "Open supply cache"

	if _interactable is ResourceNode or _interactable is CollectableItem:
		interaction_hint.text = "[F] %s  ·  walk close to auto-pick" % label
	else:
		interaction_hint.text = "[F] " + label
	interaction_hint.modulate.a = 0.0
	var tween := interaction_hint.create_tween()
	tween.tween_property(interaction_hint, "modulate:a", 1.0, 0.15)


func _on_interaction_unavailable() -> void:
	if interaction_hint:
		interaction_hint.visible = false
