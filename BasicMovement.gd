extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var ACCELERATION : float = 10.0
@export var DECELERATION : float = 10.0
@export var JUMP_VELOCITY : float = 4.5

# --- Camera Settings ---
@export var MOUSE_SENSITIVITY : float = 0.003
@export var PITCH_MIN : float = -60.0 # Max degrees looking down
@export var PITCH_MAX : float = 60.0  # Max degrees looking up

# --- Node Connections (Assigned in your Inspector) ---
@export var twist_pivot: Node3D
@export var pitch_pivot: Node3D

@onready var animation_player: AnimationPlayer = $Barbarian/AnimationPlayer

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
		
		# Pitch: Rotates the camera up/down (Removed minus sign to fix inversion)
		pitch_pivot.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		
		# Clamp the pitch rotation so the camera doesn't flip upside down
		var clamped_pitch = pitch_pivot.rotation.x
		clamped_pitch = clamp(clamped_pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))
		pitch_pivot.rotation.x = clamped_pitch

func _physics_process(delta: float) -> void:
	# Safety check: Prevent errors if nodes aren't linked in the inspector
	if not twist_pivot or not pitch_pivot:
		return

	# Add gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump (Assumes you named your mapping "jump")
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get input direction based on your exact input map settings ("move_up" is W, "move_down" is S)
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# Calculate direction relative to where the player body is currently facing
	var direction := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# FIXED: Restored movement logic code block
	if direction:
		# Smooth acceleration toward the target speed
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCELERATION * delta)
	else:
		# Smoothly decelerate to a stop when no keys are pressed
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)

	move_and_slide()

	# --- ANIMATION CONTROLLER LOOP ---
	# FIXED: Corrected structural nesting indentation
	var horizontal_velocity = Vector2(velocity.x, velocity.z).length()
	
	if is_on_floor():
		if horizontal_velocity > 0.1:
			# Player is moving! Play the running animation track
			if animation_player.current_animation != "global/Walking_A":
				animation_player.play("global/Walking_A")
		else:
			# Player is standing still. Play the idle track
			if animation_player.current_animation != "global/Idle_A":
				animation_player.play("global/Idle_A")
