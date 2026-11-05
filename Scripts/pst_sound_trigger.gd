extends Area3D

@export var play_once: bool = true

@onready var sound: AudioStreamPlayer = $Sound

var has_played: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	if not body.is_in_group("player"):
		return

	if play_once and has_played:
		return

	if sound.playing:
		return

	if sound.stream == null:
		push_warning("Assign an audio file to Sound.")
		return

	has_played = true
	sound.play()
