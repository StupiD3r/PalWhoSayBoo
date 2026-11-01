extends Node

@onready var step_sound: AudioStreamPlayer = get_node_or_null("StepSound") as AudioStreamPlayer
@onready var walk_sound: AudioStreamPlayer = $WalkSound # --- NEW ---

var typing_streak: int = 0

@export var typing_sounds_enabled: bool = true
@export_range(-40.0, 0.0) var typing_volume_db: float = -18.0

@export var combo_sounds_enabled: bool = true
@export_range(-40.0, 0.0) var combo_volume_db: float = -15.0
@export var word_complete_enabled: bool = true
@export_range(-40.0, 0.0) var word_complete_volume_db: float = -16.0

var combo_sound: AudioStreamPlayer
var sentence_sound: AudioStreamPlayer
var word_complete_sound: AudioStreamPlayer
@export var punishment_sounds_enabled: bool = true
@export_range(-40.0, 0.0) var mistake_volume_db: float = -18.0
@export_range(-40.0, 0.0) var monster_warning_volume_db: float = -24.0
@export_range(-40.0, 0.0) var miss_swipe_volume_db: float = -16.0
var mistake_sound: AudioStreamPlayer
var monster_warning_sound: AudioStreamPlayer
var miss_swipe_sound: AudioStreamPlayer
var landing_sound: AudioStreamPlayer
@export_range(-40.0, 0.0) var landing_volume_db: float = -16.0

func _ready() -> void:
	if step_sound == null:
		step_sound = AudioStreamPlayer.new()
		step_sound.name = "StepSound"
		add_child(step_sound)
	step_sound.stream = preload("res://Assets/Audio/soul_serenity_sounds-typing-sound-03-229862.mp3")
	step_sound.max_polyphony = 3
	step_sound.volume_db = typing_volume_db
	combo_sound = AudioStreamPlayer.new()
	combo_sound.name = "ComboSound"
	combo_sound.stream = preload("res://Assets/Audio/combo/combo_click_chime.wav")
	add_child(combo_sound)
	sentence_sound = AudioStreamPlayer.new()
	sentence_sound.name = "SentenceSound"
	sentence_sound.stream = preload("res://Assets/Audio/combo/sentence_three_note.wav")
	add_child(sentence_sound)
	word_complete_sound = AudioStreamPlayer.new()
	word_complete_sound.name = "WordCompleteSound"
	word_complete_sound.stream = preload("res://Assets/Audio/combo/word_complete.wav")
	add_child(word_complete_sound)
	mistake_sound = _punishment_player("MistakeScrape", preload("res://Assets/Audio/combo/typing_error_scrape.wav"))
	mistake_sound.max_polyphony = 2
	monster_warning_sound = _punishment_player("MonsterWarning", preload("res://Assets/Audio/combo/monster_warning.wav"))
	miss_swipe_sound = _punishment_player("MissSwipe", preload("res://Assets/Audio/combo/miss_swipe_breath.wav"))
	landing_sound = AudioStreamPlayer.new()
	landing_sound.name = "LandingImpact"
	landing_sound.stream = _make_landing_impact()
	add_child(landing_sound)

func _make_landing_impact() -> AudioStreamWAV:
	# A short low thud with a soft shoe scuff; generated once on startup.
	var sample_rate := 22050
	var samples := int(sample_rate * 0.26)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4817
	var filtered_noise := 0.0
	for index in range(samples):
		var time := float(index) / sample_rate
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.22)
		var attack := minf(time / 0.005, 1.0)
		var thud := sin(TAU * (70.0 * time - 65.0 * time * time)) * exp(-22.0 * time)
		var scuff := filtered_noise * exp(-30.0 * time) * 0.65
		var value := clampf((thud * 0.6 + scuff) * attack, -1.0, 1.0)
		data.encode_s16(index * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func play_landing(fall_speed: float) -> void:
	if fall_speed < 2.5:
		return
	var strength := clampf(inverse_lerp(2.5, 12.0, fall_speed), 0.0, 1.0)
	stop_walk_step()
	landing_sound.volume_db = landing_volume_db + lerpf(-6.0, 0.0, strength)
	landing_sound.pitch_scale = lerpf(1.08, 0.85, strength)
	landing_sound.play()

func _punishment_player(sound_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.name = sound_name
	sound.stream = stream
	sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sound)
	return sound

func play_typing_mistake(repeated: bool) -> void:
	if not punishment_sounds_enabled:
		return
	mistake_sound.volume_db = mistake_volume_db
	mistake_sound.pitch_scale = randf_range(0.95, 1.05)
	mistake_sound.play()
	if repeated and not monster_warning_sound.playing:
		monster_warning_sound.volume_db = monster_warning_volume_db
		monster_warning_sound.play()

func play_miss_swipe() -> void:
	if punishment_sounds_enabled:
		miss_swipe_sound.volume_db = miss_swipe_volume_db
		miss_swipe_sound.play()

func play_word_complete() -> void:
	if not word_complete_enabled:
		return
	word_complete_sound.volume_db = word_complete_volume_db
	word_complete_sound.pitch_scale = randf_range(0.97, 1.03)
	word_complete_sound.play()

func play_combo(streak: int) -> void:
	if not combo_sounds_enabled or streak < 10 or streak % 10 != 0:
		return
	combo_sound.volume_db = combo_volume_db
	combo_sound.pitch_scale = minf(1.24, 1.0 + (streak / 10.0 - 1.0) * 0.04)
	combo_sound.play()

func play_sentence_complete() -> void:
	if not combo_sounds_enabled:
		return
	# Sentence completion takes priority over a coinciding combo milestone.
	combo_sound.stop()
	sentence_sound.volume_db = combo_volume_db
	sentence_sound.play()

func set_typing_streak(value: int) -> void:
	typing_streak = maxi(0, value)

func get_climb_pitch() -> float:
	if typing_streak == 0:
		return randf_range(0.85, 1.15)
	# A small, capped rise across forty correct keys, with subtle variation.
	var progress := clampf((typing_streak - 1) / 40.0, 0.0, 1.0)
	return clampf(lerpf(0.96, 1.3, progress) + randf_range(-0.015, 0.015), 0.94, 1.3)

func play_climb_step() -> void:
	if typing_sounds_enabled and step_sound:
		step_sound.volume_db = typing_volume_db
		step_sound.pitch_scale = get_climb_pitch()
		step_sound.play()

# --- NEW: Ground footsteps ---
func play_walk_step() -> void:
	if walk_sound and not walk_sound.playing:
		walk_sound.pitch_scale = randf_range(0.95, 1.05)
		walk_sound.play()

func stop_walk_step() -> void:
	if walk_sound and walk_sound.playing:
		walk_sound.stop()
