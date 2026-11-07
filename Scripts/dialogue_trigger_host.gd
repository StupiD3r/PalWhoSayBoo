extends Area3D

@export var camera_move_time: float = 0.45
@export var dialogue_camera: Camera3D
@export var pole_camera: Camera3D
@export var pole_move_time: float = 0.9
@export var return_move_time: float = 0.6

# Line numbers start at 1 in the Inspector.
@export_range(1, 100, 1)
var pole_shot_start_line: int = 3

@export_range(1, 100, 1)
var pole_shot_end_line: int = 6

@export var npc_name: String = "HOST"

@export_multiline var dialogue_lines: Array[String] = [
	"Hoy! Ikaw na ang susunod na kalahok!",
	"Maligayang pagdating sa paligsahan ng Palosebo!",
	"Simple lang ang hamon: akyatin ang madulas na poste at abutin ang premyo sa tuktok.",
	"Pero sa paligsahang ito, salita ang sandata mo.",
	"I-type nang tama ang mga salitang lalabas para makaakyat.",
	"Bilisan mo, pero huwag magkamali. Bawat letra, mahalaga.",
	"Handa ka na? Lumapit ka sa poste kapag gusto mo nang magsimula.",
	"Good luck, kalahok… sana makarating ka sa taas."
]

@export var talk_once: bool = true

@export_group("Horror Dialogue")

@export_range(1.0, 100.0, 1.0)
var letters_per_second: float = 28.0

@export_range(1.0, 100.0, 1.0)
var ominous_letters_per_second: float = 20.0

@export_range(1.0, 100.0, 1.0)
var final_line_letters_per_second: float = 17.0

# These lines get slower typing and a lower voice.
# The final line always gets the horror effect.
@export var ominous_lines: Array[int] = [4, 6, 8]

@export_range(0.0, 1.0, 0.05)
var comma_pause: float = 0.18

@export_range(0.0, 1.5, 0.05)
var sentence_pause: float = 0.4

@export_range(0.0, 2.0, 0.05)
var ellipsis_pause: float = 0.75

@export_group("Talking Sound")

# Optional: use a short, non-looping vocal blip.
# If empty, the script uses TextBlip's stream or a built-in sound.
@export var talking_sound: AudioStream

@export_range(-40.0, 0.0, 1.0)
var talking_volume_db: float = -15.0

@export_range(0.5, 2.0, 0.05)
var voice_pitch: float = 0.95

@export_range(0.5, 2.0, 0.05)
var horror_voice_pitch: float = 0.82

@export_range(0.03, 0.3, 0.01)
var blip_interval: float = 0.075

var text_blip: AudioStreamPlayer
var blip_cooldown: float = 0.0
var character_timer: float = 0.0

var showing_pole: bool = false
var camera_tween: Tween
var camera_transitioning: bool = false
var closeup_pose: Transform3D
var closeup_fov: float
var camera_pose_saved: bool = false
var previous_camera: Camera3D

var talking: bool = false
var has_talked: bool = false
var line_index: int = 0

var player: CharacterBody3D
var previous_process_mode: Node.ProcessMode

var dialogue_layer: CanvasLayer
var dialogue_panel: PanelContainer
var name_label: Label
var dialogue_label: Label
var continue_label: Label


func _ready() -> void:
	_setup_talking_sound()
	_create_dialogue_ui()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _setup_talking_sound() -> void:
	text_blip = get_node_or_null("TextBlip") as AudioStreamPlayer

	if text_blip == null:
		text_blip = AudioStreamPlayer.new()
		text_blip.name = "TextBlip"
		add_child(text_blip)

	text_blip.autoplay = false
	text_blip.stop()
	text_blip.bus = &"Master"
	text_blip.max_polyphony = 1
	text_blip.volume_db = talking_volume_db

	if talking_sound != null:
		text_blip.stream = talking_sound

	if text_blip.stream == null:
		text_blip.stream = _make_default_blip()


func _make_default_blip() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.055
	var sample_count: int = int(float(sample_rate) * duration)

	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)

	for i in range(sample_count):
		var time: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(sample_count - 1)

		# Smooth beginning and ending.
		var envelope: float = sin(PI * progress)
		envelope *= envelope

		# Low tone with a little roughness.
		var wave: float = (
			sin(TAU * 260.0 * time)
			+ 0.22 * sin(TAU * 520.0 * time)
			+ 0.1 * sin(TAU * 780.0 * time)
		)

		var sample_value: float = wave * envelope * 0.4

		audio_data.encode_s16(
			i * 2,
			int(clampf(sample_value, -1.0, 1.0) * 32767.0)
		)

	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = sample_rate
	sound.stereo = false
	sound.loop_mode = AudioStreamWAV.LOOP_DISABLED
	sound.data = audio_data

	return sound


func _is_ominous_line() -> bool:
	return (
		line_index == dialogue_lines.size() - 1
		or (line_index + 1) in ominous_lines
	)


