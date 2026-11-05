extends WorldEnvironment

# Runtime only: the editor keeps its daylight setup for building the map.
@export var night_lighting_enabled: bool = true
@export_range(0.0, 2.0) var moonlight_energy: float = 0.42
@export_range(0.0, 1.0) var night_ambient_energy: float = 0.35
var night_lights: Node3D

func _ready() -> void:
	if not night_lighting_enabled:
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var shader := Shader.new()
	shader.code = """shader_type sky;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
void sky() {
 vec3 direction = normalize(EYEDIR);
 float height = max(direction.y, 0.0);
 vec3 color = mix(vec3(0.10,0.14,0.22), vec3(0.02,0.035,0.07), sqrt(height));
 vec3 moon_direction = normalize(vec3(-0.45,0.68,0.48));
 float alignment = max(dot(direction, moon_direction), 0.0);
 float disk = smoothstep(0.9997, 0.99985, alignment);
 float halo = pow(alignment, 90.0) * 0.025;
 vec3 grid = direction * 420.0;
 float star = step(0.9975, hash(floor(grid))) * (1.0 - smoothstep(0.04,0.15,length(fract(grid)-vec3(0.5)))) * smoothstep(0.05,0.25,height);
 COLOR = color + vec3(0.67,0.76,0.92) * disk + vec3(0.27,0.38,0.65) * halo + vec3(0.35,0.42,0.58) * star;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.43, 0.61)
	env.ambient_light_energy = night_ambient_energy
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.095, 0.16)
	env.fog_light_energy = 0.6
	env.fog_density = 0.002
	env.fog_sky_affect = 0.15
	environment = env
	_apply_night_lights.call_deferred()

func _apply_night_lights() -> void:
	var map := get_parent().get_parent()
	night_lights = Node3D.new()
	night_lights.name = "RuntimeNightLights"
	add_child(night_lights)
	var moon := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if moon:
		moon.light_color = Color(0.57, 0.7, 1.0)
		moon.light_energy = moonlight_energy
		moon.shadow_enabled = true
		var direction := Vector3(-0.45, 0.68, 0.48).normalized()
		moon.global_basis = Basis.looking_at(-direction, Vector3.UP)
		moon.directional_shadow_max_distance = 180.0
	var fills := map.get_node_or_null("Lightings")
	if fills:
		for child in fills.get_children():
			if child is OmniLight3D and child.omni_range > 100.0:
				child.visible = false
	var player := map.get_node_or_null("Player") as Node3D
	if player:
		_add_light("WakeRoomWarmth", player.global_position + Vector3.UP * 3.5, Color(1.0, 0.62, 0.3), 1.8, 13.0)
		var player_fill := _add_light("PlayerMoonFill", player.global_position, Color(0.35, 0.48, 0.8), 0.45, 8.0)
		player_fill.reparent(player)
		player_fill.position = Vector3(0, 1.5, 1.8)
	var house := map.get_node_or_null("House")
	if house:
		var radios := house.find_children("Radio", "Node3D", true, false)
		if not radios.is_empty():
			_add_light("RadioWarmth", _mesh_center(radios[0]) + Vector3.UP * 1.8, Color(1.0, 0.55, 0.25), 1.4, 11.0)
	var pole := map.get_node_or_null("Bamboo/BambooPole") as Node3D
	if pole:
		_add_light("PoleBaseWarmth", pole.global_position + Vector3.UP * 5.0, Color(1.0, 0.68, 0.35), 2.0, 22.0)
		_add_light("PoleMoonRim", pole.global_position + Vector3(-5.0, 30.0, 8.0), Color(0.4, 0.57, 0.95), 2.8, 60.0)
	for child in map.get_children():
		if not String(child.name).begins_with("LightPoleWithTransformer"):
			continue
		var lamp := child.get_node_or_null("Lamp") as Node3D
		if lamp:
			var position := _mesh_center(lamp) + Vector3.DOWN * 0.2
			var light := _add_light("StreetLamp", position, Color(1.0, 0.66, 0.32), 3.0, 22.0)
			var bulb := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.13
			sphere.height = 0.26
			bulb.mesh = sphere
			var glow := StandardMaterial3D.new()
			glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			glow.albedo_color = Color(1.0, 0.78, 0.43)
			bulb.material_override = glow
			light.add_child(bulb)

func _add_light(light_name: String, world_position: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = light_name
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	night_lights.add_child(light)
	light.global_position = world_position
	return light

func _mesh_center(node: Node3D) -> Vector3:
	var bounds := AABB()
	var found := false
	for descendant in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := descendant as MeshInstance3D
		if mesh.mesh == null:
			continue
		var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(world_bounds) if found else world_bounds
		found = true
	return bounds.get_center() if found else node.global_position
