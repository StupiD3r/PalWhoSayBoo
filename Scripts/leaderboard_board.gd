extends Node3D

const DEFAULT_PATH := "user://release_high_scores_v1.cfg"
const Store = preload("res://Scripts/leaderboard_store.gd")
const RecordsView = preload("res://Scripts/leaderboard_view.gd")
@export var pole_path: NodePath = NodePath("../Bamboo/BambooPole")
@export var player_path: NodePath = NodePath("../Player")
@export var placement_anchor_path: NodePath = NodePath("../Sketchfab_Scene4")
@export var offset_from_anchor: Vector3 = Vector3(-22.0, 0.0, 43.0)
@export var offset_from_pole: Vector3 = Vector3(10.0, 0.0, 6.0)
var record_path: String = DEFAULT_PATH
var player: CharacterBody3D
var pole: Node3D
var near_player: bool = false
var score_names: Array[Label3D] = []
var score_values: Array[Label3D] = []
var wpm_names: Array[Label3D] = []
var wpm_values: Array[Label3D] = []
var prompt: Label3D
var solid_body: StaticBody3D
var records_view: CanvasLayer
var previous_player_mode: Node.ProcessMode
var previous_mouse_mode: Input.MouseMode
var refresh_elapsed: float = 0.0

func _ready() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	pole = get_node_or_null(pole_path) as Node3D
	var anchor := get_node_or_null(placement_anchor_path) as Node3D
	if anchor:
		global_position = anchor.global_position + offset_from_anchor
		look_at(global_position + Vector3.LEFT, Vector3.UP, true)
	elif pole:
		global_position = pole.global_position + offset_from_pole
		look_at(Vector3(pole.global_position.x, global_position.y, pole.global_position.z), Vector3.UP, true)
	_build_sign()
	refresh()
	_place_on_ground.call_deferred()

func _build_sign() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.085, 0.035)
	wood.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.065, 0.035, 0.018)
	dark.roughness = 1.0
	_box(Vector3(9.6, 5.2, 0.18), Vector3(0, 3.8, 0), wood)
	for x in [-3.7, 3.7]:
		_box(Vector3(0.22, 6.5, 0.24), Vector3(x, 3.25, -0.15), dark)
	for y in [1.2, 2.0, 2.8, 3.6, 4.4, 5.2, 6.4]:
		_box(Vector3(9.65, 0.035, 0.025), Vector3(0, y, 0.105), dark)
	_box(Vector3(0.035, 4.0, 0.025), Vector3(0, 3.5, 0.11), dark)
	_text("PAL WHO SAY BOO - LOCAL RECORDS", Vector3(0, 6.04, 0.15), 42, Color(1.0, 0.85, 0.45))
	_text("TOP 10 SCORES", Vector3(-2.35, 5.52, 0.15), 40, Color(1.0, 0.85, 0.45))
	_text("TOP 10 WPM", Vector3(2.35, 5.52, 0.15), 40, Color(0.65, 1.0, 0.82))
	for index in range(10):
		var y := 4.98 - index * 0.36
		score_names.append(_text("", Vector3(-4.35, y, 0.16), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		score_values.append(_text("", Vector3(-0.3, y, 0.16), 42, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_RIGHT))
		wpm_names.append(_text("", Vector3(0.3, y, 0.16), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT))
		wpm_values.append(_text("", Vector3(4.35, y, 0.16), 42, Color(0.65, 1.0, 0.82), HORIZONTAL_ALIGNMENT_RIGHT))
	_text("PRESS E TO VIEW RECORDS AND THE LAST 20 ATTEMPTS", Vector3(0, 1.42, 0.16), 27, Color(0.9, 0.8, 0.62))
	prompt = _text("[ E ] VIEW RECORDS", Vector3(0, 0.8, 0.18), 38, Color(1.0, 0.85, 0.45))
	prompt.hide()
	solid_body = StaticBody3D.new()
	add_child(solid_body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.6, 6.4, 0.35)
	collision.shape = shape
	collision.position.y = 3.2
	solid_body.add_child(collision)
	var area := Area3D.new()
	area.name = "RecordsInteraction"
	add_child(area)
	var area_collision := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(10.2, 6.4, 5.5)
	area_collision.shape = area_shape
	area_collision.position = Vector3(0.0, 3.2, 2.2)
	area.add_child(area_collision)
	area.body_entered.connect(func(body: Node3D):
		if body == player:
			near_player = true
	)
	area.body_exited.connect(func(body: Node3D):
		if body == player:
			near_player = false
	)

func _box(dimensions: Vector3, origin: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = origin
	add_child(mesh)

func _text(value: String, origin: Vector3, font_size: int, tint: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = 0.0042
	label.modulate = tint
	label.outline_modulate = Color(0.025, 0.015, 0.01)
	label.outline_size = 4
	label.horizontal_alignment = alignment
	label.position = origin
	add_child(label)
	return label

func _place_on_ground() -> void:
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 35.0, global_position - Vector3.UP * 70.0)
	var excluded: Array[RID] = [solid_body.get_rid()]
	if player:
		excluded.append(player.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit.position.y + 0.03

func refresh() -> void:
	var store := Store.new()
	store.save_path = record_path
	var data := store.load_data()
	for index in range(10):
		_set_row(score_names[index], score_values[index], data.scores, index, "score")
		_set_row(wpm_names[index], wpm_values[index], data.wpm, index, "peak_wpm")

func _set_row(name_label: Label3D, value_label: Label3D, rows: Array, index: int, metric: String) -> void:
	name_label.text = str(index + 1) + ". " + (str(rows[index].name) if index < rows.size() else "---")
	value_label.text = str(rows[index][metric]) if index < rows.size() else ""

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed >= 2.0:
		refresh_elapsed = 0.0
		refresh()
	prompt.visible = near_player and not is_instance_valid(records_view) and player != null and not player.is_climbing

func _unhandled_input(event: InputEvent) -> void:
	if not near_player or not player or player.is_climbing or not player.can_process():
		return
	if event.is_action_pressed("interact") and not event.is_echo() and not is_instance_valid(records_view):
		get_viewport().set_input_as_handled()
		open_records()

func open_records() -> void:
	if is_instance_valid(records_view) or not player:
		return
	previous_player_mode = player.process_mode
	previous_mouse_mode = Input.mouse_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var audio := player.get_node_or_null("PlayerAudio")
	if audio and audio.has_method("stop_walk_step"):
		audio.stop_walk_step()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	records_view = RecordsView.new()
	records_view.record_path = record_path
	records_view.closed.connect(_close_records)
	add_child(records_view)

func _close_records() -> void:
	if player:
		player.process_mode = previous_player_mode
	Input.mouse_mode = previous_mouse_mode
	records_view = null
	refresh()
