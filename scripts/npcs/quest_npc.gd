class_name QuestNPC
extends StaticBody2D

const NPC_PORTRAIT_SCRIPT = preload("res://scripts/ui/npc_portrait.gd")

@export var npc_name: String = "Villager"
@export var npc_id: String = "villager"
@export var quest_id: String = ""
@export var greeting_text: String = "Hello, traveler!"
@export var quest_offer_text: String = "I have a task for you."
@export var quest_active_text: String = "How's the task going?"
@export var quest_complete_text: String = "Wonderful! Here's your reward."
@export var quest_done_text: String = "Thank you for your help!"
@export_enum("idle", "farmer", "guard", "merchant", "fisher", "herbalist", "carpenter", "miner", "builder", "cook", "blacksmith", "traveler") var job: String = "idle"
@export_enum("female", "male", "androgynous") var gender: String = "androgynous"
@export var appearance_seed: int = 0
@export var dialogue_lines: Array[String] = []
@export var affinity_friends: Array[String] = []
@export var affinity_rivals: Array[String] = []
@export var work_position: Vector2 = Vector2.ZERO
@export var work_speed: float = 42.0
@export var stays_in_village: bool = true
@export var village_boundary_margin: float = 26.0
@export var travel_route: Array[Vector2] = []
@export var trade_enabled: bool = false
@export_group("Schedule & Housing")
@export var assigned_house_door: Vector2 = Vector2.ZERO
@export var assigned_house_id: String = ""
@export var assigned_job_location: String = ""
@export var assigned_job_position: Vector2 = Vector2.ZERO
@export var is_sleeping: bool = false

var _original_collision_layer: int = 1
var _original_collision_mask: int = 1
var _collision_shape_node: CollisionShape2D = null
var _was_night_state: bool = false

var name_label: Label = null
var dialogue_panel: PanelContainer = null
var dialogue_label: RichTextLabel = null
var accept_btn: Button = null
var complete_btn: Button = null
var next_dialogue_btn: Button = null
var trade_btn: Button = null
var buy_btn: Button = null
var sell_btn: Button = null
var close_btn: Button = null
var interaction_label: Label = null
var dialogue_layer: CanvasLayer = null

var quest_system: QuestSystem = null
var is_dialogue_open: bool = false
var _dialogue_player: Node2D = null
var sprite: AnimatedSprite2D = null
var facing_direction: String = "down"
var home_position: Vector2 = Vector2.ZERO
var schedule_destination: Vector2 = Vector2.ZERO
var activity: String = "Resting"
var is_working: bool = false
var routine_phase: String = ""
var routine_clock: float = 0.0
var interaction_count: int = 0
var velocity: Vector2 = Vector2.ZERO
var activity_label: Label = null
var work_cycle_index: int = 0
var village_center: Vector2 = Vector2.ZERO
var village_radius: float = 500.0
var _village_bounds_ready: bool = false
var personality: Dictionary = {}
var schedule_profile: Dictionary = {}
var ambient_event_id: String = ""
var ambient_event_label: String = ""
var ambient_event_action: String = ""
var ambient_event_role: String = ""
var ambient_event_target: Vector2 = Vector2.ZERO
var ambient_simulation_active: bool = true
var speech_label: Label = null
var ambient_speech_clock: float = 0.0
var travel_route_index: int = 0
var trade_open: bool = false

func _ready() -> void:
	# Dialogue is a modal screen-space UI, so the NPC must still receive Escape
	# while the gameplay tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("npcs")
	var bus := _get_event_bus()
	if bus and bus.has_signal("day_night_changed") and not bus.day_night_changed.is_connected(_on_day_night_changed):
		bus.day_night_changed.connect(_on_day_night_changed)
	if job == "idle":
		job = _job_from_npc_id()
	_build_ambient_profile()
	_bind_authored_miniature_model()
	_original_collision_layer = collision_layer if collision_layer > 0 else 1
	_original_collision_mask = collision_mask if collision_mask > 0 else 1
	_collision_shape_node = get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assign_default_housing_and_job()
	home_position = assigned_house_door if assigned_house_door != Vector2.ZERO else global_position
	if work_position == Vector2.ZERO:
		work_position = assigned_job_position
	var initial_hour := _get_game_time_hours()
	var starting_night := initial_hour >= 20.0 or initial_hour < 6.0
	_was_night_state = starting_night
	if starting_night:
		global_position = assigned_house_door
		_enter_sleep_state()
	call_deferred("_configure_village_bounds")
	
	if has_node("NameLabel"):
		name_label = get_node("NameLabel") as Label
		name_label.text = npc_name
		name_label.custom_minimum_size = Vector2(132, 18)
		name_label.position = Vector2(-66, -46)
		name_label.add_theme_font_size_override("font_size", 9)
		name_label.add_theme_constant_override("outline_size", 3)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.visible = false
	_create_activity_label()
	_create_speech_label()
	
	_create_dialogue_ui()
	
	if has_node("InteractionLabel"):
		interaction_label = get_node("InteractionLabel") as Label
		interaction_label.visible = false
	
	quest_system = _find_quest_system()

