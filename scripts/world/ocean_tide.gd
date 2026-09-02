extends Node2D

@export var tide_amplitude: float = 20.0
@export var tide_speed: float = 0.3
@export var wave_speed: float = 2.0
@export var wave_amplitude: float = 5.0

var tide_time: float = 0.0
var base_positions: Array[Vector2] = []
var water_sprites: Array[Sprite2D] = []

func _ready() -> void:
	# Collect child water sprites
	for child in get_children():
		if child is Sprite2D:
			water_sprites.append(child)
			base_positions.append(child.position)

func _process(delta: float) -> void:
	tide_time += delta
	
	# Tide moves based on game time (links to day/night)
	var tide_offset := sin(tide_time * tide_speed) * tide_amplitude
	
	for i in range(water_sprites.size()):
		var wave_offset := sin(tide_time * wave_speed + i * 0.5) * wave_amplitude
		water_sprites[i].position = base_positions[i] + Vector2(0, tide_offset + wave_offset)
