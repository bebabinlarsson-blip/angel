extends Control

@onready var respawn_btn: Button = get_node_or_null("Panel/VBoxContainer/RespawnButton")
@onready var main_menu_btn: Button = get_node_or_null("Panel/VBoxContainer/MainMenuButton")
@onready var message_label: Label = get_node_or_null("Panel/VBoxContainer/MessageLabel")

func _ready() -> void:
	EventBus.player_died.connect(_on_player_died)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if respawn_btn:
		respawn_btn.pressed.connect(_on_respawn)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu)
	UITheme.style_recursive(self)

func _on_player_died() -> void:
	visible = true
	if message_label:
		message_label.text = "You have fallen...\nAll items and materials have been kept."
	var panel := get_node_or_null("Panel")
	if panel == null:
		panel = get_node_or_null("CenterContainer/PanelContainer")
	if panel is Control:
		UIAnim.pop_in(panel as Control, 0.3)

func _on_respawn() -> void:
	visible = false
	GameManager.respawn_player()

func _on_main_menu() -> void:
	visible = false
	GameManager.set_state(GameManager.GameState.PLAYING)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
