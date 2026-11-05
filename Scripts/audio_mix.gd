extends Node

# Per-sound trims account for both recording loudness and existing player volume.
# Positive trims on quiet recordings are intentional; Master catches summed peaks.
const MIX = {
	"MidclimbAttack": 0.0, "BodyFall": 0.0, "GhostBreath": 0.0, "FatalAttack": 0.0,
	"Footsteps": 9.0,
	"ClimbVoice": 11.0,
	"RetryGasp": 8.0,
	"Bamboo": 15.0,
	"Wind": 16.0,
	"Typing": 3.0,
	"Combo": 4.0,
	"WordComplete": 6.0,
	"Sentence": 4.0,
	"Mistake": 7.0,
	"Warning": 10.0,
	"Scratch": 10.0,
	"Stinger": -3.0,
	"AmbientMusic": -35.0,
	"MenuMusic": 14.0,
	"Radio": -14.0,
	"StageMusic": -12.0,
	"Crickets": 17.0,
	"NPC": 10.0,
	"Wake": 30.0,
	"Knock": -4.0,
	"UIHover": 8.0,
	"UIClick": -3.0,
	"LoadingTyping": 10.0,
	"Walking": 9.0, "Running": 9.0,
	"Grunt": 11.0, "Breathing": 11.0,
	"Bamboo1": 15.0, "Bamboo2": 15.0, "Bamboo3": 15.0,
}
const CONTROLS = [
	["MidclimbAttack", "Manananggal mid-climb scare", "Assets/Audio/mid climb manananggal 2.mp3", -12.0],
	["BodyFall", "Body falling / impact", "Assets/Audio/body falling .mp3", -8.0],
	["GhostBreath", "Random ghost breathing", "Assets/Audio/ghost breathe.mp3", -16.0],
	["FatalAttack", "Manananggal ending", "Assets/Audio/manananggal ending.mp3", -14.0],
	["Walking", "Walking footsteps", "Assets/Audio/footstep_walk.ogg", -12.0],
	["Running", "Running footsteps", "Assets/Audio/footstep_run.ogg", -12.0],
	["Grunt", "Climbing grunt", "Assets/Audio/grunt.ogg", -16.0],
	["Breathing", "Climbing / rest breathing", "Assets/Audio/exhaust.ogg", -16.0],
	["RetryGasp", "Retry wake-up gasp", "Assets/Audio/retry_wake_gasp.ogg", -12.0],
	["Wake", "First wake-up", "freesound_community-man-waking-up-from-sleep-6338.mp3", -14.0],
	["Typing", "Typing keys", "Assets/Audio/soul_serenity_sounds-typing-sound-03-229862.mp3", -18.0],
	["Combo", "Typing combo", "Assets/Audio/combo/combo_click_chime.wav", -15.0],
	["WordComplete", "Word completed", "Assets/Audio/combo/word_complete.wav", -16.0],
	["Sentence", "Sentence completed", "Assets/Audio/combo/sentence_three_note.wav", -15.0],
	["Mistake", "Wrong key", "Assets/Audio/combo/typing_error_scrape.wav", -18.0],
	["Warning", "Monster warning", "Assets/Audio/combo/monster_warning.wav", -24.0],
	["Scratch", "Scratch / missed word", "Assets/Audio/combo/miss_swipe_breath.wav", -16.0],
	["Bamboo1", "Bamboo creak 1", "Assets/Audio/bamboo_creak_1.ogg", -18.0],
	["Bamboo2", "Bamboo creak 2", "Assets/Audio/bamboo_creak_2.ogg", -18.0],
	["Bamboo3", "Bamboo creak 3", "Assets/Audio/bamboo_creak_3.ogg", -18.0],
	["Wind", "Climbing / falling wind", "Assets/Audio/swirling wind.mp3", -20.0],
	["Stinger", "Radio scare stinger", "Assets/Audio/stinger.mp3", -12.0],
	["Knock", "Door knocking", "Assets/Audio/Knocking_sfx_[cut_1sec].mp3", 0.0],
	["NPC", "NPC murmuring", "freesound_community-human_male_crazy-mumbles_1-30950.mp3", -15.0],
	["Crickets", "Crickets", "u_s8g68hg8n6-cricket-on-a-summer-night-_-cricket-sound-341501.mp3", -20.0],
	["AmbientMusic", "Game ambience", "Assets/Audio/ambient bgm free.mp3", -50.0],
	["MenuMusic", "Menu ambience", "Assets/Audio/horror-bass-ambiance-sound-effect-sfx-bgm-for-videos-films-copyrightfree_PbxbNN3Z.mp3", -32.0],
	["Radio", "Radio song", "Assets/Audio/Provincial Jail _ Ilonggo Song.mp3", -12.0],
	["StageMusic", "Festival music", "Budots 2 (Original Budots).mp3", -12.0],
	["UIHover", "Menu hover", "soul_serenity_sounds-typing-sound-04-229864.mp3", -12.0],
	["UIClick", "Menu click", "soul_serenity_sounds-typing-sound-03-229862.mp3", -10.0],
	["LoadingTyping", "Loading screen typing", "soul_serenity_sounds-typing-sound-04-229864.mp3", -10.0],
]
const NAMES = {
	"MidclimbAttackSound": "MidclimbAttack", "BodyFallSound": "BodyFall",
	"GhostBreath": "GhostBreath", "FatalMonsterSound": "FatalAttack",
	"WalkSound": "Footsteps", "ClimbVoice": "ClimbVoice",
	"RetryWakeGasp": "RetryGasp", "BambooCreak": "Bamboo",
	"ClimbingWind": "Wind", "StepSound": "Typing",
	"ComboSound": "Combo", "WordCompleteSound": "WordComplete",
	"SentenceSound": "Sentence", "MistakeScrape": "Mistake",
	"MonsterWarning": "Warning", "MissSwipe": "Scratch",
	"RadioScareStinger": "Stinger", "WakeAmbientMusic": "AmbientMusic",
	"BGM": "MenuMusic", "RadioAudio": "Radio", "SpeakerSound": "StageMusic",
	"NPCSound": "NPC", "WakeSound": "Wake", "KnockSound": "Knock",
	"HoverSound": "UIHover", "ClickSound": "UIClick", "TypingSound": "LoadingTyping",
}
var players: Array[WeakRef] = []
var scan_elapsed: float = 0.0
var settings_path: String = "user://audio_settings.cfg"
var levels: Dictionary = {}
var save_deadline: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_levels()
	for profile in MIX:
		var bus_name := "Mix_" + String(profile)
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			index = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		_apply_level(profile)
	_compress("Wake", -16.0, 4.0)
	_compress("Footsteps", -14.0, 4.0)
	_compress("Bamboo", -14.0, 3.0)
	for profile in ["Walking", "Running", "Bamboo1", "Bamboo2", "Bamboo3"]:
		_compress(profile, -14.0, 4.0 if profile in ["Walking", "Running"] else 3.0)
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for effect_index in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.resource_name = "Balanced mix peak ceiling"
		limiter.threshold_db = -1.0
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, limiter)
	get_tree().node_added.connect(_track_audio)
	_track_existing(get_tree().root)

