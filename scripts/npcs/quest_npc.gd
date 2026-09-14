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
@export_enum("idle", "farmer", "guard", "merchant", "fisher", "herbalist", "carpenter", "miner", "builder", "cook") var job: String = "idle"
@export var dialogue_lines: Array[String] = []
@export var work_position: Vector2 = Vector2.ZERO
@export var work_speed: float = 42.0

var name_label: Label = null
var dialogue_panel: PanelContainer = null
var dialogue_label: RichTextLabel = null
var accept_btn: Button = null
var complete_btn: Button = null
var next_dialogue_btn: Button = null
var close_btn: Button = null
var interaction_label: Label = null
var dialogue_layer: CanvasLayer = null

var quest_system: QuestSystem = null
var is_dialogue_open: bool = false
var visual: CustomDraw2D = null
var _dialogue_player: Node2D = null
var sprite: AnimatedSprite2D = null
var facing_direction: String = "down"
var worker_tool: WorkerTool = null
var home_position: Vector2 = Vector2.ZERO
var schedule_destination: Vector2 = Vector2.ZERO
var activity: String = "Resting"
var is_working: bool = false
var routine_phase: String = ""
var routine_clock: float = 0.0
var interaction_count: int = 0
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("npcs")
	if job == "idle":
		job = _job_from_npc_id()
	home_position = global_position
	if work_position == Vector2.ZERO:
		work_position = home_position + _default_work_offset()
	
	if has_node("NameLabel"):
		name_label = get_node("NameLabel") as Label
		name_label.text = npc_name
	
	_create_dialogue_ui()
	
	if has_node("InteractionLabel"):
		interaction_label = get_node("InteractionLabel") as Label
		interaction_label.visible = false
	
	quest_system = _find_quest_system()
	worker_tool = WorkerTool.new()
	worker_tool.name = "WorkerTool"
	worker_tool.job = job
	worker_tool.position = Vector2(0, -10)
	worker_tool.z_index = 6
	worker_tool.visible = false
	add_child(worker_tool)

func _job_from_npc_id() -> String:
	match npc_id:
		"cook", "chef": return "cook"
		"elder": return "guard"
		"carpenter": return "carpenter"
		"miner": return "miner"
		_: return "idle"

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

	next_dialogue_btn = Button.new()
	next_dialogue_btn.name = "NextDialogueButton"
	next_dialogue_btn.text = "Ask more"
	next_dialogue_btn.custom_minimum_size = Vector2(105, 34)
	next_dialogue_btn.pressed.connect(_on_next_dialogue)
	btn_row.add_child(next_dialogue_btn)

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
	interaction_count += 1
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

func _process(delta: float) -> void:
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
	if not is_dialogue_open:
		_run_daily_routine(delta)
	_update_facing()
	_update_worker_animation()

func _update_facing() -> void:
	if is_dialogue_open and _dialogue_player and is_instance_valid(_dialogue_player):
		var to_player: Vector2 = (_dialogue_player as Node2D).global_position - global_position
		if absf(to_player.x) > absf(to_player.y):
			facing_direction = "right" if to_player.x > 0 else "left"
		else:
			facing_direction = "down" if to_player.y > 0 else "up"
	elif velocity.length_squared() > 4.0:
		if absf(velocity.x) > absf(velocity.y):
			facing_direction = "right" if velocity.x > 0 else "left"
		else:
			facing_direction = "down" if velocity.y > 0 else "up"
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
		if velocity.length_squared() > 4.0:
			anim = "walk_" + facing_direction
		elif is_working:
			anim = "attack_" + facing_direction
		if sprite.sprite_frames.has_animation(anim):
			if sprite.animation != anim:
				sprite.play(anim)
		elif is_working and sprite.sprite_frames.has_animation("attack"):
			if sprite.animation != "attack":
				sprite.play("attack")
		elif velocity.length_squared() > 4.0 and sprite.sprite_frames.has_animation("walk"):
			if sprite.animation != "walk":
				sprite.play("walk")
		elif sprite.sprite_frames.has_animation("idle"):
			if sprite.animation != "idle":
				sprite.play("idle")

func _default_work_offset() -> Vector2:
	match job:
		"farmer": return Vector2(180, 90)
		"guard": return Vector2(0, -190)
		"merchant": return Vector2(-120, 70)
		"fisher": return Vector2(170, 210)
		"herbalist": return Vector2(-190, 180)
		"carpenter", "builder": return Vector2(120, 70)
		"miner": return Vector2(96, 48)
		"cook": return Vector2(-30, 58)
		_: return home_position