func _configure_village_bounds() -> void:
	if not stays_in_village:
		_village_bounds_ready = true
		return
	var terrain: IslandWorld = get_tree().get_first_node_in_group("island_world") as IslandWorld
	if terrain != null:
		village_center = terrain.village_center
		village_radius = terrain.village_radius
	global_position = _clamp_to_village(global_position)
	home_position = _clamp_to_village(home_position)
	work_position = _clamp_to_village(work_position)
	schedule_destination = _clamp_to_village(schedule_destination)
	_village_bounds_ready = true

func _clamp_to_village(target_position: Vector2) -> Vector2:
	if not stays_in_village:
		return target_position
	var offset: Vector2 = target_position - village_center
	var allowed_radius: float = maxf(32.0, village_radius - village_boundary_margin)
	if offset.length_squared() <= allowed_radius * allowed_radius:
		return target_position
	if offset.length_squared() <= 0.001:
		return village_center
	return village_center + offset.normalized() * allowed_radius

func _job_from_npc_id() -> String:
	match npc_id:
		"cook", "chef": return "cook"
		"elder": return "guard"
		"carpenter": return "carpenter"
		"miner": return "miner"
		"blacksmith": return "blacksmith"
		"traveler": return "traveler"
		_: return "idle"

func _build_ambient_profile() -> void:
	var profile_rng := RandomNumberGenerator.new()
	var seed_value: int = abs((npc_id + ":" + npc_name).hash()) + appearance_seed * 97 + 17
	profile_rng.seed = seed_value
	if gender == "androgynous":
		gender = "female" if seed_value % 2 == 0 else "male"
	personality = {
		"social": profile_rng.randf_range(0.28, 0.92),
		"shy": profile_rng.randf_range(0.18, 0.78),
		"hardworking": profile_rng.randf_range(0.36, 0.92),
		"lazy": profile_rng.randf_range(0.12, 0.58),
		"curious": profile_rng.randf_range(0.25, 0.88),
		"serious": profile_rng.randf_range(0.18, 0.78),
		"adventurous": profile_rng.randf_range(0.22, 0.84),
		"friendly": profile_rng.randf_range(0.35, 0.94),
		"grumpy": profile_rng.randf_range(0.10, 0.62),
		"spiritual": profile_rng.randf_range(0.14, 0.76),
		"night_owl": profile_rng.randf_range(0.12, 0.76),
		"early_riser": profile_rng.randf_range(0.16, 0.82)
	}
	match job:
		"farmer", "miner", "carpenter", "builder", "blacksmith":
			personality["hardworking"] = minf(1.0, float(personality["hardworking"]) + 0.16)
		"merchant", "traveler", "fisher":
			personality["adventurous"] = minf(1.0, float(personality["adventurous"]) + 0.14)
		"guard":
			personality["serious"] = minf(1.0, float(personality["serious"]) + 0.18)
		"cook", "herbalist":
			personality["friendly"] = minf(1.0, float(personality["friendly"]) + 0.12)
	var wake_hour := 6.0 + profile_rng.randf_range(-0.65, 0.65)
	var sleep_hour := 22.0 + profile_rng.randf_range(-0.65, 0.75)
	if float(personality["night_owl"]) > 0.62:
		wake_hour += 0.75
		sleep_hour += 0.85
	if float(personality["early_riser"]) > 0.68:
		wake_hour -= 0.8
		sleep_hour -= 0.45
	schedule_profile = {
		"wake_hour": fposmod(wake_hour, 24.0),
		"sleep_hour": clampf(sleep_hour, 20.5, 24.0),
		"work_start": 8.0 + profile_rng.randf_range(-0.45, 0.55),
		"work_end": 17.0 + profile_rng.randf_range(-0.55, 0.55),
		"phase_offset": profile_rng.randf_range(-0.28, 0.28)
	}

func _bind_authored_miniature_model() -> void:
	# NPC visuals are authored in the packed scene. Runtime logic may start an
	# existing animation, but it never creates a model, picks a sprite sheet, or
	# applies a procedural tint. This keeps every NPC inspectable in Godot's
	# scene tree and prevents invisible/script-only NPCs from being spawned.
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		push_warning("QuestNPC %s is missing its scene-authored AnimatedSprite2D." % npc_id)
		return
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.visible = true
	if sprite.sprite_frames == null:
		push_warning("QuestNPC %s has no scene-authored SpriteFrames resource." % npc_id)
		return
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func get_ambient_personality_value(key: String) -> float:
	if personality.is_empty():
		_build_ambient_profile()
	return clampf(float(personality.get(key, 0.5)), 0.0, 1.0)

