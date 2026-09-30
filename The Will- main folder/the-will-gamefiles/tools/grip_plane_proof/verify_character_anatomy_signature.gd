extends SceneTree

const Rig = preload("res://scenes/player/player_humanoid_rig.tscn")
const Baker = preload("res://tools/grip_plane_proof/bake_character_hand_anatomy.gd")
const Signature = preload("res://tools/grip_plane_proof/character_anatomy_source_signature.gd")
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var actor = Rig.instantiate()
	root.add_child(actor)
	_quiet(actor)
	actor.skeleton.reset_bone_poses()
	actor.skeleton.force_update_all_bone_transforms()
	var source: Dictionary = Baker.new().capture_source(actor, &"josie", Rig.resource_path)
	_check(bool(source.get("valid", false)), "isolated rest rig supplies valid preparation source")
	if not bool(source.get("valid", false)):
		print("SOURCE_FAILURE=" + JSON.stringify(source))
		actor.queue_free()
		await process_frame
		quit(1)
		return
	var definitions: Array = []
	for index in range(actor.skeleton.get_bone_count()):
		definitions.append({"name": actor.skeleton.get_bone_name(index), "parent": actor.skeleton.get_bone_parent(index), "rest": actor.skeleton.get_bone_rest(index)})
	var args := {"capture": source["capture"], "skeleton_definition": definitions, "metric_basis": (source["machine_to_world"] as Transform3D).basis,
		"rule_packets": source["packets"], "character_scene_path": source["character_scene_path"], "preparation_revision": Baker.REVISION, "recipe_hashes": _recipes()}
	var source_before := var_to_bytes(source)
	var args_before := var_to_bytes(args)
	var baseline := _build(args)
	_check(bool(baseline.get("valid", false)) and baseline.get("signature") == source["signature"], "reconstructed build arguments match the actual baker signature")
	var expected := {}
	for slot: StringName in [&"hand_right", &"hand_left"]:
		for digit_id: StringName in [&"thumb", &"index", &"middle", &"ring", &"pinky"]:
			expected[String(slot) + "/" + String(digit_id)] = false
	for packet: Dictionary in args["rule_packets"]:
		var identity := String(packet["slot_id"]) + "/" + String(packet["rules"]["digit_id"])
		if expected.has(identity):
			expected[identity] = true
	_check(args["rule_packets"].size() == 10 and not expected.values().has(false), "source signature covers all ten authored digit packets")
	var repeated := _build(args)
	_check(var_to_bytes(repeated) == var_to_bytes(baseline), "identical source produces identical signature and diagnostic manifest")
	var reordered: Dictionary = _reverse_dictionary_order(args)
	var reordered_before := var_to_bytes(reordered)
	var reordered_result := _build(reordered)
	_check(bool(reordered_result.get("valid", false)) and reordered_result["signature"] == baseline["signature"], "recursive dictionary insertion order does not change the signature")
	_check(var_to_bytes(reordered) == reordered_before, "canonicalization leaves reordered source dictionaries untouched")
	for mutation: String in ["topology_indices", "vertex", "weight", "bone_influence", "bind_frame", "bind_global_rest", "hand_rest", "named_reference_frame", "bone_parent", "bone_rest", "metric_scale", "metric_handedness", "morph_value", "joint_limit", "hinge_axis", "recipe_hash"]:
		var changed: Dictionary = args.duplicate(true)
		if not _mutate(changed, mutation):
			_check(false, mutation + " has an applicable source fixture")
			continue
		var changed_before := var_to_bytes(changed)
		var result := _build(changed)
		_check(bool(result.get("valid", false)) and result.get("signature") != baseline["signature"], mutation + " invalidates the source signature")
		_check(var_to_bytes(changed) == changed_before, mutation + " hashing leaves its source untouched")
	for packet_index: int in range(args["rule_packets"].size()):
		var packet: Dictionary = args["rule_packets"][packet_index]
		if packet["rules"]["digit_id"] not in [&"index", &"ring", &"pinky"]:
			continue
		var changed: Dictionary = args.duplicate(true)
		changed["rule_packets"][packet_index]["rules"]["max_angles_rad"][0] += 0.001
		var changed_before := var_to_bytes(changed)
		var result := _build(changed)
		var identity := String(packet["slot_id"]) + "/" + String(packet["rules"]["digit_id"])
		_check(bool(result.get("valid", false)) and result.get("signature") != baseline["signature"], identity + " added joint rule invalidates the source signature")
		_check(var_to_bytes(changed) == changed_before, identity + " hashing leaves the mutated source untouched")
	var missing: Dictionary = args.duplicate(true)
	missing["capture"]["reference_skin"].erase("mesh_origin_record")
	var rejected := _build(missing)
	_check(not bool(rejected.get("valid", true)) and String(rejected.get("signature", "unexpected")).is_empty(), "missing named mesh origin is rejected without a usable signature")
	_check(var_to_bytes(source) == source_before and var_to_bytes(args) == args_before, "all checks leave the original captured source unchanged")
	print("CHARACTER_ANATOMY_SIGNATURE_VERIFICATION=" + JSON.stringify({"checks": checks, "failures": failures, "source_signature": source["signature"], "rig_instances": 1, "expensive_bake_ran": false, "files_written": false}))
	actor.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func _build(args: Dictionary) -> Dictionary:
	return Signature.new().build(args["capture"], args["skeleton_definition"], args["metric_basis"], args["rule_packets"], args["character_scene_path"], args["preparation_revision"], args["recipe_hashes"])


