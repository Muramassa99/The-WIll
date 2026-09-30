extends RefCounted

## Reuse a historical complete pose only after proving that the new anatomy is
## an extension of the same character surface, metric and calibrated digits.
## This does not capture a fresh pose, change any frame or infer missing bones.
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const CoherentSkin = preload("res://tools/grip_plane_proof/prepared_hand_skin_query.gd")
const Signature = preload("res://tools/grip_plane_proof/character_anatomy_source_signature.gd")


func validate_extension(previous: Resource, extended: Resource) -> Dictionary:
	var store := Store.new()
	for definition: Resource in [previous, extended]:
		var checked: Dictionary = store.validate(definition)
		if not checked.get("valid", false): return checked
		var manifest: Dictionary = definition.source_manifest
		if manifest.get("schema") != Signature.SCHEMA or not manifest.get("component_hashes") is Dictionary:
			return {"valid":false,"reason":"missing_signed_anatomy_manifest"}
		if Signature.new()._hash({"schema":Signature.SCHEMA,"components":manifest.component_hashes}) != definition.source_signature:
			return {"valid":false,"reason":"anatomy_signature_does_not_match_manifest"}
	if extended.preparation_revision != "rest_all_digits_surface_measurements_v1":
		return {"valid":false,"reason":"extension_requires_full_hand_revision"}
	for field: String in ["surfaces", "bind_bone_names", "bind_poses", "bind_global_rests", "hand_global_rests", "named_reference_frames", "blend_shape_values", "skeleton_definition", "character_metric"]:
		if not previous.source_manifest.component_hashes.has(field) or previous.source_manifest.component_hashes[field] != extended.source_manifest.component_hashes.get(field):
			return {"valid":false,"reason":"anatomy_extension_changed_source_component","field":field}
	for field: String in ["character_scene_path", "mesh_resource_path", "sampling_method"]:
		if not previous.source_manifest.source_identity.has(field) or previous.source_manifest.source_identity[field] != extended.source_manifest.source_identity.get(field):
			return {"valid":false,"reason":"anatomy_extension_changed_source_identity","field":field}
	for field: String in ["schema_revision", "character_id", "character_scene_path", "root_origin_id", "reference_skin", "character_measurements"]:
		if var_to_bytes(previous.get(field)) != var_to_bytes(extended.get(field)):
			return {"valid":false,"reason":"anatomy_extension_changed_existing_source","field":field}
	if extended.digits.size() != 10:
		return {"valid":false,"reason":"extension_requires_ten_measured_digits"}
	for old_digit: Dictionary in previous.digits:
		var matches: int = 0
		for new_digit: Dictionary in extended.digits:
			if old_digit.slot_id == new_digit.slot_id and old_digit.digit_id == new_digit.digit_id:
				matches += 1
				if var_to_bytes(old_digit) != var_to_bytes(new_digit):
					return {"valid":false,"reason":"anatomy_extension_changed_existing_digit","slot":old_digit.slot_id,"digit":old_digit.digit_id}
		if matches != 1: return {"valid":false,"reason":"existing_digit_missing_or_duplicated"}
	return {"valid":true,"source_signature":previous.source_signature,"extended_signature":extended.source_signature,
		"reference_skin_identical":true,"existing_digits_identical":true,"character_measurements_identical":true,
		"invariant_manifest_components_identical":true,"manifest_signatures_verified":true,
		"capture_is_historical":true,"pose_or_weapon_frames_changed":false}


func extend_trace(previous: Resource, extended: Resource, trace: Dictionary) -> Dictionary:
	var verified: Dictionary = validate_extension(previous, extended)
	if not verified.get("valid",false): return verified
	if trace.get("schema") != "grip_placement_trace_v1" or not trace.get("valid",false) or trace.get("anatomy_signature") != previous.source_signature:
		return {"valid":false,"reason":"trace_does_not_match_previous_anatomy"}
	var before: PackedByteArray = var_to_bytes(trace)
	var copied: Dictionary = trace.duplicate(true)
	var count: Array = [0]
	var result: Dictionary = _extend_packets(copied,previous,extended,count)
	if not result.get("valid",false): return result
	if count[0] == 0: return {"valid":false,"reason":"trace_has_no_complete_captured_pose"}
	if var_to_bytes(trace) != before: return {"valid":false,"reason":"source_trace_was_mutated"}
	copied["anatomy_signature"] = extended.source_signature
	copied["anatomy_extension_provenance"] = verified.duplicate(true)
	copied.anatomy_extension_provenance["pose_packet_count"] = count[0]
	return {"valid":true,"trace":copied,"verification":copied.anatomy_extension_provenance}


func _extend_packets(value: Variant, previous: Resource, extended: Resource, count: Array) -> Dictionary:
	if value is Array:
		for entry: Variant in value:
			var checked: Dictionary = _extend_packets(entry,previous,extended,count)
			if not checked.get("valid",false): return checked
	elif value is Dictionary:
		if value.get("schema") == &"coherent_skin_pose_capture_v1":
			if value.get("anatomy_signature") != previous.source_signature:
				return {"valid":false,"reason":"nested_capture_signature_mismatch"}
			var skin := CoherentSkin.new()
			var prepared: Dictionary = skin.prepare(previous.reference_skin,previous.source_signature)
			var old_pose: Dictionary = skin.pose(prepared,value)
			if not old_pose.get("valid",false): return old_pose
			value["anatomy_signature"] = extended.source_signature
			value["anatomy_extension_provenance"] = {"previous_signature":previous.source_signature,
				"reference_skin_identical":true,"capture_is_historical":true,"pose_or_weapon_frames_changed":false}
			if value.has("prepared_anatomy_path"):
				value.anatomy_extension_provenance["previous_prepared_anatomy_path"] = value.prepared_anatomy_path
				value["prepared_anatomy_path"] = extended.resource_path
			prepared = skin.prepare(extended.reference_skin,extended.source_signature)
			var new_pose: Dictionary = skin.pose(prepared,value)
			if not new_pose.get("valid",false): return new_pose
			if old_pose.vertices_world != new_pose.vertices_world:
				return {"valid":false,"reason":"extension_changed_reconstructed_skin"}
			count[0] += 1
			return {"valid":true}
		for key: Variant in value:
			var checked: Dictionary = _extend_packets(value[key],previous,extended,count)
			if not checked.get("valid",false): return checked
	return {"valid":true}
