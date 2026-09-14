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

# Timed food effects. Eating a new buff replaces the previous food effect so
# the active result is always clear to the player.
var active_buff_name: String = ""
var active_buff_remaining: float = 0.0
var buff_attack: float = 0.0
var buff_defense: float = 0.0
var buff_speed: float = 0.0
var buff_stamina_regen: float = 0.0

# Stamina costs
const DASH_STAMINA_COST := 10.0
const SWIM_STAMINA_PER_SEC := 3.0
const STAMINA_REGEN_RATE := 8.0 # per second
const STAMINA_REGEN_DELAY := 1.0 # seconds after use

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

func update_buffs(delta: float) -> void:
	if active_buff_remaining <= 0.0:
		return
	active_buff_remaining = maxf(0.0, active_buff_remaining - delta)
	if active_buff_remaining <= 0.0:
		var expired_name: String = active_buff_name
		_clear_food_buff()
		if not expired_name.is_empty():
			EventBus.show_notification.emit("%s has worn off." % expired_name)

func apply_food_buff(item: Dictionary) -> void:
	var duration: float = float(item.get("buff_duration", 0.0))
	if duration <= 0.0:
		return

	active_buff_name = str(item.get("buff_name", item.get("name", "Food Buff")))
	active_buff_remaining = duration
	buff_attack = float(item.get("buff_attack", 0.0))
	buff_defense = float(item.get("buff_defense", 0.0))
	buff_speed = float(item.get("buff_speed", 0.0))
	buff_stamina_regen = float(item.get("buff_stamina_regen", 0.0))

	var effects: Array[String] = []
	if buff_attack != 0.0:
		effects.append("+%d attack" % int(buff_attack))
	if buff_defense != 0.0:
		effects.append("+%d defense" % int(buff_defense))
	if buff_speed != 0.0:
		effects.append("+%d%% speed" % int(buff_speed * 100.0))
	if buff_stamina_regen != 0.0:
		effects.append("+%d stamina regen" % int(buff_stamina_regen))
	var effect_text: String = ""
	for effect in effects:
		if not effect_text.is_empty():
			effect_text += ", "
		effect_text += effect
	if effect_text.is_empty():
		effect_text = "special nourishment"
	EventBus.show_notification.emit("%s active: %s for %ds" % [active_buff_name, effect_text, int(active_buff_remaining)])

func _clear_food_buff() -> void:
	active_buff_name = ""
	active_buff_remaining = 0.0
	buff_attack = 0.0
	buff_defense = 0.0
	buff_speed = 0.0
	buff_stamina_regen = 0.0

func get_attack_buff() -> float:
	return buff_attack

func get_defense_buff() -> float:
	return buff_defense

func get_speed_multiplier() -> float:
	return maxf(0.25, 1.0 + buff_speed)

func get_active_buff_text() -> String:
	if active_buff_remaining <= 0.0 or active_buff_name.is_empty():
		return ""
	return "%s  %ds" % [active_buff_name, int(ceilf(active_buff_remaining))]

func take_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)
	EventBus.player_health_changed.emit(current_hp, get_max_hp())
	# NOTE: death signal is owned by GameManager.game_over() (via Player.die)
	# to avoid double player_died emits. Callers must check hp<=0.

func heal(amount: float) -> void:
	current_hp = minf(get_max_hp(), current_hp + amount)
	EventBus.player_health_changed.emit(current_hp, get_max_hp())

func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		EventBus.player_stamina_changed.emit(current_stamina, get_max_stamina())
		return true
	return false

func regen_stamina(delta: float) -> void:
	if current_stamina < get_max_stamina():
		var regen_rate: float = STAMINA_REGEN_RATE + buff_stamina_regen
		current_stamina = minf(get_max_stamina(), current_stamina + regen_rate * delta)
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
		"active_buff_name": active_buff_name,
		"active_buff_remaining": active_buff_remaining,
		"buff_attack": buff_attack,
		"buff_defense": buff_defense,
		"buff_speed": buff_speed,
		"buff_stamina_regen": buff_stamina_regen,
	}

func load_save_data(data: Dictionary) -> void:
	level = maxi(0, int(data.get("level", 0)))
	current_exp = clampi(int(data.get("current_exp", 0)), 0, get_exp_required() - 1)
	current_hp = clampf(float(data.get("current_hp", BASE_HP)), 0.0, get_max_hp())
	current_stamina = clampf(float(data.get("current_stamina", BASE_STAMINA)), 0.0, get_max_stamina())
	money = maxi(0, int(data.get("money", 0)))

	active_buff_name = str(data.get("active_buff_name", ""))
	active_buff_remaining = maxf(0.0, float(data.get("active_buff_remaining", 0.0)))
	buff_attack = float(data.get("buff_attack", 0.0))
	buff_defense = float(data.get("buff_defense", 0.0))
	buff_speed = float(data.get("buff_speed", 0.0))
	buff_stamina_regen = float(data.get("buff_stamina_regen", 0.0))
	if active_buff_remaining <= 0.0:
		_clear_food_buff()