func get_ambient_event_join_score(event_id: String) -> float:
	var score := 0.32
	score += get_ambient_personality_value("social") * 0.34
	score += get_ambient_personality_value("friendly") * 0.16
	score -= get_ambient_personality_value("shy") * 0.18
	if event_id.find("ritual") >= 0 or event_id.find("mourning") >= 0:
		score += get_ambient_personality_value("spiritual") * 0.28
	if event_id.find("strange") >= 0:
		score += get_ambient_personality_value("curious") * 0.30
	if event_id.find("work") >= 0:
		score += get_ambient_personality_value("hardworking") * 0.18
	if event_id.find("dance") >= 0 or event_id.find("game") >= 0:
		score += get_ambient_personality_value("adventurous") * 0.14
	if routine_phase == "sleep":
		score -= 0.42
	return clampf(score, 0.05, 0.98)

func get_ambient_affinity_to(other: QuestNPC) -> float:
	if other == null or other == self:
		return 0.0
	var affinity := 0.22 + get_ambient_personality_value("friendly") * 0.28
	if other.npc_id in affinity_friends:
		affinity += 0.34
	if other.npc_id in affinity_rivals:
		affinity -= 0.30
	if job == other.job:
		affinity += 0.18
	var pair_seed: int = abs((npc_id + "|" + other.npc_id).hash()) % 100
	affinity += float(pair_seed) / 100.0 * 0.18
	return clampf(affinity, 0.0, 1.0)

func has_ambient_event() -> bool:
	return not ambient_event_id.is_empty()

func set_ambient_simulation_active(active: bool) -> void:
	ambient_simulation_active = active
	if not active:
		if activity_label:
			activity_label.visible = false
		if name_label:
			name_label.visible = false
	# Far NPCs keep their SpriteFrames animation but stop running schedule,
	# label and path logic every frame. Dialogue and active events always wake
	# the script back up.
	set_process(active or is_dialogue_open)

func begin_ambient_event(event_id: String, label: String, target: Vector2, action: String, role: String) -> void:
	ambient_event_id = event_id
	ambient_event_label = label
	ambient_event_action = action
	ambient_event_role = role
	ambient_event_target = _clamp_to_village(target)
	schedule_destination = ambient_event_target
	routine_phase = "ambient"
	routine_clock = 0.0
	velocity = Vector2.ZERO
	is_working = false
	activity = label
	set_ambient_simulation_active(true)

func end_ambient_event() -> void:
	ambient_event_id = ""
	ambient_event_label = ""
	ambient_event_action = ""
	ambient_event_role = ""
	ambient_event_target = Vector2.ZERO
	routine_phase = ""
	routine_clock = 0.0
	activity = "Resting"
	if sprite != null:
		sprite.rotation = 0.0
	set_process(ambient_simulation_active or is_dialogue_open)

func _create_activity_label() -> void:
	activity_label = Label.new()
	activity_label.name = "ActivityLabel"
	activity_label.custom_minimum_size = Vector2(150, 18)
	activity_label.position = Vector2(-75, -78)
	activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	activity_label.visible = false
	activity_label.add_theme_color_override("font_color", Color("#b8d7c0"))
	activity_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.92))
	activity_label.add_theme_constant_override("outline_size", 3)
	activity_label.add_theme_font_size_override("font_size", 11)
	add_child(activity_label)

func _create_speech_label() -> void:
	speech_label = Label.new()
	speech_label.name = "SpeechLabel"
	speech_label.custom_minimum_size = Vector2(190, 22)
	speech_label.position = Vector2(-95, -105)
	speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speech_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speech_label.visible = false
	speech_label.add_theme_color_override("font_color", Color("#fff3c4"))
	speech_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.06, 0.95))
	speech_label.add_theme_constant_override("outline_size", 4)
	speech_label.add_theme_font_size_override("font_size", 10)
	add_child(speech_label)

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
	else:
		var generated_frame := PanelContainer.new()
		var generated_style := StyleBoxFlat.new()
		generated_style.bg_color = Color(0.12, 0.15, 0.22, 1.0)
		generated_style.border_color = Color(0.95, 0.75, 0.35, 0.8)
		generated_style.set_border_width_all(2)
		generated_style.set_corner_radius_all(6)
		generated_frame.add_theme_stylebox_override("panel", generated_style)

		var generated_portrait := NPC_PORTRAIT_SCRIPT.new() as Control
		generated_portrait.set("npc_id", portrait_id)
		generated_portrait.set("job", job)
		generated_portrait.custom_minimum_size = Vector2(76, 76)
		generated_portrait.size = Vector2(76, 76)
		generated_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		generated_frame.add_child(generated_portrait)
		content_row.add_child(generated_frame)

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

	trade_btn = Button.new()
	trade_btn.name = "TradeButton"
	trade_btn.text = "Trade"
	trade_btn.custom_minimum_size = Vector2(92, 34)
	trade_btn.pressed.connect(_on_trade)
	btn_row.add_child(trade_btn)

	buy_btn = Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(125, 34)
	buy_btn.pressed.connect(_on_buy_trade)
	btn_row.add_child(buy_btn)

	sell_btn = Button.new()
	sell_btn.name = "SellButton"
	sell_btn.text = "Sell"
	sell_btn.custom_minimum_size = Vector2(125, 34)
	sell_btn.pressed.connect(_on_sell_trade)
	btn_row.add_child(sell_btn)

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

