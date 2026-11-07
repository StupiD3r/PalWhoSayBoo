extends Area3D

@export var camera_sway_enabled: bool = true
@export var camera_sway_distance: float = 0.04
@export var camera_sway_degrees: float = 1.0
@export var camera_sway_speed: float = 1.2
@export var camera_move_time: float = 1.2
@export var dialogue_camera: Camera3D

@export var npc_name: String = "MANANAYAW"

@export_multiline var dialogue_lines: Array[String] = [
	"NPC|Happy Festival!",
	"NPC|Sayaw muna! Halika, sabayan mo ako!",
	"IKAW|Ang saya mo naman. Kanina ka pa sumasayaw?",
	"NPC|Siyempre! Minsan lang ang piyesta, sulitin na natin!",
	"NPC|Tara, kahit isang kanta lang!",
	"IKAW|Gusto ko sana, kaso pupunta pa ako sa competition.",
	"NPC|Ay, sasali ka pala sa Palosebo! Handa ka na ba?",
	"IKAW|Oo naman! Maya, balik ako.",
	"NPC|Sige, good luck sa competition mo!",
	"NPC|Pag nanalo ka, sayaw tayo ulit!"
]

@export var talk_once: bool = true

@export_group("Dialogue Animation")

@export var shout_mode: bool = true

@export_range(1.0, 100.0, 1.0)
var letters_per_second: float = 30.0

@export_range(1.0, 2.0, 0.05)
var shout_typing_multiplier: float = 1.2

@export_group("Talking Sound")

# Leave empty to use the built-in blip.
@export var talking_sound: AudioStream

@export_range(-40.0, 0.0, 1.0)
var talking_volume_db: float = -16.0

@export_range(0.0, 10.0, 1.0)
var shout_boost_db: float = 4.0

@export_range(0.03, 0.3, 0.01)
var blip_interval: float = 0.065

@export_range(0.5, 2.0, 0.05)
var npc_voice_pitch: float = 0.95

@export_range(0.5, 2.0, 0.05)
var player_voice_pitch: float = 1.15

var text_blip: AudioStreamPlayer
var blip_cooldown: float = 0.0
var reveal: float = 0.0

var camera_sway_time: float = 0.0
var camera_tween: Tween
var camera_transitioning: bool = false
var closeup_pose: Transform3D
var closeup_fov: float
var camera_pose_saved: bool = false

var previous_camera: Camera3D
var pending_player: CharacterBody3D
var last_status: String = ""

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

	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_resolve_dialogue_camera()


func _setup_talking_sound() -> void:
	# Reuse an existing TextBlip child if you already added one.
	text_blip = get_node_or_null("TextBlip") as AudioStreamPlayer

	if text_blip == null:
		text_blip = AudioStreamPlayer.new()
		text_blip.name = "TextBlip"
		add_child(text_blip)

	text_blip.autoplay = false
	text_blip.stop()
	text_blip.bus = &"Master"
	text_blip.max_polyphony = 1

	if talking_sound != null:
		text_blip.stream = talking_sound

	if text_blip.stream == null:
		text_blip.stream = _make_default_blip()
		push_warning(
			"Talking Sound is empty. Using the built-in dialogue blip."
		)

	text_blip.volume_db = _get_voice_volume()


