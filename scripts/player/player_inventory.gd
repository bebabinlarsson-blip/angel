class_name PlayerInventory
extends Resource

enum ItemType { MATERIAL, WEAPON, ARMOR, DISH, POTION, QUEST_ITEM, COLLECTABLE }

var items: Array[Dictionary] = []
var equipped_weapon: Dictionary = {}
var equipped_armor: Dictionary = {}
var max_slots: int = 30

func add_item(item_data: Dictionary) -> bool:
	# Check if stackable and already exists
	var stackable: bool = item_data.get("stackable", true)
	if stackable:
		for i in range(items.size()):
			if items[i].get("id", "") == item_data.get("id", ""):
				items[i]["quantity"] = items[i].get("quantity", 1) + item_data.get("quantity", 1)
				EventBus.item_collected.emit(item_data)
				return true
	
	if items.size() >= max_slots:
		return false  # inventory full
	
	if not item_data.has("quantity"):
		item_data["quantity"] = 1
	items.append(item_data)
	EventBus.item_collected.emit(item_data)
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	for i in range(items.size()):
		if items[i].get("id", "") == item_id:
			var current_qty: int = items[i].get("quantity", 1)
			if current_qty > quantity:
				items[i]["quantity"] = current_qty - quantity
				return true
			elif current_qty == quantity:
				items.remove_at(i)
				return true
			else:
				return false  # not enough
	return false

func has_item(item_id: String, quantity: int = 1) -> bool:
	for item in items:
		if item.get("id", "") == item_id:
			return item.get("quantity", 1) >= quantity
	return false

func get_item_count(item_id: String) -> int:
	for item in items:
		if item.get("id", "") == item_id:
			return item.get("quantity", 1)
	return 0

func get_items_by_type(type: ItemType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items:
		if item.get("type", -1) == type:
			result.append(item)
	return result

func equip_weapon(item_data: Dictionary) -> void:
	equipped_weapon = item_data

func equip_armor(item_data: Dictionary) -> void:
	equipped_armor = item_data

func get_save_data() -> Dictionary:
	return {
		"items": items,
		"equipped_weapon": equipped_weapon,
		"equipped_armor": equipped_armor,
	}

func load_save_data(data: Dictionary) -> void:
	items.assign(data.get("items", []))
	equipped_weapon = data.get("equipped_weapon", {})
	equipped_armor = data.get("equipped_armor", {})