func interact(player: CharacterBody2D) -> void:
	if is_dialogue_open:
		_close_dialogue()
		return
	if not can_talk():
		var bus := _get_event_bus()
		if bus and bus.has_signal("show_notification"):
			bus.show_notification.emit("%s is asleep. Come back after sunrise." % npc_name)
		return
	
	for overlay_name: String in ["BigMap", "InventoryUI", "QuestMenu", "PauseMenu", "CookingUILayer", "FastTravelLayer"]:
		_hide_overlay(overlay_name)
	is_dialogue_open = true
	trade_open = false
	_dialogue_player = player
	interaction_count += 1
	if dialogue_panel:
		dialogue_panel.visible = true
		UIAnim.pop_in(dialogue_panel, 0.18)
	
	if quest_system == null:
		quest_system = _find_quest_system()
	
	get_tree().paused = true
	var gm := _get_game_manager()
	if gm and "is_paused" in gm:
		gm.is_paused = true
	_update_dialogue()

func _process(delta: float) -> void:
	if not ambient_simulation_active and not is_dialogue_open:
		return
	if stays_in_village and not _village_bounds_ready:
		_configure_village_bounds()
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
	if not is_dialogue_open and not get_tree().paused:
		if has_ambient_event():
			_run_ambient_event_routine(delta)
		else:
			_run_daily_routine(delta)
	_update_facing()
	_update_activity_label()
	_update_speech_bubble(delta)

func _run_ambient_event_routine(delta: float) -> void:
	if ambient_event_target == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	if stays_in_village:
		ambient_event_target = _clamp_to_village(ambient_event_target)
	var distance := global_position.distance_to(ambient_event_target)
	if distance > 8.0:
		velocity = (ambient_event_target - global_position).normalized() * work_speed
		global_position = _clamp_to_village(global_position + velocity * delta)
		is_working = false
		return
	velocity = Vector2.ZERO
	routine_clock += delta
	# Existing 32px SpriteFrames are reused for every event. Action text and
	# facing changes communicate the social behavior without spawning costly
	# animation graphs or physics bodies.
	is_working = ambient_event_action in ["investigating", "sheltering"]
	if ambient_event_action == "dancing" and sprite != null:
		sprite.rotation = sin(routine_clock * 5.0) * 0.06
	else:
		if sprite != null:
			sprite.rotation = move_toward(sprite.rotation, 0.0, delta * 0.8)

func _update_facing() -> void:
	if is_sleeping or not visible:
		return
	if is_dialogue_open and _dialogue_player and is_instance_valid(_dialogue_player):
		var to_player: Vector2 = (_dialogue_player as Node2D).global_position - global_position
		if absf(to_player.x) > absf(to_player.y):
			facing_direction = "right" if to_player.x > 0 else "left"
		else:
			facing_direction = "down" if to_player.y > 0 else "up"
	elif has_ambient_event() and ambient_event_target != Vector2.ZERO:
		var to_event: Vector2 = ambient_event_target - global_position
		if to_event.length_squared() > 36.0:
			if absf(to_event.x) > absf(to_event.y):
				facing_direction = "right" if to_event.x > 0 else "left"
			else:
				facing_direction = "down" if to_event.y > 0 else "up"
	elif velocity.length_squared() > 4.0:
		if absf(velocity.x) > absf(velocity.y):
			facing_direction = "right" if velocity.x > 0 else "left"
		else:
			facing_direction = "down" if velocity.y > 0 else "up"
	elif _get_player_node() != null:
		var p := _get_player_node()
		var dist_sq: float = global_position.distance_squared_to(p.global_position)
		if dist_sq < 6400.0: # within 80px
			var to_player: Vector2 = p.global_position - global_position
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
		"carpenter", "builder", "blacksmith": return Vector2(120, 70)
		"miner": return Vector2(96, 48)
		"cook": return Vector2(-30, 58)
		"traveler": return Vector2(210, -80)
		_: return home_position

