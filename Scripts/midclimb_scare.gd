extends Node3D

signal finished

const MONSTER = preload("res://Assets/Mananaggal/mananaggal_model.glb")
const RETURN_START := 1.85
const COUNTDOWN_START := 2.55
const TOTAL_DURATION := 5.55

var active: bool = false
var elapsed: float = 0.0
var actor: CharacterBody3D
var source_camera: Camera3D
var camera: Camera3D
var monster: Node3D
var actor_mesh: Node3D
var previous_mesh_visible: bool = true
var previous_process_mode: Node.ProcessMode
var source_pose: Transform3D
var fpv_pose: Transform3D
var source_fov: float = 75.0
var fpv_fov: float = 75.0
var overlay: CanvasLayer
var edges: ShaderMaterial
var countdown: Label
var turn_side: float = 1.0
var scare_sound: AudioStreamPlayer
var scare_sound_played: bool = false

func _ready() -> void:
	set_process(false)
	scare_sound = AudioStreamPlayer.new()
	scare_sound.name = "MidclimbAttackSound"
	scare_sound.stream = preload("res://Assets/Audio/mid climb manananggal 2.mp3")
	scare_sound.volume_db = -12.0
	add_child(scare_sound)
	monster = Node3D.new()
	add_child(monster)
	var model := MONSTER.instantiate() as Node3D
	monster.add_child(model)
	var bounds := AABB()
	var found := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local_bounds: AABB = monster.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(local_bounds) if found else local_bounds
		found = true
	if found:
		var size_scale := 2.4 / maxf(bounds.size.y, 0.01)
		model.scale *= size_scale
		model.position -= bounds.get_center() * size_scale
	monster.hide()
	# A small private light keeps the face readable in both day and night maps.
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.82, 1.0)
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = Vector3(0, 0.8, 1.5)
	monster.add_child(light)
	overlay = CanvasLayer.new()
	overlay.layer = 12
	add_child(overlay)
	var screen := ColorRect.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float strength = 0.0;
