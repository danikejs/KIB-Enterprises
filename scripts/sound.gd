extends Node
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var next_voice: int = 0
var volume: float = 0.6
var tracks: Dictionary = {}

func _ready() -> void:
	for key in ["hit", "wall", "perfect", "point", "special", "click"]:
		tracks[key] = load("res://assets/audio/" + key + ".wav")
	for i in range(8):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/arena_loop.wav")
	if music.stream is AudioStreamWAV:
		music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.stream.loop_begin = 0
		music.stream.loop_end = music.stream.data.size() / 2
	add_child(music)
	music.finished.connect(func(): music.play())
	set_volume(volume)
	music.play()

func set_volume(value: float) -> void:
	volume = clampf(value, 0, 1)
	if music != null:
		music.volume_db = linear_to_db(maxf(0.00001, volume * 0.70))
	for voice in voices:
		voice.volume_db = linear_to_db(maxf(0.00001, volume * 0.55))

func play(kind: String) -> void:
	if not tracks.has(kind) or voices.is_empty():
		return
	var voice := voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = tracks[kind]
	voice.pitch_scale = randf_range(0.94, 1.06) if kind == "hit" else 1.0
	voice.play()

func stop_all() -> void:
	if is_instance_valid(music):
		music.stop()
	for voice in voices:
		voice.stop()

func _exit_tree() -> void:
	stop_all()
