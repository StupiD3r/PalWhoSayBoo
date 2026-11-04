extends Node3D

signal finished
const DURATION := 5.9
var pole: Node3D
var flag: MeshInstance3D
var flag_anchor: Node3D
var hud: Node
var hud_was_visible: bool = false
var target := Vector3.ZERO
var bottom_y: float = 0.0
var active: bool = false
var elapsed: float = 0.0
var actor: CharacterBody3D
var original_camera: Camera3D
var camera: Camera3D
var actor_mesh: Node3D
var original_mesh_visible: bool
var previous_mode: Node.ProcessMode
var original_pose: Transform3D
var eye_pose: Transform3D
var fall_origin := Vector3.ZERO
var away := Vector3.BACK
var fall_distance: float = 4.0
var overlay: CanvasLayer
var black: ColorRect
var wind: AudioStreamPlayer
var creak: AudioStreamPlayer
var slipped: bool = false

func _ready() -> void:
	set_process(false)
	_make_flag()
	overlay = CanvasLayer.new()
	overlay.layer = 15
	add_child(overlay)
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()
	wind = AudioStreamPlayer.new()
	wind.stream = preload("res://Assets/Audio/swirling wind.mp3")
	wind.volume_db = -34.0
	add_child(wind)
	creak = AudioStreamPlayer.new()
	creak.stream = preload("res://Assets/Audio/bamboo_creak_1.ogg")
	creak.volume_db = -14.0
	add_child(creak)

func _make_flag() -> void:
	if not is_instance_valid(pole):
		return
	var bounds := AABB()
	var found := false
	for node in pole.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(world_bounds) if found else world_bounds
		found = true
	if not found:
		return
	bottom_y = bounds.position.y
	var size := clampf(bounds.size.y * 0.045, 1.5, 3.0)
	var top := Vector3(bounds.get_center().x, bounds.end.y, bounds.get_center().z)
	var mast := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.height = size * 1.1
	cylinder.top_radius = 0.025
	cylinder.bottom_radius = 0.025
	mast.mesh = cylinder
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.65, 0.5)
	mast.material_override = material
	add_child(mast)
	mast.global_position = top + Vector3.UP * size * 0.4
	flag = MeshInstance3D.new()
	flag.name = "WhiteGoalFlag"
	var cloth := QuadMesh.new()
	cloth.size = Vector2(size, size * 0.6)
	cloth.subdivide_width = 18
	cloth.subdivide_depth = 8
	flag.mesh = cloth
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled, unshaded;
void vertex() { VERTEX.z += sin(VERTEX.x * 5.0 - TIME * 3.0) * UV.x * 0.12; }
void fragment() { ALBEDO = vec3(0.96, 0.96, 0.92); ROUGHNESS = 0.9; EMISSION = vec3(0.12); }
"""
	var cloth_material := ShaderMaterial.new()
	cloth_material.shader = shader
	flag.material_override = cloth_material
	flag_anchor = Node3D.new()
	add_child(flag_anchor)
	flag_anchor.global_position = top + Vector3.UP * size * 0.6
	flag_anchor.add_child(flag)
	flag.position = Vector3.RIGHT * size * 0.5
	target = flag.global_position

func begin(player: CharacterBody3D) -> bool:
	if active or not is_instance_valid(flag) or not is_instance_valid(player) or player.get("is_climbing") != true:
		return false
	var controller := player.get_node_or_null("PlayerCamera")
	var fpv: Camera3D = controller.get("first_person_cam") if controller else null
	var current := get_viewport().get_camera_3d()
	if fpv == null or current == null or not player.is_ancestor_of(current):
		return false
	actor = player
	original_camera = current
	original_pose = current.global_transform.orthonormalized()
	eye_pose = fpv.global_transform.orthonormalized()
	fall_origin = eye_pose.origin
	away = fall_origin - Vector3(flag_anchor.global_position.x, fall_origin.y, flag_anchor.global_position.z)
	if away.length_squared() < 0.01:
		away = player.global_basis.z
	away.y = 0.0
	away = away.normalized()
	# Move the camera clear of the pole while the grip slips.
	fall_origin += away * 1.2 + Vector3.UP.cross(away).normalized() * 0.7
	fall_distance = clampf((fall_origin.y - bottom_y) * 0.35, 0.3, 8.0)
	# Tilt the cloth toward the falling viewpoint so the goal reads clearly from below.
	flag_anchor.look_at(fall_origin, Vector3.UP)
	target = flag.global_position
	hud = player.get_parent().get_node_or_null("HUD")
	if hud != null and hud.has_method("hide"):
		hud_was_visible = bool(hud.get("visible"))
		hud.hide()
	previous_mode = player.process_mode
	actor_mesh = player.get_node_or_null("Player") as Node3D
	if actor_mesh:
		original_mesh_visible = actor_mesh.visible
		actor_mesh.hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	add_child(camera)
	camera.near = fpv.near
	camera.far = maxf(fpv.far, 1000.0)
	camera.cull_mask = fpv.cull_mask
	camera.environment = current.environment
	camera.attributes = current.attributes
	camera.fov = current.fov
	camera.global_transform = original_pose
	camera.make_current()
	elapsed = 0.0
	slipped = false
	active = true
	black.color.a = 0.0
	overlay.show()
	wind.volume_db = -34.0
	wind.play()
	set_process(true)
	return true

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(actor) or not is_instance_valid(original_camera):
		cancel()
		finished.emit()
		return
	elapsed = minf(DURATION, elapsed + delta)
	if not slipped and elapsed >= 0.65:
		slipped = true
		creak.play()
	if elapsed < 0.65:
		camera.global_transform = original_pose.interpolate_with(eye_pose, smoothstep(0.0, 0.65, elapsed))
	else:
		var fall_time := maxf(0.0, elapsed - 1.45)
		var progress := clampf(fall_time / 4.0, 0.0, 1.0)
		var origin := fall_origin + away * progress * 1.5 + Vector3.DOWN * fall_distance * progress * progress
		var upward_pose := Transform3D(Basis.IDENTITY, origin).looking_at(target, away)
		var weight := smoothstep(0.65, 1.45, elapsed)
		camera.global_transform = eye_pose.interpolate_with(upward_pose, weight)
		var jolt := sin((elapsed - 0.65) * 35.0) * (1.0 - smoothstep(0.65, 1.3, elapsed))
		camera.rotate_object_local(Vector3.FORWARD, jolt * 0.035 + sin(fall_time * 2.0) * 0.015)
		camera.fov = lerpf(75.0, 32.0, smoothstep(0.8, 2.4, elapsed))
	black.color.a = smoothstep(4.7, 5.55, elapsed)
	wind.volume_db = lerpf(-34.0, -17.0, smoothstep(0.65, 4.4, elapsed)) - black.color.a * 35.0
	if elapsed >= DURATION:
		cancel()
		finished.emit()

func cancel() -> void:
	active = false
	set_process(false)
	if is_instance_valid(hud):
		hud.set("visible", hud_was_visible)
	hud = null
	if is_instance_valid(actor):
		actor.process_mode = previous_mode
	if is_instance_valid(actor_mesh):
		actor_mesh.visible = original_mesh_visible
	if is_instance_valid(original_camera):
		original_camera.make_current()
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	actor = null
	original_camera = null
	if is_instance_valid(overlay):
		overlay.hide()
	if is_instance_valid(wind):
		wind.stop()
	if is_instance_valid(creak):
		creak.stop()

func _exit_tree() -> void:
	cancel()
