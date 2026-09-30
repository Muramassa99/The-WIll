extends RefCounted

## Validates already prepared data. No generation, mutation, scene creation, or
## physical overlap policy belongs here. Run at bake/load boundaries, not once
## per finger or per frame: topology validation visits every stored triangle.
const PreparedWrapperScript = preload("res://core/models/prepared_grip_target_wrapper.gd")
const HandlePacketScript = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const SOURCE_VERTEX_ROUNDTRIP_TOLERANCE_M := 0.0000005
const CONFIG_TOLERANCE := 0.000000000001


static func validate(
	wrapper: Resource,
	handle_packet: Dictionary,
	config: Dictionary = {}
) -> Dictionary:
	if wrapper == null or wrapper.get_script() != PreparedWrapperScript:
		return _failure("prepared_wrapper_resource_type_invalid")
	if int(wrapper.get("schema_version")) != PreparedWrapperScript.SCHEMA_VERSION:
		return _failure("prepared_wrapper_schema_invalid")
	if StringName(wrapper.get("construction_revision")) != PreparedWrapperScript.CONSTRUCTION_REVISION:
		return _failure("prepared_wrapper_construction_revision_invalid")
	if StringName(wrapper.get("vertices_origin_id")) != HandlePacketScript.VERTICES_ORIGIN_ID:
		return _failure("prepared_wrapper_vertices_origin_invalid")
	if StringName(wrapper.get("profile_origin_id")) != PreparedWrapperScript.PROFILE_ORIGIN_ID:
		return _failure("prepared_wrapper_profile_origin_invalid")
	var stored_config := validate_config({
		"character_id": wrapper.get("character_id"),
		"anatomy_signature": wrapper.get("anatomy_signature"),
		"inward_min_radius_m": wrapper.get("inward_min_radius_m"),
		"guide_inward_target_offset_m": wrapper.get("guide_inward_target_offset_m"),
		"palm_guide_target_depth_m": wrapper.get("palm_guide_target_depth_m"),
	})
	if not bool(stored_config.get("valid", false)):
		return stored_config
	if not config.is_empty():
		var expected_config := validate_config(config)
		if not bool(expected_config.get("valid", false)):
			return expected_config
		var stored: Dictionary = stored_config["config"]
		var expected: Dictionary = expected_config["config"]
		for key: String in ["character_id", "anatomy_signature"]:
			if stored[key] != expected[key]:
				return _failure("prepared_wrapper_%s_mismatch" % key)
		for key: String in [
			"inward_min_radius_m", "guide_inward_target_offset_m", "palm_guide_target_depth_m",
		]:
			if absf(float(stored[key]) - float(expected[key])) > CONFIG_TOLERANCE:
				return _failure("prepared_wrapper_%s_mismatch" % key)
	var handle := HandlePacketScript.validate(handle_packet)
	if not bool(handle.get("valid", false)):
		return _failure("prepared_wrapper_source_%s" % String(handle.get("error", "invalid")))
	if String(wrapper.get("source_body_signature")) != String(handle["body_signature"]):
		return _failure("prepared_wrapper_source_body_signature_mismatch")
	var source_vertices: PackedVector3Array = wrapper.get("source_handle_vertices_m")
	var source_indices: PackedInt32Array = wrapper.get("source_handle_indices")
	var handle_vertices: PackedVector3Array = handle["vertices"]
	var handle_indices: PackedInt32Array = handle["indices"]
	if source_indices != handle_indices:
		return _failure("prepared_wrapper_source_indices_mismatch")
	if source_vertices.size() != handle_vertices.size():
		return _failure("prepared_wrapper_source_vertex_count_mismatch")
	for vertex_index: int in range(source_vertices.size()):
		var vertex := source_vertices[vertex_index]
		if not vertex.is_finite():
			return _failure("prepared_wrapper_source_vertex_nonfinite")
		if vertex.distance_to(handle_vertices[vertex_index]) > SOURCE_VERTEX_ROUNDTRIP_TOLERANCE_M:
			return _failure("prepared_wrapper_source_vertex_mismatch")
	for profile_key: String in [
		"source_profile_m", "envelope_profile_m", "target_profile_m", "palm_target_profile_m",
	]:
		var profile_result := _validate_profile(wrapper.get(profile_key), profile_key)
		if not bool(profile_result.get("valid", false)):
			return profile_result
	var target_result := _validate_closed_mesh(
		wrapper.get("target_vertices_m"), wrapper.get("target_indices"), "target"
	)
	if not bool(target_result.get("valid", false)):
		return target_result
	var palm_result := _validate_closed_mesh(
		wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices"), "palm_target"
	)
	if not bool(palm_result.get("valid", false)):
		return palm_result
	var build_ms := float(wrapper.get("build_ms"))
	if not is_finite(build_ms) or build_ms < 0.0:
		return _failure("prepared_wrapper_build_duration_invalid")
	return {"valid": true, "error": ""}


