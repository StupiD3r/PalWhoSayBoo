extends Area3D

var player_node = null

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.name == "Player":
		player_node = body
		print("Press 'E' to start climbing")

func _on_body_exited(body):
	if body.name == "Player":
		player_node = null

func _input(event):
	# Press 'E' to attach to or detach from the pole
	if player_node and event.is_action_pressed("interact"):
		if not player_node.is_climbing:
			player_node.start_climbing(global_position)
		else:
			player_node.is_climbing = false # Detach
