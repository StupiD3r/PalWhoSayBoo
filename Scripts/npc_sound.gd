extends AudioStreamPlayer3D


func _ready() -> void:
	if stream == null:
		push_error("Assign an audio file to NPCSound's Stream.")
		return

	finished.connect(_on_sound_finished)
	play()


func _on_sound_finished() -> void:
	play()
