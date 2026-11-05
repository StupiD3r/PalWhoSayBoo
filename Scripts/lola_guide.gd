extends Node3D

const COMPLETED_META := "pal_who_say_boo_lola_intro_completed"
@export var required_intro: bool = true
@export var interaction_radius: float = 5.0
var player: CharacterBody3D
var lola: Node3D
var pole: Node3D
var skeleton: Skeleton3D
var head_bone: int = -1
var near_lola: bool = false
var active: bool = false
var returning: bool = false
var objective_done: bool = false
var line_index: int = 0
var line_age: float = 0.0
var reveal: float = 0.0
var camera: Camera3D
var source_camera: Camera3D
var source_pose: Transform3D
var previous_mode: Node.ProcessMode
var saved_lola_rotation: Vector3
var return_pose: Transform3D
var return_age: float = 0.0
var layer: CanvasLayer
var panel: PanelContainer
var speaker: Label
var subtitle: RichTextLabel
var hint: Label
var prompt: Label
var objective: Label
var dialogue: Array[Array] = [
	["LOLA", "APO!!"],
	["LOLA", "Pupunta ka na ba sa piyesta?"],
	["LOLA", "Sigurado ka na? Maraming kumakalat na balita ngayon… may sumpa raw ang posteng ’yon."],
	["IKAW", "Ano ka ba, La? Kaya kong akyatin ’yon, noh!"],
	["LOLA", "Sige… mag-ingat ka."],
	["LOLA", "Alam mo naman ang daan, ’di ba?"],
	["LOLA", "Diretso ka lang dito. Makikita mo na agad."],
	["LOLA", "Basta huwag mong kalimutan…"],
	["LOLA", "Salita ang sandata sa pag-akyat."],
]

func _ready() -> void:
	add_to_group("lola_intro_dialogue")
	reset_for_retry()
	player = get_parent().get_node_or_null("Player") as CharacterBody3D
	lola = get_parent().get_node_or_null("Lola") as Node3D
	pole = get_parent().get_node_or_null("Bamboo/BambooPole") as Node3D
	if player == null or lola == null:
		queue_free()
		return
	var skeletons := lola.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		skeleton = skeletons[0] as Skeleton3D
		head_bone = skeleton.find_bone("mixamorig_Head")
	_build_ui()
	if player.has_signal("climbing_started"):
		player.connect("climbing_started", func(): objective_done = true)

func reset_for_retry() -> void:
	# Also supports retries that reuse this scene instead of reloading it.
	if active:
		_release()

	required_intro = true
	objective_done = false
	near_lola = false
	active = false
	returning = false
	line_index = 0
	line_age = 0.0
	reveal = 0.0
	return_age = 0.0

	# Engine metadata survives scene reloads, so clear the previous run.
	if Engine.has_meta(COMPLETED_META):
		Engine.remove_meta(COMPLETED_META)

	if is_instance_valid(panel):
		panel.hide()
	if is_instance_valid(prompt):
		prompt.hide()
	if is_instance_valid(objective):
		objective.text = "Kausapin muna si Lola sa labas ng bahay."
		objective.visible = _can_talk()

func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = -205
	panel.offset_bottom = -28
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.018, 0.026, 0.9)
	style.border_color = Color(0.5, 0.39, 0.21, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	speaker = Label.new()
	speaker.add_theme_font_size_override("font_size", 20)
	column.add_child(speaker)
	subtitle = RichTextLabel.new()
	subtitle.scroll_active = false
	subtitle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_font_size_override("normal_font_size", 26)
	column.add_child(subtitle)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 16)
	hint.modulate = Color(0.78, 0.81, 0.86)
	column.add_child(hint)
	prompt = Label.new()
	prompt.text = "E — Kausapin si Lola"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(prompt)
	prompt.anchor_top = 0.8
	prompt.anchor_bottom = 0.8
	prompt.anchor_right = 1.0
	prompt.add_theme_font_size_override("font_size", 24)
	_style_text(prompt)
	objective = Label.new()
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(objective)
	objective.anchor_left = 0.1
	objective.anchor_right = 0.9
	objective.offset_top = 65
	objective.offset_bottom = 115
	objective.add_theme_font_size_override("font_size", 20)
	objective.modulate = Color(1.0, 0.86, 0.57)
	_style_text(objective)
	panel.hide()
	prompt.hide()
	objective.hide()

func _style_text(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)

func _head_target() -> Vector3:
	if is_instance_valid(skeleton) and head_bone >= 0:
		return skeleton.global_transform * skeleton.get_bone_global_pose(head_bone).origin + Vector3.UP * 0.12
	return lola.global_position + Vector3.UP * 4.2

func _can_talk() -> bool:
	if not is_instance_valid(player) or not player.can_process() or player.get("is_climbing") == true:
		return false
	if get_parent().has_node("OpeningCutscene"):
		return false
	var current := get_viewport().get_camera_3d()
	return current != null and player.is_ancestor_of(current)

