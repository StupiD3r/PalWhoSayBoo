extends Node3D

@export var opening_angle := 90.0
@export var opening_time := 0.7

@onready var hinge: AnimatableBody3D = $Hinge
@onready var interaction_area: Area3D = $InteractionArea
@onready var prompt: Label3D = $Prompt

var nearby_player: CharacterBody3D
var closed_transform: Transform3D
var current_angle := 0.0
var is_open := false
var moving := false


func _ready() -> void:
	closed_transform = hinge.global_transform

	prompt.text = "E — Open"
	prompt.hide()

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.is_in_group("Player"):
		nearby_player = body as CharacterBody3D
		prompt.show()


func _on_body_exited(body: Node3D) -> void:
	if body == nearby_player:
		nearby_player = null
		prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if moving or not is_instance_valid(nearby_player):
		return

	if not nearby_player.can_process():
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_toggle_door()


func _toggle_door() -> void:
	moving = true
	is_open = not is_open

	prompt.text = "Opening..." if is_open else "Closing..."

	var target_angle := deg_to_rad(opening_angle) if is_open else 0.0

	var tween := create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_method(
		_apply_door_angle,
		current_angle,
		target_angle,
		opening_time
	)

	await tween.finished

	moving = false
	prompt.text = "E — Close" if is_open else "E — Open"


func _apply_door_angle(angle: float) -> void:
	current_angle = angle

	# Swing around the world's vertical axis.
	var turn := Basis(Vector3.UP, angle)

	hinge.global_transform = Transform3D(
		turn * closed_transform.basis,
		closed_transform.origin
	)