func _run_daily_routine(delta: float) -> void:
	if job == "idle":
		velocity = Vector2.ZERO
		activity = "Resting"
		is_working = false
		return
	var hour := GameManager.game_time_hours
	var new_phase := "sleep" if hour < 6.0 or hour >= 22.0 else ("work" if hour >= 8.0 and hour < 17.0 else "social")
	if new_phase != routine_phase:
		routine_phase = new_phase
		routine_clock = 0.0
		match routine_phase:
			"sleep":
				schedule_destination = home_position
				activity = "Sleeping"
			"work":
				schedule_destination = work_position
				activity = _job_activity()
			"social":
				schedule_destination = home_position.lerp(Vector2.ZERO, 0.72)
				activity = "At the village square"
	routine_clock += delta
	if global_position.distance_to(schedule_destination) > 8.0:
		var travel := (schedule_destination - global_position).normalized()
		velocity = travel * work_speed
		is_working = false
		global_position += velocity * delta
	else:
		velocity = Vector2.ZERO
		is_working = routine_phase == "work"
		# Working animations have a gentle cadence so every villager visibly acts.
		if is_working and routine_clock > 4.0:
			routine_clock = 0.0

func _job_activity() -> String:
	match job:
		"farmer": return "Tending the fields"
		"guard": return "Patrolling the village"
		"merchant": return "Sorting the market stall"
		"fisher": return "Fishing by the lake"
		"herbalist": return "Gathering medicinal herbs"
		"carpenter", "builder": return "Building and repairing"
		"miner": return "Working the quarry"
		"cook": return "Preparing the evening meal"
		_: return "Working"

func _update_worker_animation() -> void:
	if worker_tool:
		worker_tool.active = is_working
	if name_label and not npc_name.is_empty():
		name_label.text = npc_name + ("\n" + activity if is_working else "")

func _update_dialogue() -> void:
	if quest_id.is_empty() or quest_system == null:
		_show_text(_get_dynamic_dialogue())
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = false
		if next_dialogue_btn: next_dialogue_btn.visible = true
		return
	if next_dialogue_btn: next_dialogue_btn.visible = false
	
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
		_show_text("%s\n\n[color=cyan]Current Progress: %s[/color]\n\n[color=#9fb6c5]%s[/color]" % [quest_active_text, progress, activity])
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = false
	else:
		_show_text("%s\n\n[color=#9fb6c5]%s[/color]" % [quest_offer_text, activity])
		if accept_btn: accept_btn.visible = true
		if complete_btn: complete_btn.visible = false

func _show_text(text: String) -> void:
	if dialogue_label:
		dialogue_label.text = "[b][color=gold]%s:[/color][/b]\n%s" % [npc_name, text]

func _get_dynamic_dialogue() -> String:
	var lines := dialogue_lines
	if lines.is_empty():
		lines = _default_dialogue_lines()
	if lines.is_empty():
		return greeting_text
	var hour := GameManager.game_time_hours
	var index := (interaction_count + int(hour / 4.0)) % lines.size()
	return lines[index] + "\n\n[color=#9fb6c5]" + activity + "[/color]"

func _default_dialogue_lines() -> Array[String]:
	match job:
		"farmer": return ["The soil is good this year, but the western field needs water.", "I saw fresh tracks beyond the hedgerow. Keep your sword ready."]
		"guard": return ["The night watch has been quiet so far. That usually means trouble is coming.", "I patrol the northern road every morning. The slimes are spreading."]
		"merchant": return ["Rare crystals fetch a good price in the capital.", "Bring me anything ancient-looking. Travelers love a mysterious souvenir."]
		"fisher": return ["The lake is calm today. The big fish hide near the reeds.", "If you find bright blue crystals, do not drop them in the water."]
		"herbalist": return ["Moon petals open after sunset. They make excellent medicine.", "Wild berries grow near the old stones, if the monsters have not eaten them first."]
		"carpenter", "builder": return ["Every repair keeps one more family safe through the storm season.", "The village grows one beam at a time. Bring me wood if you find any."]
		"miner": return ["The deeper veins are rich, but the crystal slimes guard them.", "A proper mine needs patience, a lantern and a sturdy pick."]
		"cook": return ["A warm meal brings people together after a long day.", "I am testing a berry-and-mushroom stew tonight. Do not tell the elder."]
		_: return [greeting_text]

func _on_accept() -> void:
	if quest_system and not quest_id.is_empty():
		quest_system.accept_quest(quest_id)
		_update_dialogue()

func _on_complete() -> void:
	if quest_system and not quest_id.is_empty():
		quest_system.try_complete_quest(quest_id)
		_update_dialogue()

func _on_next_dialogue() -> void:
	interaction_count += 1
	_show_text(_get_dynamic_dialogue())

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
