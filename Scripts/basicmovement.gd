extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var ACCELERATION : float = 10.0
@export var DECELERATION : float = 10.0
@export var JUMP_VELOCITY : float = 4.5
@export var CLIMB_SPEED : float = 3.0

# --- Camera Settings ---
@export var MOUSE_SENSITIVITY : float = 0.003
@export var PITCH_MIN : float = -60.0
@export var PITCH_MAX : float = 60.0
@export var third_person_cam: Camera3D
@export var first_person_cam: Camera3D

# --- Node Connections ---
@export var twist_pivot: Node3D
@export var pitch_pivot: Node3D

@onready var animation_player: AnimationPlayer = $"Man/AnimationPlayer"

# --- CLIMBING STATE & SIGNALS ---
var is_climbing = false
signal climbing_started
signal climbing_stopped

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if animation_player and animation_player.has_animation("HumanArmature|Man_Idle"):
		animation_player.play("HumanArmature|Man_Idle")

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# --- Handle Mouse Look Panning and Tilting ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_climbing:
			# STATIC BODY IN FIRST PERSON: Pan using the twist pivot instead of rotating the whole body
			if twist_pivot:
				twist_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		else:
			# NORMAL GROUND LOOK: Rotate the entire character body left/right
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Pitch: Look up/down (applies in both ground and climbing states)
		if pitch_pivot:
			pitch_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
			var clamped_pitch = clamp(pitch_pivot.rotation.x, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
			pitch_pivot.rotation.x = clamped_pitch

func _physics_process(delta: float) -> void:
	if not twist_pivot or not pitch_pivot:
		return

	# --- 1. CLIMBING OVERRIDE ---
	if is_climbing:
		# Manual WASD movement disabled during typing minigame!
		velocity.x = 0
		velocity.y = 0
		velocity.z = 0
		
		# Spacebar acts as the exit key to dismount from the pole
		if Input.is_action_just_pressed("jump"):
			is_climbing = false
			velocity.y = JUMP_VELOCITY
			
			# Reset camera pivots for normal ground view
			if twist_pivot:
				twist_pivot.rotation.y = 0
			if pitch_pivot:
				pitch_pivot.rotation.x = 0
			
			if third_person_cam:
				third_person_cam.current = true
			
			# EMIT SIGNAL TO HIDE TYPING UI
			climbing_stopped.emit()
		
		move_and_slide()
		_update_climbing_animations(0.0) # Pause or keep idle climbing frame
		return

	# --- 2. NORMAL GRAVITY ---
	if not is_on_floor():
		velocity += get_gravity() * delta

	# --- 3. NORMAL JUMPING ---
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# --- 4. NORMAL WALKING ---
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)

	move_and_slide()
	_update_ground_animations()

# --- GROUND/AIR ANIMATIONS ---
func _update_ground_animations() -> void:
	if not animation_player:
		return

	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()

	if not is_on_floor():
		if animation_player.current_animation != "HumanArmature|Man_Jump" and animation_player.has_animation("HumanArmature|Man_Jump"):
			animation_player.play("HumanArmature|Man_Jump")
	elif horizontal_velocity > 0.1:
		if animation_player.current_animation != "HumanArmature|Man_Walk" and animation_player.has_animation("HumanArmature|Man_Walk"):
			animation_player.play("HumanArmature|Man_Walk")
	else:
		if animation_player.current_animation != "HumanArmature|Man_Idle" and animation_player.has_animation("HumanArmature|Man_Idle"):
			animation_player.play("HumanArmature|Man_Idle")

# --- CLIMBING ANIMATIONS ---
func _update_climbing_animations(climb_dir: float) -> void:
	if not animation_player:
		return

	if climb_dir != 0:
		if animation_player.current_animation != "HumanArmature|Man_Walk" and animation_player.has_animation("HumanArmature|Man_Walk"):
			animation_player.play("HumanArmature|Man_Walk")
	else:
		if animation_player.is_playing():
			animation_player.pause()

# --- ATTACH TRIGGER ---
func start_climbing(pole_position):
	is_climbing = true
	velocity = Vector3.ZERO
	
	global_position.x = pole_position.x
	global_position.z = pole_position.z + 0.6
	
	look_at(Vector3(pole_position.x, global_position.y, pole_position.z), Vector3.UP)
	
	if twist_pivot:
		twist_pivot.rotation.y = 0
	if pitch_pivot:
		pitch_pivot.rotation.x = 0
	
	if first_person_cam:
		first_person_cam.current = true

	# Trigger the typing UI!
	climbing_started.emit()
