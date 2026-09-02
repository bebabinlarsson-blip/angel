class_name CookingPot
extends StaticBody2D

@onready var interaction_label: Label = get_node_or_null("InteractionLabel")

var cooking_ui_layer: CanvasLayer = null
var recipe_list: VBoxContainer = null
var close_btn: Button = null
var cooking_system: CookingSystem = null
var visual: CustomDraw2D = null

func _ready() -> void:
	visual = get_node_or_null("CustomDraw2D") as CustomDraw2D
	if visual == null:
		visual = CustomDraw2D.new()
		visual.name = "CustomDraw2D"
		visual.entity_type = CustomDraw2D.EntityType.CAMPFIRE
		add_child(visual)
	
	_create_cooking_ui()
	
	if interaction_label:
		interaction_label.visible = false

func _create_cooking_ui() -> void:
	cooking_ui_layer = CanvasLayer.new()
	cooking_ui_layer.name = "CookingUILayer"
	cooking_ui_layer.layer = 50
	
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	cooking_ui_layer.add_child(root)
	
	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_close_cooking()
	)
	root.add_child(dimmer)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.96)
	style.border_color = Color(0.95, 0.65, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "CAMPFIRE HEARTH"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	header.add_child(title)
	
	close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(32, 32)
	close_btn.pressed.connect(_close_cooking)
	header.add_child(close_btn)
	vbox.add_child(header)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	recipe_list = VBoxContainer.new()
	recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_list.add_theme_constant_override("separation", 8)
	scroll.add_child(recipe_list)
	vbox.add_child(scroll)
	
	margin.add_child(vbox)
	panel.add_child(margin)
	center.add_child(panel)
	
	add_child(cooking_ui_layer)
	cooking_ui_layer.visible = false

func interact(player: CharacterBody2D) -> void:
	cooking_system = get_tree().root.find_child("CookingSystem", true, false) as CookingSystem
	if cooking_system == null:
		EventBus.show_notification.emit("No cooking system found!")
		return
	
	if cooking_ui_layer == null:
		_create_cooking_ui()
	
	cooking_ui_layer.visible = !cooking_ui_layer.visible
	if cooking_ui_layer.visible:
		_refresh_recipes(player)

func _refresh_recipes(player: CharacterBody2D) -> void:
	if recipe_list == null or cooking_system == null:
		return
	
	for child in recipe_list.get_children():
		child.queue_free()
	
	var recipes := cooking_system.get_available_recipes(player.inventory)
	for recipe in recipes:
		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(360, 36)
		
		var label := Label.new()
		var ingredients_text := ""
		for item_id in recipe.get("ingredients", {}):
			if ingredients_text != "":
				ingredients_text += ", "
			var has_qty: int = player.inventory.get_item_count(item_id)
			var req_qty: int = recipe["ingredients"][item_id]
			ingredients_text += "%s (%d/%d)" % [item_id, has_qty, req_qty]
		
		label.text = "%s\n[%s]" % [recipe.get("name", "???"), ingredients_text]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		var cook_btn := Button.new()
		cook_btn.text = "Cook" if recipe.get("can_cook", false) else "Need Items"
		cook_btn.disabled = not recipe.get("can_cook", false)
		var recipe_id: String = recipe.get("id", "")
		cook_btn.pressed.connect(_on_cook.bind(recipe_id, player))
		hbox.add_child(cook_btn)
		
		recipe_list.add_child(hbox)

func _on_cook(recipe_id: String, player: CharacterBody2D) -> void:
	if cooking_system:
		cooking_system.cook(recipe_id, player.inventory)
		_refresh_recipes(player)

func _close_cooking() -> void:
	if cooking_ui_layer:
		cooking_ui_layer.visible = false

func show_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = true
		interaction_label.text = "[F] Cook"

func hide_interaction_hint() -> void:
	if interaction_label:
		interaction_label.visible = false
