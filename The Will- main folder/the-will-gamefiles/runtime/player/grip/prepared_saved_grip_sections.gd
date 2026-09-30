extends RefCounted

## Read-only W3 adapter: slice Forge's saved targets alongside its real Handle.
## No envelope construction, skin/IK solve, scene mutation or material policy.
## prepare() freezes one source/configuration/hand epoch. Reprepare when geometry,
## configuration, weapon orientation, or any hand measurement plane changes.
## Translation queries reuse its triangle indices; they never move the hand.
## Godot 4.7 Transform3D: translated(), affine_inverse(), packed vertex transform.
const Wrapper = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const HandlePacket = preload("res://core/resolvers/primary_grip_handle_mesh_packet.gd")
const Section = preload("res://runtime/player/grip/prepared_weapon_plane_section.gd")
const HandSkin = preload("res://runtime/player/grip/prepared_hand_skin_query.gd")
const Origins = preload("res://core/models/combat_origin_record.gd")
const ROOT := Origins.ORIGIN_RL_BONE_ROOT
const WEAPON := Origins.ORIGIN_WEAPON_ROOT
const REVISION := &"prepared_saved_grip_sections_v1"
const OWNER := &"prepared_saved_grip_sections"
const FRAME_TOLERANCE_M := 0.000005
const AXIAL_TOLERANCE_M := 0.0000001
const KINDS: Array[StringName] = [&"handle", &"digit_target", &"palm_target"]
var _section := Section.new()


