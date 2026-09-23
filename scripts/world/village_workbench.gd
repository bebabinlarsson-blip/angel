extends Area2D

const IRON_SWORD := {
	"id": "iron_sword",
	"name": "Iron Sword",
	"type": PlayerInventory.ItemType.WEAPON,
	"quantity": 1,
	"stackable": false,
	"attack_bonus": 28.0,
	"description": "A sturdy blade forged at the village blacksmith's table.",
}

func _ready() -> void:
	add_to_group("village_workbenches")
	monitoring = true

func interact(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player) or player.inventory == null:
		EventBus.show_notification.emit("Bring your pack to the blacksmith's table.")
		return

	var inventory := player.inventory
	if not inventory.has_item("iron_ore", 3) or not inventory.has_item("wood", 2):
		EventBus.show_notification.emit("Forge an Iron Sword here with 3 Iron Ore and 2 Wood.")
		return
	if not inventory.can_add_item(IRON_SWORD):
		EventBus.show_notification.emit("Make room in your backpack before forging a sword.")
		return

	if not inventory.remove_item("iron_ore", 3):
		return
	if not inventory.remove_item("wood", 2):
		inventory.add_item({"id": "iron_ore", "name": "Iron Ore", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 3, "stackable": true}, false)
		return

	if inventory.add_item(IRON_SWORD):
		inventory.equip_weapon(IRON_SWORD)
		EventBus.show_notification.emit("Forged and equipped an Iron Sword.")
	else:
		inventory.add_item({"id": "iron_ore", "name": "Iron Ore", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 3, "stackable": true}, false)
		inventory.add_item({"id": "wood", "name": "Crafting Wood", "type": PlayerInventory.ItemType.MATERIAL, "quantity": 2, "stackable": true}, false)
