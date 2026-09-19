extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var ACCELERATION : float = 10.0
@export var DECELERATION : float = 10.0
@export var JUMP_VELOCITY : float = 4.5
@export var CLIMB_SPEED : float = 3.0

# --- Camera Settings ---
@export var MOUSE_SENSITIVITY : float = 0.003
@export var PITCH_MIN : float = -60.0 # Max degrees looking down
@export var PITCH_MAX : float = 60.0  # Max degrees looking up

# --- Node Connections (Assigned in your Inspector) ---
@export var twist_pivot: Node3D
@export var pitch_pivot: Node3D

@onready var animation_player: AnimationPlayer = $Barbarian/AnimationPlayer

# --- CLIMBING STATE ---
var is_climbing = false

func _ready() -> void:
	# Captures the mouse cursor so it stays locked inside the game window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Plays the default idle animation when the game starts
	if animation_player.has_animation("global/Idle_A"):
		animation_player.play("global/Idle_A")

func _unhandled_input(event: InputEvent) -> void:
	# --- Release/Capture Mouse toggle for testing ---
	if Input.is_action_just_pressed("ui_cancel"): # "ui_cancel" is Escape by default
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# --- Handle Mouse Look Panning and Tilting ---
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Yaw: Rotates the WHOLE player body left/right so the Barbarian faces the camera direction
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		# Pitch: Rotates the camera up/down
		pitch_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		
		# Clamp the pitch rotation so the camera doesn't flip upside down
		var clamped_pitch = pitch_pivot.rotation.x
		clamped_pitch = clamp(clamped_pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		pitch_pivot.rotation.x = clamped_pitch

func _physics_process(delta: float) -> void:
	# Safety check: Prevent errors if nodes aren't linked in the inspector
	if not twist_pivot or not pitch_pivot:
		return

	# --- 1. CLIMBING OVERRIDE ---
	if is_climbing:
		# W/Up key gives 1, S/Down key gives -1
		var climb_dir = Input.get_axis("ui_down", "ui_up")
		velocity.y = climb_dir * CLIMB_SPEED
		velocity.x = 0
		velocity.z = 0
		
		# Press Spacebar (ui_accept) to jump off the pole
		if Input.is_action_just_pressed("ui_accept"):
			is_climbing = false
			velocity.y = JUMP_VELOCITY
		
		move_and_slide()
		return # Skips normal gravity and walking code below!

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

	# --- 5. ANIMATION CONTROLLER LOOP ---
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	
	if is_on_floor():
		if horizontal_velocity > 0.1:
			if animation_player.current_animation != "global/Walking_A":
				animation_player.play("global/Walking_A")
		else:
			if animation_player.current_animation != "global/Idle_A":
				animation_player.play("global/Idle_A")

# --- 6. ATTACH TRIGGER (Called by the Pole) ---
func start_climbing(pole_position):
	is_climbing = true
	global_position.x = pole_position.x
	# Increased offset to 2.0 so you don't get trapped inside the pole's solid shape
	global_position.z = pole_position.z + 2.0 
	velocity = Vector3.ZERO