func _schedule_phase_for_hour(hour: float) -> String:
	if schedule_profile.is_empty():
		_build_ambient_profile()
	var local_hour := fposmod(hour + float(schedule_profile.get("phase_offset", 0.0)), 24.0)
	var wake_hour := float(schedule_profile.get("wake_hour", 6.0))
	var sleep_hour := float(schedule_profile.get("sleep_hour", 22.0))
	if local_hour < wake_hour or local_hour >= sleep_hour:
		return "sleep"
	if local_hour >= float(schedule_profile.get("work_start", 8.0)) and local_hour < float(schedule_profile.get("work_end", 17.0)):
		return "work"
	return "social"

func _get_game_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	return get_node_or_null("/root/GameManager")

func _get_event_bus() -> Node:
	if Engine.is_editor_hint():
		return null
	return get_node_or_null("/root/EventBus")

func _get_player_node() -> CharacterBody2D:
	var gm := _get_game_manager()
	if gm != null and "player" in gm and is_instance_valid(gm.player):
		return gm.player as CharacterBody2D
	return null

func _get_game_time_hours() -> float:
	var gm := _get_game_manager()
	if gm != null and "game_time_hours" in gm:
		return float(gm.game_time_hours)
	return 8.0

func _enter_sleep_state() -> void:
	is_sleeping = true
	visible = false
	if sprite != null:
		sprite.visible = false
	collision_layer = 0
	collision_mask = 0
	if _collision_shape_node != null and is_instance_valid(_collision_shape_node):
		_collision_shape_node.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	is_working = false
	activity = "Sleeping"
	routine_phase = "sleep"
	if activity_label != null:
		activity_label.visible = false
	if speech_label != null:
		speech_label.visible = false
	if interaction_label != null:
		interaction_label.visible = false
	if is_dialogue_open:
		_close_dialogue()

func _wake_from_sleep_state() -> void:
	is_sleeping = false
	global_position = assigned_house_door
	visible = true
	if sprite != null:
		sprite.visible = true
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")
	collision_layer = _original_collision_layer
	collision_mask = _original_collision_mask
	if _collision_shape_node != null and is_instance_valid(_collision_shape_node):
		_collision_shape_node.set_deferred("disabled", false)
	routine_phase = "day"
	schedule_destination = assigned_job_position
	work_cycle_index = 0
	routine_clock = 0.0
	activity = _job_activity()

func _run_daily_routine(delta: float) -> void:
	var hour := _get_game_time_hours()
	var is_night_now := hour >= 20.0 or hour < 6.0

	# Day/Night transition detection
	if is_night_now != _was_night_state:
		_was_night_state = is_night_now
		if not is_night_now:
			_wake_from_sleep_state()
		else:
			if is_dialogue_open:
				_close_dialogue()
			trade_open = false
			schedule_destination = assigned_house_door
			activity = "Heading to bed"
			is_working = false

	# Night State (20:00 - 06:00):
	# NPCs pathfind to their assigned House door trigger.
	# Upon entering the trigger: Disable NPC sprite visibility and collision (sleeping).
	if is_night_now:
		if is_sleeping:
			velocity = Vector2.ZERO
			is_working = false
			return
		schedule_destination = assigned_house_door
		activity = "Heading to bed"
		var to_door := assigned_house_door - global_position
		var dist_to_door := to_door.length()
		if dist_to_door <= 24.0:
			global_position = assigned_house_door
			_enter_sleep_state()
			return
		velocity = to_door.normalized() * work_speed
		global_position += velocity * delta
		is_working = false
		return

	# Day State (06:00 - 20:00):
	# At 06:00: Enable visibility/collision at the door trigger and resume day pathing.
	# NPCs patrol and work at assigned job tiles (Market, Blacksmith, Shops, Plaza).
	if is_sleeping:
		_wake_from_sleep_state()

	routine_clock += delta
	if schedule_destination == Vector2.ZERO:
		schedule_destination = assigned_job_position

	var to_dest := schedule_destination - global_position
	var dist := to_dest.length()
	if dist > 16.0:
		velocity = to_dest.normalized() * work_speed
		global_position += velocity * delta
		is_working = false
	else:
		velocity = Vector2.ZERO
		is_working = true
		activity = _job_activity()
		if routine_clock >= 5.0:
			routine_clock = 0.0
			work_cycle_index += 1
			schedule_destination = assigned_job_position + _patrol_offset_for_job(work_cycle_index)

