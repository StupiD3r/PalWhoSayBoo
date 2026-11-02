extends AudioStreamPlayer3D


func _ready() -> void:
	if stream == null:
		return

	finished.connect(_on_finished)

	await get_tree().create_timer(randf_range(0.0, 3.0)).timeout
	play()
	
func _on_finished() -> void:
	play()
