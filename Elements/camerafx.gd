extends Camera3D

var is_shaking := false

func _ready() -> void:
	# _ready does not take an 'event' parameter
	shake_pos(0.02, 3.0)

func shake_rot(max_rot_deg: float = 2.0, duration: float = 0.25) -> void:
	if is_shaking: 
		return
	
	is_shaking = true
	var max_rot := deg_to_rad(max_rot_deg)
	var time_left := duration
	var start_rotation := rotation
	
	while time_left > 0:
		var offset_x := randf_range(-max_rot, max_rot) # up/down
		var offset_y := randf_range(-max_rot, max_rot) # left/right
		
		rotation.x = start_rotation.x + offset_x
		rotation.y = start_rotation.y + offset_y
		
		time_left -= get_process_delta_time()
		await get_tree().process_frame
		
	rotation = start_rotation
	is_shaking = false

func shake_pos(intensity: float = 0.02, duration: float = 0.25) -> void:
	if is_shaking: 
		return
		
	is_shaking = true
	var time_left := duration
	var start_position := position
	
	while time_left > 0:
		var offset := Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		
		position = start_position + offset
		time_left -= get_process_delta_time()
		
		await get_tree().process_frame
			
	position = start_position
	is_shaking = false
