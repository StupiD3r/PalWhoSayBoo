extends Node

@onready var step_sound: AudioStreamPlayer = $StepSound
@onready var walk_sound: AudioStreamPlayer = $WalkSound # --- NEW ---

func play_climb_step() -> void:
	if step_sound:
		step_sound.pitch_scale = randf_range(0.85, 1.15)
		step_sound.play()

# --- NEW: Ground footsteps ---
func play_walk_step() -> void:
	if walk_sound and not walk_sound.playing:
		walk_sound.pitch_scale = randf_range(0.9, 1.1)
		walk_sound.play()

func stop_walk_step() -> void:
	if walk_sound and walk_sound.playing:
		walk_sound.stop()
