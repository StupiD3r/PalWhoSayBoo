extends SceneTree

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var packed := load("res://Assets/light post/powe_poles.glb") as PackedScene
	if packed == null:
		printerr("Could not load the pole pack as a scene.")
		quit(1)
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	_print_tree(instance, 0)
	quit()

func _print_tree(node: Node, depth: int) -> void:
	var prefix := "  ".repeat(depth)
	var details := node.get_class()
	if node is Node3D:
		details += " pos=" + str((node as Node3D).position) + " scale=" + str((node as Node3D).scale)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		details += " mesh=" + str(mi.mesh.resource_name) + " surfaces=" + str(mi.mesh.get_surface_count()) + " aabb=" + str(mi.get_aabb()) + " global_aabb=" + str(mi.global_transform * mi.get_aabb())
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			details += " mat%d=%s" % [s, mat.resource_name if mat else "none"]
	print(prefix + node.name + " [" + details + "]")
	for child in node.get_children():
		_print_tree(child, depth + 1)
