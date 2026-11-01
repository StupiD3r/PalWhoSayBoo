extends CharacterBody3D

@export var walk_speed := 1.2
@export var wait_at_point := 2.0
@export var arrival_distance := 0.4

# Assign markers from Main through the Inspector.
@export var patrol_points: Array[Node3D] = []

@onready var walk_player: AnimationPlayer = $Model/SideChar/NPCWalk
@onready var idle_player: AnimationPlayer = $Model/SideChar/NPCIdle

@export var walk_animation: StringName = &"NPCWalk"
@export var idle_animation: StringName = &"NPCIdle"

var point_index := 0
var wait_remaining := 0.0


func _ready() -> void:
	# Override any old animation name saved in the Inspector.
	walk_animation = &"NPCWalk"

	walk_player.stop()
	idle_player.stop()

	walk_player.active = true
	idle_player.active = true

	if walk_player.has_animation(walk_animation):
		walk_player.get_animation(
			walk_animation
		).loop_mode = Animation.LOOP_LINEAR
	else:
		push_error(
			"Missing walk animation on: "
			+ str(walk_player.get_path())
			+ ". Available: "
			+ str(walk_player.get_animation_list())
		)

	if idle_player.has_animation(idle_animation):
		idle_player.get_animation(
			idle_animation
		).loop_mode = Animation.LOOP_LINEAR

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0

	var direction := Vector3.ZERO

	if wait_remaining > 0.0:
		wait_remaining = maxf(0.0, wait_remaining - delta)

	elif not patrol_points.is_empty():
		var point := patrol_points[point_index]

		if is_instance_valid(point):
			var offset := point.global_position - global_position

			# Gravity handles terrain height.
			offset.y = 0.0

			if offset.length() <= arrival_distance:
				wait_remaining = wait_at_point
				point_index = (
					point_index + 1
				) % patrol_points.size()
			else:
				direction = offset.normalized()

	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	if direction.length_squared() > 0.0:
		var target_yaw := atan2(-direction.x, -direction.z)

		global_rotation.y = lerp_angle(
			global_rotation.y,
			target_yaw,
			1.0 - exp(-8.0 * delta)
		)

	move_and_slide()

	var actual_velocity := get_real_velocity()
	var horizontal_speed := Vector2(
		actual_velocity.x,
		actual_velocity.z
	).length()

	if horizontal_speed > 0.1:
		_play_animation(walk_animation)
	else:
		_play_animation(idle_animation)


func _play_animation(animation_name: StringName) -> void:
	var target: AnimationPlayer
	var other: AnimationPlayer

	if animation_name == walk_animation:
		target = walk_player
		other = idle_player
	else:
		target = idle_player
		other = walk_player

	if not target.has_animation(animation_name):
		return

	# Prevent both players from animating the skeleton together.
	if other.is_playing():
		other.stop()

	if target.current_animation != animation_name \
	or not target.is_playing():
		target.play(animation_name, 0.2)
