extends AnimationPlayer

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
				"Choose Animation Name. Available: "
				+ str(available)
			)
			return

		animation_name = available[0]

	if not has_animation(animation_name):
		push_error(
			"Animation not found. Available: "
			+ str(get_animation_list())
		)
		return

	get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	speed_scale = playback_speed
	play(animation_name)
