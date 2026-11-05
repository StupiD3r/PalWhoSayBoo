extends AudioStreamPlayer3D


func _ready() -> void:
	if stream == null:
		push_error("Assign an audio file to SpeakerSound's Stream.")
		return

	finished.connect(_on_finished)
	play()


func _on_finished() -> void:
	play()
