extends SceneTree

const PACK_PATH := "res://Assets/light post/powe_poles.glb"
const OUTPUT_DIR := "res://Assets/light post/powe_poles_separated"

func _initialize() -> void:
	call_deferred("split_pack")

func split_pack() -> void:
	var packed := load(PACK_PATH) as PackedScene
	if packed == null:
		printerr("Unable to load the source pole pack.")
		quit(1)
		return
	var source := packed.instantiate()
	root.add_child(source)
	await process_frame
	var source_root := source.find_child("RootNode", true, false)
	if source_root == null:
		printerr("Could not find RootNode in the pack.")
		quit(1)
		return
	var out_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(out_path)
	if dir_error != OK:
		printerr("Could not create output directory: " + error_string(dir_error))
		quit(1)
		return
	var total := 0
	var pole_sections := ["base_pole", "base_wood_pole", "big_pole", "concrete_pole", "single_concrete_pole", "single_wood_pole", "top_pole", "wood_pole", "cable", "lamp"]
	for section in source_root.get_children():
		if section.name.to_snake_case() not in pole_sections:
			continue
		var meshes := section.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			printerr("Skipping node without mesh: " + section.name)
			continue
		var isolated := Node3D.new()
		isolated.name = section.name
		var copy := section.duplicate()
		copy.name = section.name
		copy.position = Vector3.ZERO # Remove its layout placement while retaining the model's scale.
		isolated.add_child(copy)
		var isolated_meshes := copy.find_children("*", "MeshInstance3D", true, false)
		var mi := isolated_meshes[0] as MeshInstance3D
		var local_bounds := mi.transform * mi.get_aabb()
		var scaled_bounds := Transform3D(copy.transform.basis, Vector3.ZERO) * local_bounds
		var center := scaled_bounds.get_center()
		copy.position = Vector3(-center.x, -scaled_bounds.position.y, -center.z)
		var document := GLTFDocument.new()
		document.image_format = "PNG"
		var state := GLTFState.new()
		var err := document.append_from_scene(isolated, state)
		if err == OK:
			var filename := section.name.to_snake_case() + ".glb"
			err = document.write_to_filesystem(state, out_path.path_join(filename))
		if err != OK:
			printerr("Export failed for %s: %s" % [section.name, error_string(err)])
		else:
			print("Exported " + section.name + " -> " + out_path.path_join(section.name.to_snake_case() + ".glb"))
			total += 1
		isolated.free()

	# Keep the source pack's matching transforms so the pole, lamp, and rounded
	# transformer remain assembled as shown in the reference pack.
	var assembly := Node3D.new()
	assembly.name = "LightPoleWithTransformer"
	root.add_child(assembly)
	for part_name in ["BasePole", "Lamp", "RoundedTransformer"]:
		var part := source_root.get_node_or_null(part_name)
		if part == null:
			printerr("Missing light pole component: " + part_name)
			assembly.free()
			quit(1)
			return
		assembly.add_child(part.duplicate())
	await process_frame
	var bounds := AABB()
	var has_bounds := false
	for mesh_node in assembly.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		var mesh_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		bounds = mesh_bounds if not has_bounds else bounds.merge(mesh_bounds)
		has_bounds = true
	if has_bounds:
		assembly.position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	var assembly_document := GLTFDocument.new()
	assembly_document.image_format = "PNG"
	var assembly_state := GLTFState.new()
	var assembly_error := assembly_document.append_from_scene(assembly, assembly_state)
	if assembly_error == OK:
		assembly_error = assembly_document.write_to_filesystem(assembly_state, out_path.path_join("light_pole_with_transformer.glb"))
	if assembly_error != OK:
		printerr("Light pole assembly export failed: " + error_string(assembly_error))
	else:
		print("Exported assembled light pole with rounded transformer and lamp.")
		total += 1
	print("Finished: %d pole, cable, and assembled light pole GLB assets." % total)
	quit(0 if total == pole_sections.size() + 1 else 1)