func _mutate(args: Dictionary, mutation: String) -> bool:
	var reference: Dictionary = args["capture"]["reference_skin"]
	var surface: Dictionary = reference["surfaces"][0]
	match mutation:
		"topology_indices":
			var indices: PackedInt32Array = surface["indices"]
			if indices.is_empty() or surface["vertices"].size() < 2:
				return false
			indices[0] = (indices[0] + 1) % surface["vertices"].size()
			surface["indices"] = indices
		"vertex":
			var vertices: PackedVector3Array = surface["vertices"]
			vertices[0] += Vector3(0.0001, 0.0, 0.0)
			surface["vertices"] = vertices
		"weight":
			var weights: PackedFloat32Array = surface["weights"]
			weights[0] = weights[0] * 0.99 if weights[0] > 0.0 else 0.001
			surface["weights"] = weights
		"bone_influence":
			var bones: PackedInt32Array = surface["bones"]
			if reference["bind_bone_names"].size() < 2:
				return false
			bones[0] = (bones[0] + 1) % reference["bind_bone_names"].size()
			surface["bones"] = bones
		"bind_frame", "bind_global_rest":
			var key := "bind_poses" if mutation == "bind_frame" else "bind_global_rests"
			var frame: Transform3D = reference[key][0]
			frame.origin += Vector3(0.0001, 0.0, 0.0)
			reference[key][0] = frame
		"hand_rest":
			var key: Variant = reference["hand_global_rests"].keys()[0]
			var frame: Transform3D = reference["hand_global_rests"][key]
			frame.origin += Vector3(0.0001, 0.0, 0.0)
			reference["hand_global_rests"][key] = frame
		"named_reference_frame":
			var frame: Transform3D = reference["mesh_origin_record"]["transform_to_parent"]
			frame.origin += Vector3(0.0001, 0.0, 0.0)
			reference["mesh_origin_record"]["transform_to_parent"] = frame
		"bone_parent":
			for bone: Dictionary in args["skeleton_definition"]:
				if int(bone["parent"]) >= 0:
					bone["parent"] = -1
					return true
			return false
		"bone_rest":
			var frame: Transform3D = args["skeleton_definition"][0]["rest"]
			frame.origin += Vector3(0.0001, 0.0, 0.0)
			args["skeleton_definition"][0]["rest"] = frame
		"metric_scale":
			var metric: Basis = args["metric_basis"]
			metric.x *= 1.01
			args["metric_basis"] = metric
		"metric_handedness":
			args["metric_basis"] = Basis(Vector3(-1.0, 0.0, 0.0), Vector3.UP, Vector3.BACK) * (args["metric_basis"] as Basis)
		"morph_value":
			var values: Array = args["capture"]["model_identity"]["blend_shape_values"]
			if values.is_empty():
				values.append(0.125)
			else:
				values[0] = float(values[0]) + 0.125
		"joint_limit":
			args["rule_packets"][0]["rules"]["max_angles_rad"][0] += 0.001
		"hinge_axis":
			args["rule_packets"][0]["rules"]["hinge_axes_local"][0] += Vector3(0.01, 0.02, 0.03)
		"recipe_hash":
			var key: Variant = args["recipe_hashes"].keys()[0]
			args["recipe_hashes"][key] = (String(args["recipe_hashes"][key]) + ":verification_mutation").sha256_text()
		_:
			return false
	return true


func _recipes() -> Dictionary:
	# Explicit baker dependency contract. Baseline equality above detects drift.
	var result: Dictionary = {}
	for path: String in ["res://tools/grip_plane_proof/bake_character_hand_anatomy.gd", "res://tools/grip_plane_proof/character_hand_anatomy_def.gd", "res://tools/grip_plane_proof/character_anatomy_source_signature.gd", "res://tools/grip_plane_proof/capture_model_skin_samples.gd", "res://tools/grip_plane_proof/measure_digit_skin_surface.gd", "res://tools/grip_plane_proof/prepare_digit_skin_outlines.gd", "res://runtime/player/player_finger_surface_grip_solver.gd", "res://runtime/player/player_digit_hinge_rules.gd", "res://tools/grip_plane_proof/slice_reachable_surface.gd", "res://core/resolvers/primary_grip_seat_resolver.gd", "res://core/resolvers/combat_origin_registry.gd", "res://core/models/combat_origin_record.gd"]:
		result[path] = FileAccess.get_sha256(path)
	result["godot_engine"] = JSON.stringify(Engine.get_version_info()).sha256_text()
	return result


func _reverse_dictionary_order(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.reverse()
		for key: Variant in keys:
			result[key] = _reverse_dictionary_order(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_reverse_dictionary_order(item))
		return result
	return value


func _quiet(node: Node) -> void:
	node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is AnimationPlayer:
		node.stop()
	if node is AnimationTree or node is SkeletonModifier3D:
		node.active = false
	for child: Node in node.get_children():
		_quiet(child)


func _check(passed: bool, label: String) -> void:
	checks += 1
	print("%s: %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		failures += 1
