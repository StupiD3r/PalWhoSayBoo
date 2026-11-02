extends Node3D

# Leave empty to automatically use the only non-RESET animation.
@export var animation_name: StringName = &""
@export_range(0.1, 3.0, 0.1) var playback_speed := 1.0

@onready var animation_player: AnimationPlayer = $DancingBuang


func _ready() -> void:
	animation_player.stop()

	if animation_name == &"":
		var available: Array[StringName] = []

		for name in animation_player.get_animation_list():
			if name != "RESET":
				available.append(StringName(name))

		if available.size() == 1:
			animation_name = available[0]
		else:
			push_error(
				"Choose Animation Name in the Inspector. Available: "
				+ str(available)
			)
			return

	if not animation_player.has_animation(animation_name):
		push_error(
			"Animation not found. Available: "
			+ str(animation_player.get_animation_list())
		)
		return

	var animation := animation_player.get_animation(animation_name)
	animation.loop_mode = Animation.LOOP_LINEAR

	animation_player.active = true
	animation_player.speed_scale = playback_speed
	animation_player.play(animation_name)
