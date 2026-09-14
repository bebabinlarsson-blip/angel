class_name PlayerInventory
extends Resource

enum ItemType { MATERIAL, WEAPON, ARMOR, DISH, POTION, QUEST_ITEM, COLLECTABLE }

var items: Array[Dictionary] = []
var equipped_weapon: Dictionary = {}
var equipped_armor: Dictionary = {}
var max_slots: int = 30

func _find_item_index(item_id: String) -> int:
	for i in range(items.size()):
		if str(items[i].get("id", "")) == item_id:
			return i
	return -1

func can_add_item(item_data: Dictionary) -> bool:
	var item_id: String = str(item_data.get("id", ""))
	var quantity: int = int(item_data.get("quantity", 1))
	if item_id.is_empty() or quantity <= 0:
		return false
	var stackable: bool = bool(item_data.get("stackable", true))
	if stackable and _find_item_index(item_id) >= 0:
		return true
	return items.size() < max_slots

func add_item(item_data: Dictionary, emit_collection_signal: bool = true) -> bool:
	var item: Dictionary = item_data.duplicate(true)
	var item_id: String = str(item.get("id", ""))
	var quantity: int = int(item.get("quantity", 1))
	if item_id.is_empty() or quantity <= 0:
		return false
	item["id"] = item_id
	item["quantity"] = quantity
	item["stackable"] = bool(item.get("stackable", true))

	if item["stackable"]:
		var existing_index: int = _find_item_index(item_id)
		if existing_index >= 0:
			items[existing_index]["quantity"] = int(items[existing_index].get("quantity", 1)) + quantity
			if emit_collection_signal:
				EventBus.item_collected.emit(item.duplicate(true))
			EventBus.inventory_changed.emit()
			return true

	if items.size() >= max_slots:
		EventBus.show_notification.emit("Inventory full!")
		return false

	items.append(item)
	if emit_collection_signal:
		EventBus.item_collected.emit(item.duplicate(true))
	EventBus.inventory_changed.emit()
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	var index: int = _find_item_index(item_id)
	if index < 0:
		return false
	var current_qty: int = int(items[index].get("quantity", 1))
	if current_qty < quantity:
		return false
	if current_qty == quantity:
		items.remove_at(index)
	else:
		items[index]["quantity"] = current_qty - quantity
	EventBus.inventory_changed.emit()
	return true

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_count(item_id) >= quantity

func get_item_count(item_id: String) -> int:
	var index: int = _find_item_index(item_id)
	if index < 0:
		return 0
	return maxi(0, int(items[index].get("quantity", 1)))

func get_items_by_type(type: ItemType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in items:
		if int(item.get("type", -1)) == int(type):
			result.append(item)
	return result

func equip_weapon(item_data: Dictionary) -> void:
	if item_data.is_empty():
		equipped_weapon = {}
	elif int(item_data.get("type", -1)) == ItemType.WEAPON:
		equipped_weapon = item_data.duplicate(true)
	else:
		return
	EventBus.inventory_changed.emit()

func equip_armor(item_data: Dictionary) -> void:
	if item_data.is_empty():
		equipped_armor = {}
	elif int(item_data.get("type", -1)) == ItemType.ARMOR:
		equipped_armor = item_data.duplicate(true)
	else:
		return
	EventBus.inventory_changed.emit()

func get_save_data() -> Dictionary:
	return {
		"items": items.duplicate(true),
		"equipped_weapon": equipped_weapon.duplicate(true),
		"equipped_armor": equipped_armor.duplicate(true),
	}

func _restore_equipped(value: Variant, expected_type: int) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var saved_item: Dictionary = value
	var item_id: String = str(saved_item.get("id", ""))
	var index: int = _find_item_index(item_id)
	if index < 0 or int(items[index].get("type", -1)) != expected_type:
		return {}
	return items[index].duplicate(true)

func load_save_data(data: Dictionary) -> void:
	items.clear()
	var saved_items: Variant = data.get("items", [])
	if saved_items is Array:
		for raw_item in saved_items:
			if not (raw_item is Dictionary):
				continue
			var item: Dictionary = raw_item.duplicate(true)
			var item_id: String = str(item.get("id", ""))
			var quantity: int = int(item.get("quantity", 1))
			if item_id.is_empty() or quantity <= 0:
				continue
			item["id"] = item_id
			item["quantity"] = quantity
			item["stackable"] = bool(item.get("stackable", true))
			items.append(item)

	equipped_weapon = _restore_equipped(data.get("equipped_weapon", {}), ItemType.WEAPON)
	equipped_armor = _restore_equipped(data.get("equipped_armor", {}), ItemType.ARMOR)
