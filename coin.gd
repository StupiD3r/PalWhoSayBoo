extends Area3D

var player_in_range = false

func _ready():
	# Connects the area signals so we know when the player enters/leaves
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	print("Something bumped the coin: ", body.name) # Add this line!
	if body.is_in_group("Player"):
		player_in_range = true
		print("Press 'E' to collect coin")

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false
		print("Player left coin area")

func _input(event):
	# Detects if the 'E' key is pressed while the player is inside the boundary
	if player_in_range and event.is_action_pressed("interact"):
		collect_coin()

func collect_coin():
	print("Coin collected!")
	# Add visual effects or score increases here later
	queue_free() # Removes the coin from the game