uniform float age = 0.0;
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float edge = smoothstep(0.35, 1.15, length(p));
 float smear = sin(UV.x * 23.0 + sin(UV.y * 14.0) * 2.0) * sin(UV.y * 19.0 + UV.x * 9.0) * 0.5 + 0.5;
 float scratch = 0.0;
 for (int i = 0; i < 3; i++) {
   float offset = float(i) * 0.12;
   float line = UV.y - (0.15 + offset + UV.x * 0.65);
   scratch += (1.0 - smoothstep(0.008, 0.035, abs(line))) * smoothstep(0.04, 0.18, UV.x) * (1.0 - smoothstep(0.82, 0.98, UV.x));
 }
 float drip = 0.0;
 for (int i = 0; i < 12; i++) {
   float x = (float(i) + 0.5) / 12.0;
   float seed = grain(vec2(float(i), 4.0));
   float bottom = 0.12 + seed * 0.55 + min(age, 4.0) * 0.025;
   float width = 0.003 + seed * 0.007;
   float path = x + sin(UV.y * 14.0 + seed * 20.0) * 0.007;
   float trail = (1.0 - smoothstep(width, width + 0.004, abs(UV.x - path))) * (1.0 - smoothstep(bottom - 0.025, bottom, UV.y));
   vec2 tip = vec2(x + sin((bottom - 0.015) * 14.0 + seed * 20.0) * 0.007, bottom - 0.015);
   float drop = 1.0 - smoothstep(0.75, 1.1, length((UV - tip) / vec2(width * 1.5, 0.018 + seed * 0.015)));
   drip += max(trail, drop);
 }
 vec3 blood = mix(vec3(0.16, 0.001, 0.008), vec3(0.48, 0.009, 0.025), smear);
 blood = mix(blood, vec3(0.63, 0.025, 0.035), min(scratch, 1.0) * 0.7);
 blood *= 1.0 - min(drip, 1.0) * 0.35;
 float coverage = clamp(0.67 + smear * 0.18 + edge * 0.2 + drip * 0.15 + scratch * 0.12, 0.0, 0.97);
 COLOR = vec4(blood, coverage * strength);
}
"""
	edges = ShaderMaterial.new()
	edges.shader = shader
	screen.material = edges
	countdown = Label.new()
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown.add_theme_font_size_override("font_size", 160)
	countdown.add_theme_color_override("font_outline_color", Color(0.04, 0.0, 0.0))
	countdown.add_theme_constant_override("outline_size", 10)
	countdown.add_theme_color_override("font_shadow_color", Color.BLACK)
	countdown.add_theme_constant_override("shadow_offset_x", 2)
	countdown.add_theme_constant_override("shadow_offset_y", 2)
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(countdown)
	countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.hide()

func begin(player: CharacterBody3D) -> bool:
	if active or not is_instance_valid(player) or not player.can_process() or player.get("is_climbing") != true:
		return false
	var controller := player.get_node_or_null("PlayerCamera")
	var first_person: Camera3D = controller.get("first_person_cam") if controller else null
	var current := get_viewport().get_camera_3d()
	if first_person == null or current == null or not player.is_ancestor_of(current):
		return false
	actor = player
	source_camera = current
	source_pose = current.global_transform.orthonormalized()
	source_fov = current.fov
	fpv_fov = first_person.fov
	fpv_pose = first_person.global_transform.orthonormalized()
	# The body faces the pole. A quarter turn from that direction clears it
	# regardless of where the player last moved the climbing camera.
	turn_side = -1.0 if randf() < 0.5 else 1.0
	var forward := -player.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized().rotated(Vector3.UP, turn_side * PI * 0.5)
	fpv_pose.origin += forward * 0.25
	fpv_pose = fpv_pose.looking_at(fpv_pose.origin + forward, Vector3.UP)
	previous_process_mode = player.process_mode
	var audio := player.get_node_or_null("PlayerAudio")
	if audio and audio.has_method("stop_ghost_breath"):
		audio.stop_ghost_breath()
	actor_mesh = player.get_node_or_null("Player") as Node3D
	if actor_mesh:
		previous_mesh_visible = actor_mesh.visible
		actor_mesh.hide()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera = Camera3D.new()
	add_child(camera)
	camera.global_transform = source_pose
	camera.fov = source_fov
	camera.near = first_person.near
	camera.far = first_person.far
	camera.cull_mask = current.cull_mask
	camera.environment = current.environment
	camera.attributes = current.attributes
	camera.make_current()
	elapsed = 0.0
	scare_sound_played = false
	scare_sound.stop()
	active = true
	overlay.show()
	edges.set_shader_parameter("strength", 0.0)
	countdown.text = ""
	set_process(true)
	return true

func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(actor) or not is_instance_valid(source_camera):
		cancel()
		finished.emit()
		return
	if get_viewport().get_camera_3d() != camera:
		cancel(false)
		finished.emit()
		return
	elapsed += delta
	if not scare_sound_played and elapsed >= 0.95 and elapsed < TOTAL_DURATION:
		scare_sound_played = true
		scare_sound.play()
	if elapsed >= TOTAL_DURATION:
		cancel()
		finished.emit()
		return
	var impact := 0.0
	if elapsed < 0.65:
		camera.global_transform = source_pose.interpolate_with(fpv_pose, smoothstep(0.0, 0.65, elapsed))
		camera.fov = lerpf(source_fov, fpv_fov, smoothstep(0.0, 0.65, elapsed))
	elif elapsed < RETURN_START:
		camera.global_transform = fpv_pose
		var rush := smoothstep(0.95, 1.32, elapsed)
		var distance := lerpf(4.5, 1.05, rush)
		var retreat := smoothstep(1.5, RETURN_START, elapsed)
		var local_position := Vector3(retreat * 4.0, -0.55 + sin(elapsed * 3.0) * 0.06 + retreat * 3.0, -distance - retreat * 2.0)
		monster.global_position = fpv_pose * local_position
		monster.look_at(fpv_pose.origin, Vector3.UP, true)
		monster.visible = true
		impact = smoothstep(1.18, 1.32, elapsed) * (1.0 - smoothstep(1.42, 2.05, elapsed))
		camera.fov = fpv_fov - rush * (1.0 - retreat) * 5.0
		camera.rotate_object_local(Vector3.RIGHT, sin(elapsed * 83.0) * impact * 0.018)
		camera.rotate_object_local(Vector3.FORWARD, sin(elapsed * 67.0) * impact * 0.025)
		camera.global_position += fpv_pose.basis.x * sin(elapsed * 91.0) * impact * 0.018
	else:
		monster.hide()
		var weight := smoothstep(RETURN_START, COUNTDOWN_START, elapsed)
		camera.global_transform = fpv_pose.interpolate_with(source_pose, weight)
		camera.fov = lerpf(fpv_fov, source_fov, weight)
		impact = (1.0 - smoothstep(RETURN_START, COUNTDOWN_START, elapsed)) * 0.4
		if elapsed >= COUNTDOWN_START:
			if actor_mesh:
				actor_mesh.visible = previous_mesh_visible
			countdown.text = str(ceili(TOTAL_DURATION - elapsed))
	var blood_strength := smoothstep(1.18, 1.4, elapsed) * (1.0 - smoothstep(COUNTDOWN_START, TOTAL_DURATION, elapsed))
	edges.set_shader_parameter("strength", blood_strength)
	edges.set_shader_parameter("age", maxf(0.0, elapsed - 1.18))

func cancel(restore_camera: bool = true) -> void:
	if is_instance_valid(scare_sound):
		scare_sound.stop()
	active = false
	set_process(false)
	if is_instance_valid(actor):
		actor.process_mode = previous_process_mode
	if is_instance_valid(actor_mesh):
		actor_mesh.visible = previous_mesh_visible
	if restore_camera and is_instance_valid(source_camera):
		source_camera.make_current()
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	actor = null
	source_camera = null
	if is_instance_valid(monster):
		monster.hide()
	if is_instance_valid(overlay):
		overlay.hide()

func _exit_tree() -> void:
	cancel(false)