## Accept the current character contact_config radius name or the normalized
## stored name. Never infer missing settings or retune any overlap limit.
static func validate_config(config: Dictionary) -> Dictionary:
	var character_variant: Variant = config.get("character_id", null)
	if not (character_variant is StringName or character_variant is String):
		return _failure("prepared_wrapper_character_id_invalid")
	var character_id := StringName(character_variant)
	if String(character_id).strip_edges().is_empty():
		return _failure("prepared_wrapper_character_id_invalid")
	var signature_variant: Variant = config.get("anatomy_signature", null)
	if not signature_variant is String or String(signature_variant).strip_edges().is_empty():
		return _failure("prepared_wrapper_anatomy_signature_invalid")
	var radius_variant: Variant = config.get("inward_min_radius_m", config.get("envelope_radius_m", null))
	if not _is_positive_number(radius_variant):
		return _failure("prepared_wrapper_inward_min_radius_m_invalid")
	if config.has("inward_min_radius_m") and config.has("envelope_radius_m"):
		var envelope_variant: Variant = config["envelope_radius_m"]
		if not _is_positive_number(envelope_variant):
			return _failure("prepared_wrapper_envelope_radius_m_invalid")
		if absf(float(radius_variant) - float(envelope_variant)) > CONFIG_TOLERANCE:
			return _failure("prepared_wrapper_radius_alias_mismatch")
	for key: String in ["guide_inward_target_offset_m", "palm_guide_target_depth_m"]:
		if not _is_positive_number(config.get(key, null)):
			return _failure("prepared_wrapper_%s_invalid" % key)
	return {
		"valid": true,
		"error": "",
		"config": {
			"character_id": character_id,
			"anatomy_signature": String(signature_variant),
			"inward_min_radius_m": float(radius_variant),
			"guide_inward_target_offset_m": float(config["guide_inward_target_offset_m"]),
			"palm_guide_target_depth_m": float(config["palm_guide_target_depth_m"]),
		},
	}


static func _validate_profile(profile: PackedVector2Array, label: String) -> Dictionary:
	if profile.size() < 3:
		return _failure("prepared_wrapper_%s_missing" % label)
	var doubled_area := 0.0
	for vertex_index: int in range(profile.size()):
		var vertex := profile[vertex_index]
		if not vertex.is_finite():
			return _failure("prepared_wrapper_%s_nonfinite" % label)
		doubled_area += vertex.cross(profile[(vertex_index + 1) % profile.size()])
	if not is_finite(doubled_area) or doubled_area == 0.0:
		return _failure("prepared_wrapper_%s_degenerate" % label)
	return {"valid": true, "error": ""}


static func _validate_closed_mesh(
	vertices: PackedVector3Array,
	indices: PackedInt32Array,
	label: String
) -> Dictionary:
	if vertices.size() < 4 or indices.size() < 12 or indices.size() % 3 != 0:
		return _failure("prepared_wrapper_%s_topology_invalid" % label)
	for vertex: Vector3 in vertices:
		if not vertex.is_finite():
			return _failure("prepared_wrapper_%s_vertex_nonfinite" % label)
	for vertex_index: int in indices:
		if vertex_index < 0 or vertex_index >= vertices.size():
			return _failure("prepared_wrapper_%s_index_invalid" % label)
	var edge_counts: Dictionary = {}
	var edge_directions: Dictionary = {}
	for triangle_offset: int in range(0, indices.size(), 3):
		var a := indices[triangle_offset]
		var b := indices[triangle_offset + 1]
		var c := indices[triangle_offset + 2]
		var cross_product := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if not cross_product.is_finite() or cross_product.length_squared() == 0.0:
			return _failure("prepared_wrapper_%s_triangle_degenerate" % label)
		for directed_edge: Vector2i in [Vector2i(a, b), Vector2i(b, c), Vector2i(c, a)]:
			var edge := Vector2i(mini(directed_edge.x, directed_edge.y), maxi(directed_edge.x, directed_edge.y))
			edge_counts[edge] = int(edge_counts.get(edge, 0)) + 1
			var direction := 1 if directed_edge.x < directed_edge.y else -1
			edge_directions[edge] = int(edge_directions.get(edge, 0)) + direction
	for edge: Vector2i in edge_counts:
		if int(edge_counts[edge]) != 2:
			return _failure("prepared_wrapper_%s_mesh_not_closed" % label)
		if int(edge_directions[edge]) != 0:
			return _failure("prepared_wrapper_%s_winding_inconsistent" % label)
	return {"valid": true, "error": ""}


static func _is_positive_number(value: Variant) -> bool:
	if not (value is float or value is int):
		return false
	return is_finite(float(value)) and float(value) > 0.0


static func _failure(error: String) -> Dictionary:
	return {"valid": false, "error": error}
