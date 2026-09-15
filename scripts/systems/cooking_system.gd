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
				"description": "A warm, savory stew that restores 35 HP and 10 Stamina.",
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
				"description": "A crisp salad that restores 20 HP and 5 Stamina.",
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
				"description": "A mineral tonic that restores 50 HP and 30 Stamina.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"berry_compote": {
			"id": "berry_compote",
			"name": "Berry Compote",
			"ingredients": {"berry": 2, "apple": 1, "flower": 1},
			"result": {
				"id": "berry_compote",
				"name": "Berry Compote",
				"type": 3, # DISH
				"heal": 25.0,
				"stamina_restore": 10.0,
				"buff_name": "Fleetfoot",
				"buff_speed": 0.18,
				"buff_duration": 45.0,
				"description": "Sweet berries and apple grant Fleetfoot: +18% movement speed for 45 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"foragers_salad": {
			"id": "foragers_salad",
			"name": "Forager's Salad",
			"ingredients": {"herb": 1, "plant": 1, "flower": 1},
			"result": {
				"id": "foragers_salad",
				"name": "Forager's Salad",
				"type": 3, # DISH
				"heal": 30.0,
				"stamina_restore": 12.0,
				"buff_name": "Barkskin",
				"buff_defense": 8.0,
				"buff_duration": 60.0,
				"description": "A wild greens salad that grants Barkskin: +8 defense for 60 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"orchard_pie": {
			"id": "orchard_pie",
			"name": "Orchard Pie",
			"ingredients": {"apple": 2, "berry": 1, "pear": 1},
			"result": {
				"id": "orchard_pie",
				"name": "Orchard Pie",
				"type": 3, # DISH
				"heal": 40.0,
				"stamina_restore": 15.0,
				"buff_name": "Hunter's Focus",
				"buff_attack": 12.0,
				"buff_duration": 60.0,
				"description": "A hearty pie that grants Hunter's Focus: +12 attack for 60 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"tropical_fruit_bowl": {
			"id": "tropical_fruit_bowl",
			"name": "Tropical Fruit Bowl",
			"ingredients": {"banana": 1, "orange": 1, "pear": 1, "grapes": 1},
			"result": {
				"id": "tropical_fruit_bowl",
				"name": "Tropical Fruit Bowl",
				"type": 3, # DISH
				"heal": 20.0,
				"stamina_restore": 35.0,
				"buff_name": "Quickened Breath",
				"buff_stamina_regen": 5.0,
				"buff_duration": 60.0,
				"description": "Fresh island fruit grants +5 stamina regeneration for 60 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"herbalist_broth": {
			"id": "herbalist_broth",
			"name": "Herbalist's Broth",
			"ingredients": {"herb": 2, "mushroom": 1, "plant": 1},
			"result": {
				"id": "herbalist_broth",
				"name": "Herbalist's Broth",
				"type": 3, # DISH
				"heal": 45.0,
				"stamina_restore": 20.0,
				"buff_name": "Iron Roots",
				"buff_defense": 5.0,
				"buff_stamina_regen": 3.0,
				"buff_duration": 75.0,
				"description": "Restorative broth grants +5 defense and +3 stamina regeneration for 75 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"garden_soup": {
			"id": "garden_soup",
			"name": "Garden Soup",
			"ingredients": {"tomato": 1, "carrot": 1, "herb": 1},
			"result": {
				"id": "garden_soup",
				"name": "Garden Soup",
				"type": 3, # DISH
				"heal": 40.0,
				"stamina_restore": 15.0,
				"buff_name": "Steady Hands",
				"buff_defense": 3.0,
				"buff_duration": 60.0,
				"description": "A fresh village soup that grants +3 defense for 60 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"fruit_punch": {
			"id": "fruit_punch",
			"name": "Fruit Punch",
			"ingredients": {"apple": 1, "orange": 1, "berry": 1},
			"result": {
				"id": "fruit_punch",
				"name": "Fruit Punch",
				"type": 3, # DISH
				"heal": 18.0,
				"stamina_restore": 50.0,
				"buff_name": "Bright Spirit",
				"buff_stamina_regen": 8.0,
				"buff_duration": 60.0,
				"description": "Bright island fruit restores stamina and grants +8 stamina regeneration.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"root_roast": {
			"id": "root_roast",
			"name": "Root Roast",
			"ingredients": {"carrot": 2, "wheat": 1, "mushroom": 1},
			"result": {
				"id": "root_roast",
				"name": "Root Roast",
				"type": 3, # DISH
				"heal": 55.0,
				"stamina_restore": 10.0,
				"buff_name": "Rooted Resolve",
				"buff_defense": 8.0,
				"buff_duration": 75.0,
				"description": "Roasted roots grant +8 defense for 75 seconds.",
				"stackable": true,
				"quantity": 1,
			},
		},
		"lavender_tea": {
			"id": "lavender_tea",
			"name": "Lavender Tea",
			"ingredients": {"lavender": 1, "mint": 1, "flower": 1},
			"result": {
				"id": "lavender_tea",
				"name": "Lavender Tea",
				"type": 3, # DISH
				"heal": 12.0,
				"stamina_restore": 35.0,
				"buff_name": "Calm Focus",
				"buff_attack": 4.0,
				"buff_duration": 90.0,
				"description": "Fragrant tea sharpens attacks by +4 for 90 seconds.",
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
	var result_value: Variant = recipe.get("result", {})
	if not (result_value is Dictionary):
		return {}
	var result: Dictionary = (result_value as Dictionary).duplicate(true)

	# Check the result slot before consuming anything. This keeps cooking
	# atomic when the bag is full and the dish is not already stackable.
	if not inventory.can_add_item(result):
		EventBus.show_notification.emit("Inventory full — make room before cooking.")
		return {}

	EventBus.cooking_started.emit(recipe_id)
	var removed_items: Array[Dictionary] = []
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for raw_item_id in ingredients:
		var item_id: String = str(raw_item_id)
		var required: int = int(ingredients.get(raw_item_id, 0))
		if required <= 0:
			continue
		if not inventory.remove_item(item_id, required):
			# This should be unreachable after can_cook(), but preserve the
			# player's materials if another system changed the bag this frame.
			for rollback: Dictionary in removed_items:
				inventory.add_item(rollback, false)
			return {}
		removed_items.append({
			"id": item_id,
			"name": item_id.replace("_", " ").capitalize(),
			"type": 0,
			"quantity": required,
			"stackable": true
		})

	if not inventory.add_item(result, false):
		for rollback: Dictionary in removed_items:
			inventory.add_item(rollback, false)
		EventBus.show_notification.emit("Cooking failed — your materials were returned.")
		return {}

	EventBus.cooking_finished.emit(result)
	EventBus.show_notification.emit("Cooked: %s!" % str(result.get("name", "Dish")))

	return result

func get_available_recipes(inventory: PlayerInventory) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id].duplicate(true)
		recipe["can_cook"] = can_cook(recipe_id, inventory)
		available.append(recipe)
	return available
