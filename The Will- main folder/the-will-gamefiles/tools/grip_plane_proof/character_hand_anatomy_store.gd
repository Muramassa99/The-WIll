extends RefCounted

const DefinitionScript = preload("res://tools/grip_plane_proof/character_hand_anatomy_def.gd")
const OriginScript = preload("res://core/models/combat_origin_record.gd")
const RegistryScript = preload("res://core/resolvers/combat_origin_registry.gd")
const SCHEMA := "character_hand_anatomy_v1"
const FIELDS: Array[String] = ["schema_revision", "preparation_revision", "character_id", "character_scene_path", "source_signature", "source_manifest", "root_origin_id", "measurement_status", "contact_shape_validated", "reference_skin", "digits", "character_measurements", "origin_records"]

## Explicit single-writer tool operation. An existing file is never replaced.
## A load miss returns a diagnostic; this store does not prepare or bake data.
func save_new(definition: Resource, path: String) -> Dictionary:
	var target := _checked_path(path)
	if target.is_empty():
		return _failure("invalid_definition_path")
	if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)):
		return _failure("definition_already_exists", target)
	var validation := validate(definition)
	if not bool(validation.valid):
		return validation
	var directory := ProjectSettings.globalize_path(target).get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK:
		return {"valid": false, "status": "cannot_create_definition_directory", "path": target, "error": directory_error}
	if FileAccess.file_exists(target):
		return _failure("definition_already_exists", target)
	var save_error := ResourceSaver.save(definition, target)
	if save_error != OK:
		return {"valid": false, "status": "definition_save_failed", "path": target, "error": save_error}
	return {"valid": true, "status": "definition_saved", "path": target, "resource": definition}


func load_matching(path: String, expected_signature: String, expected_revision: String) -> Dictionary:
	var target := _checked_path(path)
	if target.is_empty() or expected_signature.is_empty() or expected_revision.is_empty():
		return _failure("invalid_load_expectation", path)
	if not FileAccess.file_exists(target):
		return _failure("definition_missing", target)
	# Godot 4.7: bypass cache for this Resource and its subresources. Its script
	# remains an ordinary external dependency; no mutable data Resource is cached.
	var definition := ResourceLoader.load(target, "Resource", ResourceLoader.CACHE_MODE_IGNORE)
	if definition == null:
		return _failure("definition_load_failed", target)
	var validation := validate(definition)
	if not bool(validation.valid):
		validation["path"] = target
		return validation
	if String(definition.get("source_signature")) != expected_signature:
		return _failure("source_signature_mismatch", target)
	if String(definition.get("preparation_revision")) != expected_revision:
		return _failure("preparation_revision_mismatch", target)
	return {"valid": true, "status": "matching_definition_loaded", "path": target, "resource": definition}


