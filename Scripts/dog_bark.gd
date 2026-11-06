extends AudioStreamPlayer3D

@export var pause_between_barks: float = 2.0


func _ready() -> void:
	if stream == null:
		push_warning("Drag dog.mp3 into DogBark's Stream field.")
		return

	finished.connect(_on_bark_finished)
	play()


func _on_bark_finished() -> void:
	await get_tree().create_timer(
		maxf(pause_between_barks, 0.1)
	).timeout

	if is_inside_tree():
		play()
