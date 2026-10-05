extends Area3D

# Looking specifically for the child node named "KnockSound"
@onready var knock_sound: AudioStreamPlayer3D = $KnockSound
@export var play_only_once: bool = true

var has_played: bool = false

func _on_body_entered(body: Node3D) -> void:
	# Check if the object entering the zone is the Player
	if body.name == "Player":
		if play_only_once and has_played:
			return
			
		knock_sound.play()
		has_played = true
		
