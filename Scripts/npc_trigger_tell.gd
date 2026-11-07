extends Area3D

@export var camera_move_time: float = 0.45
@export var dialogue_camera: Camera3D

@export var enable_pole_shot: bool = false
@export var pole_camera: Camera3D
@export var pole_move_time: float = 0.9
@export var return_move_time: float = 0.6

# Line numbers start at 1.
@export_range(1, 100, 1)
var pole_shot_start_line: int = 3

@export_range(1, 100, 1)
var pole_shot_end_line: int = 6

@export var npc_name: String = "STAFF"

@export_multiline var dialogue_lines: Array[String] = [
	"NPC|Uy! Asan ka galing? Kanina ka pa namin hinahanap!",
	"IKAW|Pasensya na, may kinausap lang ako. Bakit, anong meron?",
	"NPC|Ikaw na ang susunod na participant sa Palosebo!",
	"IKAW|Ako na agad? Sige, handa na ako!",
	"NPC|Punta ka na sa host malapit sa poste. Hinihintay ka na roon.",
	"IKAW|Sige, pupunta na ako. Salamat!",
	"NPC|Good luck! Galingan mo sa competition!"
]

@export var talk_once: bool = true

@export_group("Dialogue Pace")

@export_range(1.0, 100.0, 1.0)
var staff_letters_per_second: float = 44.0

@export_range(1.0, 100.0, 1.0)
var player_letters_per_second: float = 30.0

@export_range(0.0, 1.0, 0.01)
var comma_pause: float = 0.08

@export_range(0.0, 1.0, 0.01)
var sentence_pause: float = 0.18

@export_group("Talking Sound")

# Optional: assign a short, non-looping vocal blip.
@export var talking_sound: AudioStream

@export_range(-40.0, 0.0, 1.0)
var talking_volume_db: float = -15.0

@export_range(0.5, 2.0, 0.05)
var staff_voice_pitch: float = 1.1

@export_range(0.5, 2.0, 0.05)
var player_voice_pitch: float = 1.0

@export_range(0.03, 0.3, 0.005)
var blip_interval: float = 0.055

var text_blip: AudioStreamPlayer
var blip_cooldown: float = 0.0
var character_timer: float = 0.0
var player_speaking: bool = false

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
	_resolve_dialogue_camera()

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
	var duration: float = 0.04
	var sample_count: int = int(float(sample_rate) * duration)

	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)

	for i in range(sample_count):
		var time: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(sample_count - 1)

		var envelope: float = sin(PI * progress)
		envelope *= envelope

		var wave: float = (
			sin(TAU * 300.0 * time)
			+ 0.2 * sin(TAU * 600.0 * time)
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


func _play_text_blip() -> void:
	if not is_instance_valid(text_blip):
		return

	if text_blip.stream == null:
		return

	if blip_cooldown > 0.0 or text_blip.playing:
		return

	var pitch: float = (
		player_voice_pitch
		if player_speaking
		else staff_voice_pitch
	)

	text_blip.pitch_scale = pitch * randf_range(0.97, 1.03)
	text_blip.volume_db = talking_volume_db
	text_blip.play()

	blip_cooldown = blip_interval


func _stop_text_blip() -> void:
	if is_instance_valid(text_blip):
		text_blip.stop()

	blip_cooldown = 0.0


func _resolve_dialogue_camera() -> void:
	if is_instance_valid(dialogue_camera):
		return

	dialogue_camera = get_node_or_null("NPCTellCamera") as Camera3D

	if dialogue_camera == null:
		dialogue_camera = (
			get_parent().get_node_or_null("NPCTellCamera") as Camera3D
		)


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
	style.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	style.border_color = Color(0.8, 0.65, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
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
		body.is_in_group("player")
		or body.is_in_group("Player")
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
	_resolve_dialogue_camera()

	if not is_instance_valid(dialogue_camera):
		push_warning(
			"Select NPCTriggerTell and assign NPCTellCamera to Dialogue Camera."
		)
		return

	previous_camera = get_viewport().get_camera_3d()

	if not is_instance_valid(previous_camera):
		return

	if enable_pole_shot and is_instance_valid(pole_camera):
		if pole_camera == dialogue_camera:
			push_warning(
				"Dialogue Camera and Pole Camera must be different cameras."
			)
			return

	if (
		previous_camera == dialogue_camera
		or (
			enable_pole_shot
			and previous_camera == pole_camera
		)
	):
		push_warning(
			"Keep the dialogue cameras Current off before dialogue."
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

	var speed: float = (
		player_letters_per_second
		if player_speaking
		else staff_letters_per_second
	)

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

		var delay: float = 1.0 / maxf(speed, 1.0)

		if character in [",", ";", ":"]:
			delay += comma_pause

		elif character in [".", "!", "?", "…"]:
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

		# Next press advances to the following line.
		line_index += 1

		if line_index >= dialogue_lines.size():
			_finish_dialogue()
		else:
			_show_line()


func _show_line() -> void:
	_stop_text_blip()
	character_timer = 0.0

	var parts := dialogue_lines[line_index].split("|", true, 1)
	var line_text: String

	if parts.size() == 2:
		var speaker_tag: String = parts[0].strip_edges()

		player_speaking = speaker_tag == "IKAW"

		name_label.text = (
			npc_name if speaker_tag == "NPC" else speaker_tag
		)
		line_text = parts[1]
	else:
		player_speaking = false
		name_label.text = npc_name
		line_text = dialogue_lines[line_index]

	name_label.modulate = (
		Color(0.6, 0.85, 1.0)
		if player_speaking
		else Color(1.0, 0.8, 0.4)
	)

	dialogue_label.visible_characters = 0
	dialogue_label.text = line_text

	var line_number: int = line_index + 1

	var use_pole: bool = (
		enable_pole_shot
		and is_instance_valid(pole_camera)
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
