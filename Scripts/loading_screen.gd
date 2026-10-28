extends Control

const GAME_SCENE := "res://Elements/main.tscn"
const TARGET := "PLAY"

@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var typing_sound: AudioStreamPlayer = $TypingSound

var status_label: Label
var instruction_label: Label
var letters: Array[Label] = []

var typed_count := 0
var ready_to_type := false
var starting := false


func _ready() -> void:
	background_music.play()

	# Pitch-black background.
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Center the loading message and typing prompt.
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	center.add_child(column)

	status_label = Label.new()
	status_label.text = "LOADING..."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(status_label)

	# Instruction above PLAY.
	instruction_label = Label.new()
	instruction_label.text = "type to continue"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.add_theme_color_override(
		"font_color", Color.WHITE
	)
	column.add_child(instruction_label)
	instruction_label.hide()

	var word_row := HBoxContainer.new()
	word_row.alignment = BoxContainer.ALIGNMENT_CENTER
	word_row.add_theme_constant_override("separation", 12)
	column.add_child(word_row)

	for character in TARGET:
		var letter := Label.new()
		letter.text = character
		letter.add_theme_font_size_override("font_size", 72)
		letter.add_theme_color_override(
			"font_color", Color(0.18, 0.18, 0.18)
		)
		word_row.add_child(letter)
		letters.append(letter)

	word_row.hide()

	# Load gameplay in the background.
	var error := ResourceLoader.load_threaded_request(GAME_SCENE)

	if error != OK:
		status_label.text = "Could not load the game."
		push_error("Check scene path: " + GAME_SCENE)
		return

	await get_tree().create_timer(1.0).timeout

	while true:
		var load_status := ResourceLoader.load_threaded_get_status(
			GAME_SCENE
		)

		if load_status == ResourceLoader.THREAD_LOAD_LOADED:
			break

		if load_status == ResourceLoader.THREAD_LOAD_FAILED \
		or load_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			status_label.text = "Loading failed."
			push_error("Loading failed: " + GAME_SCENE)
			return

		await get_tree().process_frame

	status_label.hide()
	instruction_label.show()
	word_row.show()
	ready_to_type = true


func _input(event: InputEvent) -> void:
	if not ready_to_type or starting:
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_BACKSPACE:
		if typed_count > 0:
			typing_sound.play()
			typed_count -= 1
			_update_colors()
		return

	if event.unicode == 0:
		return

	var character := String.chr(event.unicode).to_upper()

	if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
		return

	typing_sound.play()

	# Ignore incorrect letters.
	if character != TARGET.substr(typed_count, 1):
		return

	typed_count += 1
	_update_colors()

	if typed_count == TARGET.length():
		starting = true
		ready_to_type = false
		_start_game()


func _update_colors() -> void:
	for index in range(letters.size()):
		var color := Color(0.18, 0.18, 0.18)

		if index < typed_count:
			color = Color.WHITE

		letters[index].add_theme_color_override(
			"font_color", color
		)


func _start_game() -> void:
	# Briefly show the completed white word.
	await get_tree().create_timer(0.5).timeout

	instruction_label.hide()

	for letter in letters:
		letter.hide()

	# Play the presentation before entering gameplay.
	await _show_presents()

	var game_scene := ResourceLoader.load_threaded_get(
		GAME_SCENE
	) as PackedScene

	if game_scene == null:
		status_label.text = "Could not open the game."
		status_label.show()
		return

	var error := get_tree().change_scene_to_packed(game_scene)

	if error != OK:
		status_label.text = "Could not start the game."
		status_label.show()
		push_error("Scene change failed: %s" % error)


func _show_presents() -> void:
	var presents := Label.new()
	presents.text = "PhobicPhilia Presents......"
	presents.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	presents.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	presents.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	presents.add_theme_font_size_override("font_size", 40)
	presents.add_theme_color_override("font_color", Color.WHITE)
	presents.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(presents)
	presents.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	presents.modulate.a = 0.0

	var fade := create_tween()

	# Fade in.
	fade.tween_property(presents, "modulate:a", 1.0, 1.5)

	# Hold.
	fade.tween_interval(2.0)

	# Fade out.
	fade.tween_property(presents, "modulate:a", 0.0, 1.5)

	await fade.finished
	presents.queue_free()

	# Brief black screen before gameplay.
	await get_tree().create_timer(0.5).timeout
