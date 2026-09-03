class_name WaterZone
extends Area2D

## Detects when player enters/exits water for swimming

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_water"):
		body.enter_water()
	elif body.has_method("set_swimming"):
		body.set_swimming(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_water"):
		body.exit_water()
	elif body.has_method("set_swimming"):
		body.set_swimming(false)
