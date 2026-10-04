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
@export var first_person_cam: Camera3D
@export var climbing_cam: Camera3D 
@export var transition_cam: Camera3D # Add this!

# --- State Tracking ---
var target_climb_y: float = 0.0
var climb_tween: Tween
var default_twist_y: float = 0.0
var default_pitch_x: float = 0.0

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
	
	# Save your editor camera rotation so it never flips backwards!
	if twist_pivot:
		default_twist_y = twist_pivot.rotation.y
	if pitch_pivot:
		default_pitch_x = pitch_pivot.rotation.x
	
	# Force the correct camera on startup!
	if first_person_cam:
		first_person_cam.current = true
	
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
			
			# Align the body to where the camera is looking, then restore default offsets
			if twist_pivot:
				var look_dir = twist_pivot.global_rotation.y
				global_rotation.y = look_dir
				twist_pivot.rotation.y = default_twist_y
				
			if pitch_pivot:
				pitch_pivot.rotation.x = default_pitch_x
			
			# Switch back to first-person walking view
			switch_cameras(climbing_cam, first_person_cam, 0.4) # 0.4 seconds to fly out
			
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
	
	target_climb_y = global_position.y # Anchor for smooth climbing
	
	look_at(Vector3(pole_position.x, global_position.y, pole_position.z), Vector3.UP)
	
	# Use the memorized default instead of hardcoding 0
	if twist_pivot: twist_pivot.rotation.y = default_twist_y
	if pitch_pivot: pitch_pivot.rotation_degrees.x = 15.0 
	
	# Activate the dedicated climbing camera!
	switch_cameras(first_person_cam, climbing_cam, 0.4) # 0.4 seconds to fly in

	if animation_player.has_animation("custom/climbing"):
		# The '0.0' forces it to ignore blend times and cut instantly
		animation_player.play("custom/climbing", 0.0)
		
		# The 'true' forces the 3D skeleton to physically update its pose this exact frame
		animation_player.seek(0.0, true)
		
		animation_player.pause()

	climbing_started.emit()

# --- MANUAL TYPING MOVEMENT ---
func climb_step(height_per_key: float = 0.3, anim_time_per_key: float = 0.15) -> void:
	if not is_climbing or not animation_player:
		return
		
	# 1. Update the absolute target height so you never lose distance if you type fast
	target_climb_y += height_per_key
	
	# 2. Stop the old tween if typing quickly, and smoothly bridge to the new height
	if climb_tween and climb_tween.is_valid():
		climb_tween.kill()
		
	climb_tween = get_tree().create_tween()
	climb_tween.tween_property(self, "global_position:y", target_climb_y, 0.15).set_trans(Tween.TRANS_LINEAR)
	
	# 3. Let the animation play continuously and naturally
	if animation_player.assigned_animation != "custom/climbing":
		animation_player.play("custom/climbing")
		
	if not animation_player.is_playing():
		animation_player.play()
		
	# 4. Automatically pause the animation exactly when the upward sliding stops!
	climb_tween.tween_callback(animation_player.pause)

# --- CAMERA SWOOP TRANSITION ---
func switch_cameras(from_cam: Camera3D, to_cam: Camera3D, duration: float = 0.5) -> void:
	if not transition_cam or not from_cam or not to_cam:
		if to_cam: to_cam.current = true
		return
		
	# 1. Snap the transition camera to your current exact view
	transition_cam.global_transform = from_cam.global_transform
	transition_cam.current = true
	
	# 2. Smoothly fly to the new camera's position and rotation
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(transition_cam, "global_position", to_cam.global_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Using quaternion ensures the camera rotation blends perfectly without flipping upside down
	tween.tween_property(transition_cam, "quaternion", to_cam.global_transform.basis.get_rotation_quaternion(), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Hand control over to the actual destination camera when the flight finishes
	tween.chain().tween_callback(func(): to_cam.current = true)
	


func update_wpm(new_wpm: int) -> void:
	pass # Replace with function body.
