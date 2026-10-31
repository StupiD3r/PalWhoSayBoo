@tool
extends Control

@export_range(0.0, 1.0, 0.01) var closed_amount: float = 1.0:
	set(value):
		closed_amount = clampf(value, 0.0, 1.0)

		if is_node_ready():
			_update_effects()

@export_range(0.0, 5.0, 0.01) var blur_amount: float = 3.0:
	set(value):
		blur_amount = clampf(value, 0.0, 5.0)

		if is_node_ready():
			_update_effects()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_effects()


func _update_effects() -> void:
	var mask := get_node_or_null("EyeMask") as ColorRect

	if mask != null:
		mask.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		mask.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var eye_material := mask.material as ShaderMaterial

		if eye_material != null:
			eye_material.set_shader_parameter(
				"closed_amount",
				closed_amount
			)

	var blur := get_parent().get_node_or_null(
		"WakeBlur"
	) as ColorRect

	if blur != null:
		blur.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		blur.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var blur_material := blur.material as ShaderMaterial

		if blur_material != null:
			blur_material.set_shader_parameter(
				"blur_amount",
				blur_amount
			)
