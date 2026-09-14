class_name InventoryUI
extends Control

@onready var grid_container: GridContainer = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ScrollContainer/GridContainer")
@onready var item_name_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemName")
@onready var item_type_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemType")
@onready var item_stats_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemStats")
@onready var item_desc_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ItemDesc")
@onready var use_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BodySplit/ItemInfo/MarginContainer/DetailVBox/ActionButtons/UseButton")
@onready var money_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/MoneyLabel")
@onready var capacity_label: Label = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/BagLabel")
@onready var close_button: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton")
@onready var dimmer: ColorRect = get_node_or_null("Dimmer")

@onready var btn_all: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnAll")
@onready var btn_weapons: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnWeapons")
@onready var btn_armor: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnArmor")
@onready var btn_dishes: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnDishes")
@onready var btn_potions: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnPotions")
@onready var btn_materials: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnMaterials")
@onready var btn_collectibles: Button = get_node_or_null("CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CategoryBar/BtnCollectibles")

var selected_item: Dictionary = {}
var filter_type: int = -1 # -1=All, 0=Material, 1=Weapon, 2=Armor, 3=Dish, 4=Potion, 6=Collectible

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not EventBus.inventory_toggled.is_connected(_toggle):
		EventBus.inventory_toggled.connect(_toggle)

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
	if btn_collectibles:
		btn_collectibles.pressed.connect(func(): _set_filter(6))
	UITheme.style_recursive(self)

func _set_filter(type: int) -> void:
	filter_type = type
	selected_item = {}
	_clear_detail()
	_refresh()

func _toggle() -> void:
	visible = not visible
	if visible:
		var q_menu := get_tree().root.find_child("QuestMenu", true, false)
		if q_menu and q_menu.visible:
			q_menu.visible = false
		var p_menu := get_tree().root.find_child("PauseMenu", true, false)
		if p_menu and p_menu.visible:
			p_menu.visible = false

		_refresh()
		get_tree().paused = true
		GameManager.is_paused = true
		var card := get_node_or_null("CenterContainer/PanelContainer")
		if card is Control:
			UIAnim.pop_in(card as Control, 0.2)
	else:
		var p_menu := get_tree().root.find_child("PauseMenu", true, false)
		var q_menu := get_tree().root.find_child("QuestMenu", true, false)
		if (p_menu == null or not p_menu.visible) and (q_menu == null or not q_menu.visible):
			get_tree().paused = false
			GameManager.is_paused = false

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
	if player == null or player.inventory == null:
		return

	if money_label and player.stats:
		money_label.text = "%d Gold" % player.stats.money
	if capacity_label:
		capacity_label.text = "Bag %d/%d" % [player.inventory.items.size(), player.inventory.max_slots]
	_update_category_counts(player)

	var display_items: Array[Dictionary] = []
	for item: Dictionary in player.inventory.items:
		if filter_type == -1 or int(item.get("type", 0)) == filter_type:
			display_items.append(item)

	for item: Dictionary in display_items:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(78, 74)
		slot.focus_mode = Control.FOCUS_ALL
		slot.tooltip_text = item.get("description", "A useful item.")
		var qty: int = int(item.get("quantity", 1))
		var item_type: int = int(item.get("type", 0))
		var is_equipped := _is_equipped(player, item, item_type)
		var name_str := str(item.get("name", "???"))
		if is_equipped:
			name_str = "[E] " + name_str + "\nEquipped"
		else:
			name_str += "\nx%d" % qty
		slot.text = name_str
		slot.add_theme_font_size_override("font_size", 11)
		slot.pressed.connect(_on_item_selected.bind(item))
		UITheme.style_button(slot)
		grid_container.add_child(slot)

	var remaining: int = maxi(0, 30 - display_items.size())
	for i in range(remaining):
		var empty_slot := Panel.new()
		empty_slot.custom_minimum_size = Vector2(78, 74)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.06, 0.10, 0.5)
		style.border_color = Color(0.15, 0.20, 0.30, 0.4)
		style.set_border_width_all(1)
		empty_slot.add_theme_stylebox_override("panel", style)
		grid_container.add_child(empty_slot)