func _get_typing_speed() -> float:
	if line_index == dialogue_lines.size() - 1:
		return final_line_letters_per_second

	if _is_ominous_line():
		return ominous_letters_per_second

	if line_index <= 1:
		# The opening sounds more like an announcer.
		return letters_per_second * 1.15

	return letters_per_second


func _play_text_blip() -> void:
	if not is_instance_valid(text_blip):
		return

	if text_blip.stream == null:
		return

	if blip_cooldown > 0.0 or text_blip.playing:
		return

	var pitch: float = voice_pitch

	if _is_ominous_line():
		pitch = horror_voice_pitch

	if line_index == dialogue_lines.size() - 1:
		pitch *= 0.94

	text_blip.pitch_scale = pitch * randf_range(0.98, 1.02)
	text_blip.volume_db = talking_volume_db
	text_blip.play()

	blip_cooldown = blip_interval

	if _is_ominous_line():
		blip_cooldown *= 1.2


func _stop_text_blip() -> void:
	if is_instance_valid(text_blip):
		text_blip.stop()

	blip_cooldown = 0.0


func _move_camera_to(
	target_pose: Transform3D,
	target_fov: float,
	duration: float
) -> Tween:
	if camera_tween != null:
		camera_tween.kill()

	var start_pose := dialogue_camera.global_transform
	var start_fov := dialogue_camera.fov

	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE)
	camera_tween.set_ease(Tween.EASE_IN_OUT)

	camera_tween.tween_method(
		func(weight: float) -> void:
			dialogue_camera.global_transform = (
				start_pose.interpolate_with(target_pose, weight)
			)
			dialogue_camera.fov = lerpf(
				start_fov, target_fov, weight
			),
		0.0,
		1.0,
		maxf(duration, 0.1)
	)

	return camera_tween