func _patrol_offset_for_job(cycle: int) -> Vector2:
	match assigned_job_location:
		"market":
			var offsets := [
				Vector2.ZERO,
				Vector2(0, -32),
				Vector2(32, -16),
				Vector2(32, 24),
				Vector2(0, 32),
				Vector2(-24, 0)
			]
			return offsets[cycle % offsets.size()]
		"blacksmith":
			var offsets := [
				Vector2.ZERO,
				Vector2(-32, 16),
				Vector2(-16, -24),
				Vector2(24, 0)
			]
			return offsets[cycle % offsets.size()]
		"general_shop", "armory_shop":
			var offsets := [
				Vector2.ZERO,
				Vector2(24, 0),
				Vector2(0, 24),
				Vector2(-24, 0)
			]
			return offsets[cycle % offsets.size()]
		"plaza":
			var angles := [0.0, PI * 0.5, PI, PI * 1.5]
			return Vector2(cos(angles[cycle % 4]), sin(angles[cycle % 4])) * 36.0
		_:
			var angle := float(cycle % 8) * (TAU / 8.0)
			return Vector2(cos(angle), sin(angle)) * 24.0

func _assign_default_housing_and_job() -> void:
	if assigned_house_door == Vector2.ZERO:
		match npc_id:
			"blacksmith", "carpenter", "builder":
				assigned_house_id = "house_5"
				assigned_house_door = Vector2(320, 160)
			"merchant", "trader", "apothecary", "herbalist":
				assigned_house_id = "house_6"
				assigned_house_door = Vector2(-352, 64)
			"cook", "farmer", "gardener":
				assigned_house_id = "house_2"
				assigned_house_door = Vector2(256, -256)
			"guard", "soldier", "watch", "miner":
				assigned_house_id = "house_3"
				assigned_house_door = Vector2(320, -32)
			"elder":
				assigned_house_id = "house_4"
				assigned_house_door = Vector2(0, 256)
			"traveler", "fisher":
				assigned_house_id = "house_1"
				assigned_house_door = Vector2(0, -288)
			_:
				var house_keys := ["house_1", "house_2", "house_3", "house_4", "house_5", "house_6"]
				var doors := [
					Vector2(0, -288),
					Vector2(256, -256),
					Vector2(320, -32),
					Vector2(0, 256),
					Vector2(320, 160),
					Vector2(-352, 64)
				]
				var h_idx: int = abs((npc_id + ":" + npc_name).hash()) % house_keys.size()
				assigned_house_id = house_keys[h_idx]
				assigned_house_door = doors[h_idx]

	if assigned_job_position == Vector2.ZERO or assigned_job_location.is_empty():
		match job:
			"blacksmith":
				assigned_job_location = "blacksmith"
				assigned_job_position = Vector2(224, 80)
			"carpenter", "builder":
				assigned_job_location = "blacksmith"
				assigned_job_position = Vector2(224, 110)
			"merchant", "farmer", "gardener", "fisher":
				assigned_job_location = "market"
				assigned_job_position = Vector2(-224, 0)
			"herbalist":
				assigned_job_location = "general_shop"
				assigned_job_position = Vector2(-224, -128)
			"guard":
				if npc_id in ["soldier", "watch"]:
					assigned_job_location = "armory_shop"
					assigned_job_position = Vector2(-224, 128)
				else:
					assigned_job_location = "plaza"
					assigned_job_position = Vector2(0, 0)
			"miner":
				assigned_job_location = "armory_shop"
				assigned_job_position = Vector2(-224, 140)
			"cook", "traveler":
				assigned_job_location = "plaza"
				assigned_job_position = Vector2(0, 0)
			_:
				assigned_job_location = "plaza"
				assigned_job_position = Vector2(0, 0)

func _update_activity_label() -> void:
	if activity_label == null:
		return
	if is_sleeping or not visible:
		activity_label.visible = false
		return
	var p := _get_player_node()
	var player_near := false
	if p != null and is_instance_valid(p):
		player_near = global_position.distance_squared_to(p.global_position) <= 57600.0
	activity_label.visible = player_near and not is_dialogue_open
	if name_label:
		name_label.visible = false
	activity_label.text = activity

func can_talk() -> bool:
	if is_sleeping or not visible:
		return false
	var hour := _get_game_time_hours()
	if hour >= 20.0 or hour < 6.0:
		return false
	return routine_phase != "sleep"

func _on_day_night_changed(is_night: bool) -> void:
	_was_night_state = is_night
	if is_night:
		if is_dialogue_open:
			_close_dialogue()
		trade_open = false
		if speech_label:
			speech_label.visible = false
		schedule_destination = assigned_house_door
		activity = "Heading to bed"
		is_working = false
	else:
		if is_sleeping:
			_wake_from_sleep_state()


func _job_activity() -> String:
	match job:
		"farmer": return "Tending the fields"
		"guard": return "Patrolling the village"
		"merchant": return "Sorting the market stall"
		"fisher": return "Fishing by the lake"
		"herbalist": return "Gathering medicinal herbs"
		"carpenter", "builder": return "Building and repairing"
		"blacksmith": return "Forging and sharpening"
		"miner": return "Working the quarry"
		"cook": return "Preparing the evening meal"
		"traveler": return "Planning the next journey"
		_: return "Working"

