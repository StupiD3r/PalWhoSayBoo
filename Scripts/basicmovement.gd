extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var SPRINT_SPEED : float = 18.0 
@export var ACCELERATION : float = 50.0
@export var DECELERATION : float = 50.0
@export var JUMP_VELOCITY : float = 4.5
@export_range(0.0, 3.0, 0.05) var slide_speed: float = 0.35

# --- State Tracking ---
var is_climbing: bool = false
var typing_uses_space: bool = false
var target_climb_y: float = 0.0
var max_climb_y: float = INF
var min_climb_y: float = 0.0
var climb_tween: Tween

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
		velocity = Vector3.ZERO
		# Space never dismounts; slide and typing control the climb.
		target_climb_y = maxf(min_climb_y, target_climb_y - slide_speed * delta)
		global_position.y = clampf(lerpf(global_position.y, target_climb_y, 1.0 - exp(-20.0 * delta)), min_climb_y, max_climb_y)
		move_and_slide()
		return

	# Gravity & Jump
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
		if is_on_floor(): audio_ctrl.play_walk_step()
		else: audio_ctrl.stop_walk_step()
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)
		audio_ctrl.stop_walk_step()

	move_and_slide()
	
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	animator.update_ground_animation(horizontal_speed, is_on_floor(), Input.is_action_pressed("run"))

# --- CLIMBING LOGIC ---
func start_climbing(pole_position: Vector3, height_limit: float = INF) -> void:
	is_climbing = true
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
	if not is_climbing: return
	
	audio_ctrl.play_climb_step()
	target_climb_y = minf(target_climb_y + height_per_key, max_climb_y)
	
	if climb_tween and climb_tween.is_valid():
		climb_tween.kill()
		
	climb_tween = create_tween()
	climb_tween.tween_interval(anim_time_per_key)
	
	animator.step_climb()
	climb_tween.tween_callback(animator.pause)

func force_dismount(is_failing: bool) -> void:
	typing_uses_space = false
	if climb_tween and climb_tween.is_valid():
		climb_tween.kill()
	is_climbing = false
	velocity.y = -2.0 if is_failing else JUMP_VELOCITY
	
	camera_ctrl.reset_pivots(self)
	camera_ctrl.switch_cameras(camera_ctrl.climbing_cam, camera_ctrl.first_person_cam, 0.4)
	climbing_stopped.emit()
