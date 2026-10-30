extends AnimationPlayer

func _ready() -> void:
	# Replace this with the exact imported animation name.
	play("Idle")

	# Apply the pose at the beginning, then freeze it.
	seek(0.0, true)
	pause()