func _update_dialogue() -> void:
	if trade_open:
		_show_trade_options()
		return
	_update_trade_buttons(false)
	if quest_id.is_empty() or quest_system == null:
		_show_text(_get_dynamic_dialogue())
		if accept_btn: accept_btn.visible = false
		if complete_btn: complete_btn.visible = false
		if next_dialogue_btn: next_dialogue_btn.visible = true
		return
	if next_dialogue_btn: next_dialogue_btn.visible = true
	
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
		if quest_system.has_active_other_than(quest_id):
			_show_text("A different quest is already active. Finish it before taking this one.\n\n[color=#9fb6c5]%s[/color]" % activity)
			if accept_btn: accept_btn.visible = false
		else:
			_show_text("%s\n\n[color=#9fb6c5]%s[/color]" % [quest_offer_text, activity])
			if accept_btn: accept_btn.visible = true
		if complete_btn: complete_btn.visible = false

func _show_text(text: String) -> void:
	if dialogue_label:
		dialogue_label.text = "[b][color=gold]%s:[/color][/b]\n%s" % [npc_name, text]

func _get_dynamic_dialogue() -> String:
	var lines: Array[String] = []
	for line in dialogue_lines:
		if not lines.has(line):
			lines.append(line)
	for line in _default_dialogue_lines():
		if not lines.has(line):
			lines.append(line)
	if lines.is_empty():
		return greeting_text
	var hour := _get_game_time_hours()
	var index := (interaction_count + int(hour / 4.0)) % lines.size()
	return lines[index] + "\n\n[color=#9fb6c5]" + activity + "[/color]"

func _default_dialogue_lines() -> Array[String]:
	match job:
		"farmer": return ["The soil is good this year, but the western field needs water.", "I saw fresh tracks beyond the hedgerow.", "Suri and I trade seed ideas when the wind is calm.", "A patient hand grows better food than a hurried one."]
		"guard": return ["The village is safest when everyone watches the quiet places.", "I patrol the open ground at first light.", "Rook marks the eastern edge while I check the square.", "If you hear a bell, find a soldier before drawing steel."]
		"merchant": return ["Rare crystals fetch a good price in distant markets.", "Bring me anything unusual and I will name a fair price.", "A good bargain leaves both people able to smile.", "Travelers carry stories that sell better than trinkets."]
		"fisher": return ["The lake is calm today. Big fish hide near the reeds.", "The moon changes the best fishing spot.", "I follow the water when I need a clear thought.", "Mira's rule is simple: never waste a quiet morning."]
		"herbalist": return ["Moon petals open after sunset and make strong medicine.", "Wild berries grow where the ground stays cool.", "Plants tell you when they are ready if you stop rushing.", "Elin keeps notes on every useful leaf she finds."]
		"carpenter", "builder": return ["Every repair keeps one more family safe through storm season.", "The village grows one careful beam at a time.", "Measure twice, then ask someone else to check.", "Loose boards make loud warnings before they make disasters."]
		"miner": return ["Iron veins still appear in the hills beyond the village.", "A good pick and a steady lamp solve many problems.", "I can read old stone by the way it catches rain.", "The safest ore is the ore you can reach without a cave."]
		"cook": return ["A warm meal brings people together after a long day.", "Berry and mushroom stew needs less salt than you think.", "Maria trusts hungry travelers more than fancy recipes.", "Come back near supper if you want an honest opinion."]
		"traveler": return ["Every path looks different after rain.", "I trade small goods for the stories that come with them.", "The next village is farther than it looks on a clear day.", "I keep moving because every horizon has one more answer."]
		_: return [greeting_text, "The village feels different when you slow down.", "I noticed new footprints near the open ground.", "Come back later; I may remember another story."]

func _update_trade_buttons(show_trade: bool) -> void:
	var available := trade_enabled or job in ["merchant", "traveler"]
	if trade_btn:
		trade_btn.visible = available and not show_trade
	if buy_btn:
		buy_btn.visible = available and show_trade
	if sell_btn:
		sell_btn.visible = available and show_trade
	if accept_btn and show_trade:
		accept_btn.visible = false
	if complete_btn and show_trade:
		complete_btn.visible = false
	if next_dialogue_btn and show_trade:
		next_dialogue_btn.visible = false

