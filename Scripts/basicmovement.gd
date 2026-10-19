extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var SPRINT_SPEED : float = 8.0 
@export var ACCELERATION : float = 50.0
@export var DECELERATION : float = 50.0
@export var JUMP_VELOCITY : float = 4.5

# --- State Tracking ---
var is_getting_up: bool = true
var is_climbing: bool = false
var target_climb_y: float = 0.0
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
	
	# Getting up sequence timing & camera transition
	is_getting_up = true
	var anim_length = animator.play_getting_up()
	if anim_length > 0.0:
		var swoop_duration = 1.0
		var wait_time = max(0.1, anim_length - swoop_duration)
		await get_tree().create_timer(wait_time).timeout
		
		if camera_ctrl.third_person_cam and camera_ctrl.first_person_cam:
			camera_ctrl.switch_cameras(camera_ctrl.third_person_cam, camera_ctrl.first_person_cam, swoop_duration)
			await get_tree().create_timer(swoop_duration).timeout
			
	is_getting_up = false
	animator.play_idle()

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if is_getting_up:
		return
		
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_ctrl.handle_mouse_look(event, is_climbing, self)

func _physics_process(delta: float) -> void:
	if is_getting_up:
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	if is_climbing:
		velocity = Vector3.ZERO
		if Input.is_action_just_pressed("jump"):
			force_dismount(false)
		move_and_slide()
		return

	# Gravity & Jump
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
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
func start_climbing(pole_position: Vector3) -> void:
	is_climbing = true
	velocity = Vector3.ZERO
	global_position.x = pole_position.x
	global_position.z = pole_position.z + 0.6
	target_climb_y = global_position.y
	
	look_at(Vector3(pole_position.x, global_position.y, pole_position.z), Vector3.UP)
	
	if camera_ctrl.twist_pivot: camera_ctrl.twist_pivot.rotation.y = camera_ctrl.default_twist_y
	if camera_ctrl.pitch_pivot: camera_ctrl.pitch_pivot.rotation_degrees.x = 15.0
	
	camera_ctrl.switch_cameras(camera_ctrl.first_person_cam, camera_ctrl.climbing_cam, 0.4)
	animator.prepare_climb()
	climbing_started.emit()

func climb_step(height_per_key: float = 0.3, anim_time_per_key: float = 0.15) -> void:
	if not is_climbing: return
	
	audio_ctrl.play_climb_step()
	target_climb_y += height_per_key
	
	if climb_tween and climb_tween.is_valid():
		climb_tween.kill()
		
	climb_tween = create_tween()
	climb_tween.tween_property(self, "global_position:y", target_climb_y, 0.15).set_trans(Tween.TRANS_LINEAR)
	
	animator.step_climb()
	climb_tween.tween_callback(animator.pause)

func force_dismount(is_failing: bool) -> void:
	is_climbing = false
	velocity.y = -2.0 if is_failing else JUMP_VELOCITY
	
	camera_ctrl.reset_pivots(self)
	camera_ctrl.switch_cameras(camera_ctrl.climbing_cam, camera_ctrl.first_person_cam, 0.4)
	climbing_stopped.emit()