func _physics_process(_delta: float) -> void:
	if active or not is_instance_valid(player) or not is_instance_valid(lola):
		return
	near_lola = false
	if not _can_talk():
		return
	var difference := player.global_position - lola.global_position
	if Vector2(difference.x, difference.z).length() > interaction_radius or absf(difference.y) > 6.0:
		return
	# Avoid calling through the wall before the player has left the house.
	var eye := get_viewport().get_camera_3d().global_position
	var query := PhysicsRayQueryParameters3D.create(eye, _head_target())
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and not lola.is_ancestor_of(hit.collider):
		return
	near_lola = true
	if required_intro:
		begin_dialogue()

func _process(delta: float) -> void:
	if layer == null:
		return
	objective.visible = not active and not objective_done and _can_talk()
	objective.text = "Kausapin muna si Lola sa labas ng bahay." if required_intro else "Pumunta sa poste sa piyesta."
	prompt.visible = not active and not required_intro and near_lola and _can_talk()
	if not active:
		return
	if not is_instance_valid(player) or not is_instance_valid(source_camera):
		_release(false)
		return
	if get_viewport().get_camera_3d() != camera:
		_release(false)
		return
	if returning:
		return_age += delta
		camera.global_transform = return_pose.interpolate_with(source_pose, smoothstep(0.0, 0.65, return_age))
		camera.fov = lerpf(68.0, source_camera.fov, smoothstep(0.0, 0.65, return_age))
		if return_age >= 0.65:
			_release()
		return
	line_age += delta
	reveal += delta * (28.0 if line_index == 8 else 42.0)
	subtitle.visible_characters = mini(int(reveal), subtitle.text.length())
	var target := _head_target()
	if line_index == 6 and is_instance_valid(pole):
		target = pole.global_position
		target.y = camera.global_position.y
	var desired := Transform3D(camera.global_basis, source_pose.origin).looking_at(target, Vector3.UP)
	camera.global_transform = camera.global_transform.interpolate_with(desired, 1.0 - exp(-4.0 * delta))
	camera.fov = lerpf(camera.fov, 68.0, 1.0 - exp(-4.0 * delta))
	hint.text = "E — Ipakita ang linya" if subtitle.visible_characters < subtitle.text.length() else ("E — Magpatuloy" if line_index < dialogue.size() - 1 else "E — Tapusin")

func _input(event: InputEvent) -> void:
	if event.is_action("ui_cancel"):
		return
	if active:
		if event.is_action_pressed("interact") and not event.is_echo() and not returning:
			advance_dialogue()
		get_viewport().set_input_as_handled()
	elif near_lola and _can_talk() and event.is_action_pressed("interact") and not event.is_echo():
		begin_dialogue()
		get_viewport().set_input_as_handled()

func begin_dialogue() -> bool:
	if active or not _can_talk():
		return false
	source_camera = get_viewport().get_camera_3d()
	source_pose = source_camera.global_transform.orthonormalized()
	previous_mode = player.process_mode
	player.velocity = Vector3.ZERO
	var audio := player.get_node_or_null("PlayerAudio")
	if audio and audio.has_method("stop_walk_step"):
		audio.stop_walk_step()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	saved_lola_rotation = lola.rotation
	lola.look_at(Vector3(player.global_position.x, lola.global_position.y, player.global_position.z), Vector3.UP, true)
	camera = Camera3D.new()
	add_child(camera)
	camera.global_transform = source_pose
	camera.fov = source_camera.fov
	camera.near = source_camera.near
	camera.far = source_camera.far
	camera.cull_mask = source_camera.cull_mask
	camera.environment = source_camera.environment
	camera.attributes = source_camera.attributes
	camera.make_current()
	active = true
	returning = false
	line_index = 0
	_show_line()
	panel.show()
	prompt.hide()
	objective.hide()
	return true

func _show_line() -> void:
	speaker.text = dialogue[line_index][0]
	speaker.modulate = Color(0.6, 0.85, 1.0) if speaker.text == "IKAW" else Color(1.0, 0.82, 0.45)
	subtitle.text = dialogue[line_index][1]
	subtitle.modulate = Color(1.0, 0.88, 0.61) if line_index == 8 else Color.WHITE
	subtitle.visible_characters = 0
	reveal = 0.0
	line_age = 0.0
	hint.text = "E — Ipakita ang linya"

func advance_dialogue() -> void:
	if line_age < 0.35 or (line_index in [6, 7] and line_age < 1.0):
		return
	if subtitle.visible_characters < subtitle.text.length():
		reveal = subtitle.text.length()
		subtitle.visible_characters = subtitle.text.length()
		return
	if line_index < dialogue.size() - 1:
		line_index += 1
		_show_line()
	else:
		required_intro = false
		Engine.set_meta(COMPLETED_META, true)
		returning = true
		return_age = 0.0
		return_pose = camera.global_transform
		panel.hide()

func show_required_hint() -> void:
	if is_instance_valid(objective):
		objective.text = "Kausapin muna si Lola sa labas ng bahay."
		objective.show()

func _release(restore_camera: bool = true) -> void:
	active = false
	returning = false
	if is_instance_valid(player):
		player.process_mode = previous_mode
	if is_instance_valid(lola) and is_instance_valid(source_camera):
		lola.rotation = saved_lola_rotation
	if restore_camera and is_instance_valid(source_camera):
		source_camera.make_current()
	if is_instance_valid(camera):
		camera.queue_free()
	camera = null
	source_camera = null
	if is_instance_valid(panel):
		panel.hide()

func _exit_tree() -> void:
	if active:
		_release(false)
