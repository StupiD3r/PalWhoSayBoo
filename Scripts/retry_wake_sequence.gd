extends Node

const RETRY_META := "pal_who_say_boo_retry_wake"
const DURATION := 8.2
const GASP_TIME := 0.06
@export_range(-40.0, 0.0) var gasp_volume_db: float = -12.0
var gasp_sound: AudioStreamPlayer
var gasp_played: bool = false

var player: CharacterBody3D
var gameplay_camera: Camera3D
var cutscene_camera: Camera3D
var eyelids: Control
var finished_callback: Callable
var elapsed: float = 0.0
var finished: bool = false
var standing_transform: Transform3D
var standing_fov: float = 75.0
var low_eye_y: float = 0.5
var body_scale: float = 1.0
var horizontal_right := Vector3.RIGHT
var horizontal_forward := Vector3.FORWARD

# Time, height fraction, yaw, pitch, roll, eye closure, blur, FOV offset,
# sideways offset, forward offset. Offsets are relative to the final standing spot.
var poses: Array[Array] = [
	[0.00, 0.00, 0.0, 88.0, 0.0, 1.0, 2.8, -4.0, -0.70, -1.20],
	# Eyes, gasp and sit-up start together, then the body settles from the jolt.
	[0.06, 0.00, 0.0, 88.0, 0.0, 1.0, 2.8, -4.0, -0.70, -1.20],
	[0.18, 0.24, 0.0, 40.0, -1.5, 0.06, 1.3, 7.0, -0.70, -0.78],
	[0.34, 0.47, 0.0, -6.0, 2.0, 0.0, 0.6, 3.0, -0.70, -0.42],
	[0.65, 0.44, 0.0, -2.0, 0.0, 0.0, 0.3, 0.0, -0.70, -0.45],
	# Small breathing movement while seated, before checking the room.
	[0.95, 0.447, 0.0, -1.0, 0.4, 0.0, 0.2, 0.5, -0.70, -0.45],
	[1.35, 0.44, 0.0, -2.0, 0.0, 0.0, 0.1, 0.0, -0.70, -0.45],
	[1.75, 0.445, 0.0, -1.5, -0.3, 0.15, 0.1, 0.0, -0.70, -0.45],
	[1.95, 0.44, 0.0, -2.0, 0.0, 0.0, 0.1, 0.0, -0.70, -0.45],
	[2.70, 0.44, 0.0, -2.0, 0.0, 0.0, 0.0, 0.0, -0.70, -0.45],
	# Check both sides while remaining seated.
	[3.50, 0.44, -42.0, -4.0, -1.5, 0.0, 0.0, 0.0, -0.70, -0.45],
	[3.85, 0.44, -42.0, -4.0, -1.5, 0.0, 0.0, 0.0, -0.70, -0.45],
	[4.65, 0.44, 46.0, -1.0, 1.5, 0.0, 0.0, 0.0, -0.70, -0.45],
	[5.05, 0.44, 46.0, -1.0, 1.5, 0.0, 0.0, 0.0, -0.70, -0.45],
	# Look at the bed edge, swing the legs off, and plant the feet.
	[5.50, 0.43, 6.0, -18.0, -1.0, 0.0, 0.0, 0.0, -0.65, -0.40],
	[6.25, 0.37, 0.0, -28.0, -3.0, 0.0, 0.0, 0.0, -0.25, -0.10],
	[6.60, 0.35, 0.0, -22.0, -1.0, 0.0, 0.0, 0.0, -0.10, 0.0],
	# Push up to standing and settle at the actual gameplay camera.
	[7.65, 1.015, 0.0, -2.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0],
	[8.20, 1.00, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]

func play(actor: CharacterBody3D, gameplay: Camera3D, camera: Camera3D, eyes: Control, callback: Callable) -> void:
	if gasp_sound == null:
		gasp_sound = AudioStreamPlayer.new()
		gasp_sound.name = "RetryWakeGasp"
		gasp_sound.stream = preload("res://Assets/Audio/retry_wake_gasp.ogg")
		add_child(gasp_sound)
	gasp_sound.stop()
	gasp_sound.volume_db = gasp_volume_db
	gasp_played = false
	player = actor
	gameplay_camera = gameplay
	cutscene_camera = camera
	eyelids = eyes
	finished_callback = callback
	standing_transform = gameplay_camera.global_transform.orthonormalized()
	standing_fov = gameplay_camera.fov
	var standing_height := maxf(0.8, standing_transform.origin.y - player.global_position.y)
	body_scale = clampf(standing_height / 1.7, 0.6, 2.5)
	# Pillow height scales with this project's unusually tall player model.
	low_eye_y = minf(standing_transform.origin.y, player.global_position.y + standing_height * 0.32)
	horizontal_right = standing_transform.basis.x
	horizontal_right.y = 0.0
	horizontal_right = horizontal_right.normalized()
	horizontal_forward = -standing_transform.basis.z
	horizontal_forward.y = 0.0
	horizontal_forward = horizontal_forward.normalized()
	cutscene_camera.near = gameplay_camera.near
	cutscene_camera.far = gameplay_camera.far
	cutscene_camera.cull_mask = gameplay_camera.cull_mask
	var mesh := player.get_node_or_null("Player") as Node3D
	if mesh:
		mesh.hide()
	elapsed = 0.0
	finished = false
	_apply_pose(0.0)
	cutscene_camera.make_current()
	set_process(true)

func _process(delta: float) -> void:
	if finished or not is_instance_valid(cutscene_camera):
		return
	elapsed = minf(DURATION, elapsed + delta)
	if not gasp_played and elapsed >= GASP_TIME:
		gasp_played = true
		gasp_sound.play()
	_apply_pose(elapsed)
	if elapsed >= DURATION:
		finished = true
		set_process(false)
		if finished_callback.is_valid():
			finished_callback.call()

func sample_pose(time: float) -> Array:
	if time >= DURATION:
		return poses.back().duplicate()
	for index in range(poses.size() - 1):
		var a := poses[index]
		var b := poses[index + 1]
		if time <= float(b[0]):
			var weight := smoothstep(0.0, 1.0, clampf((time - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
			var result: Array = [time]
			for component in range(1, a.size()):
				result.append(lerpf(float(a[component]), float(b[component]), weight))
			return result
	return poses.back().duplicate()

func _apply_pose(time: float) -> void:
	var pose := sample_pose(time)
	var origin := standing_transform.origin
	origin += horizontal_right * float(pose[8]) * body_scale
	origin += horizontal_forward * float(pose[9]) * body_scale
	origin.y = lerpf(low_eye_y, standing_transform.origin.y, float(pose[1]))
	var yaw := Basis(Vector3.UP, deg_to_rad(float(pose[2])))
	var pitch := Basis(Vector3.RIGHT, deg_to_rad(float(pose[3])))
	var roll := Basis(Vector3.BACK, deg_to_rad(float(pose[4])))
	cutscene_camera.global_transform = Transform3D(standing_transform.basis * yaw * pitch * roll, origin)
	cutscene_camera.fov = standing_fov + float(pose[7])
	if eyelids:
		eyelids.set("closed_amount", float(pose[5]))
		eyelids.set("blur_amount", float(pose[6]))
