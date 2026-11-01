extends Node3D

# --- Camera Settings ---
@export var MOUSE_SENSITIVITY : float = 0.003
@export var PITCH_MIN : float = -60.0
@export var PITCH_MAX : float = 40.0

@export var twist_pivot: Node3D
@export var pitch_pivot: Node3D

@export var first_person_cam: Camera3D
@export var climbing_cam: Camera3D 
@export var transition_cam: Camera3D
@export var third_person_cam: Camera3D

@export_group("First Person Movement")
@export var walk_bob_amount: float = 0.018
@export var run_bob_amount: float = 0.032
@export var walk_bob_frequency: float = 1.7
@export var run_bob_frequency: float = 2.6
@export var sway_degrees: float = 1.2
@export var sprint_fov_boost: float = 6.0
@export var landing_dip_amount: float = 0.065

var rest_camera_position: Vector3
var rest_camera_roll: float = 0.0
var rest_camera_fov: float = 75.0
var bob_phase: float = 0.0
var motion_offset: Vector3 = Vector3.ZERO
var turn_sway: float = 0.0
var landing_elapsed: float = 1.0
var landing_strength: float = 0.0

var default_twist_y: float = 0.0
var default_pitch_x: float = 0.0

func _ready() -> void:
	if twist_pivot: default_twist_y = twist_pivot.rotation.y
	if pitch_pivot: default_pitch_x = pitch_pivot.rotation.x
	if first_person_cam:
		rest_camera_position = first_person_cam.position
		rest_camera_roll = first_person_cam.rotation.z
		rest_camera_fov = first_person_cam.fov
	
	if third_person_cam:
		third_person_cam.current = true
	elif first_person_cam:
		first_person_cam.current = true

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null or first_person_cam == null:
		return
	if not first_person_cam.current or body.get("is_climbing") == true:
		_reset_movement_camera()
		return
	var walking_speed := float(body.get("SPEED"))
	_update_movement_camera(delta, body.velocity, body.is_on_floor(), Input.is_action_pressed("run"), walking_speed, body.global_basis)

func _update_movement_camera(delta: float, velocity: Vector3, grounded: bool, sprinting: bool, walking_speed: float, body_basis: Basis) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := grounded and speed > 0.15
	var running := moving and sprinting and speed > walking_speed * 1.1
	var blend := 1.0 - exp(-10.0 * delta)
	var target_offset := Vector3.ZERO
	if moving:
		var frequency := run_bob_frequency if running else walk_bob_frequency
		var amount := run_bob_amount if running else walk_bob_amount
		var intensity := clampf(speed / maxf(walking_speed, 0.1), 0.0, 1.0)
		bob_phase = fmod(bob_phase + delta * TAU * frequency * intensity, TAU * 2.0)
		target_offset = Vector3(sin(bob_phase * 0.5) * amount * 0.5, sin(bob_phase) * amount, 0.0) * intensity
	motion_offset = motion_offset.lerp(target_offset, blend)
	landing_elapsed += delta
	var landing_weight := 0.0
	if landing_elapsed < 0.07:
		landing_weight = smoothstep(0.0, 0.07, landing_elapsed)
	elif landing_elapsed < 0.42:
		landing_weight = 1.0 - smoothstep(0.07, 0.42, landing_elapsed)
	first_person_cam.position = rest_camera_position + motion_offset + Vector3.DOWN * landing_dip_amount * landing_strength * landing_weight
	var local_velocity := body_basis.orthonormalized().inverse() * velocity
	var strafe := clampf(local_velocity.x / maxf(walking_speed, 0.1), -1.0, 1.0) if moving else 0.0
	var target_roll := deg_to_rad(-strafe * sway_degrees) + turn_sway
	first_person_cam.rotation.z = lerpf(first_person_cam.rotation.z, rest_camera_roll + target_roll, blend)
	turn_sway = lerpf(turn_sway, 0.0, 1.0 - exp(-8.0 * delta))
	var target_fov := rest_camera_fov + (sprint_fov_boost if running else 0.0)
	first_person_cam.fov = lerpf(first_person_cam.fov, target_fov, 1.0 - exp(-5.0 * delta))

func _reset_movement_camera() -> void:
	if first_person_cam == null:
		return
	first_person_cam.position = rest_camera_position
	first_person_cam.rotation.z = rest_camera_roll
	first_person_cam.fov = rest_camera_fov
	motion_offset = Vector3.ZERO
	turn_sway = 0.0
	bob_phase = 0.0
	landing_elapsed = 1.0
	landing_strength = 0.0

func play_landing(fall_speed: float) -> bool:
	if first_person_cam == null or not first_person_cam.current or fall_speed < 2.5:
		return false
	landing_strength = clampf(inverse_lerp(2.5, 12.0, fall_speed), 0.25, 1.0)
	landing_elapsed = 0.0
	return true

func handle_mouse_look(event: InputEventMouseMotion, is_climbing: bool, character_body: CharacterBody3D) -> void:
	if is_climbing:
		if twist_pivot:
			twist_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	else:
		character_body.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		turn_sway = clampf(turn_sway - event.relative.x * 0.00008, -deg_to_rad(sway_degrees), deg_to_rad(sway_degrees))
	
	if pitch_pivot:
		pitch_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))

func reset_pivots(character_body: CharacterBody3D) -> void:
	if twist_pivot:
		character_body.global_rotation.y = twist_pivot.global_rotation.y
		twist_pivot.rotation.y = default_twist_y
	if pitch_pivot:
		pitch_pivot.rotation.x = default_pitch_x

func switch_cameras(from_cam: Camera3D, to_cam: Camera3D, duration: float = 0.8, player_mesh: Node3D = null) -> void:
	if not transition_cam or not from_cam or not to_cam:
		if to_cam: to_cam.current = true
		if player_mesh: player_mesh.visible = false
		return
		
	# 1. Lock transition camera to starting position AND rotation
	var start_pos = from_cam.global_position
	transition_cam.global_transform = from_cam.global_transform
	transition_cam.current = true
	
	# Distance threshold (meters) before snapping into FPV view
	var transition_distance_limit: float = 0.4
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_method(func(weight: float):
		var target_pos = to_cam.global_position
		
		# 2. Push straight forward toward the target position without turning
		transition_cam.global_position = start_pos.lerp(target_pos, weight)
		
		# 3. Check distance limit to the player's head
		var dist_to_head = transition_cam.global_position.distance_to(target_pos)
		
		# Hide mesh right before crossing into skull space
		if player_mesh and dist_to_head <= transition_distance_limit:
			player_mesh.visible = false
	, 0.0, 1.0, duration)
	
	# 4. Snap view directly to FPV at the end of the move
	tween.chain().tween_callback(func(): 
		if player_mesh: player_mesh.visible = true
		to_cam.current = true
	)
