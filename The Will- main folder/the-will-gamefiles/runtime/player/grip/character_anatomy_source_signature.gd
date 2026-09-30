extends RefCounted

## Pure preparation-source fingerprint. Dictionary keys are sorted recursively;
## surface/bind/rule arrays preserve caller order. skeleton_definition must list
## every bone in engine index order as {name, parent, rest}. Metric basis must
## describe the character's actual scale/shear before scene placement: Gram(B)
## removes rotation algebraically, but cannot undo prior floating-point roundoff.
## No cached summary hash, live node path, clock, or instance ID is trusted.
const SCHEMA := "character_anatomy_source_signature_v1"

func build(capture: Dictionary, skeleton_definition: Array, metric_basis: Basis, rule_packets: Array, character_scene_path: String, preparation_revision: String, recipe_hashes: Dictionary) -> Dictionary:
	var reason := _input_reason(capture, skeleton_definition, metric_basis, rule_packets, character_scene_path, preparation_revision, recipe_hashes)
	if not reason.is_empty():
		return {"valid": false, "signature": "", "manifest": {}, "reason": reason}
	var reference: Dictionary = capture["reference_skin"]
	var identity: Dictionary = capture["model_identity"]
	var components: Dictionary = {}
	var surfaces: Array = []
	var vertex_count := 0
	for surface: Dictionary in reference["surfaces"]:
		var hashes: Dictionary = {}
		for key: String in ["vertices", "indices", "bones", "weights"]:
			hashes[key] = _hash(surface[key])
		surfaces.append(hashes)
		vertex_count += surface["vertices"].size()
	components["surfaces"] = _hash(surfaces)
	for key: String in ["bind_bone_names", "bind_poses", "bind_global_rests", "hand_global_rests"]:
		components[key] = _hash(reference[key])
	components["named_reference_frames"] = _hash({"vertices_origin_id": reference["vertices_origin_id"], "mesh_origin_record": reference["mesh_origin_record"], "bone_origin_records": reference["bone_origin_records"]})
	components["blend_shape_values"] = _hash(identity["blend_shape_values"])
	components["bone_local_samples"] = _hash(capture["samples"])
	components["skeleton_definition"] = _hash(skeleton_definition)
	components["authored_rule_packets"] = _hash(rule_packets)
	components["recipe_hashes"] = _hash(recipe_hashes)
	var gram: Array = []
	for row in range(3):
		var values: Array[float] = []
		for column in range(3):
			values.append(metric_basis[row].dot(metric_basis[column]))
		gram.append(values)
	if not _data_valid(gram):
		return {"valid": false, "signature": "", "manifest": {}, "reason": "nonfinite_character_metric_gram"}
	var metric := {"gram_matrix": gram, "determinant_sign": -1 if metric_basis.determinant() < 0.0 else 1}
	components["character_metric"] = _hash(metric)
	var source_identity := {"character_scene_path": character_scene_path, "mesh_resource_path": identity["mesh_resource_path"], "preparation_revision": preparation_revision, "sampling_method": capture["sampling_method"]}
	components["source_identity"] = _hash(source_identity)
	var manifest := {
		"schema": SCHEMA, "source_identity": source_identity, "component_hashes": components,
		"surface_component_hashes": surfaces, "surface_count": surfaces.size(),
		"vertex_count": vertex_count, "bone_count": skeleton_definition.size(),
		"bind_count": reference["bind_bone_names"].size(), "rule_packet_count": rule_packets.size(),
		"character_metric": metric,
	}
	return {"valid": true, "signature": _hash({"schema": SCHEMA, "components": components}), "manifest": manifest}


