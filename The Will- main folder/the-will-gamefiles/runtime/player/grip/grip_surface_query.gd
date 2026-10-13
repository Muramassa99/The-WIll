extends RefCounted

## V6 immutable saved-surface queries. No scene/physics objects, skin slicing or
## closure policy. Saved ForgeSavedGripSourceOrigin metres are scaled to private
## millimetre query units, retaining the source origin (not inventing a new zero).
## TriangleMesh snaps to 0.0001 input units: here that is 0.0001 mm, not 0.1 mm.
const Wrapper = preload("res://core/resolvers/prepared_grip_target_wrapper_resolver.gd")
const WrapperData = preload("res://core/models/prepared_grip_target_wrapper.gd")
const Source = preload("res://runtime/player/grip/saved_wrapper_grip_source.gd")
const QUERY_UNITS_PER_METER := 1000.0
const MAX_CACHED_GEOMETRIES := 8
static var _cache: Dictionary = {}
static var _cache_lock := Mutex.new()


## Call on the acquisition worker, once per input. Geometry is immutable after
## publication; cached BVHs may be queried concurrently, never rebuilt in place.
static func prepare(saved_source: Dictionary, expected_config: Dictionary = {}) -> Dictionary:
	var started := Time.get_ticks_usec()
	if not saved_source.get("valid", false):
		return _failure("saved_surface_source_invalid")
	if saved_source.get("source_origin_id", &"") != Source.SOURCE_ORIGIN:
		return _failure("saved_surface_source_origin_invalid")
	if saved_source.get("metric_units", &"") != &"meters":
		return _failure("saved_surface_metric_invalid")
	if not saved_source.get("source_to_weapon") is Transform3D:
		return _failure("saved_surface_transform_missing")
	var source_to_weapon: Transform3D = saved_source.source_to_weapon
	if not source_to_weapon.is_finite() or absf(source_to_weapon.basis.determinant()) < 0.000000001:
		return _failure("saved_surface_transform_invalid")
	var wrapper: Resource = saved_source.get("wrapper")
	var packet: Dictionary = saved_source.get("handle_packet", {})
	if wrapper == null:
		return _failure("saved_surface_wrapper_missing")
	var legacy := int(wrapper.get("schema_version")) == WrapperData.LEGACY_SCHEMA_VERSION
	var geometry := {
		&"physical": [packet.get("vertices", PackedVector3Array()), packet.get("indices", PackedInt32Array())],
		&"digit": [wrapper.get("target_vertices_m"), wrapper.get("target_indices")],
		&"palm": [wrapper.get("palm_target_vertices_m"), wrapper.get("palm_target_indices")],
	}
	if not legacy:
		geometry[&"non_thumb_s1"] = [wrapper.get("non_thumb_s1_target_vertices_m"), wrapper.get("non_thumb_s1_target_indices")]
	var stored_depths := {&"digit": float(wrapper.get("guide_inward_target_offset_m")),
		&"palm": float(wrapper.get("palm_guide_target_depth_m")),
		&"non_thumb_s1": float(wrapper.get("guide_inward_target_offset_m") if legacy else wrapper.get("non_thumb_s1_guide_target_depth_m"))}
	var requested_depths: Dictionary = stored_depths.duplicate()
	if not expected_config.is_empty():
		var settings := Wrapper.validate_config(expected_config)
		if not settings.get("valid", false): return _failure(str(settings.error))
		if settings.config.character_id != wrapper.get("character_id") or settings.config.anatomy_signature != wrapper.get("anatomy_signature"):
			return _failure("saved_surface_character_configuration_mismatch")
		if absf(float(settings.config.inward_min_radius_m) - float(wrapper.get("inward_min_radius_m"))) > Wrapper.CONFIG_TOLERANCE:
			return _failure("saved_surface_curvature_requires_forge_save")
		requested_depths = {&"digit": float(settings.config.guide_inward_target_offset_m),
			&"palm": float(settings.config.palm_guide_target_depth_m),
			&"non_thumb_s1": float(settings.config.non_thumb_s1_guide_target_depth_m)}
	var offsets := {}
	var adapted: Array[StringName] = []
	for kind: StringName in stored_depths:
		offsets[kind] = float(requested_depths[kind]) - float(stored_depths[kind])
		if absf(float(offsets[kind])) > Wrapper.CONFIG_TOLERANCE: adapted.append(kind)
	var target_contract := {"revision": &"section_attraction_depths_v2", "saved_schema": int(wrapper.get("schema_version")),
		"legacy_shared_digit_target": legacy, "local_normal_adaptation_used": not adapted.is_empty(),
		"adaptation_revision": &"saved_target_local_normal_depth_delta_v1", "adapted_kinds": adapted,
		"stored_depths_m": stored_depths, "requested_depths_m": requested_depths,
		"rebaked_geometry_equivalent": adapted.is_empty(), "saved_geometry_mutated": false}
	# Hash actual arrays as well as save provenance. A profile edit must not reuse
	# a prior BVH merely because it retained the same weapon/library identity.
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes([geometry, packet.get("primary_grip_handle_body_signature", ""),
		wrapper.get("source_body_signature"), wrapper.get("schema_version"),
		wrapper.get("construction_revision"), wrapper.get("vertices_origin_id"),
		wrapper.get("source_handle_vertices_m"), wrapper.get("source_handle_indices"),
		wrapper.get("character_id"), wrapper.get("anatomy_signature"),
		wrapper.get("inward_min_radius_m"), wrapper.get("guide_inward_target_offset_m"),
		wrapper.get("non_thumb_s1_guide_target_depth_m"),
		wrapper.get("palm_guide_target_depth_m")]))
	var fingerprint := digest.finish().hex_encode()
	_cache_lock.lock()
	var cached: Dictionary = _cache.get(fingerprint, {})
	_cache_lock.unlock()
	var cache_hit := not cached.is_empty()
	if not cache_hit:
		var checked := Wrapper.validate(wrapper, packet)
		if not checked.get("valid", false):
			return _failure(str(checked.get("error", "saved_surface_wrapper_invalid")))
		var surfaces: Dictionary = {}
		for kind: StringName in geometry:
			var arrays: Array = geometry[kind]
			var surface := _build_surface(arrays[0], arrays[1])
			if not surface.get("valid", false):
				return _failure("%s_%s" % [kind, surface.get("reason", "surface_build_failed")])
			surfaces[kind] = surface
		if legacy: surfaces[&"non_thumb_s1"] = surfaces[&"digit"]
		surfaces.make_read_only()
		cached = {"surfaces": surfaces, "fingerprint": fingerprint}
		cached.make_read_only()
		_cache_lock.lock()
		# A second worker may have prepared the same immutable data meanwhile.
		if _cache.has(fingerprint):
			cached = _cache[fingerprint]
		else:
			if _cache.size() >= MAX_CACHED_GEOMETRIES:
				_cache.erase(_cache.keys()[0])
			_cache[fingerprint] = cached
		_cache_lock.unlock()
	var source_bounds: AABB = cached.surfaces[&"physical"].bounds_m
	return {"valid": true, "surfaces": cached.surfaces, "fingerprint": fingerprint,
		"source_origin_id": Source.SOURCE_ORIGIN,
		"source_parent_origin_id": saved_source.get("source_parent_origin_id", &""),
		"source_to_weapon": source_to_weapon, "metric_units": &"meters",
		"source_bounds": source_bounds, "reach_m": source_bounds.size.length(),
		"attraction_depth_offsets_m": offsets, "target_contract": target_contract,
		"cache_hit": cache_hit, "build_ms": float(Time.get_ticks_usec() - started) / 1000.0}


