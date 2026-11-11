extends Control

@onready var start_button: Button = $StartButton
@onready var credits_button: Button = $CreditsButton
@onready var quit_button: Button = $QuitButton
@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var bgm: AudioStreamPlayer = $BGM

var settings_dialog: AcceptDialog
var credits_dialog: AcceptDialog
var start_dialog: AcceptDialog
var quit_dialog: ConfirmationDialog # Added a new variable for the Quit confirmation
var hover_tweens: Dictionary = {}

func _ready() -> void:
	bgm.play()
	_create_dialogs()
	_create_facebook_button()

	# Connect pressed signals
	start_button.pressed.connect(_start_pressed)
	credits_button.pressed.connect(_credits_pressed)
	quit_button.pressed.connect(_quit_pressed)
	
	# Connect hover sounds
	start_button.mouse_entered.connect(_play_hover_sound)
	credits_button.mouse_entered.connect(_play_hover_sound)
	quit_button.mouse_entered.connect(_play_hover_sound)

	# Apply your styling and glow effect to all buttons!
	for button in [
		start_button,
		credits_button,
		quit_button
	]:
		# Set the pivot to the exact center of the button
		button.pivot_offset = button.size / 2.0

		button.add_theme_constant_override("shadow_offset_x", 0)
		button.add_theme_constant_override("shadow_offset_y", 0)
		button.add_theme_constant_override("shadow_outline_size", 8)
		button.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0))

		button.mouse_entered.connect(_set_button_glow.bind(button, true))
		button.mouse_exited.connect(_set_button_glow.bind(button, false))

func _create_facebook_button() -> void:
	var facebook_logo := Image.new()
	facebook_logo.load_svg_from_string("""
		<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24">
		  <circle cx="12" cy="12" r="12" fill="#0866ff"/>
		  <path fill="#fff" d="M13.9 24v-9.3H17l.5-3.6h-3.6V8.8c0-1 .3-1.8 1.8-1.8h1.9V3.8c-.3 0-1.5-.1-2.8-.1-2.8 0-4.7 1.7-4.7 4.8v2.6H7v3.6h3.1V24z"/>
		</svg>
	""")
	var facebook_button := Button.new()
	facebook_button.icon = ImageTexture.create_from_image(facebook_logo)
	facebook_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	facebook_button.custom_minimum_size = Vector2(44, 44)
	facebook_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	facebook_button.tooltip_text = "PhobicPhilia on Facebook"
	facebook_button.mouse_entered.connect(_play_hover_sound)
	facebook_button.pressed.connect(func() -> void:
		click_sound.play()
		OS.shell_open("https://www.facebook.com/PhobicPhilia")
	)
	var follow_row := HBoxContainer.new()
	follow_row.add_theme_constant_override("separation", 8)
	follow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(follow_row)
	follow_row.add_child(facebook_button)

	var arrow := Label.new()
	arrow.text = "\u2190"
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.add_theme_font_size_override("font_size", 24)
	arrow.add_theme_constant_override("outline_size", 4)
	follow_row.add_child(arrow)

	var follow_label := Label.new()
	follow_label.text = "Follow Us"
	follow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	follow_label.add_theme_font_override("font", preload("res://UI/HororDramaDemoRegular.ttf"))
	follow_label.add_theme_font_size_override("font_size", 26)
	follow_label.add_theme_constant_override("outline_size", 4)
	follow_row.add_child(follow_label)

	follow_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	follow_row.position += Vector2(16, -16)

	follow_label.resized.connect(func() -> void:
		follow_label.pivot_offset = follow_label.size * 0.5
	)
	follow_label.pivot_offset = follow_label.size * 0.5

	var dance := follow_label.create_tween().set_loops()
	dance.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	dance.tween_property(follow_label, "rotation_degrees", -8.0, 0.16)
	dance.parallel().tween_property(follow_label, "scale", Vector2(1.1, 1.1), 0.16)
	dance.tween_property(follow_label, "rotation_degrees", 8.0, 0.23)
	dance.tween_property(follow_label, "rotation_degrees", -5.0, 0.19)
	dance.tween_property(follow_label, "rotation_degrees", 0.0, 0.18)
	dance.parallel().tween_property(follow_label, "scale", Vector2.ONE, 0.18)
	dance.tween_interval(0.8)

