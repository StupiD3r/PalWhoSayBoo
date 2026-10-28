extends Control

@onready var start_button: Button = $StartButton
@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var bgm: AudioStreamPlayer = $BGM

var settings_dialog: AcceptDialog
var credits_dialog: AcceptDialog
var start_dialog: AcceptDialog


func _ready() -> void:
	bgm.play()
	_create_dialogs()

	start_button.pressed.connect(_start_pressed)
	start_button.mouse_entered.connect(_play_hover_sound)
	for button in [
		start_button,
		
	]:
		button.add_theme_constant_override("shadow_offset_x", 0)
		button.add_theme_constant_override("shadow_offset_y", 0)
		button.add_theme_constant_override("shadow_outline_size", 8)
		button.add_theme_color_override(
			"font_shadow_color", Color(1, 1, 1, 0)
		)

		button.mouse_entered.connect(
			_set_button_glow.bind(button, true)
		)
		button.mouse_exited.connect(
			_set_button_glow.bind(button, false)
		)

func _create_dialogs() -> void:
	# Settings window.
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


	# Credits window.
	credits_dialog = AcceptDialog.new()
	credits_dialog.title = "Credits"
	credits_dialog.dialog_text = (
		"Created by: Your Name\n\nMade with Godot"
	)
	add_child(credits_dialog)

	# Temporary Start window to test the button.
	start_dialog = AcceptDialog.new()
	start_dialog.title = "Start"
	start_dialog.dialog_text = "Start button works!"
	add_child(start_dialog)


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

	if enabled:
		glow_color = Color(1, 1, 1, 0.35)

	button.add_theme_color_override(
		"font_shadow_color", glow_color
	)
