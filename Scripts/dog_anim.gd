extends AnimationPlayer

@export var animation_name: StringName = &"metarig|Dog1_Bark"
@export var playback_speed: float = 1.0


func _ready() -> void:
	stop()
	active = true

	# Handle an empty value saved in the Inspector.
	if animation_name == &"":
		animation_name = &"metarig|Dog1_Bark"

	if not has_animation(animation_name):
		push_error(
			"Dog animation not found: "
			+ str(animation_name)
			+ ". Available: "
			+ str(get_animation_list())
		)
		return

	get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	speed_scale = playback_speed
	play(animation_name)