func _input_reason(capture: Dictionary, skeleton_definition: Array, metric_basis: Basis, rule_packets: Array, character_scene_path: String, preparation_revision: String, recipe_hashes: Dictionary) -> String:
	if capture.get("valid") != true or not capture.get("reference_skin") is Dictionary or not capture.get("model_identity") is Dictionary:
		return "missing_valid_character_capture"
	if character_scene_path.strip_edges().is_empty() or preparation_revision.strip_edges().is_empty() or recipe_hashes.is_empty():
		return "missing_character_identity_revision_or_recipe_hashes"
	if not _data_valid(metric_basis) or not is_finite(metric_basis.determinant()) or metric_basis.determinant() == 0.0:
		return "invalid_character_metric_basis"
	var reference: Dictionary = capture["reference_skin"]
	var identity: Dictionary = capture["model_identity"]
	if not identity.get("mesh_resource_path") is String or not identity.get("blend_shape_values") is Array:
		return "missing_mesh_identity_or_explicit_morph_values"
	if not capture.get("samples") is Dictionary or capture["samples"].is_empty() or not capture.get("sampling_method") is String or String(capture["sampling_method"]).is_empty():
		return "missing_bone_local_samples_or_sampling_method"
	for key: String in ["surfaces", "bind_bone_names", "bind_poses", "bind_global_rests"]:
		if not reference.get(key) is Array or reference[key].is_empty():
			return "missing_reference_" + key
	var bind_count: int = reference["bind_bone_names"].size()
	if reference["bind_poses"].size() != bind_count or reference["bind_global_rests"].size() != bind_count:
		return "mismatched_bind_arrays"
	if not reference.get("hand_global_rests") is Dictionary or reference["hand_global_rests"].is_empty() or not reference.get("mesh_origin_record") is Dictionary or not reference.get("bone_origin_records") is Dictionary or not _nonempty_name(reference.get("vertices_origin_id")):
		return "missing_named_reference_frames_or_hand_rests"
	if not _origin_record_valid(reference["mesh_origin_record"], reference["vertices_origin_id"]):
		return "invalid_named_reference_mesh_frame"
	for index in range(bind_count):
		var name: Variant = reference["bind_bone_names"][index]
		if not _nonempty_name(name) or not _frame_valid(reference["bind_poses"][index]) or not _frame_valid(reference["bind_global_rests"][index]) or not _origin_record_valid(reference["bone_origin_records"].get(name), name):
			return "invalid_bind_or_named_reference_bone_frame"
	for name: Variant in reference["hand_global_rests"]:
		if not _nonempty_name(name) or not _frame_valid(reference["hand_global_rests"][name]):
			return "invalid_named_hand_rest"
	for surface: Variant in reference["surfaces"]:
		if not surface is Dictionary or not surface.get("vertices") is PackedVector3Array or surface["vertices"].is_empty() or not surface.get("indices") is PackedInt32Array or not surface.get("bones") is PackedInt32Array or not surface.get("weights") is PackedFloat32Array:
			return "missing_complete_surface_arrays"
		if surface["weights"].is_empty() or surface["weights"].size() != surface["bones"].size() or surface["weights"].size() % surface["vertices"].size() != 0:
			return "mismatched_surface_influences"
	if skeleton_definition.is_empty() or rule_packets.is_empty():
		return "missing_skeleton_definition_or_authored_rules"
	var names: Dictionary = {}
	for index in range(skeleton_definition.size()):
		var bone: Variant = skeleton_definition[index]
		if not bone is Dictionary or not _nonempty_name(bone.get("name")) or not bone.get("parent") is int or not _frame_valid(bone.get("rest")):
			return "missing_named_bone_parent_or_rest"
		if names.has(String(bone["name"])) or int(bone["parent"]) < -1 or int(bone["parent"]) >= skeleton_definition.size() or int(bone["parent"]) == index:
			return "invalid_skeleton_definition"
		names[String(bone["name"])] = true
	for name: Variant in reference["bind_bone_names"]:
		if not names.has(String(name)):
			return "skeleton_definition_missing_bound_bone"
	for packet: Variant in rule_packets:
		if not packet is Dictionary or packet.is_empty():
			return "missing_authored_rule_packet"
	for recipe: Variant in recipe_hashes:
		if not _nonempty_name(recipe) or not recipe_hashes[recipe] is String or String(recipe_hashes[recipe]).is_empty():
			return "missing_named_recipe_hash"
	# Check only the source fields that are hashed; incidental live scene paths and
	# previous summary hashes in capture.model_identity are deliberately excluded.
	if not _data_valid([reference, capture["samples"], identity["blend_shape_values"], skeleton_definition, rule_packets, recipe_hashes]):
		return "nonfinite_or_unsupported_source_data"
	return ""


func _origin_record_valid(value: Variant, expected_name: Variant) -> bool:
	return value is Dictionary and value.get("origin_id") == expected_name and value.has("parent_origin_id") and (value["parent_origin_id"] is String or value["parent_origin_id"] is StringName) and _frame_valid(value.get("transform_to_parent"))


func _nonempty_name(value: Variant) -> bool:
	return (value is String or value is StringName) and not String(value).is_empty()


func _frame_valid(value: Variant) -> bool:
	return value is Transform3D and (value as Transform3D).is_finite() and is_finite((value as Transform3D).basis.determinant()) and (value as Transform3D).basis.determinant() != 0.0


func _data_valid(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_QUATERNION, TYPE_TRANSFORM3D:
			return value.is_finite()
		TYPE_BASIS:
			return value.x.is_finite() and value.y.is_finite() and value.z.is_finite()
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not (key is String or key is StringName or key is int) or not _data_valid(value[key]):
					return false
			return true
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_STRING_ARRAY:
			for item: Variant in value:
				if not _data_valid(item):
					return false
			return true
	return false


func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var entries: Array = []
		for key: Variant in value:
			entries.append([key, _canonical(value[key])])
		entries.sort_custom(func(a: Array, b: Array) -> bool: return var_to_bytes(a[0]).hex_encode() < var_to_bytes(b[0]).hex_encode())
		return [TYPE_DICTIONARY, entries]
	if value is Array:
		var entries: Array = []
		for item: Variant in value:
			entries.append(_canonical(item))
		return [TYPE_ARRAY, entries]
	return value


func _hash(value: Variant) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(var_to_bytes(_canonical(value)))
	return hashing.finish().hex_encode()