## plane_context contains digit_planes {digit: {plane_to_world, plane_origin_id}},
## origin_records (serialized complete chains), resolve_phase, station_axis_world
## and vectors_origin_id=RL_BoneRoot. Plane chains cannot descend from the weapon.
## config is the current character contact configuration, NOT copied from wrapper.
func prepare(wrapper: Resource, handle_packet: Dictionary, weapon_to_world: Transform3D,
		machine_to_world: Transform3D, plane_context: Dictionary, config: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not _valid_frame(machine_to_world) or not _metric_frame(weapon_to_world):
		return _fail("invalid_machine_or_nonmetric_weapon_frame")
	if handle_packet.get("primary_grip_handle_vertices_origin_id") != WEAPON:
		return _fail("missing_explicit_handle_origin")
	var expected := Wrapper.validate_config(config)
	if not expected.get("valid", false): return _fail("invalid_current_wrapper_config", expected)
	var validated := Wrapper.validate(wrapper, handle_packet, config)
	if not validated.get("valid", false): return _fail("saved_wrapper_rejected", validated)
	if not plane_context.get("digit_planes") is Dictionary or plane_context.digit_planes.is_empty():
		return _fail("missing_digit_planes")
	if not plane_context.get("origin_records") is Array or plane_context.get("vectors_origin_id") != ROOT:
		return _fail("missing_named_plane_context")
	var phase := StringName(plane_context.get("resolve_phase", &""))
	if phase not in [Origins.PHASE_EDITOR_PREVIEW, Origins.PHASE_POST_FINAL_POSE, Origins.PHASE_BAKE_TIME]:
		return _fail("unsupported_resolve_phase")
	var registered := HandSkin.new()._registry(plane_context.origin_records, phase)
	if not registered.get("valid", false): return _fail("invalid_plane_origin_chain", registered)
	var registry = registered.registry
	if not registry.has_origin(WEAPON) or not _same_frame(machine_to_world * registry.resolve_transform_to_machine(WEAPON), weapon_to_world):
		return _fail("weapon_origin_frame_mismatch")
	var axis: Variant = plane_context.get("station_axis_world")
	if not axis is Vector3 or not axis.is_finite() or axis.length_squared() < 1.0e-12:
		return _fail("missing_or_degenerate_station_axis")
	var source: Dictionary = HandlePacket.validate(handle_packet)
	var surfaces: Dictionary = {
		&"handle": _surface(source.vertices, source.indices, weapon_to_world),
		&"digit_target": _surface(wrapper.get("target_vertices_m"), wrapper.get("target_indices"), weapon_to_world),
		&"palm_target": _surface(wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices"), weapon_to_world),
	}
	var digits: Dictionary = {}
	for digit: Variant in plane_context.digit_planes:
		if not (digit is String or digit is StringName) or String(digit).is_empty():
			return _fail("invalid_digit_id")
		var input: Variant = plane_context.digit_planes[digit]
		if not input is Dictionary or not input.get("plane_to_world") is Transform3D:
			return _fail("missing_digit_plane", {"digit": digit})
		var plane: Transform3D = input.plane_to_world
		var id := StringName(input.get("plane_origin_id", &""))
		if id in [StringName(), ROOT, WEAPON] or not registry.has_origin(id) or not _metric_frame(plane):
			return _fail("invalid_named_metric_digit_plane", {"digit": digit})
		if WEAPON in registry.validate_origin_chain(id).get("chain_ids", []):
			return _fail("hand_plane_cannot_follow_weapon", {"digit": digit})
		if not _same_frame(machine_to_world * registry.resolve_transform_to_machine(id), plane):
			return _fail("digit_plane_origin_frame_mismatch", {"digit": digit})
		var query_id := StringName(String(id) + "SavedGripSourceQueryOrigin")
		if registry.has_origin(query_id): return _fail("source_query_origin_already_owned")
		var indexed: Dictionary = {}
		for kind: StringName in KINDS:
			indexed[kind] = _section.prepare(surfaces[kind], plane, query_id)
			if not indexed[kind].get("valid", false):
				return _fail("saved_surface_index_failed", {"digit": digit, "kind": kind, "result": indexed[kind]})
		digits[digit] = {"plane_to_world": plane, "origin_id": id, "query_origin_id": query_id,
			"indexed": indexed, "origin_chain": registry.validate_origin_chain(id)}
	var parent_id: StringName = registry.get_origin(WEAPON).parent_origin_id
	return {"valid": true, "revision": REVISION, "digits": digits,
		"weapon_to_world": weapon_to_world, "weapon_to_world_origin_id": ROOT,
		"machine_to_world": machine_to_world, "vectors_origin_id": ROOT,
		"weapon_parent_to_world": machine_to_world * registry.resolve_transform_to_machine(parent_id),
		"station_axis_world": (axis as Vector3).normalized(), "station_axis_origin_id": ROOT,
		"origin_records": plane_context.origin_records.duplicate(true), "resolve_phase": phase,
		"source_body_signature": source.body_signature, "config": expected.config.duplicate(true),
		"source_fingerprint": var_to_bytes([REVISION, source.body_signature, expected.config,
			wrapper.get("source_handle_vertices_m"), wrapper.get("source_handle_indices"),
			wrapper.get("target_vertices_m"), wrapper.get("target_indices"),
			wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices")]).hex_encode().sha256_text(),
		"metric_units": &"meters", "source_geometry_frozen": true,
		"wrapper_generation_ran": false, "full_weapon_material_included": false,
		"production_pose_written": false, "actual_3d_grip_verified": false,
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}


## Single shared WORLD-presentation displacement derived through RL_BoneRoot.
## No per-digit placement and no axial/roll changes are accepted here.
## Polygon center on each section is its OWN measured area centroid. Only the
## enclosing digit record's center is the canonical physical-Handle guide center.
## Empty digit_ids retains all prepared digits. An explicit ordered selection
## queries only those planes; it never creates separate weapon placements.
func slice(prepared: Dictionary, weapon_translation_world: Vector3, translation_origin_id: StringName = ROOT,
		digit_ids: Array = []) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not prepared.get("valid", false) or prepared.get("revision") != REVISION:
		return _fail("invalid_saved_section_preparation")
	if translation_origin_id != ROOT or not weapon_translation_world.is_finite():
		return _fail("invalid_named_weapon_translation")
	if absf(weapon_translation_world.dot(prepared.station_axis_world)) > AXIAL_TOLERANCE_M:
		return _fail("weapon_translation_changes_handle_station")
	var selected: Array = prepared.digits.keys() if digit_ids.is_empty() else []
	var seen: Dictionary = {}
	for value: Variant in digit_ids:
		if not (value is String or value is StringName) or String(value).is_empty():
			return _fail("invalid_selected_digit_id")
		var digit := StringName(value)
		if not prepared.digits.has(digit): return _fail("unknown_selected_digit_id", {"digit": digit})
		if seen.has(digit): return _fail("duplicate_selected_digit_id", {"digit": digit})
		seen[digit] = true
		selected.append(digit)
	var weapon: Transform3D = prepared.weapon_to_world
	weapon.origin += weapon_translation_world
	var records: Array = prepared.origin_records.duplicate(true)
	for record: Dictionary in records:
		if record.origin_id == WEAPON:
			record.transform_to_parent = (prepared.weapon_parent_to_world as Transform3D).affine_inverse() * weapon
			record.owner_system = OWNER
			record.is_dynamic = true
	var result: Dictionary = {"valid": true, "revision": REVISION, "digits": {},
		"weapon_to_world": weapon, "weapon_to_world_origin_id": ROOT,
		"weapon_translation_world": weapon_translation_world, "translation_origin_id": ROOT,
		"machine_to_world": prepared.machine_to_world, "vectors_origin_id": ROOT,
		"source_fingerprint": prepared.source_fingerprint, "source_body_signature": prepared.source_body_signature,
		"metric_units": &"meters", "full_weapon_material_included": false,
		"wrapper_generation_ran": false, "production_pose_written": false, "actual_3d_grip_verified": false}
	for digit: Variant in selected:
		var fixed: Dictionary = prepared.digits[digit]
		var plane: Transform3D = fixed.plane_to_world
		# Translating the source by D and slicing with P equals slicing the fixed
		# source with translated(P,-D). XY coordinates are identical; no reprojection,
		# new wrapping or triangle transform is needed per seating query.
		var query_plane := plane
		query_plane.origin -= weapon_translation_world
		records.append({"origin_id": fixed.query_origin_id, "parent_origin_id": ROOT,
			"transform_to_parent": (prepared.machine_to_world as Transform3D).affine_inverse() * query_plane,
			"owner_system": OWNER, "resolve_phase": prepared.resolve_phase,
			"space_type": Origins.SPACE_TYPE_PRESENTATION, "is_dynamic": true})
		var entry: Dictionary = {"origin_id": fixed.origin_id, "plane_to_world": plane,
			"plane_to_world_origin_id": ROOT, "query_origin_id": fixed.query_origin_id}
		for kind: StringName in KINDS:
			var section: Dictionary = _section.slice(fixed.indexed[kind], query_plane)
			if not section.get("valid", false):
				return _fail("saved_surface_section_failed", {"digit": digit, "kind": kind, "result": section})
			# Record the numerical query and rebind its equal XY coordinates to the
			# actual unchanged hand plane. SourceQuery is not a second hand placement.
			section["source_query_origin_id"] = fixed.query_origin_id
			section["source_query_plane_to_world"] = query_plane
			section["source_query_plane_to_world_origin_id"] = ROOT
			section["origin_id"] = fixed.origin_id
			section["plane"] = plane
			section["plane_to_world"] = plane
			section["plane_to_world_origin_id"] = ROOT
			section["surface_role"] = kind
			section["is_physical_material"] = kind == &"handle"
			entry[kind] = section
		var center: Vector2 = entry.handle.center
		var radius := 0.0
		for kind: StringName in KINDS:
			for point: Vector2 in entry[kind].polygon:
				radius = maxf(radius, point.distance_to(center))
		entry["center"] = center
		entry["center_origin_id"] = fixed.origin_id
		entry["center_policy"] = &"physical_handle_slice_area_centroid"
		entry["required_enclosing_radius_m"] = radius
		result.digits[digit] = entry
	var registered := HandSkin.new()._registry(records, prepared.resolve_phase)
	if not registered.get("valid", false): return _fail("translated_origin_chain_invalid", registered)
	result["origin_records"] = records
	result["resolve_phase"] = prepared.resolve_phase
	result["slice_ms"] = float(Time.get_ticks_usec() - started) / 1000.0
	return result


func _surface(vertices: PackedVector3Array, indices: PackedInt32Array, weapon_to_world: Transform3D) -> Dictionary:
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for index: int in indices.size(): faces[index] = vertices[indices[index]]
	return {"valid": true, "triangles_world": weapon_to_world * faces,
		"surface_source_origin_id": WEAPON, "resolved_world_origin_id": ROOT}


func _metric_frame(frame: Transform3D) -> bool:
	return _valid_frame(frame) and frame.basis.is_equal_approx(frame.basis.orthonormalized()) and frame.basis.determinant() > 0.99999


func _valid_frame(frame: Transform3D) -> bool:
	return frame.is_finite() and is_finite(frame.basis.determinant()) and absf(frame.basis.determinant()) > 1.0e-12


func _same_frame(first: Transform3D, second: Transform3D) -> bool:
	if first.origin.distance_to(second.origin) > FRAME_TOLERANCE_M: return false
	for axis: int in 3:
		if first.basis[axis].distance_to(second.basis[axis]) > FRAME_TOLERANCE_M: return false
	return true


func _fail(reason: String, detail: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "detail": detail,
		"production_pose_written": false, "actual_3d_grip_verified": false}
