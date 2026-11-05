extends Node3D

const RetryWake = preload("res://Scripts/retry_wake_sequence.gd")
const LolaGuide = preload("res://Scripts/lola_guide.gd")

@export var player: CharacterBody3D
@export var gameplay_camera: Camera3D
@export_range(-40.0, 0.0) var ambient_volume_db: float = -22.0

@onready var cutscene_camera: Camera3D = $CutsceneCamera
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var previous_process_mode: Node.ProcessMode
var finished := false


func _ready() -> void:
	_start_ambient_music()
	# Start after the other scene nodes finish their setup.
	call_deferred("_begin_cutscene")


func _start_ambient_music() -> void:
	var scene := get_parent()
	if scene.has_node("WakeAmbientMusic"):
		return
	var music := AudioStreamPlayer.new()
	music.name = "WakeAmbientMusic"
	var stream := preload("res://Assets/Audio/ambient bgm free.mp3").duplicate() as AudioStreamMP3
	stream.loop = true
	music.stream = stream
	music.volume_db = -50.0
	# Keep the ambience after this temporary intro node is removed.
	scene.add_child.call_deferred(music)
	music.ready.connect(func():
		music.play()
		var fade := music.create_tween()
		fade.tween_property(music, "volume_db", ambient_volume_db, 1.5)
	, CONNECT_ONE_SHOT)


func _begin_cutscene() -> void:
	var is_retry := bool(Engine.get_meta(RetryWake.RETRY_META, false))
	if get_parent().has_node("Lola") and not get_parent().has_node("LolaGuide"):
		var guide := LolaGuide.new()
		guide.name = "LolaGuide"
		guide.required_intro = not is_retry and not bool(Engine.get_meta(LolaGuide.COMPLETED_META, false))
		get_parent().add_child.call_deferred(guide)
	if Engine.has_meta(RetryWake.RETRY_META):
		Engine.remove_meta(RetryWake.RETRY_META)
	# Find your existing player if it wasn't assigned.
	if player == null:
		player = get_parent().get_node_or_null(
			"Player"
		) as CharacterBody3D

	# This matches your latest player hierarchy.
	if gameplay_camera == null and player != null:
		gameplay_camera = player.get_node_or_null(
		"Player/Skeleton3D/TwistPivot/PitchPivot/FirstPersonCam"
		) as Camera3D

	if player == null or gameplay_camera == null:
		push_error(
			"Assign Player and Gameplay Camera on OpeningCutscene."
		)
		return

	if is_retry:
		# Keep the initial AnimationPlayer sequence unchanged; retries use FPV.
		previous_process_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		animation_player.stop()
		var retry := RetryWake.new()
		retry.name = "RetryWake"
		add_child(retry)
		retry.play(player, gameplay_camera, cutscene_camera, get_node_or_null("BlinkLayer/Eyelids") as Control, _on_animation_finished.bind(&"intro"))
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
