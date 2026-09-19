extends Area3D

var player_node = null
@onready var prompt_label = $Label3D # Grabs a reference to your new floating text

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_node = body
		prompt_label.visible = true # Shows the floating text

func _on_body_exited(body):
	if body.name == "Player":
		player_node = null
		prompt_label.visible = false # Hides the text when they walk away

func _input(event):
	if player_node and event.is_action_pressed("interact"):
		if not player_node.is_climbing:
			player_node.start_climbing(global_position)
			prompt_label.visible = false # Hide text once they start climbing
		else:
			player_node.is_climbing = false # Detach
			prompt_label.visible = true # Show text again when they jump off