func _trade_offers() -> Array[Dictionary]:
	if job == "traveler":
		return [
			{"id": "herb", "name": "Wild Herb", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 1, "stackable": true, "price": 12},
			{"id": "mushroom", "name": "Moon Mushroom", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 1, "stackable": true, "price": 18},
			{"id": "stamina_tonic", "name": "Stamina Tonic", "type": PlayerInventory.ItemType.POTION, "quantity": 1, "stackable": true, "stamina_restore": 25, "heal": 15, "price": 28},
		]
	return [
		{"id": "wood", "name": "Crafting Wood", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 1, "stackable": true, "price": 8},
		{"id": "herb", "name": "Fresh Herb", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 1, "stackable": true, "price": 10},
		{"id": "stamina_tonic", "name": "Stamina Tonic", "type": PlayerInventory.ItemType.POTION, "quantity": 1, "stackable": true, "stamina_restore": 25, "heal": 15, "price": 24},
	]

func _show_trade_options() -> void:
	_update_trade_buttons(true)
	var offers := _trade_offers()
	var names: Array[String] = []
	for offer: Dictionary in offers:
		names.append("%s: %dg" % [str(offer.get("name", "Item")), int(offer.get("price", 0))])
	_show_text("I carry:\n%s\n\nBuy one item or sell one material from your pack.\nGold: %d" % ["\n".join(names), _player_gold()])
	if buy_btn:
		buy_btn.text = "Buy %s" % str(offers[0].get("name", "Item"))
	if sell_btn:
		sell_btn.text = "Sell material"

func _on_trade() -> void:
	if not can_talk():
		return
	trade_open = true
	_show_trade_options()

func _on_buy_trade() -> void:
	var player := _get_player_node()
	if player == null or not is_instance_valid(player) or player.inventory == null or player.stats == null:
		return
	var offer: Dictionary = _trade_offers()[0]
	var price := int(offer.get("price", 0))
	if _player_gold() < price:
		_show_text("You need %d gold. Come back after a good haul." % price)
		return
	if not player.inventory.can_add_item(offer):
		_show_text("Your pack is full.")
		return
	player.stats.add_money(-price)
	player.inventory.add_item(offer)
	_show_text("One %s, neatly packed. Gold left: %d" % [str(offer.get("name", "item")), _player_gold()])

func _on_sell_trade() -> void:
	var player := _get_player_node()
	if player == null or not is_instance_valid(player) or player.inventory == null or player.stats == null:
		return
	for item: Dictionary in player.inventory.items:
		var item_type := int(item.get("type", -1))
		if item_type != PlayerInventory.ItemType.MATERIAL:
			continue
		var item_id := str(item.get("id", ""))
		if item_id.is_empty() or not player.inventory.remove_item(item_id, 1):
			continue
		var value := maxi(2, int(item.get("sell_price", 6)))
		player.stats.add_money(value)
		_show_text("Sold one %s for %d gold. Gold: %d" % [str(item.get("name", item_id)), value, _player_gold()])
		return
	_show_text("Bring me a material and I will make an offer.")

func _player_gold() -> int:
	var player := _get_player_node()
	if player != null and is_instance_valid(player) and player.stats != null:
		return int(player.stats.money)
	return 0

func _update_speech_bubble(delta: float) -> void:
	if speech_label == null:
		return
	var h := _get_game_time_hours()
	var is_night_now := h >= 20.0 or h < 6.0
	if not has_ambient_event() or routine_phase == "sleep" or is_night_now:
		speech_label.visible = false
		return
	ambient_speech_clock += delta
	if ambient_speech_clock >= 4.0 or speech_label.text.is_empty():
		ambient_speech_clock = 0.0
		speech_label.text = _ambient_line_for_action()
	speech_label.visible = ambient_event_action in ["conversation", "laughing", "greeting", "arguing", "celebrating"]

func _ambient_line_for_action() -> String:
	match ambient_event_action:
		"laughing": return "Did you hear that?"
		"arguing": return "That was not my route!"
		"greeting": return "Good to see you."
		"celebrating": return "To another bright day!"
		_: return "The road was kinder today."

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
	var gm := _get_game_manager()
	if gm and int(gm.get("current_state")) == 1 and not _has_other_overlay():
		get_tree().paused = false
		gm.set("is_paused", false)

func _hide_overlay(node_name: String) -> void:
	var overlay := get_tree().root.find_child(node_name, true, false)
	if overlay is Control:
		(overlay as Control).visible = false
	elif overlay is CanvasLayer:
		(overlay as CanvasLayer).visible = false

func _has_other_overlay() -> bool:
	for node_name: String in ["BigMap", "InventoryUI", "QuestMenu", "PauseMenu", "CookingUILayer", "FastTravelLayer"]:
		var overlay := get_tree().root.find_child(node_name, true, false)
		if overlay is Control and (overlay as Control).visible:
			return true
		if overlay is CanvasLayer and (overlay as CanvasLayer).visible:
			return true
	return false

func show_interaction_hint() -> void:
	if is_sleeping or not visible or not can_talk():
		if interaction_label:
			interaction_label.visible = false
		return
	if interaction_label:
		interaction_label.visible = true
		interaction_label.text = "[F] Talk"

func hide_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = false
