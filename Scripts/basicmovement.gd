extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var SPRINT_SPEED : float = 18.0 
@export var ACCELERATION : float = 50.0
@export var DECELERATION : float = 50.0
@export var JUMP_VELOCITY : float = 4.5
@export_range(0.0, 3.0, 0.05) var slide_speed: float = 0.35
@export_range(0.0, 1.0, 0.05) var typo_slip_distance: float = 0.15
@export_range(0.0, 2.0, 0.05) var repeated_typo_slip_distance: float = 0.30

# --- State Tracking ---
var is_climbing: bool = false
var climb_resting: bool = false
var typing_uses_space: bool = false
var target_climb_y: float = 0.0
var max_climb_y: float = INF
var min_climb_y: float = 0.0
var climb_tween: Tween
var consecutive_typing_errors: int = 0

# --- Signals ---
signal climbing_started
signal climbing_stopped

# --- Component References ---
@onready var camera_ctrl: Node3D = $PlayerCamera
@onready var animator: Node = $PlayerAnimator
@onready var audio_ctrl: Node = $PlayerAudio

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Start standing in first person, with no introductory movement lock.
	animator.play_idle()
	if camera_ctrl.first_person_cam:
		camera_ctrl.first_person_cam.make_current()
		$Player.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_ctrl.handle_mouse_look(event, is_climbing, self)

func _physics_process(delta: float) -> void:

	if is_climbing:
		audio_ctrl.stop_walk_step()
		velocity = Vector3.ZERO
		if climb_resting:
			return
		# Space never dismounts; slide and typing control the climb.
		target_climb_y = maxf(min_climb_y, target_climb_y - slide_speed * delta)
		global_position.y = clampf(lerpf(global_position.y, target_climb_y, 1.0 - exp(-20.0 * delta)), min_climb_y, max_climb_y)
		move_and_slide()
		return

	# Gravity & Jump
	var was_grounded := is_on_floor()
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump") and not typing_uses_space:
		velocity.y = JUMP_VELOCITY

	# Locomotion
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("run") else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)
		audio_ctrl.stop_walk_step()

	var fall_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	if not was_grounded and is_on_floor() and fall_speed >= 2.5:
		camera_ctrl.play_landing(fall_speed)
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and direction != Vector3.ZERO and horizontal_speed > 0.15:
		audio_ctrl.play_walk_step(Input.is_action_pressed("run") and horizontal_speed > SPEED * 1.1)
	else:
		audio_ctrl.stop_walk_step()
	animator.update_ground_animation(horizontal_speed, is_on_floor(), Input.is_action_pressed("run"))

# --- CLIMBING LOGIC ---
func start_climbing(pole_position: Vector3, height_limit: float = INF) -> void:
	climb_resting = false
	audio_ctrl.stop_walk_step()
	audio_ctrl.start_climb_voice()
	is_climbing = true
	consecutive_typing_errors = 0
	velocity = Vector3.ZERO
	
	# 1. Unhide player mesh so character is visible on the pole!
	$Player.visible = true
	
	global_position.x = pole_position.x
	global_position.z = pole_position.z + 0.6
	target_climb_y = global_position.y
	min_climb_y = global_position.y
	max_climb_y = maxf(global_position.y, height_limit)
	
	look_at(Vector3(pole_position.x, global_position.y, pole_position.z), Vector3.UP)
	
	if camera_ctrl.twist_pivot: camera_ctrl.twist_pivot.rotation.y = camera_ctrl.default_twist_y
	if camera_ctrl.pitch_pivot: camera_ctrl.pitch_pivot.rotation_degrees.x = 15.0
	
	# 2. Smoothly swoop from FPV into the third-person climbing angle
	camera_ctrl.switch_cameras(camera_ctrl.first_person_cam, camera_ctrl.climbing_cam, 0.4)
	animator.prepare_climb()
	climbing_started.emit()

func climb_step(height_per_key: float = 0.3, anim_time_per_key: float = 0.15) -> void:
	if not is_climbing or climb_resting: return
	consecutive_typing_errors = 0
	
	audio_ctrl.play_climb_step()
	target_climb_y = minf(target_climb_y + height_per_key, max_climb_y)
	
	if climb_tween and climb_tween.is_valid():
		climb_tween.kill()
		
	climb_tween = create_tween()
	climb_tween.tween_interval(anim_time_per_key)
	
	animator.step_climb()
	climb_tween.tween_callback(animator.pause)

func force_dismount(is_failing: bool) -> void:
	climb_resting = false
	audio_ctrl.stop_climb_voice()
	consecutive_typing_errors = 0
	typing_uses_space = false
	if climb_tween and climb_tween.is_valid():
		climb_tween.kill()
	is_climbing = false
	velocity.y = -2.0 if is_failing else JUMP_VELOCITY
	
	camera_ctrl.reset_pivots(self)
	camera_ctrl.switch_cameras(camera_ctrl.climbing_cam, camera_ctrl.first_person_cam, 0.4)
	climbing_stopped.emit()

func set_climb_resting(resting: bool) -> void:
	climb_resting = resting
	velocity = Vector3.ZERO
	if resting:
		target_climb_y = global_position.y
		if climb_tween and climb_tween.is_valid():
			climb_tween.kill()
		animator.pause()
	audio_ctrl.set_climb_resting(resting)

func on_typing_error() -> void:
	if not is_climbing or climb_resting:
		return
	consecutive_typing_errors += 1
	var repeated := consecutive_typing_errors % 3 == 0
	var distance := repeated_typo_slip_distance if repeated else typo_slip_distance
	# Move both the actual height and its target so queued steps cannot erase the slip.
	global_position.y = maxf(min_climb_y, global_position.y - distance)
	target_climb_y = maxf(min_climb_y, target_climb_y - distance)
	if audio_ctrl and audio_ctrl.has_method("play_typing_mistake"):
		audio_ctrl.play_typing_mistake(repeated)
