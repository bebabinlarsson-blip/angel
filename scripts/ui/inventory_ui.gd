class_name InventoryUI
extends Control

@onready var grid_container: GridContainer = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ScrollContainer/GridContainer")
@onready var item_info_panel: PanelContainer = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo")
@onready var item_name_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemName")
@onready var item_type_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemType")
@onready var item_stats_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemStats")
@onready var item_desc_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemDesc")
@onready var use_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ActionButtons/UseButton")
@onready var money_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/MoneyLabel")
@onready var close_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")

# Category Buttons
@onready var btn_all: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnAll")
@onready var btn_weapons: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnWeapons")
@onready var btn_armor: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnArmor")
@onready var btn_dishes: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnDishes")
@onready var btn_potions: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnPotions")
@onready var btn_materials: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnMaterials")

var selected_item: Dictionary = {}
var filter_type: int = -1 # -1 = All, 0=Material, 1=Weapon, 2=Armor, 3=Dish, 4=Potion

func _ready() -> void:
	EventBus.inventory_toggled.connect(_toggle)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if close_button:
		close_button.pressed.connect(_toggle)
	if dimmer:
		dimmer.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_toggle()
		)
	
	if btn_all:
		btn_all.pressed.connect(func(): _set_filter(-1))
	if btn_weapons:
		btn_weapons.pressed.connect(func(): _set_filter(1))
	if btn_armor:
		btn_armor.pressed.connect(func(): _set_filter(2))
	if btn_dishes:
		btn_dishes.pressed.connect(func(): _set_filter(3))
	if btn_potions:
		btn_potions.pressed.connect(func(): _set_filter(4))
	if btn_materials:
		btn_materials.pressed.connect(func(): _set_filter(0))
	UITheme.style_recursive(self)

func _set_filter(type: int) -> void:
	filter_type = type
	_refresh()

func _toggle() -> void:
	visible = !visible
	if visible:
		var q_menu := get_tree().root.find_child("QuestMenu", true, false)
		if q_menu and q_menu.visible:
			q_menu.visible = false
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
		var q_menu := get_tree().root.find_child("QuestMenu", true, false)
		if (p_menu == null or not p_menu.visible) and (q_menu == null or not q_menu.visible):
			get_tree().paused = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and visible:
		_toggle()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if grid_container == null:
		return
	
	for child in grid_container.get_children():
		child.queue_free()
	
	var player := GameManager.player
	if player == null:
		return
	
	if money_label and player.stats:
		money_label.text = "%d Gold  |  Lv. %d  (ATK %d, DEF %d)" % [
			player.stats.money,
			player.stats.level,
			int(player.get_effective_attack() if player.has_method("get_effective_attack") else player.stats.get_attack()),
			int(player.get_effective_defense() if player.has_method("get_effective_defense") else 0.0)
		]
	
	var display_items: Array[Dictionary] = []
	for item in player.inventory.items:
		if filter_type == -1 or item.get("type", 0) == filter_type:
			display_items.append(item)
	
	for item in display_items:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(74, 74)
		var qty: int = item.get("quantity", 1)
		var is_eq: bool = false
		if item.get("type", 0) == 1 and player.inventory.equipped_weapon.get("id", "") == item.get("id", ""):
			is_eq = true
		elif item.get("type", 0) == 2 and player.inventory.equipped_armor.get("id", "") == item.get("id", ""):
			is_eq = true
		
		var name_str: String = item.get("name", "???")
		if is_eq:
			name_str = "[E] " + name_str + "
(Equipped)"
		else:
			name_str += "
x%d" % qty
		
		slot.text = name_str
		slot.pressed.connect(_on_item_selected.bind(item))
		UITheme.style_button(slot)
		grid_container.add_child(slot)
	
	var remaining: int = maxi(0, 30 - display_items.size())
	for i in range(remaining):
		var empty_slot := Panel.new()
		empty_slot.custom_minimum_size = Vector2(74, 74)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.06, 0.10, 0.5)
		style.border_color = Color(0.15, 0.20, 0.30, 0.4)
		style.set_border_width_all(1)
		empty_slot.add_theme_stylebox_override("panel", style)
		grid_container.add_child(empty_slot)

func _on_item_selected(item: Dictionary) -> void:
	selected_item = item
	if item_name_label:
		item_name_label.text = item.get("name", "Unknown")
	
	var item_type: int = item.get("type", 0)
	var type_names := {0: "Material", 1: "Weapon", 2: "Armor", 3: "Cooked Dish", 4: "Potion", 6: "Collectible"}
	if item_type_label:
		item_type_label.text = "Type: " + type_names.get(item_type, "Item")
	
	var stats_text := ""
	if item.has("attack_bonus"):
		stats_text += "Attack: +%d
" % int(item["attack_bonus"])
	if item.has("defense_bonus"):
		stats_text += "Defense: +%d
" % int(item["defense_bonus"])
	if item.has("heal"):
		stats_text += "Heal: +%d HP
" % int(item["heal"])
	if item.has("stamina_restore"):
		stats_text += "Stamina: +%d
" % int(item["stamina_restore"])
	if stats_text == "":
		stats_text = "Quantity in Bag: %d" % item.get("quantity", 1)
	
	if item_stats_label:
		item_stats_label.text = stats_text
	
	if item_desc_label:
		item_desc_label.text = item.get("description", "A useful item.")
	
	if use_button:
		if item_type in [3, 4]:
			use_button.text = "Consume"
			use_button.visible = true
		elif item_type in [1, 2]:
			var player := GameManager.player
			var is_eq: bool = false
			if player:
				if item_type == 1 and player.inventory.equipped_weapon.get("id", "") == item.get("id", ""):
					is_eq = true
				elif item_type == 2 and player.inventory.equipped_armor.get("id", "") == item.get("id", ""):
					is_eq = true
			use_button.text = "Equipped" if is_eq else "Equip"
			use_button.visible = true
		else:
			use_button.visible = false

func _on_use_pressed() -> void:
	if selected_item.is_empty():
		return
	var player := GameManager.player
	if player == null:
		return
	
	var item_type: int = selected_item.get("type", 0)
	var item_id: String = selected_item.get("id", "")
	
	if item_type == 3 or item_type == 4: # DISH or POTION
		var heal_amount: float = selected_item.get("heal", 20.0)
		var stamina_amount: float = selected_item.get("stamina_restore", 0.0)
		player.stats.heal(heal_amount)
		if stamina_amount > 0:
			player.stats.current_stamina = min(player.stats.get_max_stamina(), player.stats.current_stamina + stamina_amount)
			EventBus.player_stamina_changed.emit(player.stats.current_stamina, player.stats.get_max_stamina())
		player.inventory.remove_item(item_id, 1)
		EventBus.item_used.emit(selected_item)
		EventBus.show_notification.emit("Consumed " + selected_item.get("name", ""))
		
		if not player.inventory.has_item(item_id, 1):
			selected_item = {}
			if item_name_label:
				item_name_label.text = "Select an Item"
			if item_stats_label:
				item_stats_label.text = ""
			if item_desc_label:
				item_desc_label.text = "Click any item to view its stats and actions."
			if use_button:
				use_button.visible = false
		_refresh()
	elif item_type == 1: # WEAPON
		player.inventory.equip_weapon(selected_item)
		EventBus.show_notification.emit("Equipped " + selected_item.get("name", ""))
		_refresh()
		_on_item_selected(selected_item)
	elif item_type == 2: # ARMOR
		player.inventory.equip_armor(selected_item)
		EventBus.show_notification.emit("Equipped " + selected_item.get("name", ""))
		_refresh()
		_on_item_selected(selected_item)
