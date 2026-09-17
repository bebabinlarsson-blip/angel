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

func _ready() -> void:
	# Dialogue is a modal screen-space UI, so the NPC must still receive Escape
	# while the gameplay tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("npcs")
	if job == "idle":
		job = _job_from_npc_id()
	_build_ambient_profile()
	_bind_authored_miniature_model()
	home_position = global_position
	if work_position == Vector2.ZERO:
		work_position = home_position + _default_work_offset()
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
	var seed_value := abs((npc_id + ":" + npc_name).hash()) + appearance_seed * 97 + 17
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
	var pair_seed := abs((npc_id + "|" + other.npc_id).hash()) % 100
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
	
	for overlay_name: String in ["BigMap", "InventoryUI", "QuestMenu", "PauseMenu", "CookingUILayer", "FastTravelLayer"]:
		_hide_overlay(overlay_name)
	is_dialogue_open = true
	_dialogue_player = player
	interaction_count += 1
	if dialogue_panel:
		dialogue_panel.visible = true
		UIAnim.pop_in(dialogue_panel, 0.18)
	
	if quest_system == null:
		quest_system = _find_quest_system()
	
	get_tree().paused = true
	GameManager.is_paused = true
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
		"carpenter", "builder", "blacksmith": return Vector2(120, 70)
		"miner": return Vector2(96, 48)
		"cook": return Vector2(-30, 58)
		"traveler": return Vector2(210, -80)
		_: return home_position

func _schedule_phase_for_hour(hour: float) -> String:
	if schedule_profile.is_empty():
		_build_ambient_profile()
	var local_hour := fposmod(hour + float(schedule_profile.get("phase_offset", 0.0)), 24.0)
	# Guards have a deliberately different overnight shift instead of sharing
	# the same sleep/work boundaries as farmers and shopkeepers.
	if job == "guard" and (local_hour >= 18.0 or local_hour < 2.0):
		return "work"
	var wake_hour := float(schedule_profile.get("wake_hour", 6.0))
	var sleep_hour := float(schedule_profile.get("sleep_hour", 22.0))
	if local_hour < wake_hour or local_hour >= sleep_hour:
		return "sleep"
	if local_hour >= float(schedule_profile.get("work_start", 8.0)) and local_hour < float(schedule_profile.get("work_end", 17.0)):
		return "work"
	return "social"

func _run_daily_routine(delta: float) -> void:
	if job == "idle":
		velocity = Vector2.ZERO
		activity = "Resting"
		is_working = false
		return

	if stays_in_village:
		global_position = _clamp_to_village(global_position)
		home_position = _clamp_to_village(home_position)
		work_position = _clamp_to_village(work_position)
		schedule_destination = _clamp_to_village(schedule_destination)

	var hour := GameManager.game_time_hours
	var new_phase := _schedule_phase_for_hour(hour)
	if new_phase != routine_phase:
		routine_phase = new_phase
		routine_clock = 0.0
		work_cycle_index = 0
		match routine_phase:
			"sleep":
				schedule_destination = _clamp_to_village(home_position)
				activity = "Sleeping"
			"work":
				schedule_destination = _clamp_to_village(work_position)
				activity = _job_activity()
			"social":
				schedule_destination = _clamp_to_village(home_position.lerp(village_center, 0.72))
				activity = "At the village square"

	routine_clock += delta
	if global_position.distance_to(schedule_destination) > 8.0:
		var travel := (schedule_destination - global_position).normalized()
		velocity = travel * work_speed
		is_working = false
		global_position = _clamp_to_village(global_position + velocity * delta)
		return

	velocity = Vector2.ZERO
	is_working = routine_phase == "work"
	if is_working and routine_clock >= 4.5:
		routine_clock = 0.0
		work_cycle_index += 1
		schedule_destination = _clamp_to_village(work_position + _work_offset_for_cycle(work_cycle_index))
		is_working = false

func _work_offset_for_cycle(cycle: int) -> Vector2:
	var radius := 34.0
	match job:
		"farmer":
			radius = 88.0
		"guard":
			radius = 140.0
		"merchant", "carpenter", "builder":
			radius = 54.0
		"fisher":
			radius = 62.0
		"herbalist":
			radius = 76.0
		"miner":
			radius = 48.0
		"cook":
			radius = 30.0
		"traveler":
			radius = 110.0
	var angle := float(cycle) * 1.75
	return Vector2.RIGHT.rotated(angle) * radius

func _update_activity_label() -> void:
	if activity_label == null:
		return
	var player_near := false
	if GameManager.player and is_instance_valid(GameManager.player):
		player_near = global_position.distance_squared_to(GameManager.player.global_position) <= 57600.0
	activity_label.visible = player_near and not is_dialogue_open
	if name_label:
		# Names belong in the dialogue UI; keep the world view free of floating
		# nameplates so the miniature models read clearly in groups.
		name_label.visible = false
	activity_label.text = activity


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
	if GameManager.current_state == GameManager.GameState.PLAYING and not _has_other_overlay():
		get_tree().paused = false
		GameManager.is_paused = false

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
	if interaction_label:
		interaction_label.visible = true
		interaction_label.text = "[F] Talk"

func hide_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = false
