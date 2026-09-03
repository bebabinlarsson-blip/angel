class_name AudioManager
extends Node

## Procedural SFX: zero-asset square/sine blips generated at runtime.
## Added by game.gd and main_menu.gd (persistent across scene changes).
## All sounds go through a dedicated pool of AudioStreamPlayers so rapid
## hits don't cut each other off.

var _players: Array[AudioStreamPlayer] = []
var _pool_size: int = 8
var _next: int = 0
var _cache: Dictionary = {}

func _ready() -> void:
	name = "AudioManager"
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(_pool_size):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

func play_ui(kind: String) -> void:
	match kind:
		"hover":
			_play_tone(880.0, 0.05, 0.12)
		_:
			_play_tone(660.0, 0.07, 0.2)

func play_pickup() -> void:
	_play_tone(740.0, 0.09, 0.25, 1180.0)

func play_hit() -> void:
	_play_tone(180.0, 0.1, 0.3, 90.0)

func play_cook() -> void:
	_play_tone(520.0, 0.12, 0.25, 780.0)

func play_levelup() -> void:
	_play_tone(523.0, 0.1, 0.3, 784.0)
	_play_tone(784.0, 0.14, 0.3, 1046.0)

func play_death() -> void:
	_play_tone(300.0, 0.25, 0.3, 120.0)

func _play_tone(freq: float, duration: float, volume: float, slide_to: float = -1.0) -> void:
	var key := "%d_%d_%d" % [int(freq), int(duration * 1000.0), int(slide_to)]
	if not _cache.has(key):
		_cache[key] = _make_tone(freq, duration, slide_to)
	var p := _players[_next]
	_next = (_next + 1) % _pool_size
	p.stream = _cache[key]
	p.volume_db = linear_to_db(maxf(volume, 0.01))
	p.play()

func _make_tone(freq: float, duration: float, slide_to: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var f := freq
		if slide_to > 0.0:
			f = lerpf(freq, slide_to, float(i) / float(maxi(frames - 1, 1)))
		var env := 1.0 - float(i) / float(frames)
		var s := sin(TAU * f * t) * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
