class_name CookingSystem
extends Node

var recipes: Dictionary = {}

func _ready() -> void:
	_init_recipes()

func _init_recipes() -> void:
	recipes = {
		"mushroom_stew": {
			"id": "mushroom_stew",
			"name": "Mushroom Stew",
			"ingredients": {"mushroom": 2, "herb": 1},
			"result": {
				"id": "mushroom_stew",
				"name": "Mushroom Stew",
				"type": 3, # DISH
				"heal": 35.0,
				"stamina_restore": 10.0,
				"description": "A warm, savory mushroom stew that restores 35 HP and 10 Stamina.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"herb_salad": {
			"id": "herb_salad",
			"name": "Herb Salad",
			"ingredients": {"herb": 2},
			"result": {
				"id": "herb_salad",
				"name": "Herb Salad",
				"type": 3, # DISH
				"heal": 20.0,
				"stamina_restore": 5.0,
				"description": "A crisp, fresh herbal salad that restores 20 HP.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"stamina_tonic": {
			"id": "stamina_tonic",
			"name": "Stamina Tonic",
			"ingredients": {"herb": 1, "mushroom": 1},
			"result": {
				"id": "stamina_tonic",
				"name": "Stamina Tonic",
				"type": 4, # POTION
				"heal": 15.0,
				"stamina_restore": 25.0,
				"description": "An energizing potion that restores 15 HP and 25 Stamina.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"iron_brew": {
			"id": "iron_brew",
			"name": "Iron Vitality Brew",
			"ingredients": {"iron_ore": 1, "herb": 2},
			"result": {
				"id": "iron_brew",
				"name": "Iron Vitality Brew",
				"type": 4, # POTION
				"heal": 50.0,
				"stamina_restore": 30.0,
				"description": "A powerful tonic forged with mineral essence. Restores 50 HP and 30 Stamina.",
				"stackable": true,
				"quantity": 1,
			},
		},
	}

func can_cook(recipe_id: String, inventory: PlayerInventory) -> bool:
	if recipe_id not in recipes or inventory == null:
		return false
	var recipe: Dictionary = recipes[recipe_id]
	var ingredients: Dictionary = recipe["ingredients"]
	for item_id in ingredients:
		if not inventory.has_item(item_id, ingredients[item_id]):
			return false
	return true

func cook(recipe_id: String, inventory: PlayerInventory) -> Dictionary:
	if not can_cook(recipe_id, inventory):
		return {}
	
	var recipe: Dictionary = recipes[recipe_id]
	var ingredients: Dictionary = recipe["ingredients"]
	
	# Remove ingredients
	for item_id in ingredients:
		inventory.remove_item(item_id, ingredients[item_id])
	
	# Add result
	var result: Dictionary = recipe["result"].duplicate(true)
	inventory.add_item(result)
	
	EventBus.cooking_finished.emit(result)
	EventBus.show_notification.emit("Cooked: %s!" % result.get("name", "Dish"))
	
	# Update quest progress
	var quest_system_node := get_tree().root.find_child("QuestSystem", true, false) as QuestSystem
	if quest_system_node:
		quest_system_node.update_quest_progress("cook", result.get("id", ""), 1)
	
	return result

func get_available_recipes(inventory: PlayerInventory) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id].duplicate(true)
		recipe["can_cook"] = can_cook(recipe_id, inventory)
		available.append(recipe)
	return available