func _make_default_blip() -> AudioStreamWAV:
	var sample_rate: int = 22050
	var duration: float = 0.045
	var sample_count: int = int(float(sample_rate) * duration)

	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)

	for i in range(sample_count):
		var time: float = float(i) / float(sample_rate)
		var progress: float = float(i) / float(sample_count - 1)

		# Smooth edges prevent clicking.
		var envelope: float = sin(PI * progress)
		envelope *= envelope

		var wave: float = (
			sin(TAU * 300.0 * time)
			+ 0.25 * sin(TAU * 600.0 * time)
			+ 0.12 * sin(TAU * 900.0 * time)
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


func _get_voice_volume() -> float:
	var boost: float = shout_boost_db if shout_mode else 0.0
	return clampf(talking_volume_db + boost, -40.0, 0.0)


func _play_text_blip() -> void:
	if not is_instance_valid(text_blip):
		return

	if text_blip.stream == null:
		return

	if blip_cooldown > 0.0 or text_blip.playing:
		return

	var pitch: float = (
		player_voice_pitch
		if name_label.text == "IKAW"
		else npc_voice_pitch
	)

	if shout_mode:
		pitch *= 1.05

	text_blip.pitch_scale = pitch * randf_range(0.96, 1.04)
	text_blip.volume_db = _get_voice_volume()
	text_blip.play()

	blip_cooldown = blip_interval


func _stop_text_blip() -> void:
	if is_instance_valid(text_blip):
		text_blip.stop()

	blip_cooldown = 0.0


func _move_camera_to(
	target_pose: Transform3D,
	target_fov: float
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
		maxf(camera_move_time, 0.1)
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
	style.border_color = Color(0.8, 0.75, 0.55)
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
	name_label.modulate = Color(1.0, 0.85, 0.5)
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


func _report_status(message: String) -> void:
	if message != last_status:
		last_status = message
		print("[", name, "] ", message)


func _resolve_dialogue_camera() -> void:
	if is_instance_valid(dialogue_camera):
		return

	dialogue_camera = get_node_or_null("DancingNPCCam") as Camera3D

	if dialogue_camera == null:
		dialogue_camera = (
			get_parent().get_node_or_null("DancingNPCCam") as Camera3D
		)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	if not (
		body.is_in_group("player")
		or body.is_in_group("Player")
	):
		_report_status(
			"Add the player's CharacterBody3D to the Player group."
		)
		return

	if talking:
		return

	if talk_once and has_talked:
		_report_status(
			"Already completed. Turn Talk Once off to repeat."
		)
		return

	pending_player = body as CharacterBody3D
	_try_pending_dialogue()


func _on_body_exited(body: Node3D) -> void:
	if body == pending_player:
		pending_player = null
		last_status = ""


func _physics_process(_delta: float) -> void:
	# Wait if another conversation has disabled the player.
	if not talking and is_instance_valid(pending_player):
		_try_pending_dialogue()


func _try_pending_dialogue() -> void:
	if not is_instance_valid(pending_player):
		return

	if talking:
		return

	if talk_once and has_talked:
		pending_player = null
		return

	if dialogue_lines.is_empty():
		_report_status("Blocked: Dialogue Lines is empty.")
		return

	if not pending_player.can_process():
		_report_status(
			"Waiting: player is paused or in another dialogue."
		)
		return

	player = pending_player
	_start_dialogue()

	if talking:
		pending_player = null


func _start_dialogue() -> void:
	camera_sway_time = 0.0
	_resolve_dialogue_camera()

	if not is_instance_valid(dialogue_camera):
		_report_status(
			"Blocked: assign DancingNPCCam to Dialogue Camera."
		)
		return

	previous_camera = get_viewport().get_camera_3d()

	if not is_instance_valid(previous_camera):
		_report_status("Blocked: no current gameplay camera.")
		return

	if previous_camera == dialogue_camera:
		_report_status(
			"Blocked: turn DancingNPCCam Current off before testing."
		)
		return

	_report_status(
		"Starting dialogue with " + str(dialogue_camera.name)
	)

	talking = true
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

	_move_camera_to(closeup_pose, closeup_fov).finished.connect(
		func() -> void:
			camera_transitioning = false
			_show_line()
			dialogue_panel.show()
	)


func _input(event: InputEvent) -> void:
	if not talking:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()

		if camera_transitioning:
			return

		# First press reveals the rest of the current line.
		if dialogue_label.visible_characters < dialogue_label.text.length():
			reveal = float(dialogue_label.text.length())
			dialogue_label.visible_characters = dialogue_label.text.length()

			_stop_text_blip()
			_update_continue_label()
			return

		# Next press advances the conversation.
		line_index += 1

		if line_index >= dialogue_lines.size():
			_finish_dialogue()
		else:
			_show_line()


func _show_line() -> void:
	_stop_text_blip()
	reveal = 0.0

	var parts := dialogue_lines[line_index].split("|", true, 1)
	var line_text: String

	if parts.size() == 2:
		var speaker_name: String = parts[0].strip_edges()

		name_label.text = (
			npc_name if speaker_name == "NPC" else speaker_name
		)
		line_text = parts[1]
	else:
		name_label.text = npc_name
		line_text = dialogue_lines[line_index]

	name_label.modulate = (
		Color(0.6, 0.85, 1.0)
		if name_label.text == "IKAW"
		else Color(1.0, 0.85, 0.5)
	)

	# Hide letters before assigning the new line.
	dialogue_label.visible_characters = 0
	dialogue_label.text = (
		line_text.to_upper() if shout_mode else line_text
	)

	dialogue_label.add_theme_font_size_override(
		"font_size",
		26 if shout_mode else 24
	)

	_update_continue_label()


func _reveal_dialogue(delta: float) -> void:
	var total: int = dialogue_label.text.length()
	var previous_count: int = maxi(
		dialogue_label.visible_characters, 0
	)

	if previous_count >= total:
		return

	var speed: float = letters_per_second

	if shout_mode:
		speed *= shout_typing_multiplier

	reveal = minf(reveal + delta * speed, float(total))

	var new_count: int = mini(int(reveal), total)
	dialogue_label.visible_characters = new_count

	if new_count <= previous_count:
		return

	for character_index in range(previous_count, new_count):
		var character: String = dialogue_label.text.substr(
			character_index, 1
		)

		if character.strip_edges().is_empty():
			continue

		if character in [
			".", ",", "!", "?", "…", ":", ";", "—", "-", "'", "’"
		]:
			continue

		_play_text_blip()
		break


func _update_continue_label() -> void:
	if dialogue_label.visible_characters < dialogue_label.text.length():
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
			previous_camera.fov
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
	camera_transitioning = false
	previous_camera = null

	if is_instance_valid(player):
		player.process_mode = previous_process_mode


func _process(delta: float) -> void:
	if not talking or camera_transitioning:
		return

	# Typing and audio work independently from camera sway.
	blip_cooldown = maxf(0.0, blip_cooldown - delta)
	_reveal_dialogue(delta)
	_update_continue_label()

	if not camera_sway_enabled:
		return

	if not is_instance_valid(dialogue_camera):
		return

	camera_sway_time += delta * camera_sway_speed

	var sway: float = sin(camera_sway_time)
	var gentle_tilt: float = sin(camera_sway_time * 0.7)

	var pose := closeup_pose

	pose.origin += (
		closeup_pose.basis.x * sway * camera_sway_distance
	)

	var angles := Vector3(
		deg_to_rad(camera_sway_degrees * 0.3) * gentle_tilt,
		deg_to_rad(camera_sway_degrees) * sway,
		0.0
	)

	pose.basis = closeup_pose.basis * Basis.from_euler(angles)
	dialogue_camera.global_transform = pose


func _exit_tree() -> void:
	_stop_text_blip()

	if talking:
		_restore_player()
