extends Area3D

@export_range(0.0, 1.0) var climb_height_fraction: float = 0.7

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
			player_node.start_climbing(global_position, get_climb_height_limit())
			# The attaching key must not also reach the new typing session.
			get_viewport().set_input_as_handled()
			if prompt_label:
				prompt_label.visible = false

# Measure the visible pole in world space, including all parent scales.
func get_climb_height_limit() -> float:
	var bottom_y: float = INF
	var top_y: float = -INF
	for node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		bottom_y = minf(bottom_y, bounds.position.y)
		top_y = maxf(top_y, bounds.end.y)

	if bottom_y == INF:
		push_warning("No pole mesh found; climb height limit is unavailable.")
		return INF
	return lerpf(bottom_y, top_y, climb_height_fraction)