func _create_dialogue_ui() -> void:
	dialogue_layer = CanvasLayer.new()
	dialogue_layer.layer = 20
	add_child(dialogue_layer)

	dialogue_panel = PanelContainer.new()
	dialogue_layer.add_child(dialogue_panel)

	dialogue_panel.set_anchors_and_offsets_preset(
		Control.PRESET_BOTTOM_WIDE
	)

	dialogue_panel.offset_left = 30
	dialogue_panel.offset_right = -30
	dialogue_panel.offset_top = -210
	dialogue_panel.offset_bottom = -30
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.018, 0.022, 0.97)
	style.border_color = Color(0.48, 0.22, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 15
	style.content_margin_bottom = 15

	dialogue_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	dialogue_panel.add_child(column)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.modulate = Color(0.95, 0.72, 0.55)
	column.add_child(name_label)

	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_label.visible_characters_behavior = (
		TextServer.VC_CHARS_AFTER_SHAPING
	)
	dialogue_label.add_theme_font_size_override("font_size", 24)
	column.add_child(dialogue_label)

	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_font_size_override("font_size", 18)
	continue_label.modulate = Color(0.72, 0.69, 0.69)
	column.add_child(continue_label)

	dialogue_panel.hide()


func _on_body_entered(body: Node3D) -> void:
	if talking:
		return

	if talk_once and has_talked:
		return

	if not body is CharacterBody3D:
		return

	if not (
		body.is_in_group("Player")
		or body.is_in_group("player")
	):
		return

	if dialogue_lines.is_empty():
		push_warning("Add Dialogue Lines in the Inspector.")
		return

	player = body as CharacterBody3D

	if not player.can_process():
		return

	_start_dialogue()


func _start_dialogue() -> void:
	if not is_instance_valid(dialogue_camera):
		push_warning("Assign Dialogue Camera on the host trigger.")
		return

	previous_camera = get_viewport().get_camera_3d()

	if not is_instance_valid(previous_camera):
		return

	if is_instance_valid(pole_camera):
		if pole_camera == dialogue_camera:
			push_warning(
				"Dialogue Camera and Pole Camera must be different cameras."
			)
			return

	if (
		previous_camera == dialogue_camera
		or previous_camera == pole_camera
	):
		push_warning(
			"Keep DialogueCamera and PoleCamera Current off before dialogue."
		)
		return

	talking = true
	showing_pole = false
	camera_transitioning = true
	line_index = 0

	previous_process_mode = player.process_mode
	player.velocity = Vector3.ZERO

	var player_audio := player.get_node_or_null("PlayerAudio")

	if player_audio and player_audio.has_method("stop_walk_step"):
		player_audio.call("stop_walk_step")

	player.process_mode = Node.PROCESS_MODE_DISABLED

	closeup_pose = (
		dialogue_camera.global_transform.orthonormalized()
	)
	closeup_fov = dialogue_camera.fov
	camera_pose_saved = true

	dialogue_camera.global_transform = (
		previous_camera.global_transform.orthonormalized()
	)
	dialogue_camera.fov = previous_camera.fov
	dialogue_camera.make_current()

	dialogue_panel.hide()

	_move_camera_to(
		closeup_pose,
		closeup_fov,
		camera_move_time
	).finished.connect(
		func() -> void:
			camera_transitioning = false
			_show_line()
			dialogue_panel.show()
	)


func _process(delta: float) -> void:
	if not talking or camera_transitioning:
		return

	blip_cooldown = maxf(0.0, blip_cooldown - delta)

	_reveal_dialogue(delta)
	_update_continue_hint()


func _reveal_dialogue(delta: float) -> void:
	var total: int = dialogue_label.text.length()

	if dialogue_label.visible_characters >= total:
		return

	var speed: float = maxf(_get_typing_speed(), 1.0)

	# Avoid revealing a whole sentence after a long frame.
	character_timer -= minf(delta, 0.1)

	while (
		character_timer <= 0.0
		and dialogue_label.visible_characters < total
	):
		var character_index: int = dialogue_label.visible_characters
		var character: String = dialogue_label.text.substr(
			character_index, 1
		)

		dialogue_label.visible_characters += 1

		var delay: float = 1.0 / speed

		# Small timing changes make the delivery less mechanical.
		delay *= randf_range(0.95, 1.1)

		if character in [",", ";", ":"]:
			delay += comma_pause

		elif character == "…":
			delay += ellipsis_pause

		elif character == ".":
			var next_character: String = dialogue_label.text.substr(
				character_index + 1, 1
			)

			# Treat three dots as one pause.
			if next_character != ".":
				var previous_character: String = ""

				if character_index > 0:
					previous_character = dialogue_label.text.substr(
						character_index - 1, 1
					)

				delay += (
					ellipsis_pause
					if previous_character == "."
					else sentence_pause
				)

		elif character in ["!", "?"]:
			delay += sentence_pause

		elif not character.strip_edges().is_empty():
			if character not in ["—", "-", "'", "’"]:
				_play_text_blip()

		character_timer += delay


func _input(event: InputEvent) -> void:
	if not talking:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()

		if camera_transitioning:
			return

		# First press reveals the rest of the current line.
		if dialogue_label.visible_characters < dialogue_label.text.length():
			dialogue_label.visible_characters = dialogue_label.text.length()
			character_timer = 0.0

			_stop_text_blip()
			_update_continue_hint()
			return

		# Next press advances the conversation.
		line_index += 1

		if line_index >= dialogue_lines.size():
			_finish_dialogue()
		else:
			_show_line()


func _show_line() -> void:
	_stop_text_blip()

	name_label.text = npc_name

	dialogue_label.visible_characters = 0
	dialogue_label.text = dialogue_lines[line_index]

	if line_index == dialogue_lines.size() - 1:
		dialogue_label.modulate = Color(1.0, 0.67, 0.62)
		character_timer = 0.5

	elif _is_ominous_line():
		dialogue_label.modulate = Color(0.98, 0.83, 0.66)
		character_timer = 0.15

	else:
		dialogue_label.modulate = Color(0.94, 0.92, 0.86)
		character_timer = 0.0

	var line_number: int = line_index + 1

	var use_pole: bool = (
		is_instance_valid(pole_camera)
		and line_number >= pole_shot_start_line
		and line_number <= pole_shot_end_line
	)

	if use_pole != showing_pole:
		showing_pole = use_pole
		camera_transitioning = true
		_update_continue_hint()

		var target_pose := closeup_pose
		var target_fov := closeup_fov
		var duration := camera_move_time

		if use_pole:
			target_pose = (
				pole_camera.global_transform.orthonormalized()
			)
			target_fov = pole_camera.fov
			duration = pole_move_time

		_move_camera_to(
			target_pose,
			target_fov,
			duration
		).finished.connect(
			func() -> void:
				camera_transitioning = false
				_update_continue_hint()
		)

	else:
		_update_continue_hint()


func _update_continue_hint() -> void:
	if camera_transitioning:
		continue_label.text = "Sandali…"
	elif dialogue_label.visible_characters < dialogue_label.text.length():
		continue_label.text = "E — Ipakita ang linya"
	elif line_index == dialogue_lines.size() - 1:
		continue_label.text = "E — Tapusin"
	else:
		continue_label.text = "E — Magpatuloy"


func _finish_dialogue() -> void:
	if camera_transitioning:
		return

	_stop_text_blip()

	dialogue_panel.hide()
	camera_transitioning = true

	if is_instance_valid(previous_camera):
		_move_camera_to(
			previous_camera.global_transform.orthonormalized(),
			previous_camera.fov,
			return_move_time
		).finished.connect(_complete_dialogue)
	else:
		_complete_dialogue()


func _complete_dialogue() -> void:
	talking = false
	has_talked = true
	_restore_player()


func _restore_player() -> void:
	_stop_text_blip()

	if camera_tween != null:
		camera_tween.kill()
		camera_tween = null

	if is_instance_valid(previous_camera):
		previous_camera.make_current()

	if camera_pose_saved and is_instance_valid(dialogue_camera):
		dialogue_camera.global_transform = closeup_pose
		dialogue_camera.fov = closeup_fov

	camera_pose_saved = false
	showing_pole = false
	camera_transitioning = false
	previous_camera = null

	if is_instance_valid(player):
		player.process_mode = previous_process_mode


func _exit_tree() -> void:
	_stop_text_blip()

	if talking:
		_restore_player()
