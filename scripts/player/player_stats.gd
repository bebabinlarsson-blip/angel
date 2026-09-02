class_name PlayerStats
extends Resource

# Base stats
const BASE_HP := 100.0
const BASE_ATTACK := 50.0
const BASE_STAMINA := 30.0
const BASE_EXP_REQUIRED := 100

# Per-level gains
const HP_PER_LEVEL := 12.0
const ATTACK_PER_LEVEL := 5.0
const STAMINA_PER_LEVEL := 3.0

# Current values
var level: int = 0
var current_exp: int = 0
var current_hp: float = BASE_HP
var current_stamina: float = BASE_STAMINA
var money: int = 0

# Stamina costs
const DASH_STAMINA_COST := 10.0
const SWIM_STAMINA_PER_SEC := 3.0
const STAMINA_REGEN_RATE := 8.0  # per second
const STAMINA_REGEN_DELAY := 1.0  # seconds after use

func get_max_hp() -> float:
	return BASE_HP + (level * HP_PER_LEVEL)

func get_max_stamina() -> float:
	return BASE_STAMINA + (level * STAMINA_PER_LEVEL)

func get_attack() -> float:
	return BASE_ATTACK + (level * ATTACK_PER_LEVEL)

func get_exp_required() -> int:
	var total: float = BASE_EXP_REQUIRED
	for i in range(level):
		if i < 15:
			total *= 1.15
		elif i < 30:
			total *= 1.10
		else:
			total *= 1.05
	return int(total)

func add_exp(amount: int) -> bool:
	current_exp += amount
	var leveled_up: bool = false
	var required := get_exp_required()
	
	while current_exp >= required:
		current_exp -= required
		level += 1
		leveled_up = true
		current_hp = get_max_hp()
		current_stamina = get_max_stamina()
		EventBus.player_health_changed.emit(current_hp, get_max_hp())
		EventBus.player_stamina_changed.emit(current_stamina, get_max_stamina())
		EventBus.player_leveled_up.emit(level)
		required = get_exp_required()
	
	EventBus.player_exp_gained.emit(amount, current_exp, required)
	return leveled_up

func take_damage(amount: float) -> void:
	current_hp = max(0, current_hp - amount)
	EventBus.player_health_changed.emit(current_hp, get_max_hp())
	if current_hp <= 0:
		EventBus.player_died.emit()

func heal(amount: float) -> void:
	current_hp = min(get_max_hp(), current_hp + amount)
	EventBus.player_health_changed.emit(current_hp, get_max_hp())

func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		EventBus.player_stamina_changed.emit(current_stamina, get_max_stamina())
		return true
	return false

func regen_stamina(delta: float) -> void:
	if current_stamina < get_max_stamina():
		current_stamina = min(get_max_stamina(), current_stamina + STAMINA_REGEN_RATE * delta)
		EventBus.player_stamina_changed.emit(current_stamina, get_max_stamina())

func add_money(amount: int) -> void:
	money += amount
	EventBus.player_money_changed.emit(money)

func get_save_data() -> Dictionary:
	return {
		"level": level,
		"current_exp": current_exp,
		"current_hp": current_hp,
		"current_stamina": current_stamina,
		"money": money,
	}

func load_save_data(data: Dictionary) -> void:
	level = data.get("level", 0)
	current_exp = data.get("current_exp", 0)
	current_hp = data.get("current_hp", BASE_HP)
	current_stamina = data.get("current_stamina", BASE_STAMINA)
	money = data.get("money", 0)
