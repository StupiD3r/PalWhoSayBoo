extends Area3D

@export var camera_move_time: float = 1.2

var camera_tween: Tween
var camera_transitioning: bool = false
var closeup_pose: Transform3D
var closeup_fov: float
var camera_pose_saved: bool = false

@export var dialogue_camera: Camera3D

var previous_camera: Camera3D

@export var npc_name: String = "Kapitbahay"
@export_multiline var dialogue_lines: Array[String] = [
	"Hoy! Sandali!",
	"Pupunta ka ba sa piyesta?",
	"Mag-ingat ka roon. May kakaiba sa posteng iyon."
]
@export var talk_once: bool = true

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
	_create_dialogue_ui()
	body_entered.connect(_on_body_entered)

func _move_camera_to(target_pose: Transform3D, target_fov: float) -> Tween:
	if camera_tween != null:
		camera_tween.kill()

	var start_pose := dialogue_camera.global_transform
	var start_fov := dialogue_camera.fov

	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE)
	camera_tween.set_ease(Tween.EASE_IN_OUT)

	camera_tween.tween_method(
		func(weight: float) -> void:
			dialogue_camera.global_transform = start_pose.interpolate_with(
				target_pose, weight
			)
			dialogue_camera.fov = lerpf(start_fov, target_fov, weight),
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
	dialogue_label.add_theme_font_size_override("font_size", 24)
	column.add_child(dialogue_label)

	continue_label = Label.new()
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	continue_label.add_theme_font_size_override("font_size", 18)
	column.add_child(continue_label)

	dialogue_panel.hide()


func _on_body_entered(body: Node3D) -> void:
	print("Dialogue trigger detected: ", body.name)

	if talking:
		return

	if talk_once and has_talked:
		return

	if not body is CharacterBody3D:
		return

	if not body.is_in_group("Player"):
		print("This body is missing the player group.")
		return

	if dialogue_lines.is_empty():
		print("Add dialogue lines in the Inspector.")
		return

	player = body as CharacterBody3D

	if not player.can_process():
		print("Player is paused or disabled.")
		return

	_start_dialogue()


func _start_dialogue() -> void:
	if not is_instance_valid(dialogue_camera):
		push_warning("Assign Dialogue Camera on DialogueTrigger.")
		return

	previous_camera = get_viewport().get_camera_3d()

	if not is_instance_valid(previous_camera):
		return

	if previous_camera == dialogue_camera:
		push_warning("Keep DialogueCamera Current off before dialogue.")
		return

	talking = true
	camera_transitioning = true
	line_index = 0

	previous_process_mode = player.process_mode
	player.velocity = Vector3.ZERO

	var player_audio := player.get_node_or_null("PlayerAudio")
	if player_audio and player_audio.has_method("stop_walk_step"):
		player_audio.call("stop_walk_step")

	player.process_mode = Node.PROCESS_MODE_DISABLED

	# Remember the close-up you positioned in the editor.
	closeup_pose = dialogue_camera.global_transform.orthonormalized()
	closeup_fov = dialogue_camera.fov
	camera_pose_saved = true

	# Begin from the player's current view.
	dialogue_camera.global_transform = (
		previous_camera.global_transform.orthonormalized()
	)
	dialogue_camera.fov = previous_camera.fov
	dialogue_camera.make_current()

	dialogue_panel.hide()

	_move_camera_to(closeup_pose, closeup_fov).finished.connect(
		func() -> void:
			camera_transitioning = false
			name_label.text = npc_name
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

		line_index += 1

		if line_index >= dialogue_lines.size():
			_finish_dialogue()
		else:
			_show_line()


func _show_line() -> void:
	dialogue_label.text = dialogue_lines[line_index]

	if line_index == dialogue_lines.size() - 1:
		continue_label.text = "E — Tapusin"
	else:
		continue_label.text = "E — Magpatuloy"


func _finish_dialogue() -> void:
	if camera_transitioning:
		return

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
	if camera_tween != null:
		camera_tween.kill()
		camera_tween = null

	if is_instance_valid(previous_camera):
		previous_camera.make_current()

	# Reset the NPC camera for the next conversation.
	if camera_pose_saved and is_instance_valid(dialogue_camera):
		dialogue_camera.global_transform = closeup_pose
		dialogue_camera.fov = closeup_fov

	camera_pose_saved = false
	camera_transitioning = false
	previous_camera = null

	if is_instance_valid(player):
		player.process_mode = previous_process_mode


func _exit_tree() -> void:
	if talking:
		_restore_player()