func _compress(profile: String, threshold: float, ratio: float) -> void:
	var index := AudioServer.get_bus_index("Mix_" + profile)
	if AudioServer.get_bus_effect_count(index) == 0:
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = threshold
		compressor.ratio = ratio
		compressor.attack_us = 500.0
		compressor.release_ms = 150.0
		AudioServer.add_bus_effect(index, compressor)

func _track_existing(node: Node) -> void:
	_track_audio(node)
	for child in node.get_children():
		_track_existing(child)

func _track_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		players.append(weakref(node))
		_route_audio(node)

func _process(delta: float) -> void:
	if save_deadline > 0 and Time.get_ticks_msec() >= save_deadline:
		save_levels()
	scan_elapsed += delta
	if scan_elapsed < 0.1:
		return
	scan_elapsed = 0.0
	for index in range(players.size() - 1, -1, -1):
		var node: Node = players[index].get_ref()
		if not is_instance_valid(node):
			players.remove_at(index)
		else:
			_route_audio(node)

func _route_audio(node: Node) -> void:
	var current_bus := String(node.get("bus"))
	if current_bus != "Master" and not current_bus.begins_with("Mix_"):
		return
	var profile: String = NAMES.get(String(node.name), "")
	if String(node.name).begins_with("CricketSound"):
		profile = "Crickets"
	var current_stream := node.get("stream") as AudioStream
	if current_stream:
		var clip_profile := String(current_stream.get_meta("mix_profile", ""))
		var clip := current_stream.resource_path.get_file()
		if clip_profile in MIX:
			profile = clip_profile
		elif clip == "footstep_walk.ogg": profile = "Walking"
		elif clip == "footstep_run.ogg": profile = "Running"
		elif clip == "grunt.ogg": profile = "Grunt"
		elif clip == "exhaust.ogg": profile = "Breathing"
		elif clip.begins_with("bamboo_creak_"):
			profile = "Bamboo" + clip.get_basename().right(1)
	if profile.is_empty():
		var stream := node.get("stream") as AudioStream
		if stream:
			var filename := stream.resource_path.get_file()
			if filename == "swirling wind.mp3":
				profile = "Wind"
			elif filename.begins_with("bamboo_creak_"):
				profile = "Bamboo"
			elif filename == "ambient bgm free.mp3":
				profile = "AmbientMusic"
			elif filename == "horror-bass-ambiance-sound-effect-sfx-bgm-for-videos-films-copyrightfree_PbxbNN3Z.mp3":
				profile = "MenuMusic"
	if not profile.is_empty():
		node.set("bus", "Mix_" + profile)

func route_player(node: Node) -> void:
	_route_audio(node)

func get_level(profile: String) -> float:
	return float(levels.get(profile, 100.0))

func set_level(profile: String, percent: float) -> void:
	if profile not in MIX or not is_finite(percent):
		return
	levels[profile] = clampf(percent, 0.0, 200.0)
	_apply_level(profile)
	save_deadline = Time.get_ticks_msec() + 300

func _apply_level(profile: String) -> void:
	var bus := AudioServer.get_bus_index("Mix_" + profile)
	if bus < 0:
		return
	var percent := get_level(profile)
	AudioServer.set_bus_mute(bus, percent <= 0.0)
	AudioServer.set_bus_volume_db(bus, float(MIX[profile]) + linear_to_db(maxf(percent, 0.01) / 100.0))

func reset_levels() -> void:
	levels.clear()
	for profile in MIX:
		_apply_level(profile)
	save_levels()

func save_levels() -> void:
	var config := ConfigFile.new()
	for profile in MIX:
		config.set_value("sounds", profile, get_level(profile))
	if config.save(settings_path) == OK:
		save_deadline = 0

func _load_levels() -> void:
	if not FileAccess.file_exists(settings_path):
		return
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for profile in MIX:
		var value: Variant = config.get_value("sounds", profile, 100.0)
		if (value is float or value is int) and is_finite(float(value)):
			levels[profile] = clampf(float(value), 0.0, 200.0)

func _exit_tree() -> void:
	if save_deadline > 0:
		save_levels()
