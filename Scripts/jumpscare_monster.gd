extends Node3D

@export_range(0.1, 2.0, 0.05)
var scare_duration: float = 0.35

# Optional: assign a Marker3D positioned at the monster's face.
@export var look_target: Node3D

@onready var monster: Node3D = $Character_Monster_03
@onready var trigger: Area3D = $JumpscareTrigger
@onready var scare_sound: AudioStreamPlayer = (
	get_node_or_null("ScareSound") as AudioStreamPlayer
)

var played: bool = false
var running: bool = false

var player: CharacterBody3D
var player_camera: Camera3D
var saved_camera_transform: Transform3D
var previous_process_mode: Node.ProcessMode


func _ready() -> void:
	monster.hide()

	if not trigger.body_entered.is_connected(_on_body_entered):
		trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if played or running:
		return

	if not body is CharacterBody3D:
		return

	if not (
		body.is_in_group("Player")
		or body.is_in_group("player")
	):
		return

	if not body.can_process():
		return

	player_camera = get_viewport().get_camera_3d()

	if not is_instance_valid(player_camera):
		return

	var focus: Vector3 = _get_monster_focus()
	var direction: Vector3 = focus - player_camera.global_position

	if direction.length_squared() < 0.0001:
		return

	played = true
	running = true

	player = body as CharacterBody3D
	previous_process_mode = player.process_mode
	saved_camera_transform = player_camera.global_transform

	player.velocity = Vector3.ZERO

	var player_audio := player.get_node_or_null("PlayerAudio")

	if player_audio and player_audio.has_method("stop_walk_step"):
		player_audio.call("stop_walk_step")

	player.process_mode = Node.PROCESS_MODE_DISABLED

	# Reveal the monster.
	monster.show()

	# Turn the player's camera toward it immediately.
	var camera_up := Vector3.UP

	if absf(direction.normalized().dot(camera_up)) > 0.999:
		camera_up = Vector3.FORWARD

	player_camera.look_at(focus, camera_up)

	if is_instance_valid(scare_sound):
		scare_sound.play()

	await get_tree().create_timer(scare_duration).timeout

	_restore_gameplay()


func _get_monster_focus() -> Vector3:
	if is_instance_valid(look_target):
		return look_target.global_position

	# Aim toward the upper part of the monster mesh.
	if monster is MeshInstance3D:
		var mesh := monster as MeshInstance3D
		var bounds: AABB = mesh.get_aabb()
		var local_focus: Vector3 = bounds.get_center()

		local_focus.y = bounds.position.y + bounds.size.y * 0.8

		return mesh.to_global(local_focus)

	return monster.global_position + Vector3.UP * 1.5


func _restore_gameplay() -> void:
	if is_instance_valid(monster):
		monster.hide()

	if is_instance_valid(player_camera):
		if player_camera.is_inside_tree():
			player_camera.global_transform = saved_camera_transform

	if is_instance_valid(player):
		player.process_mode = previous_process_mode

	running = false


func _exit_tree() -> void:
	if running:
		_restore_gameplay()
