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

var default_twist_y: float = 0.0
var default_pitch_x: float = 0.0

func _ready() -> void:
	if twist_pivot: default_twist_y = twist_pivot.rotation.y
	if pitch_pivot: default_pitch_x = pitch_pivot.rotation.x
	
	if third_person_cam:
		third_person_cam.current = true
	elif first_person_cam:
		first_person_cam.current = true

func handle_mouse_look(event: InputEventMouseMotion, is_climbing: bool, character_body: CharacterBody3D) -> void:
	if is_climbing:
		if twist_pivot:
			twist_pivot.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	else:
		character_body.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
	
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
