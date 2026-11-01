extends CanvasLayer

const DURATION := 0.9
const REPEAT_DELAY_MS := 240
var active: bool = false
var age: float = DURATION
var power: float = 0.7
var strike_count: int = 0
var last_strike_ms: int = -10000
var next_left: bool = true
var screen: Control
var claws: ScratchCanvas
var vignette: ShaderMaterial

class ScratchCanvas:
	extends Control
	var paths: Array[PackedVector2Array] = []
	var progress: float = 0.0
	var opacity: float = 0.0

	func make_paths(left: bool, seed_value: int) -> void:
		paths.clear()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for claw in range(3):
			var points := PackedVector2Array()
			var start := Vector2(0.17 + claw * 0.075, 0.10 + claw * 0.02)
			var finish := Vector2(0.65 + claw * 0.075, 0.91 + claw * 0.02)
			for index in range(33):
				var t := index / 32.0
				var point := start.lerp(finish, t) + Vector2(-0.055 * sin(PI * t), 0.0)
				point.x += rng.randf_range(-0.0025, 0.0025)
				if not left:
					point.x = 1.0 - point.x
				points.append(point)
			paths.append(points)

	func _draw() -> void:
		for index in range(paths.size()):
			var reveal := clampf(progress - index * 0.16, 0.0, 1.0)
			if reveal <= 0.0:
				continue
			_draw_claw(paths[index], reveal, 0.025, Color(0.16, 0.0, 0.008, opacity * 0.55))
			_draw_claw(paths[index], reveal, 0.016, Color(0.46, 0.018, 0.035, opacity))
			_draw_claw(paths[index], reveal, 0.0055, Color(1.0, 0.82, 0.74, opacity * 0.85))

	func _draw_claw(path: PackedVector2Array, reveal: float, width: float, tint: Color) -> void:
		var count := mini(path.size(), maxi(2, int(reveal * 32.0) + 1))
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for index in range(count):
			var t := index / 32.0
			var taper := pow(maxf(0.0, sin(PI * t)), 0.55) * (1.0 - t * 0.25)
			var center := path[index] * size
			var thickness := maxf(0.3, width * size.x * taper)
			upper.append(center + Vector2(thickness, 0.0))
			lower.append(center - Vector2(thickness, 0.0))
		lower.reverse()
		upper.append_array(lower)
		if upper.size() >= 4:
			draw_colored_polygon(upper, tint)

func _ready() -> void:
	layer = 8
	screen = Control.new()
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edge := ColorRect.new()
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float amount = 0.0;
uniform float impact = 0.0;
void fragment() {
    float distance_to_edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
    float ragged = sin(UV.y * 67.0 + sin(UV.x * 43.0)) * 0.009;
    float edge = 1.0 - smoothstep(0.015, 0.34, distance_to_edge + ragged);
    float rim = 1.0 - smoothstep(0.0, 0.09, distance_to_edge);
    float hurt = clamp(edge * 0.60 + rim * 0.20, 0.0, 0.80);
    vec3 blood = vec3(0.30 + impact * 0.16, 0.005, 0.018);
    COLOR = vec4(blood, hurt * amount);
}"""
	vignette = ShaderMaterial.new()
	vignette.shader = shader
	edge.material = vignette
	claws = ScratchCanvas.new()
	claws.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(claws)
	claws.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if active:
		_begin_visuals()
	else:
		screen.hide()

func play_strike(strength: float = 0.7) -> bool:
	if strength <= 0.0:
		return false
	var now := Time.get_ticks_msec()
	if active and now - last_strike_ms < REPEAT_DELAY_MS:
		power = minf(1.0, power + 0.1)
		return false
	last_strike_ms = now
	age = 0.0
	power = clampf(strength, 0.0, 1.0)
	active = true
	strike_count += 1
	if is_node_ready():
		_begin_visuals()
	return true

func _begin_visuals() -> void:
	claws.make_paths(next_left, 101 + strike_count * 37)
	next_left = not next_left
	screen.show()
	_update_visuals()

func _process(delta: float) -> void:
	if not active:
		return
	age += delta
	if age >= DURATION:
		active = false
		screen.hide()
		return
	_update_visuals()

func _update_visuals() -> void:
	var fade := 1.0 - smoothstep(0.22, DURATION, age)
	claws.progress = clampf(age / 0.15, 0.0, 1.32)
	claws.opacity = fade * power
	claws.queue_redraw()
	vignette.set_shader_parameter("amount", fade * power)
	vignette.set_shader_parameter("impact", maxf(0.0, 1.0 - age / 0.20))

func reset_effect() -> void:
	active = false
	age = DURATION
	last_strike_ms = -10000
	if is_instance_valid(screen):
		screen.hide()
