extends Control

@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/Slider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXVolume/Slider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/Slider
@onready var fullscreen_check: CheckButton = $Panel/VBoxContainer/FullscreenCheck
@onready var back_btn: Button = $Panel/VBoxContainer/BackButton

func _ready() -> void:
	if master_slider:
		master_slider.value = 80
		master_slider.value_changed.connect(_on_master_changed)
	if sfx_slider:
		sfx_slider.value = 80
		sfx_slider.value_changed.connect(_on_sfx_changed)
	if music_slider:
		music_slider.value = 80
		music_slider.value_changed.connect(_on_music_changed)
	if fullscreen_check:
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if back_btn:
		back_btn.pressed.connect(_on_back)

func _on_master_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_sfx_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_music_changed(value: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _on_fullscreen_toggled(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back() -> void:
	visible = false
