extends Node

# Player signals
signal player_health_changed(new_health: float, max_health: float)
signal player_stamina_changed(new_stamina: float, max_stamina: float)
signal player_died()
signal player_respawned()
signal player_leveled_up(new_level: int)
signal player_exp_gained(amount: int, total: int, required: int)
signal player_money_changed(new_amount: int)

# Combat signals
signal damage_dealt(target: Node, amount: float)
signal monster_killed(monster: Node, position: Vector2)

# World signals
signal day_night_changed(is_night: bool)
signal time_changed(hour: int, minute: int)

# UI signals
signal inventory_toggled()
signal pause_toggled()
signal quest_menu_toggled()
signal show_notification(text: String)
signal interaction_available(interactable: Node)
signal interaction_unavailable()

# Item signals
signal item_collected(item_data: Dictionary)
signal item_used(item_data: Dictionary)

# Quest signals
signal quest_accepted(quest_id: String)
signal quest_completed(quest_id: String)
signal quest_updated(quest_id: String)

# Cooking signals
signal cooking_started(recipe_id: String)
signal cooking_finished(result_item: Dictionary)

# Save/Load
signal game_saved()
signal game_loaded()

# Fast travel
signal waystone_activated(waystone_id: String)
signal fast_travel_requested(destination_id: String)