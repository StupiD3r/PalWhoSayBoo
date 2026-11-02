extends Area3D

@onready var radio_audio: AudioStreamPlayer3D = $RadioAudio
@export var play_only_once: bool = true
@export var turn_duration: float = 0.16
@export var look_duration: float = 2.0
@export var return_duration: float = 0.65
@export_range(0.0, 30.0) var focus_zoom_degrees: float = 10.0
@export_range(-40.0, 0.0) var scare_volume_db: float = -12.0
@export_range(0.0, 3.0) var scare_jolt_degrees: float = 1.2

var has_played: bool = false
var pending_player: Node3D
var focused_player: Node3D
var original_camera: Camera3D
var focus_camera: Camera3D
var previous_process_mode: Node.ProcessMode
var original_transform: Transform3D
var look_transform: Transform3D
var elapsed: float = 0.0
var original_fov: float = 75.0
var focused_fov: float = 65.0
var static_sound: AudioStreamPlayer
var radio_volume_db: float = 0.0
var radio_duck: Tween


func _ready() -> void:
	radio_volume_db = radio_audio.volume_db
	static_sound = AudioStreamPlayer.new()
	static_sound.name = "RadioScareStinger"
	static_sound.stream = preload("res://Assets/Audio/stinger.mp3")
	add_child(static_sound)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player" or (play_only_once and has_played):
		return
	if is_instance_valid(focused_player) or is_instance_valid(pending_player):
		return
	if not radio_audio.playing:
		radio_audio.play()
	has_played = true
	pending_player = body


func _on_body_exited(body: Node3D) -> void:
	if body == pending_player:
		pending_player = null


func _process(delta: float) -> void:
	if is_instance_valid(pending_player):
		# Opening/retry cameras own the view until normal movement resumes.
		var active := get_viewport().get_camera_3d()
		if pending_player.can_process() and active != null and pending_player.is_ancestor_of(active):
			if pending_player.get("is_climbing") == true:
				pending_player = null
			else:
				_begin_focus(pending_player, active)
	if not is_instance_valid(focus_camera):
		return
	if not is_instance_valid(focused_player) or not is_instance_valid(original_camera):
		_finish_focus()
		return
	# Another sequence can take ownership without this one stealing it back.
	if get_viewport().get_camera_3d() != focus_camera:
		_finish_focus(false)
		return
	elapsed += delta
	var duration := maxf(turn_duration, 0.01)
	var release_duration := maxf(return_duration, 0.01)
	if elapsed < duration:
		# A fast ease-out snaps attention to the radio without teleporting the view.
		var weight := 1.0 - pow(1.0 - clampf(elapsed / duration, 0.0, 1.0), 3.0)
		focus_camera.global_transform = original_transform.interpolate_with(look_transform, weight)
		focus_camera.fov = lerpf(original_fov, focused_fov, weight)
	elif elapsed < duration + look_duration:
		focus_camera.global_transform = look_transform
		focus_camera.fov = focused_fov
	elif elapsed < duration + look_duration + release_duration:
		var weight := smoothstep(0.0, release_duration, elapsed - duration - look_duration)
		focus_camera.global_transform = look_transform.interpolate_with(original_transform, weight)
		focus_camera.fov = lerpf(focused_fov, original_fov, weight)
	else:
		_finish_focus()
		return
	_apply_scare_kick()


func _apply_scare_kick() -> void:
	# Always offset the freshly calculated pose, so the jolt cannot drift.
	if elapsed >= 0.38:
		return
	var decay := pow(1.0 - elapsed / 0.38, 2.0)
	var roll := deg_to_rad(scare_jolt_degrees) * sin(elapsed * 48.0) * decay
	var pitch := deg_to_rad(scare_jolt_degrees * 0.5) * sin(elapsed * 35.0) * decay
	focus_camera.rotate_object_local(Vector3.FORWARD, roll)
	focus_camera.rotate_object_local(Vector3.RIGHT, pitch)
	var zoom_kick := sin(PI * clampf(elapsed / 0.30, 0.0, 1.0)) * 3.0
	focus_camera.fov = maxf(20.0, focus_camera.fov - zoom_kick)


func _play_scare_sound() -> void:
	static_sound.volume_db = scare_volume_db
	static_sound.play()
	# Let the stinger hit first, then bring the existing radio music forward.
	if radio_duck != null and radio_duck.is_valid():
		radio_duck.kill()
	radio_audio.volume_db = radio_volume_db - 12.0
	radio_duck = create_tween()
	radio_duck.tween_interval(0.12)
	radio_duck.tween_property(radio_audio, "volume_db", radio_volume_db, 0.55)


func _begin_focus(body: Node3D, camera: Camera3D) -> void:
	pending_player = null
	focused_player = body
	original_camera = camera
	original_transform = camera.global_transform.orthonormalized()
	look_transform = original_transform
	var target := _radio_center()
	if original_transform.origin.distance_squared_to(target) < 0.01:
		focused_player = null
		return
	look_transform = original_transform.looking_at(target, Vector3.UP)
	previous_process_mode = body.process_mode
	var audio := body.get_node_or_null("PlayerAudio")
	if audio != null and audio.has_method("stop_walk_step"):
		audio.stop_walk_step()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	focus_camera = Camera3D.new()
	add_child(focus_camera)
	focus_camera.top_level = true
	focus_camera.global_transform = original_transform
	original_fov = camera.fov
	focused_fov = maxf(20.0, original_fov - focus_zoom_degrees)
	focus_camera.fov = original_fov
	focus_camera.near = camera.near
	focus_camera.far = camera.far
	focus_camera.cull_mask = camera.cull_mask
	focus_camera.environment = camera.environment
	focus_camera.attributes = camera.attributes
	focus_camera.make_current()
	elapsed = 0.0
	_play_scare_sound()


func _radio_center() -> Vector3:
	var radio := get_parent() as Node3D
	var bounds := AABB()
	var found := false
	for node in radio.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(world_bounds) if found else world_bounds
		found = true
	return bounds.get_center() if found else radio.global_position


func _finish_focus(restore_camera: bool = true) -> void:
	if radio_duck != null and radio_duck.is_valid():
		radio_duck.kill()
	if is_instance_valid(radio_audio):
		radio_audio.volume_db = radio_volume_db
	if is_instance_valid(static_sound):
		static_sound.stop()
	if is_instance_valid(focused_player):
		focused_player.process_mode = previous_process_mode
	if restore_camera and is_instance_valid(original_camera):
		original_camera.make_current()
	if is_instance_valid(focus_camera):
		focus_camera.queue_free()
	focus_camera = null
	focused_player = null
	original_camera = null


func _exit_tree() -> void:
	_finish_focus(false)
