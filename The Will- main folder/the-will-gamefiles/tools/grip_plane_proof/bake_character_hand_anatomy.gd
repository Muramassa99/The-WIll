extends RefCounted

const Schema = preload("res://tools/grip_plane_proof/character_hand_anatomy_def.gd")
const SourceSignature = preload("res://tools/grip_plane_proof/character_anatomy_source_signature.gd")
const Sampler = preload("res://tools/grip_plane_proof/capture_model_skin_samples.gd")
const SkinMeasurement = preload("res://tools/grip_plane_proof/measure_digit_skin_surface.gd")
const Outlines = preload("res://tools/grip_plane_proof/prepare_digit_skin_outlines.gd")
const Spatial = preload("res://runtime/player/player_finger_surface_grip_solver.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const REVISION := "rest_middle_thumb_surface_measurements_v1"
const ROOT_ID := &"RL_BoneRoot"
const SELECTED_DIGITS: Array[StringName] = [&"middle", &"thumb"]

# Reads a disposable rig in an explicitly frozen rest pose. This tool never
# opens a weapon library or Skill Crafter. The source signature is computed
# before expensive rays/outlines, so an existing matching resource is reusable.
func capture_source(actor: Node3D, character_id: StringName, scene_path: String) -> Dictionary:
	var skeleton: Skeleton3D = actor.skeleton
	var mesh: MeshInstance3D = actor.mesh_instance
	var root_index: int = skeleton.find_bone(ROOT_ID)
	if root_index < 0 or character_id == StringName():
		return {"valid": false, "reason": "missing_character_or_machine_root"}
	var machine: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(root_index)
	var names: Array[StringName] = []
	var packets: Array = []
	var definitions: Array = []
	for index: int in range(skeleton.get_bone_count()):
		definitions.append({"name": skeleton.get_bone_name(index), "parent": skeleton.get_bone_parent(index), "rest": skeleton.get_bone_rest(index)})
	for slot: StringName in [Rules.SLOT_RIGHT, Rules.SLOT_LEFT]:
		var side: Dictionary = Rules.get_surface_solver_side_rules(slot)
		if side.is_empty():
			return {"valid": false, "reason": "missing_declared_hand_rules"}
		for rules: Dictionary in side["digits"]:
			if not rules["digit_id"] in SELECTED_DIGITS:
				continue
			var first: int = skeleton.find_bone(rules["bone_names"][0])
			var hand: int = skeleton.find_bone(side["hand_bone_name"])
			if first < 0 or hand < 0 or skeleton.get_bone_parent(first) != hand or not _descends_from(skeleton, first, root_index):
				return {"valid": false, "reason": "digit_parent_or_root_mismatch"}
			for name: StringName in rules["bone_names"]:
				names.append(name)
			var anatomy_rules: Dictionary = rules.duplicate(true)
			# These old Josie constants are not measured anatomy and must not
			# become the reusable dimensions. Only the named direction is used.
			for key: String in ["capsule_radii_m", "terminal_length_m", "tip_offset_local"]:
				anatomy_rules.erase(key)
			packets.append({"slot_id": slot, "hand_bone_name": side["hand_bone_name"], "rules": anatomy_rules})
	var capture: Dictionary = Sampler.new().capture(skeleton, mesh, names)
	if not bool(capture.get("valid", false)):
		return capture
	var recipes: Dictionary = {}
	for path: String in [get_script().resource_path, "res://tools/grip_plane_proof/character_hand_anatomy_def.gd", "res://tools/grip_plane_proof/character_anatomy_source_signature.gd", "res://tools/grip_plane_proof/capture_model_skin_samples.gd", "res://tools/grip_plane_proof/measure_digit_skin_surface.gd", "res://tools/grip_plane_proof/prepare_digit_skin_outlines.gd", "res://runtime/player/player_finger_surface_grip_solver.gd", "res://runtime/player/player_digit_hinge_rules.gd", "res://tools/grip_plane_proof/slice_reachable_surface.gd"]:
		recipes[path] = FileAccess.get_sha256(path)
	for path: String in ["res://core/resolvers/primary_grip_seat_resolver.gd", "res://core/resolvers/combat_origin_registry.gd", "res://core/models/combat_origin_record.gd"]:
		recipes[path] = FileAccess.get_sha256(path)
	recipes["godot_engine"] = JSON.stringify(Engine.get_version_info()).sha256_text()
	var signature: Dictionary = SourceSignature.new().build(capture, definitions, machine.basis, packets, scene_path, REVISION, recipes)
	if not bool(signature.get("valid", false)):
		return signature
	return {"valid": true, "capture": capture, "packets": packets, "machine_to_world": machine,
		"character_id": character_id, "character_scene_path": scene_path, "signature": signature["signature"], "manifest": signature["manifest"],
		"resolved_visual_height_m": actor.resolved_visual_height_meters,
		"baseline": &"imported_rest_then_explicit_digit_calibrated_zero"}

func bake(actor: Node3D, source: Dictionary) -> Dictionary:
	if not bool(source.get("valid", false)):
		return {"valid": false, "reason": "invalid_preparation_source"}
	var started := Time.get_ticks_usec()
	var output = Schema.new()
	output.preparation_revision = REVISION
	output.character_id = source["character_id"]
	output.character_scene_path = source["character_scene_path"]
	output.source_signature = source["signature"]
	output.source_manifest = source["manifest"].duplicate(true)
	output.reference_skin = source["capture"]["reference_skin"].duplicate(true)
	output.character_measurements = {"resolved_visual_height_m": source["resolved_visual_height_m"], "baseline": source["baseline"], "hands": []}
	var machine: Transform3D = source["machine_to_world"]
	var skeleton: Skeleton3D = actor.skeleton
	var spatial = Spatial.new()
	output.origin_records.append(_origin(ROOT_ID, StringName(), Transform3D.IDENTITY, &"machine"))
	for name: StringName in output.reference_skin["bone_origin_records"]:
		if name != ROOT_ID:
			output.origin_records.append(output.reference_skin["bone_origin_records"][name].duplicate(true))
	output.origin_records.append(output.reference_skin["mesh_origin_record"].duplicate(true))
	var root_rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone(ROOT_ID))
	var skeleton_id := &"CharacterReferenceSkeletonOrigin"
	output.origin_records.append(_origin(skeleton_id, ROOT_ID, root_rest.affine_inverse()))
	output.reference_skin["bind_global_rests_origin_id"] = skeleton_id
	output.reference_skin["hand_global_rests_origin_id"] = skeleton_id
	var contexts: Dictionary = {}
	var timings: Array = []
	for packet: Dictionary in source["packets"]:
		var rules: Dictionary = packet["rules"].duplicate(true)
		# _capture uses an endpoint only to preserve its named direction.
		# Its magnitude is replaced by an actual axial skin hit below.
		rules["tip_offset_local"] = rules["zero_direction_local"]
		var snapshot: Dictionary = spatial._capture_digit_snapshot(skeleton, rules, {})
		snapshot["tip_offset_origin_id"] = rules["bone_names"][2]
		var original_relative: Array = snapshot["relative_transforms"].duplicate(true)
		var original_rotations: Array = snapshot["base_pose_rotations"].duplicate(true)
		for index: int in [1, 2]:
			snapshot["neutral_local_rotations"][index] = (snapshot["base_pose_rotations"][index] as Quaternion).inverse().normalized()
		var context := {"machine_origin_id": ROOT_ID, "machine_to_world": machine, "resolve_phase": &"bake_time", "hand_bone_name": packet["hand_bone_name"]}
		var measurement: Dictionary = SkinMeasurement.new().measure(snapshot, output.reference_skin, context)
		if not bool(measurement.get("valid", false)) or not bool(measurement.get("complete", false)):
			return {"valid": false, "reason": "incomplete_character_skin_measurement", "slot": packet["slot_id"], "digit": rules["digit_id"], "measurement_reason": measurement.get("reason", "missing_ray")}
		var lengths: Array[float] = []
		for section: Dictionary in measurement["sections"]:
			lengths.append(section["axis_length_m"])
		var fk: Dictionary = spatial._forward_kinematics(snapshot, [0.0, 0.0, 0.0])
		var terminal_frame: Transform3D = fk["joint_transforms_world"][2]
		var tip_direction: Vector3 = (rules["zero_direction_local"] as Vector3).normalized()
		snapshot["tip_offset_local"] = tip_direction * (lengths[2] / (terminal_frame.basis * tip_direction).length())
		var plane_id: StringName = measurement["plane_origin_id"]
		output.origin_records.append(_origin(plane_id, ROOT_ID, measurement["plane_to_machine"]))
		var joint_ids: Array[StringName] = []
		for index: int in range(3):
			var id := StringName(String(rules["bone_names"][index]) + "CharacterCalibratedZeroOrigin")
			joint_ids.append(id)
			output.origin_records.append(_origin(id, ROOT_ID, machine.affine_inverse() * fk["joint_transforms_world"][index]))
		# This is a diagnostic reach window, not a fitted finger radius.
		var reach: float = lengths[0] + lengths[1] + lengths[2]
		var outlines: Dictionary = Outlines.new().prepare(snapshot, output.reference_skin, context, measurement["plane_to_world"], plane_id, reach)
		if not bool(outlines.get("valid", false)):
			return {"valid": false, "reason": "character_outline_sampling_failed", "details": outlines}
		var parent_ids: Array = [packet["hand_bone_name"], rules["bone_names"][0], rules["bone_names"][1]]
		var digit := {"slot_id": packet["slot_id"], "digit_id": rules["digit_id"], "hand_bone_name": packet["hand_bone_name"], "bone_names": rules["bone_names"].duplicate(),
			"section_lengths_m": lengths, "terminal_length_is_axial_skin_extent": true,
			"plane_origin_id": plane_id, "plane_to_machine": measurement["plane_to_machine"], "root_origin_id": ROOT_ID,
			"rest_relative_transforms": original_relative, "relative_transform_origin_ids": parent_ids,
			"rest_local_rotations": original_rotations, "rest_local_rotation_origin_ids": rules["bone_names"].duplicate(),
			"neutral_local_rotations": snapshot["neutral_local_rotations"].duplicate(), "neutral_local_rotation_origin_ids": rules["bone_names"].duplicate(),
			"hinge_axes_local": rules["hinge_axes_local"].duplicate(), "hinge_axis_origin_ids": rules["hinge_axis_origin_ids"].duplicate(),
			"min_angles_rad": rules["min_angles_rad"].duplicate(), "max_angles_rad": rules["max_angles_rad"].duplicate(), "preferred_angles_rad": rules["preferred_angles_rad"].duplicate(),
			"calibrated_joint_origin_ids": joint_ids, "terminal_skin_offset_local": snapshot["tip_offset_local"], "terminal_skin_offset_origin_id": rules["bone_names"][2],
			"skin_cross_sections": _plane_measurements(measurement), "outline_samples": outlines["samples"],
			"calibration_rule": "joint_2_3_absolute_local_rotation_zero; first_joint_imported_rest_preserved",
			"contact_shape_validated": false, "outline_samples_are_not_all_angle_envelopes": true, "outline_window_m": reach}
		output.digits.append(digit)
		timings.append({"slot": packet["slot_id"], "digit": rules["digit_id"], "measurement_ms": measurement["elapsed_milliseconds"], "outlines_ms": outlines["elapsed_milliseconds"]})
		contexts[packet["slot_id"]] = packet["hand_bone_name"]
	for slot: StringName in contexts:
		var hand_name: StringName = contexts[slot]
		var prefix := "CC_Base_R_" if slot == Rules.SLOT_RIGHT else "CC_Base_L_"
		var names: Array[StringName] = [hand_name, StringName(prefix + "Mid1"), StringName(prefix + "Index1"), StringName(prefix + "Pinky1")]
		var positions: Array[Vector3] = []
		for name: StringName in names:
			var bone: int = skeleton.find_bone(name)
			if bone < 0:
				return {"valid": false, "reason": "missing_hand_dimension_reference"}
			positions.append((skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin)
		output.character_measurements["hands"].append({"slot_id": slot, "source_bone_origin_ids": names,
			"wrist_to_middle_root_m": positions[0].distance_to(positions[1]), "index_to_pinky_root_span_m": positions[2].distance_to(positions[3]),
			"these_are_bone_spans_not_outer_skin_dimensions": true})
	return {"valid": true, "resource": output, "bake_ms": float(Time.get_ticks_usec() - started) / 1000.0, "timings": timings}

func _plane_measurements(measurement: Dictionary) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	for source: Dictionary in measurement["sections"]:
		var section := {"bone_name": source["bone_name"], "axis_length_m": source["axis_length_m"], "origin_id": measurement["plane_origin_id"], "cross_sections": []}
		for sample: Dictionary in source["cross_sections"]:
			var row := {"fraction": sample["fraction"], "center_in_plane_m": sample["center_in_plane_m"], "rays": {}}
			for name: String in sample["rays"]:
				var ray: Dictionary = sample["rays"][name]
				row["rays"][name] = {"distance_m": ray["distance_m"], "position_in_plane_m": ray["position_in_plane_m"], "surface_index": ray["surface_index"], "surface_triangle_index": ray["surface_triangle_index"]}
			section["cross_sections"].append(row)
		sections.append(section)
	return sections

func _origin(id: StringName, parent: StringName, transform: Transform3D, type: StringName = &"bone_frame") -> Dictionary:
	return {"origin_id": id, "parent_origin_id": parent, "transform_to_parent": transform, "owner_system": &"character_hand_anatomy_preparation", "resolve_phase": &"bake_time", "is_dynamic": false, "space_type": type}

func _descends_from(skeleton: Skeleton3D, bone: int, ancestor: int) -> bool:
	while bone >= 0:
		if bone == ancestor:
			return true
		bone = skeleton.get_bone_parent(bone)
	return false
