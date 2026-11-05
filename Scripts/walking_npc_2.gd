extends CharacterBody3D

@export var walk_speed := 1.0
@export var acceleration := 2.0
@export var deceleration := 3.0
@export var turn_speed := 8.0

@export var wait_at_point := 2.0
@export var arrival_distance := 0.4
@export var patrol_points: Array[Node3D] = []

@export var walk_player: AnimationPlayer
@export var idle_player: AnimationPlayer

# Leave empty if each player contains only one non-RESET animation.
@export var walk_animation: StringName = &""
@export var idle_animation: StringName = &""

@export var animation_walk_speed := 1.2

var point_index := 0
var wait_remaining := 0.0
var current_player: AnimationPlayer
var walking_state := false
var stopped_time := 0.0
var smoothed_speed := 0.0

func _ready() -> void:
	if walk_player == null or idle_player == null:
		push_error("Assign Walk Player and Idle Player on WalkingNPC2.")
		set_physics_process(false)
		return

	walk_animation = _find_animation(walk_player, walk_animation)
	idle_animation = _find_animation(idle_player, idle_animation)

	if walk_animation == &"" or idle_animation == &"":
		set_physics_process(false)
		return

	walk_player.stop()
	idle_player.stop()

	walk_player.active = true
	idle_player.active = true

	walk_player.get_animation(
		walk_animation
	).loop_mode = Animation.LOOP_LINEAR

	idle_player.get_animation(
		idle_animation
	).loop_mode = Animation.LOOP_LINEAR


func _find_animation(
	player: AnimationPlayer,
	requested_name: StringName
) -> StringName:
	if requested_name != &"" and player.has_animation(requested_name):
		return requested_name

	var available: Array[StringName] = []

	for name in player.get_animation_list():
		if name != "RESET":
			available.append(StringName(name))

	if requested_name == &"" and available.size() == 1:
		return available[0]

	push_error(
		"Set the animation name for "
		+ str(player.name)
		+ ". Available: "
		+ str(available)
	)

	return &""


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var desired_velocity := Vector3.ZERO

	if wait_remaining > 0.0:
		wait_remaining = maxf(0.0, wait_remaining - delta)

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

	var rate := acceleration

	if desired_velocity.length_squared() < 0.001:
		rate = deceleration

	var horizontal := Vector2(
		velocity.x, velocity.z
	).move_toward(
		Vector2(desired_velocity.x, desired_velocity.z),
		rate * delta
	)

	velocity.x = horizontal.x
	velocity.z = horizontal.y

	move_and_slide()

	var actual := get_real_velocity()
	var actual_speed := Vector2(actual.x, actual.z).length()

	if actual_speed > 0.08:
		var target_yaw := atan2(-actual.x, -actual.z)

		global_rotation.y = lerp_angle(
			global_rotation.y,
			target_yaw,
			1.0 - exp(-turn_speed * delta)
		)

	_update_animation(actual_speed, delta)


func _update_animation(actual_speed: float, delta: float) -> void:
	smoothed_speed = lerpf(
		smoothed_speed,
		actual_speed,
		1.0 - exp(-8.0 * delta)
	)

	# Start walking once movement is clear.
	if not walking_state and actual_speed > 0.15:
		walking_state = true
		stopped_time = 0.0

	# Require a short, consistent stop before playing Idle.
	if walking_state:
		if actual_speed < 0.05:
			stopped_time += delta

			if stopped_time >= 0.25:
				walking_state = false
		else:
			stopped_time = 0.0

	var target: AnimationPlayer
	var other: AnimationPlayer
	var animation_name: StringName

	if walking_state:
		target = walk_player
		other = idle_player
		animation_name = walk_animation

		walk_player.speed_scale = clampf(
			smoothed_speed / maxf(animation_walk_speed, 0.01),
			0.25,
			2.0
		)
	else:
		target = idle_player
		other = walk_player
		animation_name = idle_animation
		idle_player.speed_scale = 1.0

	if current_player != target:
		# Keep the previous pose until the new player takes over.
		other.stop(true)
		other.active = false

		target.active = true
		current_player = target
		target.play(animation_name)

	elif not target.is_playing():
		target.play(animation_name)
