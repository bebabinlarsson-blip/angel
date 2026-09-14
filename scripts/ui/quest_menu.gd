class_name QuestMenu
extends Control

const NPC_PORTRAIT_SCRIPT = preload("res://scripts/ui/npc_portrait.gd")

@onready var quest_list: VBoxContainer = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/ScrollContainer/QuestList")
@onready var quest_detail: RichTextLabel = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/MarginContainer/QuestDetail")
@onready var close_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")
var quest_portrait: Control = null

func _ready() -> void:
	EventBus.quest_menu_toggled.connect(_toggle)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	if close_btn:
		close_btn.pressed.connect(func(): _toggle())
	if dimmer:
		dimmer.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_toggle()
		)
	UITheme.style_recursive(self)

func _toggle() -> void:
	visible = !visible
	if visible:
		_hide_overlay("BigMap")
		_hide_overlay("CookingUILayer")
		var inv := get_tree().root.find_child("InventoryUI", true, false)
		if inv and inv.visible:
			inv.visible = false
		var p_menu := get_tree().root.find_child("PauseMenu", true, false)
		if p_menu and p_menu.visible:
			p_menu.visible = false

		_refresh()
		_on_viewport_resized()
		GameManager.set_state(GameManager.GameState.PAUSED)
		var card := get_node_or_null("CenterContainer/PanelContainer")
		if card is Control:
			UIAnim.pop_in(card as Control, 0.2)
	else:
		var p_menu := get_tree().root.find_child("PauseMenu", true, false)
		var inv := get_tree().root.find_child("InventoryUI", true, false)
		if (p_menu == null or not p_menu.visible) and (inv == null or not inv.visible):
			GameManager.set_state(GameManager.GameState.PLAYING)

func _hide_overlay(node_name: String) -> void:
	var overlay := get_tree().root.find_child(node_name, true, false)
	if overlay is Control:
		(overlay as Control).visible = false
	elif overlay is CanvasLayer:
		(overlay as CanvasLayer).visible = false

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("quest") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and visible:
		_toggle()
		get_viewport().set_input_as_handled()
		_toggle()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if quest_list == null:
		return

	for child in quest_list.get_children():
		child.queue_free()

	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system == null:
		var empty_lbl := Label.new()
		empty_lbl.text = "No Quest System found."
		quest_list.add_child(empty_lbl)
		return

	var available: Array[Dictionary] = []
	for quest_key in quest_system.all_quests:
		var quest_id: String = str(quest_key)
		if quest_system.active_quests.has(quest_id) or quest_system.completed_quests.has(quest_id):
			continue
		var quest_value: Variant = quest_system.all_quests.get(quest_id, {})
		if quest_value is Dictionary:
			var quest_data: Dictionary = quest_value
			available.append(quest_data)

	_add_section_header("Available Quests (%d)" % available.size(), Color("#7dd3fc"))
	if available.is_empty():
		_add_empty_label("  No new quests. Talk to villagers to discover work.")
	else:
		for quest_data: Dictionary in available:
			_add_quest_button(quest_data, "available")

	_add_section_header("Active Quests (%d)" % quest_system.active_quests.size(), Color("#fbbf24"))
	if quest_system.active_quests.is_empty():
		_add_empty_label("  No active quests.")
	else:
		for quest_key in quest_system.active_quests:
			var quest_value: Variant = quest_system.active_quests.get(quest_key, {})
			if quest_value is Dictionary:
				_add_quest_button(quest_value, "active")

	_add_section_header("Completed Quests (%d)" % quest_system.completed_quests.size(), Color("#86efac"))
	if quest_system.completed_quests.is_empty():
		_add_empty_label("  No completed quests yet.")
	else:
		for quest_key in quest_system.completed_quests:
			var quest_value: Variant = quest_system.completed_quests.get(quest_key, {})
			if quest_value is Dictionary:
				_add_quest_button(quest_value, "completed")

	if quest_detail:
		_clear_quest_portrait()
		quest_detail.clip_contents = false
		quest_detail.text = "[font_size=18][b][color=#fde047]QUEST JOURNAL[/color][/b][/font_size]\n\nSelect any quest to see its giver, requirements, progress and rewards."

func _add_section_header(title: String, color: Color) -> void:
	var header := Label.new()
	header.text = title
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 14)
	quest_list.add_child(header)

func _add_empty_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.60, 0.70, 0.80))
	quest_list.add_child(label)

