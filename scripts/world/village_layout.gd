class_name VillageLayout
extends Node2D

## Marker/configuration node for the village.
##
## All visible roads, houses, civic landmarks, fences and props live in the
## scene-authored TileMapLayers under AuthoredEnvironment. This node remains
## as a lightweight compatibility hook for systems that configure the village
## safe ring or look up the old layout node.

var village_center: Vector2 = Vector2.ZERO
var safe_radius: float = 500.0

func _ready() -> void:
	z_index = -88
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("village_layout")

func configure(center: Vector2, radius: float) -> void:
	village_center = center
	safe_radius = radius
