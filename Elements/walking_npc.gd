extends CharacterBody3D

@export var walk_speed := 1.0
@export var acceleration := 2.0
@export var deceleration := 3.0
@export var turn_speed := 8.0

@export var wait_at_point := 2.0
@export var arrival_distance := 0.4
@export var patrol_points: Array[Node3D] = []

# Movement speed that matches the walk animation at normal playback.
# Tune this until the feet stay planted during each step.
@export var animation_walk_speed := 1.2

@export var idle_animation: StringName = &"NPCIdle"

@onready var walk_player: AnimationPlayer = $Model/SideChar/NPCWalk
@onready var idle_player: AnimationPlayer = $Model/SideChar/NPCIdle

const WALK_ANIMATION: StringName = &"NPCWalk"

var point_index := 0
var wait_remaining := 0.0
var animation_state := ""


func _ready() -> void:
	walk_player.stop()
	idle_player.stop()

	walk_player.active = true
	idle_player.active = true

	if walk_player.has_animation(WALK_ANIMATION):
		walk_player.get_animation(
			WALK_ANIMATION
		).loop_mode = Animation.LOOP_LINEAR
	else:
		push_error(
			"NPCWalk animation missing. Available: "
			+ str(walk_player.get_animation_list())
		)

	if idle_player.has_animation(idle_animation):
		idle_player.get_animation(
			idle_animation
		).loop_mode = Animation.LOOP_LINEAR
	else:
		push_warning(
			"Idle animation missing. Available: "
			+ str(idle_player.get_animation_list())
		)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var desired_velocity := Vector3.ZERO

	if wait_remaining > 0.0:
		wait_remaining = maxf(
			0.0,
			wait_remaining - delta
		)

	elif not patrol_points.is_empty():
		point_index %= patrol_points.size()
		var point := patrol_points[point_index]

		if is_instance_valid(point):
			var offset := point.global_position - global_position
			offset.y = 0.0

			if offset.length() <= arrival_distance:
				wait_remaining = wait_at_point
				point_index = (
					point_index + 1
				) % patrol_points.size()
			else:
				desired_velocity = offset.normalized() * walk_speed

	# Smooth acceleration, braking, and changes of direction.
	var rate := acceleration

	if desired_velocity.length_squared() < 0.001:
		rate = deceleration

	var horizontal_velocity := Vector2(
		velocity.x,
		velocity.z
	).move_toward(
		Vector2(desired_velocity.x, desired_velocity.z),
		rate * delta
	)

	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.y

	move_and_slide()

	# Use actual movement, including collision response.
	var actual_velocity := get_real_velocity()
	var horizontal_motion := Vector3(
		actual_velocity.x,
		0.0,
		actual_velocity.z
	)
	var actual_speed := horizontal_motion.length()

	if actual_speed > 0.08:
		var target_yaw := atan2(
			-horizontal_motion.x,
			-horizontal_motion.z
		)

		global_rotation.y = lerp_angle(
			global_rotation.y,
			target_yaw,
			1.0 - exp(-turn_speed * delta)
		)

	_update_animation(actual_speed)


func _update_animation(actual_speed: float) -> void:
	var walking := actual_speed > 0.08

	if walking:
		# Match the feet's speed to movement through the world.
		walk_player.speed_scale = clampf(
			actual_speed / maxf(animation_walk_speed, 0.01),
			0.1,
			2.0
		)

		if animation_state != "walk":
			idle_player.stop()

			if walk_player.has_animation(WALK_ANIMATION):
				walk_player.play(WALK_ANIMATION)

			animation_state = "walk"

	else:
		if animation_state != "idle":
			walk_player.stop()
			idle_player.speed_scale = 1.0

			if idle_player.has_animation(idle_animation):
				idle_player.play(idle_animation)

			animation_state = "idle"
