extends Area3D

var player_node = null
@onready var prompt_label = $Label3D # Reference to your floating "Press E" label

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_node = body
		# Only show prompt if player isn't already climbing
		if prompt_label and not player_node.is_climbing:
			prompt_label.visible = true

func _on_body_exited(body):
	if body.name == "Player":
		player_node = null
		if prompt_label:
			prompt_label.visible = false

func _input(event):
	if player_node and event.is_action_pressed("interact"):
		# ONLY attach when not climbing. Pressing 'E' during climb does NOTHING now!
		if not player_node.is_climbing:
			player_node.start_climbing(global_position)
			if prompt_label:
				prompt_label.visible = false