func _add_quest_button(quest: Dictionary, status: String) -> void:
	var quest_title: String = str(quest.get("title", "Unnamed Quest"))
	var giver_name: String = _npc_display_name(str(quest.get("npc_id", "")))
	var prefix: String = "[New]"
	var minimum_height: float = 50.0
	if status == "active":
		prefix = "[Active]"
	elif status == "completed":
		prefix = "[Done]"
		minimum_height = 42.0

	var button := Button.new()
	button.text = "%s %s\nFrom: %s" % [prefix, quest_title, giver_name]
	button.custom_minimum_size = Vector2(0.0, minimum_height)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_show_quest_detail.bind(quest))
	UITheme.style_button(button)
	quest_list.add_child(button)

func _show_quest_detail(quest: Dictionary) -> void:
	if quest_detail == null:
		return

	var current_count: int = int(quest.get("current_count", 0))
	var target_count: int = maxi(1, int(quest.get("target_count", 1)))
	var is_ready: bool = current_count >= target_count
	var rewards: Dictionary = quest.get("rewards", {})
	var npc_id: String = str(quest.get("npc_id", ""))
	var giver_name: String = _npc_display_name(npc_id)
	var giver_job: String = _npc_job(npc_id)
	var requirement: String = str(quest.get("objective", "No requirement recorded."))
	var destination: String = _quest_destination(str(quest.get("id", "")))
	var status_text: String = "Ready to complete!" if is_ready else "In progress"
	if quest.get("completed", false):
		status_text = "Completed"

	var detail_text: String = "[font_size=18][b][color=#fde047]%s[/color][/b][/font_size]\n\n%s\n\n[color=#fbbf24]Quest giver:[/color] %s\n[color=#a5b4fc]Role:[/color] %s\n[color=#38bdf8]What you need:[/color] %s\n[color=#c4b5fd]Destination:[/color] %s\n[color=#4ade80]Progress:[/color] %d / %d  (%s)\n\n[color=#fbbf24]Rewards:[/color] %d Gold, %d EXP" % [
		str(quest.get("title", "Unnamed Quest")),
		str(quest.get("description", "")),
		giver_name,
		giver_job.capitalize(),
		requirement,
		destination,
		current_count,
		target_count,
		status_text,
		int(rewards.get("money", 0)),
		int(rewards.get("exp", 0))
	]
	quest_detail.text = detail_text
	_show_quest_portrait(npc_id, giver_job)

func _quest_destination(quest_id: String) -> String:
	if quest_id.is_empty():
		return "No destination recorded."
	var quest_system := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system == null:
		return "Explore the island."
	var waypoint: Dictionary = quest_system.get_quest_waypoint(quest_id)
	if waypoint.is_empty():
		return "Explore the island."
	return str(waypoint.get("name", "Explore the island."))

func _show_quest_portrait(npc_id: String, giver_job: String) -> void:
	_clear_quest_portrait()
	var portrait := NPC_PORTRAIT_SCRIPT.new() as Control
	portrait.name = "QuestGiverPortrait"
	portrait.set("npc_id", npc_id)
	portrait.set("job", giver_job)
	portrait.custom_minimum_size = Vector2(86.0, 86.0)
	portrait.size = Vector2(86.0, 86.0)
	portrait.anchor_left = 1.0
	portrait.anchor_right = 1.0
	portrait.offset_left = -96.0
	portrait.offset_top = 8.0
	portrait.offset_right = -10.0
	portrait.offset_bottom = 94.0
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_detail.add_child(portrait)
	quest_portrait = portrait

func _clear_quest_portrait() -> void:
	if quest_portrait != null and is_instance_valid(quest_portrait):
		quest_portrait.queue_free()
	quest_portrait = null

func _npc_display_name(npc_id: String) -> String:
	match npc_id:
		"elder":
			return "Village Elder"
		"carpenter":
			return "Carpenter"
		"cook", "chef":
			return "Chef Maria"
		"miner":
			return "Miner Torvald"
		"farmer":
			return "Anika the Farmer"
		"guard":
			return "Rook the Gatekeeper"
		"merchant":
			return "Lio the Trader"
		"fisher":
			return "Mira the Fisher"
		"herbalist":
			return "Elin the Herbalist"
		"builder":
			return "Oskar the Builder"
		_:
			return "Unknown villager"

func _npc_job(npc_id: String) -> String:
	match npc_id:
		"elder":
			return "guard"
		"cook", "chef":
			return "cook"
		"carpenter":
			return "carpenter"
		"miner":
			return "miner"
		"farmer", "guard", "merchant", "fisher", "herbalist", "builder":
			return npc_id
		_:
			return "villager"
