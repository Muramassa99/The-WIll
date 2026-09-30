extends "res://runtime/player/grip/palmar_reference_geometry.gd"

const Definition = preload("res://tools/grip_plane_proof/prepared_palmar_contact_def.gd")
const REVISION := "reference_rest_paired_core_rays_v1"

## Explicit bake/export adapter; reference geometry is shared with acquisition.
func bake(definition: Resource, machine_to_world: Transform3D) -> Dictionary:
	var started := Time.get_ticks_usec()
	if definition == null or not definition.get("reference_skin") is Dictionary or not definition.get("source_manifest") is Dictionary:
		return _fail("missing_prepared_character_reference")
	var signature: String = str(definition.get("source_signature"))
	if signature.length() != 64:
		return _fail("missing_anatomy_signature")
	var metric: Dictionary = _validate_metric(definition.source_manifest.get("character_metric", {}), machine_to_world)
	if not metric.valid:
		return metric
	var reference: Dictionary = definition.reference_skin
	var correspondence := _validate_reference_hashes(reference, definition.source_manifest)
	if not correspondence.valid:
		return correspondence
	var evaluator := HandSkin.new()
	var prepared: Dictionary = evaluator.prepare(reference, signature)
	if not prepared.get("valid", false):
		return prepared
	var mapping := {}
	for name: StringName in reference.bind_bone_names:
		mapping[name] = name
	var packet := {"anatomy_signature": signature, "root_origin_id": ROOT,
		"pose_id": &"PalmarCoreReferenceRest", "resolve_phase": &"bake_time",
		"machine_to_world": machine_to_world, "origin_records": prepared.reference_origin_records.duplicate(true),
		"bone_origin_ids": mapping, "mesh_origin_id": reference.vertices_origin_id}
	var posed: Dictionary = evaluator.pose(prepared, packet)
	if not posed.get("valid", false):
		return posed
	var registered: Dictionary = evaluator._registry(packet.origin_records, &"bake_time")
	if not registered.get("valid", false):
		return registered
	var output := Definition.new()
	output.preparation_revision = REVISION
	output.character_id = definition.character_id
	output.anatomy_signature = signature
	output.source_mesh_origin_id = reference.vertices_origin_id
	output.origin_records.assign(prepared.reference_origin_records.duplicate(true))
	output.recipe_manifest = _recipe(signature, definition.source_manifest.character_metric)
	output.recipe_fingerprint = Fingerprint.new()._hash(output.recipe_manifest)
	output.complete = true
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var measured := _measure_slot(slot, prepared, posed, registered.registry, machine_to_world)
		output.samples_by_slot[slot] = measured.get("samples", [])
		var metadata: Dictionary = measured.duplicate(true)
		metadata.erase("samples")
		if metadata.has("origin_record"):
			output.origin_records.append(metadata.origin_record)
			metadata.erase("origin_record")
		output.slot_metadata[slot] = metadata
		output.complete = output.complete and bool(measured.get("complete", false))
	var origins: Dictionary = evaluator._registry(output.origin_records, &"bake_time")
	if not origins.get("valid", false):
		return _fail("palmar_reference_origin_registration_failed", origins)
	output.measurement_status = &"paired_core_samples_complete_not_solid_certificate" if output.complete else &"partial_core_samples_not_complete"
	return {"valid": output.complete, "complete": output.complete, "resource": output,
		"reason": "" if output.complete else "incomplete_core_sample_pairs",
		"slot_metadata": output.slot_metadata.duplicate(true),
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"reference_pose_policy": "all_saved_bone_and_mesh_reference_rest_frames",
		"captured_articulation_used": false, "weapon_input_used": false,
		"palm_overlap_policy_defined": false, "actual_3d_grip_verified": false}


func _recipe(signature: String, metric: Dictionary) -> Dictionary:
	var files := {}
	for path: String in [get_script().resource_path, "res://tools/grip_plane_proof/prepared_palmar_contact_def.gd", "res://tools/grip_plane_proof/prepared_hand_skin_query.gd", "res://runtime/player/player_digit_hinge_rules.gd", "res://tools/grip_plane_proof/character_anatomy_source_signature.gd", "res://core/resolvers/combat_origin_registry.gd", "res://core/models/combat_origin_record.gd"]:
		files[path] = FileAccess.get_sha256(path)
	# Tool paths remain compatibility adapters; hash their runtime authorities too.
	for path: String in ["res://runtime/player/grip/palmar_reference_geometry.gd", "res://runtime/player/grip/prepared_hand_skin_query.gd", "res://runtime/player/grip/character_anatomy_source_signature.gd"]:
		files[path] = FileAccess.get_sha256(path)
	return {"preparation_revision": REVISION, "anatomy_signature": signature, "character_metric": metric.duplicate(true),
		"recipe_hashes": files, "engine": Engine.get_version_info(), "sample_parameters": SAMPLE_PARAMETERS.duplicate(),
		"polarity_digits": [&"middle", &"ring", &"pinky"], "minimum_closing_alignment": MIN_CLOSING_ALIGNMENT,
		"ray_epsilon_m": RAY_EPSILON_M, "barycentric_epsilon": BARYCENTRIC_EPSILON, "metric_gram_epsilon": GRAM_EPSILON,
		"overlap_policy_defined": false}
