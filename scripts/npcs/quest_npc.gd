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

var name_label: Label = null
var dialogue_panel: PanelContainer = null
var dialogue_label: RichTextLabel = null
var accept_btn: Button = null
var complete_btn: Button = null
var close_btn: Button = null
var interaction_label: Label = null
var dialogue_layer: CanvasLayer = null

var quest_system: QuestSystem = null
var is_dialogue_open: bool = false
var visual: CustomDraw2D = null
var _dialogue_player: Node2D = null
var sprite: AnimatedSprite2D = null
var facing_direction: String = "down"

func _ready() -> void:
	add_to_group("npcs")
	
	if has_node("NameLabel"):
		name_label = get_node("NameLabel") as Label
		name_label.text = npc_name
	
	_create_dialogue_ui()
	
	if has_node("InteractionLabel"):
		interaction_label = get_node("InteractionLabel") as Label
		interaction_label.visible = false
	
	quest_system = _find_quest_system()

func _create_dialogue_ui() -> void:
	# Screen-space modal: the old world-space Panel drifted with the camera
	# and its hand-placed buttons only lined up at one exact panel size.
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.name = "DialogueLayer"
	dialogue_layer.layer = 60
	dialogue_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(dialogue_layer)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Let attack clicks pass through the empty screen area.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_layer.add_child(center)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.custom_minimum_size = Vector2(460, 220)
	dialogue_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.97)
	style.border_color = Color(0.95, 0.75, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	dialogue_panel.add_theme_stylebox_override("panel", style)
	center.add_child(dialogue_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	dialogue_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var content_row := HBoxContainer.new()
	content_row.name = "ContentRow"
	content_row.add_theme_constant_override("separation", 14)
	vbox.add_child(content_row)

	var portrait_id := npc_id if npc_id != "cook" else "chef"
	var portrait_path := "res://assets/sprites/actors/npc_%s/faceset.png" % portrait_id
	if ResourceLoader.exists(portrait_path):
		var port_frame := PanelContainer.new()
		var p_style := StyleBoxFlat.new()
		p_style.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		p_style.border_color = Color(0.95, 0.75, 0.35, 0.8)
		p_style.set_border_width_all(2)
		p_style.set_corner_radius_all(6)
		port_frame.add_theme_stylebox_override("panel", p_style)
		
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(76, 76)
		portrait.texture = load(portrait_path)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		port_frame.add_child(portrait)
		content_row.add_child(port_frame)

	dialogue_label = RichTextLabel.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.custom_minimum_size = Vector2(320, 110)
	dialogue_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label.bbcode_enabled = true
	dialogue_label.fit_content = true
	dialogue_label.scroll_active = false
	content_row.add_child(dialogue_label)

	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	accept_btn = Button.new()
	accept_btn.name = "AcceptButton"
	accept_btn.text = "Accept Quest"
	accept_btn.custom_minimum_size = Vector2(120, 34)
	accept_btn.pressed.connect(_on_accept)
	btn_row.add_child(accept_btn)

	complete_btn = Button.new()
	complete_btn.name = "CompleteButton"
	complete_btn.text = "Complete Quest"
	complete_btn.custom_minimum_size = Vector2(130, 34)
	complete_btn.pressed.connect(_on_complete)
	btn_row.add_child(complete_btn)

	close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(90, 34)
	close_btn.pressed.connect(_close_dialogue)
	btn_row.add_child(close_btn)

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
	_dialogue_player = _player
	if dialogue_panel:
		dialogue_panel.visible = true
		UIAnim.pop_in(dialogue_panel, 0.18)
	
	if quest_system == null:
		quest_system = _find_quest_system()
	
	_update_dialogue()

func _input(event: InputEvent) -> void:
	if is_dialogue_open:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			_close_dialogue()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite == null:
			for child in get_children():
				if child is AnimatedSprite2D:
					sprite = child
					break
	
	# Auto-close if the player walks away with the panel open.
	if is_dialogue_open and _dialogue_player and is_instance_valid(_dialogue_player):
		if (_dialogue_player as Node2D).global_position.distance_to(global_position) > 160.0:
			_close_dialogue()
	
	_update_facing()

func _update_facing() -> void:
	if is_dialogue_open and _dialogue_player and is_instance_valid(_dialogue_player):
		var to_player: Vector2 = (_dialogue_player as Node2D).global_position - global_position
		if absf(to_player.x) > absf(to_player.y):
			facing_direction = "right" if to_player.x > 0 else "left"
		else:
			facing_direction = "down" if to_player.y > 0 else "up"
	elif GameManager.player and is_instance_valid(GameManager.player):
		var dist_sq: float = global_position.distance_squared_to(GameManager.player.global_position)
		if dist_sq < 6400.0: # within 80px
			var to_player: Vector2 = GameManager.player.global_position - global_position
			if absf(to_player.x) > absf(to_player.y):
				facing_direction = "right" if to_player.x > 0 else "left"
			else:
				facing_direction = "down" if to_player.y > 0 else "up"
		else:
			facing_direction = "down"
	else:
		facing_direction = "down"
	
	if sprite and sprite.sprite_frames:
		sprite.flip_h = false
		var anim := "idle_" + facing_direction
		if sprite.sprite_frames.has_animation(anim):
			if sprite.animation != anim:
				sprite.play(anim)
		elif sprite.sprite_frames.has_animation("idle"):
			if sprite.animation != "idle":
				sprite.play("idle")

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
	_dialogue_player = null
	if dialogue_panel:
		dialogue_panel.visible = false

func show_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = true
		interaction_label.text = "[F] Talk"

func hide_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = false
