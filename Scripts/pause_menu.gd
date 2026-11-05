extends CanvasLayer
const SoundMix = preload("res://Scripts/audio_mix.gd")

var is_paused: bool = false
var settings_open: bool = false
var previous_mouse_mode: Input.MouseMode
var previous_focus: WeakRef
var paused_scene: WeakRef
var audio_states: Array[Dictionary] = []
var screen: Control
var panel: PanelContainer
var main_options: VBoxContainer
var settings_panel: VBoxContainer
var title: Label
var resume_button: Button
var back_button: Button
var sound_rows: Dictionary = {}
var sound_scroll: ScrollContainer
var preview_sound: AudioStreamPlayer
var preview_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_menu()
	get_viewport().size_changed.connect(_layout)
	get_tree().node_removed.connect(_on_node_removed)
	_layout()
	hide()

func _build_menu() -> void:
	screen = Control.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.006, 0.009, 0.016, 0.82)
	screen.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	center.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.028, 0.038, 0.96)
	style.border_color = Color(0.58, 0.44, 0.25, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	main_options = VBoxContainer.new()
	main_options.add_theme_constant_override("separation", 16)
	panel.add_child(main_options)
	title = Label.new()
	title.text = "PalWhoSayBoo"
	title.add_theme_font_override("font", preload("res://UI/HororDramaDemoRegular.ttf"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65))
	main_options.add_child(title)
	resume_button = _button("Resume", main_options, resume_game)
	_button("Settings", main_options, show_settings)
	_button("Quit", main_options, func(): get_tree().quit())
	settings_panel = VBoxContainer.new()
	settings_panel.add_theme_constant_override("separation", 16)
	panel.add_child(settings_panel)
	var settings_title := Label.new()
	settings_title.text = "Sound settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_title.add_theme_font_size_override("font_size", 32)
	settings_panel.add_child(settings_title)
	var description := Label.new()
	description.text = "100% = balanced level   •   0% = mute\nChanges save automatically. Test one sound at a time."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 16)
	settings_panel.add_child(description)
	sound_scroll = ScrollContainer.new()
	sound_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_panel.add_child(sound_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 14)
	sound_scroll.add_child(rows)
	var mix := get_node_or_null("/root/AudioMix")
	for entry in SoundMix.CONTROLS:
		var profile: String = entry[0]
		var row := VBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override("font_size", 19)
		row.add_child(label)
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 12)
		row.add_child(controls)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 200
		slider.step = 1
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = mix.get_level(profile) if mix else 100.0
		controls.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 58
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.text = str(roundi(slider.value)) + "%"
		controls.add_child(value)
		var test := Button.new()
		test.text = "Test"
		test.custom_minimum_size = Vector2(62, 32)
		test.pressed.connect(_test_sound.bind(entry))
		controls.add_child(test)
		slider.value_changed.connect(_on_sound_level.bind(profile, value))
		sound_rows[profile] = {"slider": slider, "value": value}
	_button("Reset sound levels", settings_panel, _reset_sound_levels)
	back_button = _button("Back", settings_panel, show_main)
	settings_panel.hide()
	preview_sound = AudioStreamPlayer.new()
	preview_sound.name = "SettingsPreview"
	preview_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(preview_sound)
	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.timeout.connect(preview_sound.stop)
	add_child(preview_timer)

func _button(text: String, parent: Control, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	var width := get_viewport().get_visible_rect().size.x
	panel.custom_minimum_size.x = clampf(width - 48.0, 260.0, 840.0 if settings_open else 520.0)
	sound_scroll.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 380.0, 80.0, 420.0)
	title.add_theme_font_size_override("font_size", int(clampf(width * 0.065, 28.0, 50.0)))

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if is_paused:
		if settings_open:
			show_main()
		else:
			resume_game()
	elif _in_game():
		pause_game()
	else:
		return
	get_viewport().set_input_as_handled()

func _in_game() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.has_node("Player") and scene.has_node("TypingUI")

func pause_game() -> void:
	if is_paused or get_tree().paused or not _in_game():
		return
	previous_mouse_mode = Input.mouse_mode
	var focus := get_viewport().gui_get_focus_owner()
	previous_focus = weakref(focus) if focus else null
	paused_scene = weakref(get_tree().current_scene)
	audio_states.clear()
	_pause_audio(get_tree().root)
	is_paused = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	show_main()

func _pause_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.get("playing"):
			audio_states.append({"node": weakref(node), "paused": node.get("stream_paused")})
			node.set("stream_paused", true)
	for child in node.get_children():
		_pause_audio(child)

func resume_game() -> void:
	if not is_paused:
		return
	preview_sound.stop()
	preview_timer.stop()
	var mix := get_node_or_null("/root/AudioMix")
	if mix:
		mix.save_levels()
	get_tree().paused = false
	for state in audio_states:
		var node: Node = state.node.get_ref()
		if is_instance_valid(node):
			node.set("stream_paused", state.paused)
	audio_states.clear()
	is_paused = false
	settings_open = false
	hide()
	Input.mouse_mode = previous_mouse_mode
	var focus: Control = previous_focus.get_ref() if previous_focus else null
	if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
		focus.grab_focus()
	paused_scene = null

func show_settings() -> void:
	settings_open = true
	main_options.hide()
	settings_panel.show()
	_layout()
	back_button.grab_focus.call_deferred()

func show_main() -> void:
	preview_sound.stop()
	preview_timer.stop()
	settings_open = false
	settings_panel.hide()
	main_options.show()
	_layout()
	resume_button.grab_focus.call_deferred()

func _on_node_removed(node: Node) -> void:
	if is_paused and paused_scene and paused_scene.get_ref() == node:
		resume_game()

func _on_sound_level(value: float, profile: String, display: Label) -> void:
	display.text = str(roundi(value)) + "%"
	var mix := get_node_or_null("/root/AudioMix")
	if mix:
		mix.set_level(profile, value)

func _test_sound(entry: Array) -> void:
	var stream := load("res://" + String(entry[2])) as AudioStream
	if stream == null:
		return
	preview_sound.stop()
	stream = stream.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	preview_sound.stream = stream
	preview_sound.volume_db = float(entry[3])
	preview_sound.bus = "Mix_" + String(entry[0])
	preview_sound.play()
	preview_timer.start(2.5)

func _reset_sound_levels() -> void:
	var mix := get_node_or_null("/root/AudioMix")
	if mix:
		mix.reset_levels()
	for profile in sound_rows:
		sound_rows[profile].slider.set_value_no_signal(100.0)
		sound_rows[profile].value.text = "100%"
