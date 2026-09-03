class_name QuestMenu
extends Control

@onready var quest_list: VBoxContainer = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/ScrollContainer/QuestList")
@onready var quest_detail: RichTextLabel = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/MarginContainer/QuestDetail")
@onready var close_btn: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")

func _ready() -> void:
	EventBus.quest_menu_toggled.connect(_toggle)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		var inv := get_tree().root.find_child("InventoryUI", true, false)
		if inv and inv.visible:
			inv.visible = false
		var p_menu := get_tree().root.find_child("PauseMenu", true, false)
		if p_menu and p_menu.visible:
			p_menu.visible = false
		
		_refresh()
		get_tree().paused = true
		var card := get_node_or_null("CenterContainer/PanelContainer")
		if card is Control:
			UIAnim.pop_in(card as Control, 0.2)
	else:
		var p_menu := get_tree().root.find_child("PauseMenu", true, false)
		var inv := get_tree().root.find_child("InventoryUI", true, false)
		if (p_menu == null or not p_menu.visible) and (inv == null or not inv.visible):
			get_tree().paused = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and visible:
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
	
	# Active quests
	var header := Label.new()
	header.text = "Active Quests (%d)" % quest_system.active_quests.size()
	header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	quest_list.add_child(header)
	
	if quest_system.active_quests.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "  (No active quests. Talk to villagers!)"
		none_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
		quest_list.add_child(none_lbl)
	
	for q_id in quest_system.active_quests:
		var q: Dictionary = quest_system.active_quests[q_id]
		var btn := Button.new()
		var ready_str := " [READY]" if (q.get("current_count", 0) >= q.get("target_count", 1)) else ""
		btn.text = "%s (%d/%d)%s" % [q.get("title", ""), q.get("current_count", 0), q.get("target_count", 1), ready_str]
		btn.custom_minimum_size = Vector2(0, 38)
		btn.pressed.connect(_show_quest_detail.bind(q))
		UITheme.style_button(btn)
		quest_list.add_child(btn)
	
	# Completed quests
	var comp_header := Label.new()
	comp_header.text = "\nCompleted Quests (%d)" % quest_system.completed_quests.size()
	comp_header.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	quest_list.add_child(comp_header)
	
	for q_id in quest_system.completed_quests:
		var q: Dictionary = quest_system.completed_quests[q_id]
		var btn := Button.new()
		btn.text = "[Done] " + q.get("title", "")
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(_show_quest_detail.bind(q))
		UITheme.style_button(btn)
		quest_list.add_child(btn)

func _show_quest_detail(quest: Dictionary) -> void:
	if quest_detail:
		var current_c: int = quest.get("current_count", 0)
		var target_c: int = quest.get("target_count", 1)
		var is_ready: bool = current_c >= target_c
		var rewards: Dictionary = quest.get("rewards", {})
		
		var text := "[font_size=18][b][color=#fde047]%s[/color][/b][/font_size]\n\n%s\n\n[color=#38bdf8]Objective:[/color] %s\n[color=#4ade80]Progress:[/color] %d / %d %s\n\n[color=#fbbf24]Rewards:[/color] %d Gold, %d EXP" % [
			quest.get("title", ""),
			quest.get("description", ""),
			quest.get("objective", ""),
			current_c,
			target_c,
			("[color=#22c55e]★ (Ready to complete!)[/color]" if is_ready else ""),
			rewards.get("money", 0),
			rewards.get("exp", 0)
		]
		quest_detail.text = text
