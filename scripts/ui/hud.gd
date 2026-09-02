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

var notification_timer: float = 0.0

func _ready() -> void:
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_stamina_changed.connect(_on_stamina_changed)
	EventBus.player_money_changed.connect(_on_money_changed)
	EventBus.time_changed.connect(_on_time_changed)
	EventBus.show_notification.connect(_on_show_notification)
	EventBus.player_leveled_up.connect(_on_leveled_up)
	EventBus.player_exp_gained.connect(_on_exp_gained)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	
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
		big_draw.set_anchors_preset(Control.PRESET_CENTER)
		big_draw.position = Vector2(300, 75)
		big_map.add_child(big_draw)
		
		# Close button on big map
		var close_btn := Button.new()
		close_btn.text = "Close Map [X]"
		close_btn.position = Vector2(680, 85)
		close_btn.pressed.connect(func(): big_map.visible = false)
		big_map.add_child(close_btn)
	
	if notification_label:
		notification_label.visible = false
	if interaction_hint:
		interaction_hint.visible = false

func _process(delta: float) -> void:
	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0 and notification_label:
			notification_label.visible = false

func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current

func _on_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
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
		notification_label.text = text
		notification_label.visible = true
		notification_timer = 3.0

func _on_leveled_up(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv. %d" % new_level
	_on_show_notification("Level Up! Now level %d" % new_level)

func _on_exp_gained(_amount: int, total: int, required: int) -> void:
	if exp_bar:
		exp_bar.max_value = required
		exp_bar.value = total

func _on_interaction_available(_interactable: Node) -> void:
	if interaction_hint:
		interaction_hint.visible = true
		interaction_hint.text = "[F] Interact"

func _on_interaction_unavailable() -> void:
	if interaction_hint:
		interaction_hint.visible = false
