extends StaticBody2D

var cache_id: String = ""
var opened: bool = false
var lid_lift: float = 0.0

func _ready() -> void:
	add_to_group("supply_caches")
	_sync_from_save()
	if not EventBus.game_loaded.is_connected(_sync_from_save):
		EventBus.game_loaded.connect(_sync_from_save)
	set_process(false)

func _sync_from_save() -> void:
	if cache_id.is_empty():
		opened = false
	else:
		opened = GameManager.opened_caches.has(cache_id)
	lid_lift = 12.0 if opened else 0.0
	queue_redraw()

func interact(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player) or player.stats == null:
		return
	if cache_id.is_empty():
		EventBus.show_notification.emit("This cache has no valid identifier.")
		return
	if opened:
		EventBus.show_notification.emit("This cache is empty.")
		return
	opened = true
	if not GameManager.opened_caches.has(cache_id):
		GameManager.opened_caches.append(cache_id)
	player.stats.add_money(35)
	player.stats.add_exp(40)
	player.stats.heal(20)
	var tween := create_tween()
	tween.tween_property(self, "lid_lift", 12.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EventBus.show_notification.emit("Supply cache: 35 gold, 40 EXP, 20 health restored.")
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-18, -1, 36, 8), Color(0.1, 0.15, 0.1, 0.2))
	draw_rect(Rect2(-16, -18, 32, 22), Color("#473a2a"))
	draw_rect(Rect2(-14, -16, 28, 18), Color("#a16a3b"))
	draw_rect(Rect2(-13, -18, 26, 8), Color("#302d26"))
	draw_rect(Rect2(-16, -24 - lid_lift, 32, 12), Color("#62472d"))
	draw_rect(Rect2(-14, -22 - lid_lift, 28, 8), Color("#bb874f"))
	for x in [-11, 9]:
		draw_rect(Rect2(x, -23 - lid_lift, 3, 10), Color("#d4b86e"))
		draw_rect(Rect2(x, -11, 3, 13), Color("#d4b86e"))
	if not opened:
		draw_rect(Rect2(-3, -14, 6, 7), Color("#f0ce76"))
