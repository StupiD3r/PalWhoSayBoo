extends AnimationPlayer

# Leave empty if there is only one animation besides RESET.
@export var animation_name: StringName = &""
@export var playback_speed := 1.0


func _ready() -> void:
	stop()
	active = true

	if animation_name == &"":
		var available: Array[StringName] = []

		for name in get_animation_list():
			if name != "RESET":
				available.append(StringName(name))

		if available.size() != 1:
			push_error(
				"Set Animation Name in the Inspector. Available: "
				+ str(available)
			)
			return

		animation_name = available[0]

	if not has_animation(animation_name):
		push_error("Animation not found: " + str(animation_name))
		return

	get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR

	speed_scale = playback_speed
	play(animation_name)
