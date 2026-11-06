extends CharacterBody3D

@export_category("Movement")
@export var walk_speed: float = 1.2
@export var acceleration: float = 3.0
@export var deceleration: float = 4.0
@export var turn_speed: float = 8.0
# Use 180 if the imported model faces backward while walking.
@export var facing_offset_degrees: float = 0.0

@export_category("Patrol")
@export var patrol_points: Array[Node3D] = []
@export var wait_at_point: float = 2.0
@export var arrival_distance: float = 0.35

@export_category("Animation")
@export var walk_player: AnimationPlayer
@export var idle_player: AnimationPlayer
# Leave empty only if that player has one non-RESET animation.
@export var walk_animation: StringName = &""
@export var idle_animation: StringName = &""
# Movement speed that matches the walk clip at its original playback rate.
@export var animation_walk_speed: float = 1.2
# Crossfading works when both clips use the same AnimationPlayer.
@export var animation_blend_time: float = 0.2

var point_index: int = 0
var wait_remaining: float = 0.0
var walking_state: bool = false
var stopped_time: float = 0.0
var smoothed_speed: float = 0.0
var current_player: AnimationPlayer
var current_animation: StringName = &""


func _ready() -> void:
	walk_animation = _resolve_animation(walk_player, walk_animation, "Walk")
	idle_animation = _resolve_animation(idle_player, idle_animation, "Idle")

	for animator in [walk_player, idle_player]:
		if is_instance_valid(animator):
			animator.stop(true)
			animator.active = false

	if is_instance_valid(walk_player) and walk_animation != &"":
		walk_player.get_animation(walk_animation).loop_mode = Animation.LOOP_LINEAR
	if is_instance_valid(idle_player) and idle_animation != &"":
		idle_player.get_animation(idle_animation).loop_mode = Animation.LOOP_LINEAR

	if patrol_points.is_empty():
		push_warning(str(name) + ": assign Patrol Points in the Inspector to start walking.")
	elif _get_patrol_target() == null:
		push_warning(str(name) + ": all Patrol Points are empty or invalid.")

	_play_state(false)


func _resolve_animation(animator: AnimationPlayer, requested: StringName, label: String) -> StringName:
	if not is_instance_valid(animator):
		push_warning(str(name) + ": assign " + label + " Player. Patrol movement will still run.")
		return &""
	if requested != &"" and animator.has_animation(requested):
		return requested

	var available: Array[StringName] = []
	for clip in animator.get_animation_list():
		if clip != "RESET" and not clip.ends_with("/RESET"):
			available.append(StringName(clip))
	if requested == &"" and available.size() == 1:
		return available[0]

	push_warning(str(name) + ": set " + label + " Animation. Available: " + str(available))
	return &""


func _get_patrol_target() -> Node3D:
	if patrol_points.is_empty():
		return null
	point_index = posmod(point_index, patrol_points.size())
	# Skip deleted or unassigned markers instead of getting stuck on them.
	for attempt in range(patrol_points.size()):
		var target := patrol_points[point_index]
		if is_instance_valid(target):
			return target
		point_index = (point_index + 1) % patrol_points.size()
	return null


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var desired := Vector3.ZERO
	if wait_remaining > 0.0:
		wait_remaining = maxf(0.0, wait_remaining - delta)
	else:
		var target := _get_patrol_target()
		if target != null:
			var offset := target.global_position - global_position
			offset.y = 0.0
			if offset.length() <= maxf(arrival_distance, 0.05):
				wait_remaining = maxf(wait_at_point, 0.0)
				point_index = (point_index + 1) % patrol_points.size()
			else:
				# Slow down as the NPC approaches the marker.
				var braking_speed := sqrt(2.0 * maxf(deceleration, 0.1) * offset.length())
				desired = offset.normalized() * minf(maxf(walk_speed, 0.0), braking_speed)

	var rate := acceleration if desired.length_squared() > 0.0001 else deceleration
	var horizontal := Vector2(velocity.x, velocity.z).move_toward(
		Vector2(desired.x, desired.z), maxf(rate, 0.1) * delta
	)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	move_and_slide()

	var actual := get_real_velocity()
	var actual_speed := Vector2(actual.x, actual.z).length()
	if actual_speed > 0.03:
		var target_yaw := atan2(-actual.x, -actual.z) + deg_to_rad(facing_offset_degrees)
		global_rotation.y = lerp_angle(
			global_rotation.y, target_yaw, 1.0 - exp(-maxf(turn_speed, 0.0) * delta)
		)
	_update_animation(actual_speed, delta)


func _update_animation(actual_speed: float, delta: float) -> void:
	smoothed_speed = lerpf(smoothed_speed, actual_speed, 1.0 - exp(-10.0 * delta))
	if not walking_state and actual_speed > 0.06:
		walking_state = true
		stopped_time = 0.0
	if walking_state:
		if actual_speed < 0.025:
			stopped_time += delta
			if stopped_time >= 0.15:
				walking_state = false
		else:
			stopped_time = 0.0

	_play_state(walking_state)
	if is_instance_valid(current_player):
		current_player.speed_scale = (
			clampf(smoothed_speed / maxf(animation_walk_speed, 0.01), 0.05, 3.0)
			if walking_state else 1.0
		)


func _play_state(walking: bool) -> void:
	var target := walk_player if walking else idle_player
	var clip := walk_animation if walking else idle_animation
	if not is_instance_valid(target) or clip == &"":
		if is_instance_valid(current_player):
			current_player.stop(true)
			current_player.active = false
		current_player = null
		current_animation = &""
		return

	if current_player != target or current_animation != clip:
		var blend := 0.0
		if is_instance_valid(current_player):
			if current_player == target:
				blend = maxf(animation_blend_time, 0.0)
			else:
				current_player.stop(true)
				current_player.active = false
		target.active = true
		target.play(clip, blend)
		current_player = target
		current_animation = clip
	elif not target.is_playing():
		target.play(clip)