func _update_category_counts(player: CharacterBody2D) -> void:
	var counts := {}
	for item: Dictionary in player.inventory.items:
		var item_type := int(item.get("type", 0))
		counts[item_type] = int(counts.get(item_type, 0)) + 1
	if btn_all:
		btn_all.text = "All (%d)" % player.inventory.items.size()
	if btn_weapons:
		btn_weapons.text = "Weapons (%d)" % int(counts.get(1, 0))
	if btn_armor:
		btn_armor.text = "Armor (%d)" % int(counts.get(2, 0))
	if btn_dishes:
		btn_dishes.text = "Dishes (%d)" % int(counts.get(3, 0))
	if btn_potions:
		btn_potions.text = "Potions (%d)" % int(counts.get(4, 0))
	if btn_materials:
		btn_materials.text = "Materials (%d)" % int(counts.get(0, 0))
	if btn_collectibles:
		btn_collectibles.text = "Relics (%d)" % int(counts.get(6, 0))

func _is_equipped(player: CharacterBody2D, item: Dictionary, item_type: int) -> bool:
	if item_type == 1:
		return player.inventory.equipped_weapon.get("id", "") == item.get("id", "")
	if item_type == 2:
		return player.inventory.equipped_armor.get("id", "") == item.get("id", "")
	return false

func _on_item_selected(item: Dictionary) -> void:
	selected_item = item
	if item_name_label:
		item_name_label.text = str(item.get("name", "Unknown"))

	var item_type: int = int(item.get("type", 0))
	var type_names := {0: "Material", 1: "Weapon", 2: "Armor", 3: "Cooked Dish", 4: "Potion", 5: "Quest Item", 6: "Collectible"}
	if item_type_label:
		item_type_label.text = "Type: " + str(type_names.get(item_type, "Item"))

	var stats_text := ""
	if item.has("attack_bonus"):
		stats_text += "Attack: +%d\n" % int(item["attack_bonus"])
	if item.has("defense_bonus") or item.has("defense"):
		stats_text += "Defense: +%d\n" % int(item.get("defense", item.get("defense_bonus", 0)))
	if item.has("heal"):
		stats_text += "Heal: +%d HP\n" % int(item["heal"])
	if item.has("stamina_restore"):
		stats_text += "Stamina: +%d\n" % int(item["stamina_restore"])
	if stats_text.is_empty():
		stats_text = "Quantity in Bag: %d" % int(item.get("quantity", 1))
	if item_stats_label:
		item_stats_label.text = stats_text
	if item_desc_label:
		item_desc_label.text = str(item.get("description", "A useful item."))

	if use_button:
		if item_type in [3, 4]:
			use_button.text = "Consume"
			use_button.visible = true
		elif item_type in [1, 2]:
			var player := GameManager.player
			var is_eq := player != null and _is_equipped(player, item, item_type)
			use_button.text = "Equipped" if is_eq else "Equip"
			use_button.visible = true
		else:
			use_button.visible = false

func _clear_detail() -> void:
	if item_name_label:
		item_name_label.text = "Select an Item"
	if item_type_label:
		item_type_label.text = "Category"
	if item_stats_label:
		item_stats_label.text = ""
	if item_desc_label:
		item_desc_label.text = "Click any item to view its stats and actions."
	if use_button:
		use_button.visible = false

func _on_use_pressed() -> void:
	if selected_item.is_empty():
		return
	var player := GameManager.player
	if player == null or player.inventory == null:
		return

	var item_type: int = int(selected_item.get("type", 0))
	var item_id := str(selected_item.get("id", ""))
	if item_type in [3, 4]:
		var heal_amount: float = float(selected_item.get("heal", 20.0))
		var stamina_amount: float = float(selected_item.get("stamina_restore", 0.0))
		player.stats.heal(heal_amount)
		if stamina_amount > 0.0:
			player.stats.current_stamina = minf(player.stats.get_max_stamina(), player.stats.current_stamina + stamina_amount)
			EventBus.player_stamina_changed.emit(player.stats.current_stamina, player.stats.get_max_stamina())
		var used_item := selected_item.duplicate()
		player.inventory.remove_item(item_id, 1)
		EventBus.item_used.emit(used_item)
		EventBus.show_notification.emit("Consumed " + str(used_item.get("name", "")))
		if not player.inventory.has_item(item_id, 1):
			selected_item = {}
			_clear_detail()
		_refresh()
	elif item_type == 1:
		player.inventory.equip_weapon(selected_item)
		EventBus.show_notification.emit("Equipped " + str(selected_item.get("name", "")))
		_refresh()
		_on_item_selected(selected_item)
	elif item_type == 2:
		player.inventory.equip_armor(selected_item)
		EventBus.show_notification.emit("Equipped " + str(selected_item.get("name", "")))
		_refresh()
		_on_item_selected(selected_item)
