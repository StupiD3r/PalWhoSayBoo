extends Node

@onready var step_sound: AudioStreamPlayer = $StepSound
@onready var walk_sound: AudioStreamPlayer = $WalkSound # --- NEW ---

var typing_streak: int = 0

@export var combo_sounds_enabled: bool = true
@export_range(-40.0, 0.0) var combo_volume_db: float = -15.0

var combo_sound: AudioStreamPlayer
var sentence_sound: AudioStreamPlayer

func _ready() -> void:
	combo_sound = AudioStreamPlayer.new()
	combo_sound.name = "ComboSound"
	combo_sound.stream = preload("res://Assets/Audio/combo/combo_click_chime.wav")
	add_child(combo_sound)
	sentence_sound = AudioStreamPlayer.new()
	sentence_sound.name = "SentenceSound"
	sentence_sound.stream = preload("res://Assets/Audio/combo/sentence_three_note.wav")
	add_child(sentence_sound)

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
	if step_sound:
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
