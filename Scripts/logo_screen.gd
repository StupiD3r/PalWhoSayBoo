extends Control

# Assign your logo and menu through the Inspector.
@export var logo_texture: Texture2D
@export_file("*.tscn") var main_menu_scene: String

@export var fade_in_time := 1.5
@export var hold_time := 2.0
@export var fade_out_time := 1.5


func _ready() -> void:
	# Black background.
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Keep the logo away from the screen edges.
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override(
			"margin_" + side, 80
		)

	# Display the logo without stretching its proportions.
	var logo := TextureRect.new()
	logo.texture = logo_texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.modulate.a = 0.0
	margin.add_child(logo)

	if logo_texture == null or main_menu_scene.is_empty():
		push_error("Assign Logo Texture and Main Menu Scene on LogoScreen.")
		return

	# Fade in, hold, then fade out.
	var fade := create_tween()
	fade.tween_property(logo, "modulate:a", 1.0, fade_in_time)
	fade.tween_interval(hold_time)
	fade.tween_property(logo, "modulate:a", 0.0, fade_out_time)

	await fade.finished
	await get_tree().create_timer(0.3).timeout

	var error := get_tree().change_scene_to_file(main_menu_scene)

	if error != OK:
		push_error("Could not open main menu: " + main_menu_scene)
