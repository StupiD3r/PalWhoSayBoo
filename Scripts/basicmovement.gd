extends CharacterBody3D

# --- Movement Settings ---
@export var SPEED : float = 5.0
@export var SPRINT_SPEED : float = 8.0 
@export var ACCELERATION : float = 50.0
@export var DECELERATION : float = 50.0
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

# Updated to target the new Player child node
@onready var animation_player: AnimationPlayer = $"Player/AnimationPlayer"

# --- CLIMBING STATE & SIGNALS ---
var is_climbing = false
signal climbing_started
signal climbing_stopped

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if animation_player and animation_player.has_animation("custom/idle2"):
		animation_player.play("custom/idle2")

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
	# Check if the run button is pressed
	var current_speed = SPRINT_SPEED if Input.is_action_pressed("run") else SPEED
	
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
		# FIXED: Now uses current_speed so the player actually moves faster when running
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)
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
	var blend_time = 0.2 # 0.2 seconds of smooth crossfading

	if not is_on_floor():
		# PLACEHOLDER: Update "HumanArmature|Man_Jump" when you import a Mixamo Jump animation
		if animation_player.current_animation != "custom/jumping" and animation_player.has_animation("custom/jumping"):
			animation_player.play("custom/jumping", blend_time)
	elif horizontal_velocity > 0.1:
		# Check if running while moving
		if Input.is_action_pressed("run"):
			if animation_player.current_animation != "custom/running" and animation_player.has_animation("custom/running"):
				animation_player.play("custom/running", blend_time)
		else:
			# Play Walk animation
			if animation_player.current_animation != "mixamo_com" and animation_player.has_animation("mixamo_com"):
				animation_player.play("mixamo_com", blend_time)
	else:
		if animation_player.current_animation != "custom/idle2" and animation_player.has_animation("custom/idle2"):
			animation_player.play("custom/idle2", blend_time)

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

	# Set the climbing animation and pause it immediately
	if animation_player.has_animation("custom/climbing"):
		animation_player.play("custom/climbing")
		animation_player.pause()
	else:
		# If you see this in your Output at the bottom, your name is wrong!
		print("ERROR: Could not find custom/climbing!")

	# Trigger the typing UI!
	climbing_started.emit()

# --- MANUAL TYPING MOVEMENT ---
func climb_step(height_per_key: float = 0.3, anim_time_per_key: float = 0.15) -> void:
	if not is_climbing or not animation_player:
		return
		
	# 1. Move the character up the pole
	global_position.y += height_per_key
	
	# 2. Safety Check: Force the climbing animation if it somehow got changed
	if animation_player.assigned_animation != "custom/climbing":
		animation_player.play("custom/climbing", 0.0)
		animation_player.pause()
	
	# 3. Advance the paused animation forward
	var current_pos = animation_player.current_animation_position
	var anim_length = animation_player.current_animation_length
	
	# Prevent errors if the animation length is 0 (e.g., corrupted animation)
	if anim_length > 0:
		var new_pos = current_pos + anim_time_per_key
		if new_pos >= anim_length:
			new_pos -= anim_length
			
		animation_player.seek(new_pos, true)
		print("Stepped animation to frame: ", new_pos)
	else:
		print("ERROR: Climbing animation length is 0. Check your animation file!")