## Attraction only. Existing saves keep their exact immutable meshes. Where the
## requested section depth differs, move the hit along the saved face's inward
## normal. This local approximation preserves the existing vacuum bridge; it is
## explicitly NOT a regenerated profile inset at corners. Physical checks always
## use trace(..., &"physical", ...), never this adaptation.
static func trace_attraction(prepared: Dictionary, kind: StringName,
		from_m: Vector3, to_m: Vector3, source_to_query: Transform3D,
		query_origin_id: StringName) -> Dictionary:
	if kind not in [&"digit", &"non_thumb_s1", &"palm"]:
		return {"hit": false, "reason": "invalid_attraction_surface_kind"}
	var hit := trace(prepared, kind, from_m, to_m, source_to_query, query_origin_id)
	if not hit.get("hit", false): return hit
	var offset := float(prepared.get("attraction_depth_offsets_m", {}).get(kind, 0.0))
	hit["attraction_kind"] = kind
	hit["local_normal_adaptation_used"] = absf(offset) > Wrapper.CONFIG_TOLERANCE
	hit["additional_inward_depth_m"] = offset
	if not hit.local_normal_adaptation_used: return hit
	var surface: Dictionary = prepared.surfaces[kind]
	var source_normal: Vector3 = surface.outward_normals[int(hit.face_index)]
	var source_position: Vector3 = hit.position_source_m
	hit["saved_target_position_source_m"] = source_position
	hit["position_source_m"] = source_position - source_normal * offset
	hit["position_m"] = source_to_query * (hit.position_source_m as Vector3)
	hit["distance_m"] = from_m.distance_to(hit.position_m)
	hit["adaptation_revision"] = &"saved_target_local_normal_depth_delta_v1"
	return hit


