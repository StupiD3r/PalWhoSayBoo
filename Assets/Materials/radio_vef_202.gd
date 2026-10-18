extends Area3D

@onready var radio_audio: AudioStreamPlayer3D = $RadioAudio
@export var play_only_once: bool = true

var has_played: bool = false

func _on_body_entered(body: Node3D) -> void:
	# Check if the player is the one walking into the zone
	if body.name == "Player":
		if play_only_once and has_played:
			return
			
		# Play the music if it isn't already playing
		if not radio_audio.playing:
			radio_audio.play()
			has_played = true
