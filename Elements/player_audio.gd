extends Node

@onready var step_sound: AudioStreamPlayer = get_node_or_null("StepSound") as AudioStreamPlayer
@onready var walk_sound: AudioStreamPlayer = $WalkSound # --- NEW ---
var walking_stream: AudioStreamOggVorbis = preload("res://Assets/Audio/footstep_walk.ogg")
var running_stream: AudioStreamOggVorbis = preload("res://Assets/Audio/footstep_run.ogg")
@export_range(-40.0, 0.0) var footstep_volume_db: float = -12.0

var typing_streak: int = 0
@export_range(-40.0, 0.0) var climb_voice_volume_db: float = -16.0
var climb_voice: AudioStreamPlayer
var grunt_stream: AudioStreamOggVorbis = preload("res://Assets/Audio/grunt.ogg")
var exhaust_stream: AudioStreamOggVorbis = preload("res://Assets/Audio/exhaust.ogg")
var climb_active: bool = false
var climb_effort_steps: int = 0
var climb_voice_cooldown: float = 0.0
var time_since_climb_step: float = 0.0
var breath_pending: bool = false
@export_range(-40.0, 0.0) var wind_low_volume_db: float = -30.0
@export_range(-40.0, 0.0) var wind_high_volume_db: float = -20.0
@export_range(-40.0, 0.0) var bamboo_volume_db: float = -18.0
var climb_wind: AudioStreamPlayer
var bamboo_creak: AudioStreamPlayer
var creak_streams: Array[AudioStream] = [
	preload("res://Assets/Audio/bamboo_creak_1.ogg"),
	preload("res://Assets/Audio/bamboo_creak_2.ogg"),
	preload("res://Assets/Audio/bamboo_creak_3.ogg"),
]
var atmosphere_climbing: bool = false
var previous_climb_y: float = 0.0
var creak_cooldown: float = 0.0
var last_creak_index: int = -1
var ghost_breath: AudioStreamPlayer
var ghost_cooldown: float = 18.0

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
	ghost_breath = AudioStreamPlayer.new()
	ghost_breath.name = "GhostBreath"
	ghost_breath.stream = preload("res://Assets/Audio/ghost breathe.mp3")
	ghost_breath.volume_db = -16.0
	add_child(ghost_breath)
	climb_wind = AudioStreamPlayer.new()
	climb_wind.name = "ClimbingWind"
	var wind_stream := preload("res://Assets/Audio/swirling wind.mp3").duplicate() as AudioStreamMP3
	wind_stream.loop = true
	climb_wind.stream = wind_stream
	climb_wind.volume_db = -60.0
	add_child(climb_wind)
	bamboo_creak = AudioStreamPlayer.new()
	bamboo_creak.name = "BambooCreak"
	bamboo_creak.volume_db = bamboo_volume_db
	add_child(bamboo_creak)
	climb_voice = AudioStreamPlayer.new()
	climb_voice.name = "ClimbVoice"
	climb_voice.volume_db = climb_voice_volume_db
	add_child(climb_voice)
	walking_stream = walking_stream.duplicate() as AudioStreamOggVorbis
	running_stream = running_stream.duplicate() as AudioStreamOggVorbis
	walking_stream.loop = true
	running_stream.loop = true
	walking_stream.set_meta("mix_profile", "Walking")
	running_stream.set_meta("mix_profile", "Running")
	walk_sound.stop()
	walk_sound.stream = walking_stream
	walk_sound.volume_db = footstep_volume_db
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

func start_climb_voice() -> void:
	stop_climb_voice()
	climb_active = true
	ghost_cooldown = randf_range(12.0, 22.0)

func stop_climb_voice() -> void:
	stop_ghost_breath()
	climb_active = false
	climb_effort_steps = 0
	climb_voice_cooldown = 0.0
	time_since_climb_step = 0.0
	breath_pending = false
	if is_instance_valid(climb_voice):
		climb_voice.stop()

func set_climb_resting(resting: bool) -> void:
	stop_climb_voice()
	if resting:
		_play_climb_voice(exhaust_stream)
	else:
		climb_active = get_parent().get("is_climbing") == true
		climb_voice_cooldown = 2.5

func _process(delta: float) -> void:
	_update_climb_atmosphere(delta)
	if not climb_active:
		return
	climb_voice_cooldown = maxf(0.0, climb_voice_cooldown - delta)
	time_since_climb_step += delta
	if breath_pending and time_since_climb_step >= 0.9 and climb_voice_cooldown <= 0.0 and not climb_voice.playing:
		_play_climb_voice(exhaust_stream)
		breath_pending = false