func validate(definition: Resource) -> Dictionary:
	if definition == null or definition.get_script() != DefinitionScript:
		return _failure("wrong_definition_type")
	if String(definition.get("schema_revision")) != SCHEMA:
		return _failure("unsupported_schema_revision")
	for key: String in ["preparation_revision", "character_id", "character_scene_path", "source_signature"]:
		if String(definition.get(key)).strip_edges().is_empty():
			return _failure("missing_" + key)
	if definition.get("root_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT:
		return _failure("wrong_machine_origin")
	if definition.get("measurement_status") != &"measured_anatomy_proof":
		return _failure("unsupported_measurement_status")
	if definition.get("source_manifest").is_empty() or definition.get("reference_skin").is_empty():
		return _failure("missing_source_manifest_or_reference_skin")
	if not definition.get_meta_list().is_empty():
		return _failure("undeclared_definition_metadata")
	for key: String in FIELDS:
		var data_error := _data_error(definition.get(key), key)
		if not data_error.is_empty():
			return {"valid": false, "status": "nonpersistent_or_invalid_data", "field": data_error}
	var origin_state := _validate_origins(definition.get("origin_records"))
	if not bool(origin_state.valid):
		return origin_state
	var registry: RefCounted = origin_state.registry
	var digits: Array = definition.get("digits")
	if digits.is_empty():
		return _failure("missing_digit_entries")
	var seen := {}
	for index: int in range(digits.size()):
		var digit: Dictionary = digits[index]
		for key: String in ["digit_id", "slot_id", "hand_bone_name", "plane_origin_id"]:
			if not (digit.get(key) is String or digit.get(key) is StringName) or String(digit[key]).is_empty():
				return _failure("digit_%d_missing_%s" % [index, key])
		var identity := String(digit.slot_id) + "/" + String(digit.digit_id)
		if seen.has(identity):
			return _failure("duplicate_digit_entry", identity)
		seen[identity] = true
		if not digit.get("bone_names") is Array or digit.bone_names.size() != 3 or not digit.get("section_lengths_m") is Array or digit.section_lengths_m.size() != 3:
			return _failure("digit_requires_three_bones_and_lengths", identity)
		var names: Array = [digit.hand_bone_name, digit.plane_origin_id]
		for joint: int in range(3):
			var length_value: Variant = digit.section_lengths_m[joint]
			if not (length_value is float or length_value is int) or not is_finite(float(length_value)) or float(length_value) <= 0.0:
				return _failure("invalid_digit_section_length", identity)
			if not (digit.bone_names[joint] is String or digit.bone_names[joint] is StringName) or String(digit.bone_names[joint]).is_empty():
				return _failure("invalid_digit_bone_name", identity)
			names.append(digit.bone_names[joint])
		for name: Variant in names:
			if not bool(registry.validate_origin_chain(StringName(name)).get("ok", false)):
				return _failure("invalid_digit_origin_chain", String(name))
		if not digit.get("plane_to_machine") is Transform3D or not _frame_valid(digit.plane_to_machine):
			return _failure("invalid_digit_plane_frame", identity)
		var resolved: Transform3D = registry.resolve_transform_to_machine(StringName(digit.plane_origin_id))
		if not resolved.is_equal_approx(digit.plane_to_machine):
			return _failure("digit_plane_frame_disagrees_with_origin_chain", identity)
		var joint_state := _validate_joint_data(digit, registry)
		if not bool(joint_state.valid):
			joint_state["digit"] = identity
			return joint_state
	return {"valid": true, "status": "definition_structure_valid", "digit_count": digits.size(), "contact_shape_validated": definition.get("contact_shape_validated")}


func _validate_joint_data(digit: Dictionary, registry: RefCounted) -> Dictionary:
	if digit.get("root_origin_id") != OriginScript.ORIGIN_RL_BONE_ROOT:
		return _failure("digit_has_wrong_machine_origin")
	for key: String in ["rest_relative_transforms", "rest_local_rotations", "neutral_local_rotations", "hinge_axes_local", "min_angles_rad", "max_angles_rad", "preferred_angles_rad", "relative_transform_origin_ids", "rest_local_rotation_origin_ids", "neutral_local_rotation_origin_ids", "hinge_axis_origin_ids", "calibrated_joint_origin_ids"]:
		if not digit.get(key) is Array or digit[key].size() != 3:
			return _failure("digit_requires_three_joint_values", key)
	var parent_ids: Array = [digit.hand_bone_name, digit.bone_names[0], digit.bone_names[1]]
	for joint: int in range(3):
		for key: String in ["rest_local_rotation_origin_ids", "neutral_local_rotation_origin_ids", "hinge_axis_origin_ids", "relative_transform_origin_ids", "calibrated_joint_origin_ids"]:
			var id: Variant = digit[key][joint]
			if not (id is String or id is StringName) or not bool(registry.validate_origin_chain(StringName(id)).get("ok", false)):
				return _failure("digit_joint_origin_chain_invalid", key)
			if key == "calibrated_joint_origin_ids":
				continue
			var expected: StringName = StringName(parent_ids[joint] if key == "relative_transform_origin_ids" else digit.bone_names[joint])
			if StringName(id) != expected:
				return _failure("digit_joint_origin_disagrees_with_frame", key)
		if not digit.rest_relative_transforms[joint] is Transform3D or not _frame_valid(digit.rest_relative_transforms[joint]):
			return _failure("invalid_digit_relative_transform")
		for key: String in ["rest_local_rotations", "neutral_local_rotations"]:
			var rotation: Variant = digit[key][joint]
			if not rotation is Quaternion or not rotation.is_finite() or rotation.length_squared() <= 0.0:
				return _failure("invalid_digit_joint_rotation", key)
		var axis: Variant = digit.hinge_axes_local[joint]
		if not axis is Vector3 or not axis.is_finite() or axis.length_squared() <= 0.0:
			return _failure("invalid_digit_hinge_axis")
		for key: String in ["min_angles_rad", "max_angles_rad", "preferred_angles_rad"]:
			var angle: Variant = digit[key][joint]
			if not (angle is int or angle is float) or not is_finite(float(angle)):
				return _failure("invalid_digit_joint_angle", key)
		if float(digit.min_angles_rad[joint]) > float(digit.max_angles_rad[joint]) or float(digit.preferred_angles_rad[joint]) < float(digit.min_angles_rad[joint]) or float(digit.preferred_angles_rad[joint]) > float(digit.max_angles_rad[joint]):
			return _failure("invalid_digit_joint_angle_range")
	var terminal: Variant = digit.get("terminal_skin_offset_local")
	if not terminal is Vector3 or not terminal.is_finite() or terminal.length_squared() <= 0.0:
		return _failure("invalid_digit_terminal_skin_offset")
	if digit.get("terminal_skin_offset_origin_id") != digit.bone_names[2]:
		return _failure("digit_terminal_offset_has_wrong_origin")
	return {"valid": true}


func _validate_origins(records: Array) -> Dictionary:
	var registry = RegistryScript.new(false)
	var ids := {}
	for data: Dictionary in records:
		var id := StringName(data.get("origin_id", &""))
		if id == StringName() or ids.has(id) or not data.get("transform_to_parent") is Transform3D or not _frame_valid(data.transform_to_parent):
			return _failure("invalid_or_duplicate_origin_record", String(id))
		if data.get("resolve_phase") != OriginScript.PHASE_BAKE_TIME or bool(data.get("is_dynamic", true)) or StringName(data.get("owner_system", &"")) == StringName():
			return _failure("origin_record_is_not_owned_static_bake_data", String(id))
		var record = OriginScript.new()
		record.origin_id = id
		record.parent_origin_id = StringName(data.get("parent_origin_id", &""))
		record.transform_to_parent = data.transform_to_parent
		record.owner_system = StringName(data.owner_system)
		record.resolve_phase = OriginScript.PHASE_BAKE_TIME
		record.space_type = StringName(data.get("space_type", OriginScript.SPACE_TYPE_BONE_FRAME))
		record.is_dynamic = false
		if id == OriginScript.ORIGIN_RL_BONE_ROOT and (record.parent_origin_id != StringName() or not record.transform_to_parent.is_equal_approx(Transform3D.IDENTITY)):
			return _failure("machine_origin_must_be_identity_root")
		if not registry.register_origin(record):
			return _failure("origin_registration_failed", String(id))
		ids[id] = true
	if not ids.has(OriginScript.ORIGIN_RL_BONE_ROOT):
		return _failure("missing_explicit_machine_origin")
	var all_chains: Dictionary = registry.validate_all()
	if not bool(all_chains.get("ok", false)):
		return {"valid": false, "status": "invalid_origin_chains", "failures": all_chains.get("failures", [])}
	return {"valid": true, "registry": registry}


func _data_error(value: Variant, path: String, depth: int = 0) -> String:
	if depth > 64 or value is Object or value is Callable or value is Signal or value is RID:
		return path
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName or key is int):
				return path + ".<invalid_key>"
			var label := str(key)
			if label.ends_with("_ms") or label.ends_with("_milliseconds") or label.begins_with("elapsed_") or label == "registry":
				return path + "." + label
			var child_error := _data_error(value[key], path + "." + label, depth + 1)
			if not child_error.is_empty():
				return child_error
	elif value is Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedVector2Array or value is PackedVector3Array:
		for index: int in range(value.size()):
			var child_error := _data_error(value[index], path + "[%d]" % index, depth + 1)
			if not child_error.is_empty():
				return child_error
	elif value is float and not is_finite(value):
		return path
	elif (value is Vector2 or value is Vector3 or value is Quaternion or value is Basis) and not value.is_finite():
		return path
	elif value is Transform3D and not _frame_valid(value):
		return path
	elif value is AABB and (not value.position.is_finite() or not value.size.is_finite()):
		return path
	return ""


func _checked_path(path: String) -> String:
	var normalized := path.replace("\\", "/").strip_edges()
	if normalized.get_extension().to_lower() not in ["tres", "res"]:
		return ""
	if not normalized.begins_with("res://") and not normalized.begins_with("user://") and not normalized.is_absolute_path():
		return ""
	return normalized


func _frame_valid(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and frame.basis.determinant() != 0.0


func _failure(status: String, detail: String = "") -> Dictionary:
	return {"valid": false, "status": status, "detail": detail}
