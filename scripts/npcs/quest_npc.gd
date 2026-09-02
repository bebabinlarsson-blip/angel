class_name QuestNPC
extends StaticBody2D

@export var npc_name: String = "Villager"
@export var npc_id: String = "villager"
@export var quest_id: String = ""
@export var greeting_text: String = "Hello, traveler!"
@export var quest_offer_text: String = "I have a task for you."
@export var quest_active_text: String = "How's the task going?"
@export var quest_complete_text: String = "Wonderful! Here's your reward."
@export var quest_done_text: String = "Thank you for your help!"

@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var dialogue_panel: Panel = get_node_or_null("DialoguePanel")
@onready var dialogue_label: RichTextLabel = get_node_or_null("DialoguePanel/DialogueLabel")
@onready var accept_btn: Button = get_node_or_null("DialoguePanel/AcceptButton")
@onready var complete_btn: Button = get_node_or_null("DialoguePanel/CompleteButton")
@onready var close_btn: Button = get_node_or_null("DialoguePanel/CloseButton")
@onready var interaction_label: Label = get_node_or_null("InteractionLabel")

var quest_system: QuestSystem = null
var is_dialogue_open: bool = false
var visual: CustomDraw2D = null

func _ready() -> void:
	add_to_group("npcs")
	
	if name_label:
		name_label.text = npc_name
	
	if dialogue_panel == null:
		_create_dialogue_ui()
	else:
		dialogue_panel.visible = false
		if accept_btn: accept_btn.pressed.connect(_on_accept)
		if complete_btn: complete_btn.pressed.connect(_on_complete)
		if close_btn: close_btn.pressed.connect(_close_dialogue)
	
	if interaction_label:
		interaction_label.visible = false
	
	quest_system = _find_quest_system()

func _create_dialogue_ui() -> void:
	dialogue_panel = Panel.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.position = Vector2(-150, -220)
	dialogue_panel.custom_minimum_size = Vector2(300, 180)
	dialogue_panel.visible = false
	
	dialogue_label = RichTextLabel.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.position = Vector2(10, 10)
	dialogue_label.custom_minimum_size = Vector2(280, 110)
	dialogue_label.bbcode_enabled = true
	dialogue_panel.add_child(dialogue_label)
	
	accept_btn = Button.new()
	accept_btn.name = "AcceptButton"
	accept_btn.text = "Accept Quest"
	accept_btn.position = Vector2(10, 135)
	accept_btn.custom_minimum_size = Vector2(100, 32)
	accept_btn.pressed.connect(_on_accept)
	dialogue_panel.add_child(accept_btn)
	
	complete_btn = Button.new()
	complete_btn.name = "CompleteButton"
	complete_btn.text = "Complete Quest"
	complete_btn.position = Vector2(10, 135)
	complete_btn.custom_minimum_size = Vector2(120, 32)
	complete_btn.pressed.connect(_on_complete)
	dialogue_panel.add_child(complete_btn)
	
	close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.position = Vector2(210, 135)
	close_btn.custom_minimum_size = Vector2(80, 32)
	close_btn.pressed.connect(_close_dialogue)
	dialogue_panel.add_child(close_btn)
	
	add_child(dialogue_panel)

func _find_quest_system() -> QuestSystem:
	var node := get_tree().root.find_child("QuestSystem", true, false)
	if node is QuestSystem:
		return node
	return null

func interact(_player: CharacterBody2D) -> void:
	if is_dialogue_open:
		_close_dialogue()
		return
	
	is_dialogue_open = true
	if dialogue_panel:
		dialogue_panel.visible = true
	
	if quest_system == null:
		quest_system = _find_quest_system()
	
	_update_dialogue()

func _update_dialogue() -> void:
	if quest_id.is_empty() or quest_system == null:
		_show_text(greeting_text)
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = false
		return
	
	if quest_system.is_quest_done(quest_id):
		_show_text(quest_done_text)
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = false
	elif quest_system.is_quest_complete(quest_id):
		_show_text(quest_complete_text)
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = true
	elif quest_system.is_quest_active(quest_id):
		var quest: Dictionary = quest_system.active_quests.get(quest_id, {})
		var progress := "%d/%d" % [quest.get("current_count", 0), quest.get("target_count", 1)]
		_show_text("%s\n\n[color=cyan]Current Progress: %s[/color]" % [quest_active_text, progress])
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = false
	else:
		_show_text(quest_offer_text)
		if accept_btn: accept_btn.visible = true
		if complete_btn: complete_btn.visible = false

func _show_text(text: String) -> void:
	if dialogue_label:
		dialogue_label.text = "[b][color=gold]%s:[/color][/b]\n%s" % [npc_name, text]

func _on_accept() -> void:
	if quest_system and not quest_id.is_empty():
		quest_system.accept_quest(quest_id)
		_update_dialogue()

func _on_complete() -> void:
	if quest_system and not quest_id.is_empty():
		quest_system.try_complete_quest(quest_id)
		_update_dialogue()

func _close_dialogue() -> void:
	is_dialogue_open = false
	if dialogue_panel:
		dialogue_panel.visible = false

func show_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = true
		interaction_label.text = "[F] Talk"

func hide_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = false
