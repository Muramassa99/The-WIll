extends SceneTree

# Checked against Godot 4.7 / 5b4e0cb0f:
# drivers/gles3/shaders/skeleton.glsl (weighted render transform)
# scene/3d/mesh_instance_3d.cpp (bake rest-vertex residual).
# This compares engine bone application and CPU mesh baking, accounting for
# that documented source-code difference; it is not a GPU framebuffer test.

const Rig = preload("res://scenes/player/player_humanoid_rig.tscn")
const Preparation = preload("res://tools/grip_plane_proof/prepare_digit_anatomy.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")

func _init() -> void:
	root.visible = false
	call_deferred("_run")

func _run() -> void:
	var input: Dictionary = _read(OS.get_environment("THE_WILL_GRIP_CAPTURE_PATH"))
	var skin: Dictionary = _read(OS.get_environment("THE_WILL_CHARACTER_SAMPLES_PATH"))
	var context: Dictionary = input["capture_frame"].duplicate(true)
	context["model_identity"] = skin["model_identity"]
	context["sampling_method"] = skin["sampling_method"]
	context["hand_bone_name"] = &"CC_Base_R_Hand" if input["slot"] == &"hand_right" else &"CC_Base_L_Hand"
	var actor = Rig.instantiate()
	root.add_child(actor)
	await process_frame
	_quiet(actor)
	var measured = load("res://tools/grip_plane_proof/measure_digit_skin_surface.gd").new()
	var failures: int = 0
	for digit: String in ["middle", "thumb"]:
		var preparation: Dictionary = Preparation.new().prepare(input["digits"][digit]["snapshot"], skin["samples"], context)
		if not bool(preparation.get("valid", false)):
			push_error("Preparation unavailable: " + str(preparation))
			failures += 1
			continue
		var snapshot: Dictionary = preparation["prepared_snapshot"]
		for bent: bool in [false, true]:
			var angles: Array[float] = [0.0, 0.0, 0.0]
			if bent:
				for i: int in range(3):
					angles[i] = lerpf(float(snapshot["min_angles_rad"][i]), float(snapshot["max_angles_rad"][i]), 0.35)
			var calculated: Dictionary = measured.build_skin_world(snapshot, skin["reference_skin"], context, angles)
			if not bool(calculated.get("valid", false)):
				push_error("Skin reconstruction unavailable: " + str(calculated))
				failures += 1
				continue
			actor.skeleton.reset_bone_poses()
			actor.skeleton.global_transform = calculated["skeleton_to_world"]
			var rotations: Dictionary = Spatial.new()._build_output_rotations(snapshot, angles)
			for name: StringName in rotations:
				var bone_index: int = actor.skeleton.find_bone(name)
				var relative: Transform3D = snapshot["relative_transforms"][snapshot["bone_names"].find(name)]
				actor.skeleton.set_bone_pose_position(bone_index, relative.origin)
				actor.skeleton.set_bone_pose_scale(bone_index, relative.basis.get_scale())
				actor.skeleton.set_bone_pose_rotation(bone_index, rotations[name])
			actor.skeleton.force_update_all_bone_transforms()
			await process_frame
			var joint_error: float = 0.0
			for j: int in range(3):
				var actual_joint: Transform3D = actor.skeleton.global_transform * actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(snapshot["bone_names"][j]))
				var expected_joint: Transform3D = calculated["joint_transforms_world"][j]
				joint_error = maxf(joint_error, actual_joint.origin.distance_to(expected_joint.origin))
				for column: int in range(3):
					joint_error = maxf(joint_error, actual_joint.basis[column].distance_to(expected_joint.basis[column]))
			var baked: ArrayMesh = actor.mesh_instance.bake_mesh_from_current_skeleton_pose()
			var largest: float = 0.0
			var largest_digit: float = 0.0
			var largest_details: Dictionary = {}
			var bake_adjusted_error: float = 0.0
			var count: int = 0
			if baked == null or baked.get_surface_count() != calculated["surfaces"].size():
				failures += 1
				push_error("Missing matching Godot skin bake.")
				continue
			for s: int in range(baked.get_surface_count()):
				var actual: PackedVector3Array = baked.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				var expected: PackedVector3Array = calculated["surfaces"][s]["vertices_world"]
				if actual.size() != expected.size():
					failures += 1
					continue
				for i: int in range(actual.size()):
					var actual_world: Vector3 = actor.mesh_instance.global_transform * actual[i]
					var error: float = actual_world.distance_to(expected[i])
					var source_surface: Dictionary = skin["reference_skin"]["surfaces"][s]
					var weights: PackedFloat32Array = source_surface["weights"]
					var influence_count: int = weights.size() / actual.size()
					var weight_sum: float = 0.0
					for influence: int in range(influence_count):
						weight_sum += weights[i * influence_count + influence]
					# Godot's CPU bake retains a rest-vertex residual that the render
					# skinning shader does not. Preserve this explicit comparison;
					# do not normalize weights or modify the renderer geometry.
					var bake_residual: Vector3 = actor.mesh_instance.global_transform.basis * source_surface["vertices"][i] * (1.0 - weight_sum)
					bake_adjusted_error = maxf(bake_adjusted_error, actual_world.distance_to(expected[i] + bake_residual))
					if calculated["surfaces"][s]["digit_influence_mask"][i] != 0:
						largest_digit = maxf(largest_digit, error)
					if error > largest:
						largest = error
						largest_details = {"surface": s, "vertex": i, "weight_sum": weight_sum, "digit_influenced": calculated["surfaces"][s]["digit_influence_mask"][i] != 0, "error_vector": str(actual_world - expected[i])}
					count += 1
			var pass_check: bool = count > 0 and bake_adjusted_error <= 0.00005 and joint_error <= 0.000005
			if not pass_check:
				failures += 1
			print("CHARACTER_SKIN_PARITY=" + JSON.stringify({"digit": digit, "bent": bent, "vertices": count, "raw_bake_difference_mm": largest * 1000.0, "raw_digit_bake_difference_mm": largest_digit * 1000.0, "bake_adjusted_error_mm": bake_adjusted_error * 1000.0, "largest_raw_difference": largest_details, "weight_sum_min": calculated["weight_sum_min"], "weight_sum_max": calculated["weight_sum_max"], "joint_max_component_error": joint_error, "source_compressed": (actor.mesh_instance.mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) != 0, "pass": pass_check}))
	actor.queue_free()
	await process_frame
	print("CHARACTER_SKIN_GEOMETRY_RESULT failures=" + str(failures))
	quit(0 if failures == 0 else 1)

func _quiet(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is AnimationPlayer:
		node.stop()
	if node is AnimationTree:
		node.active = false
	if node is SkeletonModifier3D:
		node.active = false
	for child: Node in node.get_children():
		_quiet(child)

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var result: Dictionary = file.get_var()
	file.close()
	return result
