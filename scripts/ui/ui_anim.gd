class_name UIAnim
extends RefCounted

## Shared UI animation helpers: pop-in, fade, stagger.
## All tweens are lightweight (one Tween per open/close) and safe to call
## on Controls that may be freed mid-tween (callers check validity).

static func pop_in(control: Control, duration: float = 0.22) -> void:
	if control == null or not is_instance_valid(control):
		return
	# Preserve a responsive target scale calculated by UITheme.fit_modal().
	# Previously every animation ended at Vector2.ONE and made small-window
	# dialogs overflow again immediately after opening.
	var target_scale: Vector2 = control.scale
	if target_scale.length_squared() <= 0.001:
		target_scale = Vector2.ONE
	control.pivot_offset = control.size * 0.5
	control.scale = target_scale * 0.92
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", target_scale, duration)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.8)

static func fade_in(control: CanvasItem, duration: float = 0.18) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, duration)

static func fade_out_hide(control: CanvasItem, duration: float = 0.15) -> void:
	if control == null or not is_instance_valid(control):
		return
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(control):
			control.visible = false
			control.modulate.a = 1.0
	)

static func stagger_children(container: Node, delay_step: float = 0.05, duration: float = 0.25) -> void:
	if container == null or not is_instance_valid(container):
		return
	var idx := 0
	for child in container.get_children():
		if child is Control:
			var c := child as Control
			# NOTE: container-managed Controls have their position overwritten
			# by the container every sort, so only fade (+ pivot-safe scale
			# is skipped too). Modulate fade is layout-safe.
			c.modulate.a = 0.0
			var tween := c.create_tween()
			tween.tween_property(c, "modulate:a", 1.0, duration).set_delay(idx * delay_step)
			idx += 1

static func pulse(control: Control, target_scale: float = 1.06, duration: float = 0.12) -> void:
	if control == null or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(target_scale, target_scale), duration)
	tween.tween_property(control, "scale", Vector2.ONE, duration)

static func hook_button_sounds(button: Button) -> void:
	if button == null:
		return
	if not button.mouse_entered.is_connected(_on_btn_hover):
		button.mouse_entered.connect(_on_btn_hover.bind(button))
	if not button.pressed.is_connected(_on_btn_press):
		button.pressed.connect(_on_btn_press.bind(button))

static func _on_btn_hover(button: Button) -> void:
	if is_instance_valid(button) and button.visible:
		pulse(button, 1.04, 0.08)
		_play_ui_sound("hover")

static func _on_btn_press(_button: Button) -> void:
	_play_ui_sound("click")

static func _play_ui_sound(kind: String) -> void:
	var ml := Engine.get_main_loop()
	if not (ml is SceneTree):
		return
	var tree := ml as SceneTree
	if tree.root == null:
		return
	var mgr := tree.root.get_node_or_null("AudioManager")
	if mgr and is_instance_valid(mgr) and mgr.has_method("play_ui"):
		mgr.call("play_ui", kind)