## Finite first intersection. Endpoints and returned position/normal are in the
## caller's explicitly named metre frame. source_to_query must include the
## saved source-to-weapon rebase followed by weapon-to-caller transformation.
static func trace(prepared: Dictionary, kind: StringName,
		from_m: Vector3, to_m: Vector3, source_to_query: Transform3D,
		query_origin_id: StringName) -> Dictionary:
	if not prepared.get("valid", false) or query_origin_id == &"":
		return {"hit": false, "reason": "surface_or_query_origin_invalid"}
	if not from_m.is_finite() or not to_m.is_finite() or not source_to_query.is_finite():
		return {"hit": false, "reason": "surface_query_nonfinite"}
	if from_m.distance_squared_to(to_m) <= 0.000000000000000001:
		return {"hit": false, "reason": "surface_query_empty_segment"}
	if absf(source_to_query.basis.determinant()) < 0.000000001:
		return {"hit": false, "reason": "surface_query_singular_transform"}
	var surface: Dictionary = prepared.surfaces.get(kind, {})
	if surface.is_empty():
		return {"hit": false, "reason": "surface_kind_missing"}
	var query_to_source := source_to_query.affine_inverse()
	var mesh: TriangleMesh = surface.mesh
	var hit := mesh.intersect_segment((query_to_source * from_m) * QUERY_UNITS_PER_METER,
		(query_to_source * to_m) * QUERY_UNITS_PER_METER)
	if hit.is_empty():
		return {"hit": false, "reason": "surface_not_intersected"}
	var face_index := int(hit.face_index)
	var normals: PackedVector3Array = surface.outward_normals
	if face_index < 0 or face_index >= normals.size():
		return {"hit": false, "reason": "surface_face_index_invalid"}
	var position_source_m: Vector3 = hit.position / QUERY_UNITS_PER_METER
	var position_m := source_to_query * position_source_m
	# The engine flips its reported normal against the ray. Original winding,
	# oriented once by closed signed volume, retains entry/exit authority instead.
	var normal := (query_to_source.basis.transposed() * normals[face_index]).normalized()
	var normal_dot_ray := normal.dot((to_m - from_m).normalized())
	return {"hit": true, "position_m": position_m, "normal": normal,
		"distance_m": from_m.distance_to(position_m), "face_index": face_index,
		"entered_surface": normal_dot_ray < 0.0, "exited_surface": normal_dot_ray > 0.0,
		"origin_id": query_origin_id, "source_origin_id": prepared.source_origin_id,
		"source_to_query": source_to_query, "position_source_m": position_source_m}


## Bounded directional separation, NOT a global closest-point or full-skin
## collision certificate. The caller supplies the anatomical outward direction
## and sufficient reach to begin outside this surface. Missing/exit hits remain
## explicit; callers must not interpret a miss as an already valid contact.
static func sample(prepared: Dictionary, kind: StringName,
		point_m: Vector3, outward_direction: Vector3, reach_m: float,
		source_to_query: Transform3D, query_origin_id: StringName) -> Dictionary:
	if not outward_direction.is_finite() or outward_direction.length_squared() <= 0.000000000001 or not is_finite(reach_m) or reach_m <= 0.0:
		return {"hit": false, "reason": "surface_sample_direction_or_reach_invalid"}
	var direction := outward_direction.normalized()
	var hit := trace(prepared, kind, point_m + direction * reach_m,
		point_m - direction * reach_m, source_to_query, query_origin_id)
	if hit.get("hit", false):
		var separation: Vector3 = point_m - hit.position_m
		hit["signed_gap_m"] = separation.dot(hit.normal)
		hit["directional_gap_m"] = separation.dot(direction)
	return hit


static func _build_surface(vertices_m: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var faces_mm := PackedVector3Array()
	faces_mm.resize(indices.size())
	var normals := PackedVector3Array()
	normals.resize(indices.size() / 3)
	var signed_volume_six := 0.0
	# Translation-independent volume avoids cancellation when a valid handle is
	# authored far from its root. The reference is a source vertex, not a new frame.
	var volume_reference := vertices_m[indices[0]]
	var bounds_m := AABB(volume_reference, Vector3.ZERO)
	for vertex_m: Vector3 in vertices_m:
		bounds_m = bounds_m.expand(vertex_m)
	for offset: int in range(0, indices.size(), 3):
		var a := vertices_m[indices[offset]]
		var b := vertices_m[indices[offset + 1]]
		var c := vertices_m[indices[offset + 2]]
		var cross := (b - a).cross(c - a)
		if not cross.is_finite() or cross.length_squared() <= 0.0:
			return _failure("surface_degenerate_face")
		faces_mm[offset] = a * QUERY_UNITS_PER_METER
		faces_mm[offset + 1] = b * QUERY_UNITS_PER_METER
		faces_mm[offset + 2] = c * QUERY_UNITS_PER_METER
		normals[offset / 3] = cross.normalized()
		signed_volume_six += (a - volume_reference).dot((b - volume_reference).cross(c - volume_reference))
	if not is_finite(signed_volume_six) or absf(signed_volume_six) <= 0.000000000000000001:
		return _failure("surface_has_no_oriented_volume")
	if signed_volume_six < 0.0:
		for index: int in range(normals.size()):
			normals[index] = -normals[index]
	var mesh := TriangleMesh.new()
	if not mesh.create_from_faces(faces_mm):
		return _failure("surface_bvh_build_failed")
	var result := {"valid": true, "mesh": mesh, "outward_normals": normals,
		"vertices_m": vertices_m, "indices": indices, "bounds_m": bounds_m,
		"source_origin_id": Source.SOURCE_ORIGIN, "metric_units": &"meters"}
	result.make_read_only()
	return result


static func _failure(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
