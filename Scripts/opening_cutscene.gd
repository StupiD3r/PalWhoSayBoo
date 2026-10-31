extends Node3D

@export var player: CharacterBody3D
@export var gameplay_camera: Camera3D

@onready var cutscene_camera: Camera3D = $CutsceneCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var previous_process_mode: Node.ProcessMode
var finished := false


func _ready() -> void:
	# Start after the other scene nodes finish their setup.
	call_deferred("_begin_cutscene")


func _begin_cutscene() -> void:
	# Find your existing player if it wasn't assigned.
	if player == null:
		player = get_parent().get_node_or_null(
			"Player"
		) as CharacterBody3D

	# This matches your latest player hierarchy.
	if gameplay_camera == null and player != null:
		gameplay_camera = player.get_node_or_null(
			"Player/Skeleton3D/BoneAttachment3D2/TwistPivot/PitchPivot/FirstPersonCam"
		) as Camera3D

	if player == null or gameplay_camera == null:
		push_error(
			"Assign Player and Gameplay Camera on OpeningCutscene."
		)
		return

	if not animation_player.has_animation("intro"):
		push_error("Create an animation named intro.")
		return

	animation_player.get_animation(
		"intro"
	).loop_mode = Animation.LOOP_NONE

	# Freeze the player without pausing the whole scene.
	previous_process_mode = player.process_mode
	player.process_mode = Node.PROCESS_MODE_DISABLED

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cutscene_camera.make_current()

	animation_player.animation_finished.connect(
		_on_animation_finished
	)
	animation_player.play("intro")


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"intro" or finished:
		return

	finished = true

	gameplay_camera.make_current()
	player.process_mode = previous_process_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Remove the cutscene without reloading Main.
	queue_free()
