extends StaticBody2D

var cache_id: String = ""
var opened: bool = false
var lid_lift: float = 0.0
var _sync_timer: float = 0.0

func _ready() -> void:
	if cache_id.is_empty():
		# An unset ID must still be unique; otherwise opening one default cache
		# marks every other default cache as opened in the save data.
		cache_id = name
	add_to_group("supply_caches")
	opened = cache_id in GameManager.opened_caches
	lid_lift = 12.0 if opened else 0.0
	var feet := CollisionShape2D.new()
	feet.name = "ChestFootprint"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 16)
	feet.shape = shape
	feet.position.y = -3
	add_child(feet)

func interact(player: CharacterBody2D) -> void:
	if player == null or not is_instance_valid(player) or player.stats == null:
		return
	if opened:
		EventBus.show_notification.emit("This cache is empty.")
		return
	opened = true
	GameManager.opened_caches.append(cache_id)
	player.stats.add_money(35)
	player.stats.add_exp(40)
	player.stats.heal(20)
	var tween := create_tween()
	tween.tween_property(self, "lid_lift", 12.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EventBus.show_notification.emit("Supply cache: 35 gold, 40 EXP, 20 health restored.")

func _process(delta: float) -> void:
	_sync_timer -= delta
	if _sync_timer > 0.0:
		return
	_sync_timer = 0.25
	var saved_open: bool = cache_id in GameManager.opened_caches
	if opened != saved_open:
		opened = saved_open
		lid_lift = 12.0 if opened else 0.0
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