func _update_climb_atmosphere(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var climbing: bool = body != null and body.get("is_climbing") == true
	var target_volume := -60.0
	if climbing:
		var height := body.global_position.y
		var resting: bool = body.get("climb_resting") == true
		_update_ghost_breath(delta, resting)
		if not atmosphere_climbing:
			previous_climb_y = height
			creak_cooldown = 1.0
		if not climb_wind.playing:
			climb_wind.play()
		var bottom := float(body.get("min_climb_y"))
		var top := float(body.get("max_climb_y"))
		var progress := clampf((height - bottom) / maxf(top - bottom, 1.0), 0.0, 1.0) if is_finite(top) else 0.0
		target_volume = lerpf(wind_low_volume_db, wind_high_volume_db, progress) - (8.0 if resting else 0.0)
		creak_cooldown = maxf(0.0, creak_cooldown - delta)
		if resting:
			bamboo_creak.stop()
		elif height > previous_climb_y + 0.0005 and creak_cooldown <= 0.0 and not bamboo_creak.playing:
			var index := randi_range(0, creak_streams.size() - 1)
			if index == last_creak_index:
				index = (index + 1) % creak_streams.size()
			last_creak_index = index
			bamboo_creak.stream = creak_streams[index]
			bamboo_creak.pitch_scale = randf_range(0.94, 1.06)
			_route_sound(bamboo_creak)
			bamboo_creak.play()
			creak_cooldown = randf_range(3.5, 6.0)
		previous_climb_y = height
	else:
		bamboo_creak.stop()
		if ghost_breath.playing:
			stop_ghost_breath()
	atmosphere_climbing = climbing
	climb_wind.volume_db = lerpf(climb_wind.volume_db, target_volume, 1.0 - exp(-2.5 * delta))
	if not climbing and climb_wind.volume_db < -59.5:
		climb_wind.stop()

func _update_ghost_breath(delta: float, resting: bool) -> void:
	if resting:
		ghost_breath.stop()
		ghost_cooldown = maxf(ghost_cooldown, 8.0)
		return
	ghost_cooldown = maxf(0.0, ghost_cooldown - delta)
	if ghost_cooldown <= 0.0 and not ghost_breath.playing and not climb_voice.playing:
		ghost_breath.pitch_scale = randf_range(0.97, 1.03)
		ghost_breath.play()
		ghost_cooldown = randf_range(25.0, 45.0)

func stop_ghost_breath() -> void:
	if is_instance_valid(ghost_breath):
		ghost_breath.stop()
	ghost_cooldown = randf_range(25.0, 45.0)

func _play_climb_voice(stream: AudioStream) -> void:
	climb_voice.stream = stream
	climb_voice.pitch_scale = randf_range(0.97, 1.03)
	_route_sound(climb_voice)
	climb_voice.play()
	climb_voice_cooldown = maxf(2.5, stream.get_length() + 0.8)

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
	if climb_active:
		time_since_climb_step = 0.0
		climb_effort_steps += 1
		if climb_effort_steps >= 8:
			breath_pending = true
		if climb_voice_cooldown <= 0.0 and not climb_voice.playing:
			# Alternate effort and breath during sustained climbing too.
			var use_breath := breath_pending and climb_voice.stream == grunt_stream
			_play_climb_voice(exhaust_stream if use_breath else grunt_stream)
			if use_breath:
				breath_pending = false
				climb_effort_steps = 0
	if typing_sounds_enabled and step_sound:
		step_sound.volume_db = typing_volume_db
		step_sound.pitch_scale = get_climb_pitch()
		step_sound.play()

# One player keeps the walking and running loops from overlapping.
func play_walk_step(sprinting: bool = false) -> void:
	var stream := running_stream if sprinting else walking_stream
	if walk_sound.stream != stream:
		walk_sound.stop()
		walk_sound.stream = stream
	_route_sound(walk_sound)
	if not walk_sound.playing:
		walk_sound.pitch_scale = 1.0
		walk_sound.play()

func stop_walk_step() -> void:
	if walk_sound and walk_sound.playing:
		walk_sound.stop()

func _route_sound(sound: AudioStreamPlayer) -> void:
	var mix := get_node_or_null("/root/AudioMix")
	if mix:
		mix.route_player(sound)
