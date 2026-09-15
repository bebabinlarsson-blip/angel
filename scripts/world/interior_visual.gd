class_name InteriorVisual
extends Node2D

## Compatibility marker for older interior scenes.
##
## Interior art is authored by the InteriorTilemap TileMapLayer scenes. This
## node intentionally has no drawing code so it cannot overlay hand-drawn room
## geometry on top of those tiles.

@export var theme_kind: String = "house"
@export var room_size: Vector2 = Vector2(960, 640)
