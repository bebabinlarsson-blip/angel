class_name VillageLayout
extends Node2D

## Marker/configuration node for the village.
##
## The editor-facing village map lives under World/VillageDistrict, with the
## terrain, road, house, decoration, collision and entrance layers grouped in
## AuthoredEnvironment. This node provides the safe-ring configuration.

var village_center: Vector2 = Vector2.ZERO
var safe_radius: float = 500.0

func _ready() -> void:
	z_index = -88
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("village_layout")

func configure(center: Vector2, radius: float) -> void:
	village_center = center
	safe_radius = radius