func _create_dialogs() -> void:
	# --- Settings Window ---
	settings_dialog = AcceptDialog.new()
	settings_dialog.title = "Settings"
	add_child(settings_dialog)

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 16)
	settings_dialog.add_child(container)

	var volume_label := Label.new()
	volume_label.text = "Master Volume"
	container.add_child(volume_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.custom_minimum_size = Vector2(260, 32)

	var master_bus := AudioServer.get_bus_index("Master")
	slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(master_bus)
	)

	# --- Credits Window (Upgraded Design) ---
	credits_dialog = AcceptDialog.new()
	credits_dialog.title = "Credits"
	add_child(credits_dialog)
	
	# Use a VBoxContainer to organize the text neatly
	var credits_vbox := VBoxContainer.new()
	credits_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	credits_vbox.add_theme_constant_override("separation", 12) # Space between elements
	credits_dialog.add_child(credits_vbox)
	
	# Team Name Label
	var team_label := Label.new()
	team_label.text = "- PhobicPhilia -"
	team_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	team_label.add_theme_font_size_override("font_size", 28) # Larger font for the team name
	credits_vbox.add_child(team_label)
	
	# Team Members Label (Edit these 3 names to match your actual team!)
	var members_label := Label.new()
	members_label.text = "D3r / NiFer \nBlack Siren \n Hazuxa"
	members_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	members_label.add_theme_font_size_override("font_size", 18)
	credits_vbox.add_child(members_label)
	
	# "Made with Godot" footer
	var godot_label := Label.new()
	godot_label.text = "\nMade with Godot Engine"
	godot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	godot_label.add_theme_font_size_override("font_size", 14)
	godot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6)) # Gray color
	credits_vbox.add_child(godot_label)



	# --- Start Window (Temporary) ---
	start_dialog = AcceptDialog.new()
	start_dialog.title = "Start"
	start_dialog.dialog_text = "Start button works!"
	add_child(start_dialog)
	
	# --- Quit Confirmation Window ---
	quit_dialog = ConfirmationDialog.new()
	quit_dialog.title = "Quit Game"
	quit_dialog.dialog_text = "Are you sure you want to leave?"
	quit_dialog.get_ok_button().text = "Yes"
	quit_dialog.get_cancel_button().text = "No"
	add_child(quit_dialog)
	
	# Connect the "Yes" button to actually quit the game
	quit_dialog.confirmed.connect(_on_quit_confirmed)


func _start_pressed() -> void:
	click_sound.play()

	start_button.disabled = true
	var intro_scene := preload(
		"res://UI/loading_screen.tscn"
	)
	var intro := intro_scene.instantiate()

	var overlay := CanvasLayer.new()
	overlay.layer = 10
	add_child(overlay)
	overlay.add_child(intro)

func _play_hover_sound() -> void:
	hover_sound.play()
	
func _set_button_glow(button: Button, enabled: bool) -> void:
	var glow_color := Color(1, 1, 1, 0)
	
	# If this button is already animating, stop the old animation
	if hover_tweens.has(button) and hover_tweens[button]:
		hover_tweens[button].kill()

	if enabled:
		glow_color = Color(1, 1, 1, 0.35)
		
		# Create a looping animation (set_loops) for the shake
		var tween = create_tween().set_loops()
		hover_tweens[button] = tween
		
		# Rotate right, then left, using a smooth SINE wave transition
		tween.tween_property(button, "rotation_degrees", 3.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(button, "rotation_degrees", -3.0, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	else:
		# When the mouse leaves, smoothly return the button to 0 rotation
		var tween = create_tween()
		hover_tweens[button] = tween
		tween.tween_property(button, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	button.add_theme_color_override("font_shadow_color", glow_color)
	
func _credits_pressed() -> void:
	click_sound.play()
	credits_dialog.popup_centered()

func _quit_pressed() -> void:
	click_sound.play()
	# Instead of instantly quitting, show the Yes/No dialog
	quit_dialog.popup_centered()

func _on_quit_confirmed() -> void:
	# The player clicked "Yes" in the popup window
	click_sound.play()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
