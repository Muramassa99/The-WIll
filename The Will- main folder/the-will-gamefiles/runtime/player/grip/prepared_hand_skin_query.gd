extends RefCounted

const ContactPreference = preload("res://runtime/player/grip/skin_section_contact_preference.gd")

const Origins = preload("res://core/models/combat_origin_record.gd")
const Registry = preload("res://core/resolvers/combat_origin_registry.gd")
const REVISION := &"coherent_prepared_hand_skin_v1"

## P1 surface input, not grip acceptance. Compile unchanged reference weights and
## bind-space points once; evaluate every contributing bone from ONE supplied pose.
## No scene reads/writes, rest substitution, weapon dependency or anatomy rebake.
## Keep the full supplied mesh until a smaller contact domain is independently
## established. Triangle/source identity is preserved, including shared tissue.
## The caller validates model/signature correspondence once during setup. A pose
## label declares provenance; the capture/candidate builder establishes coherence.
func prepare(reference: Dictionary, anatomy_signature: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if anatomy_signature.is_empty():
		return _fail("missing_anatomy_signature")
	if not reference.get("bind_bone_names") is Array or not reference.get("bind_poses") is Array:
		return _fail("missing_reference_binds")
	var names: Array = reference.bind_bone_names
	var binds: Array = reference.bind_poses
	if names.is_empty() or names.size() != binds.size():
		return _fail("mismatched_reference_binds")
	if not reference.get("bone_origin_records") is Dictionary or not reference.get("mesh_origin_record") is Dictionary:
		return _fail("missing_reference_origins")
	var records: Array = reference.bone_origin_records.values().duplicate(true)
	# The existing reference-skin schema predates space_type. Its two containers
	# explicitly identify bone and mesh records; declare that role on copies only.
	for raw: Variant in records:
		if not raw is Dictionary:
			return _fail("invalid_reference_bone_origin")
		if not raw.has("space_type"):
			raw["space_type"] = Origins.SPACE_TYPE_MACHINE if raw.get("origin_id") == Origins.ORIGIN_RL_BONE_ROOT else Origins.SPACE_TYPE_BONE_FRAME
	var mesh_record: Dictionary = reference.mesh_origin_record.duplicate(true)
	if not mesh_record.has("space_type"):
		mesh_record["space_type"] = Origins.SPACE_TYPE_PRESENTATION
	records.append(mesh_record)
	var registered: Dictionary = _registry(records, Origins.PHASE_BAKE_TIME)
	if not bool(registered.get("valid", false)):
		return registered
	var registry = registered.registry
	var reference_mesh_id: StringName = _id(reference.get("vertices_origin_id"))
	if reference_mesh_id == StringName() or reference_mesh_id == Origins.ORIGIN_RL_BONE_ROOT or reference.mesh_origin_record.get("origin_id") != reference_mesh_id:
		return _fail("invalid_reference_mesh_origin")
	for index: int in range(names.size()):
		var name: StringName = _id(names[index])
		if name == StringName() or not registry.has_origin(name) or not _valid_frame(binds[index]):
			return _fail("invalid_reference_bind", {"bind_index": index})
	if not reference.get("surfaces") is Array or reference.surfaces.is_empty():
		return _fail("missing_reference_surfaces")

	var vertex_offsets := PackedInt32Array([0])
	var influence_binds := PackedInt32Array()
	var weighted_points := PackedVector3Array()
	var influence_weights := PackedFloat64Array()
	var residual_weights := PackedFloat64Array()
	var triangle_indices := PackedInt32Array()
	var triangle_surface_ids := PackedInt32Array()
	var triangle_local_ids := PackedInt32Array()
	var ranges: Array[Dictionary] = []
	var preference_vertex_aliases := PackedInt32Array()
	var used: Dictionary = {}
	for surface_index: int in range(reference.surfaces.size()):
		if not reference.surfaces[surface_index] is Dictionary:
			return _fail("invalid_reference_surface")
		var source: Dictionary = reference.surfaces[surface_index]
		if not source.get("vertices") is PackedVector3Array or not source.get("bones") is PackedInt32Array or not source.get("weights") is PackedFloat32Array or not source.get("indices") is PackedInt32Array:
			return _fail("invalid_reference_surface_arrays")
		var points: PackedVector3Array = source.vertices
		var bones: PackedInt32Array = source.bones
		var weights: PackedFloat32Array = source.weights
		if points.is_empty() or weights.is_empty() or weights.size() % points.size() != 0 or bones.size() != weights.size():
			return _fail("mismatched_reference_influences")
		var influences: int = weights.size() / points.size()
		var first_vertex: int = residual_weights.size()
		# Reconnect exact imported render seams for contour percentages only.
		# Physical vertices, weights and source identities are never merged.
		var local_aliases := ContactPreference.build_vertex_aliases(points, bones, weights, influences)
		for vertex: int in points.size():
			preference_vertex_aliases.append(first_vertex + (local_aliases[vertex] if local_aliases.size() == points.size() else vertex))
		var first_triangle: int = triangle_indices.size() / 3
		for vertex: int in range(points.size()):
			if not points[vertex].is_finite():
				return _fail("nonfinite_reference_vertex")
			var weight_sum: float = 0.0
			for influence: int in range(influences):
				var offset: int = vertex * influences + influence
				var weight: float = weights[offset]
				if not is_finite(weight) or weight < 0.0:
					return _fail("invalid_reference_weight")
				if weight == 0.0:
					continue
				var bind: int = bones[offset]
				if bind < 0 or bind >= names.size():
					return _fail("invalid_reference_bind_index")
				var point: Vector3 = (binds[bind] as Transform3D) * points[vertex]
				if not point.is_finite() or not (point * weight).is_finite():
					return _fail("nonfinite_weighted_bind_point")
				influence_binds.append(bind)
				weighted_points.append(point * weight)
				influence_weights.append(weight)
				weight_sum += weight
				used[bind] = true
			if not is_finite(weight_sum) or weight_sum <= 0.0:
				return _fail("vertex_without_valid_influences")
			# Renderer adds mesh presentation translation ONCE after weighted XYZ.
			# Preserve nonunit sums. Do not add a residual reference vertex.
			residual_weights.append(1.0 - weight_sum)
			vertex_offsets.append(influence_binds.size())
		var indices: PackedInt32Array = source.indices.duplicate()
		if indices.is_empty():
			for vertex: int in range(points.size()):
				indices.append(vertex)
		if indices.is_empty() or indices.size() % 3 != 0:
			return _fail("non_triangle_reference_surface")
		for offset: int in range(indices.size()):
			if indices[offset] < 0 or indices[offset] >= points.size():
				return _fail("invalid_reference_triangle_index")
			triangle_indices.append(first_vertex + indices[offset])
			if offset % 3 == 0:
				triangle_surface_ids.append(surface_index)
				triangle_local_ids.append(offset / 3)
		ranges.append({"surface_index": surface_index, "first_vertex": first_vertex,
			"vertex_count": points.size(), "first_triangle": first_triangle,
			"triangle_count": indices.size() / 3})
	var used_indices: Array = used.keys()
	used_indices.sort()
	return {"valid": true, "revision": REVISION, "anatomy_signature": anatomy_signature,
		"reference_vertices_origin_id": reference_mesh_id,
		"bind_bone_names": names.duplicate(), "weighted_bind_point_origin_ids": names.duplicate(),
		"required_bind_indices": PackedInt32Array(used_indices),
		"vertex_offsets": vertex_offsets, "influence_binds": influence_binds,
		"weighted_bind_points": weighted_points, "influence_weights": influence_weights,
		"residual_weights": residual_weights, "triangle_indices": triangle_indices,
		"triangle_surface_ids": triangle_surface_ids, "triangle_local_ids": triangle_local_ids,
		"surface_ranges": ranges, "vertex_count": residual_weights.size(),
		"preference_vertex_aliases": preference_vertex_aliases,
		"triangle_count": triangle_indices.size() / 3,
		"reference_origin_records": records, "weights_normalized_by_tool": false,
		"anatomy_measurement_ran": false, "actual_3d_grip_verified": false,
		"preparation_ms": float(Time.get_ticks_usec() - started) / 1000.0}


## The pose packet owns explicit origin records at one phase, a source-bone to
## pose-origin map, a posed mesh origin and machine presentation. Missing current
## transforms never fall back to bind rests. Bone records may have parent chains.
func pose(prepared: Dictionary, packet: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	if not bool(prepared.get("valid", false)) or prepared.get("revision") != REVISION:
		return _fail("invalid_prepared_hand_skin")
	if packet.get("anatomy_signature") != prepared.anatomy_signature:
		return _fail("pose_anatomy_signature_mismatch")
	if packet.get("root_origin_id") != Origins.ORIGIN_RL_BONE_ROOT or _id(packet.get("pose_id")) == StringName():
		return _fail("missing_named_pose_or_machine")
	if not _valid_frame(packet.get("machine_to_world")):
		return _fail("invalid_machine_presentation")
	var phase: StringName = _id(packet.get("resolve_phase"))
	if phase not in [Origins.PHASE_BAKE_TIME, Origins.PHASE_EDITOR_PREVIEW, Origins.PHASE_POST_FINAL_POSE]:
		return _fail("unsupported_pose_phase")
	if not packet.get("origin_records") is Array or not packet.get("bone_origin_ids") is Dictionary:
		return _fail("missing_pose_origins")
	var registered: Dictionary = _registry(packet.origin_records, phase)
	if not bool(registered.get("valid", false)):
		return registered
	var registry = registered.registry
	var mesh_id: StringName = _id(packet.get("mesh_origin_id"))
	if mesh_id == StringName() or mesh_id == Origins.ORIGIN_RL_BONE_ROOT or not registry.has_origin(mesh_id):
		return _fail("missing_posed_mesh_origin")
	var mesh_to_machine: Transform3D = registry.resolve_transform_to_machine(mesh_id)
	var names: Array = prepared.bind_bone_names
	var bone_origins: Dictionary = packet.bone_origin_ids
	var source_by_origin: Dictionary = {}
	for source: Variant in bone_origins:
		var source_id: StringName = _id(source)
		var origin: StringName = _id(bone_origins[source])
		if source_id == StringName() or not names.has(source_id) or origin == StringName() or origin == mesh_id or not registry.has_origin(origin):
			return _fail("invalid_bone_pose_mapping", {"source_bone_id": source_id})
		if source_by_origin.has(origin) and source_by_origin[origin] != source_id:
			return _fail("aliased_bone_pose_origins")
		if (source_id == Origins.ORIGIN_RL_BONE_ROOT) != (origin == Origins.ORIGIN_RL_BONE_ROOT):
			return _fail("invalid_machine_bone_mapping")
		source_by_origin[origin] = source_id
	var frames: Array[Transform3D] = []
	frames.resize(names.size())
	var resolved_bones: Dictionary = {}
	for bind: int in prepared.required_bind_indices:
		var source_id: StringName = names[bind]
		if not bone_origins.has(source_id):
			return _fail("missing_contributing_bone_pose", {"source_bone_id": source_id})
		var origin: StringName = bone_origins[source_id]
		frames[bind] = registry.resolve_transform_to_machine(origin)
		resolved_bones[source_id] = frames[bind]
	var validation_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var count: int = prepared.vertex_count
	var machine_vertices := PackedVector3Array()
	var world_vertices := PackedVector3Array()
	machine_vertices.resize(count)
	world_vertices.resize(count)
	var offsets: PackedInt32Array = prepared.vertex_offsets
	var binds: PackedInt32Array = prepared.influence_binds
	var points: PackedVector3Array = prepared.weighted_bind_points
	var weights: PackedFloat64Array = prepared.influence_weights
	var residual: PackedFloat64Array = prepared.residual_weights
	var machine_to_world: Transform3D = packet.machine_to_world
	for vertex: int in range(count):
		# Accumulator is explicitly machine-local; each term comes from its named
		# bone origin. No normalized basis or assumed character scale is used.
		var position_machine: Vector3 = mesh_to_machine.origin * residual[vertex]
		for influence: int in range(offsets[vertex], offsets[vertex + 1]):
			var frame: Transform3D = frames[binds[influence]]
			position_machine += frame.basis * points[influence] + frame.origin * weights[influence]
		var position_world: Vector3 = machine_to_world * position_machine
		if not position_machine.is_finite() or not position_world.is_finite():
			return _fail("nonfinite_posed_vertex", {"vertex": vertex})
		machine_vertices[vertex] = position_machine
		world_vertices[vertex] = position_world
	return {"valid": true, "revision": REVISION, "anatomy_signature": prepared.anatomy_signature,
		"pose_id": packet.pose_id, "resolve_phase": phase,
		"vertices_machine": machine_vertices, "vertices_world": world_vertices,
		"origin_id": Origins.ORIGIN_RL_BONE_ROOT, "vertices_machine_origin_id": Origins.ORIGIN_RL_BONE_ROOT,
		"resolved_world_origin_id": Origins.ORIGIN_RL_BONE_ROOT, "machine_to_world": machine_to_world,
		"mesh_origin_id": mesh_id, "mesh_to_machine": mesh_to_machine,
		"bone_origin_ids": bone_origins.duplicate(), "bone_transforms_to_machine": resolved_bones,
		"origin_records": packet.origin_records.duplicate(true),
		"triangle_indices": prepared.triangle_indices.duplicate(), "triangle_surface_ids": prepared.triangle_surface_ids.duplicate(),
		"triangle_local_ids": prepared.triangle_local_ids.duplicate(), "surface_ranges": prepared.surface_ranges.duplicate(true),
		"vertex_count": count, "triangle_count": prepared.triangle_count,
		"contributing_bind_count": prepared.required_bind_indices.size(),
		"all_contributing_poses_supplied": true, "other_bones_use_hand_rebased_rest": false,
		"weights_normalized_by_tool": false, "anatomy_measurement_ran": false,
		"production_pose_written": false, "actual_3d_grip_verified": false,
		"preparation_ms": prepared.preparation_ms, "pose_validation_ms": validation_ms,
		"elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0}


func _registry(records: Array, phase: StringName) -> Dictionary:
	var registry = Registry.new(false)
	var seen: Dictionary = {}
	for raw: Variant in records:
		if not raw is Dictionary:
			return _fail("invalid_origin_record")
		var data: Dictionary = raw
		var id: StringName = _id(data.get("origin_id"))
		var parent: StringName = _id(data.get("parent_origin_id"))
		if id == StringName() or seen.has(id):
			return _fail("missing_or_duplicate_origin_id")
		if not data.has("parent_origin_id") or not _valid_frame(data.get("transform_to_parent")):
			return _fail("invalid_origin_parent_or_transform")
		if data.get("resolve_phase") != phase or _id(data.get("owner_system")) == StringName() or _id(data.get("space_type")) in [StringName(), Origins.SPACE_TYPE_UNKNOWN] or not data.get("is_dynamic") is bool:
			return _fail("incomplete_or_mixed_origin_provenance")
		if id == Origins.ORIGIN_RL_BONE_ROOT:
			# Check BEFORE Registry/Record normalization could hide a malformed root.
			if parent != StringName() or data.transform_to_parent != Transform3D.IDENTITY:
				return _fail("noncanonical_machine_origin")
		elif parent == StringName():
			return _fail("origin_without_parent")
		var record = Origins.new()
		for field: String in ["origin_id", "parent_origin_id", "transform_to_parent", "owner_system", "resolve_phase", "space_type", "is_dynamic"]:
			record.set(field, data[field])
		if not registry.register_origin(record):
			return _fail("origin_registration_failed")
		seen[id] = true
	if not registry.has_origin(Origins.ORIGIN_RL_BONE_ROOT) or not bool(registry.validate_all().get("ok", false)):
		return _fail("incomplete_or_cyclic_origin_chain")
	for id: StringName in registry.get_origin_ids():
		if not _valid_frame(registry.resolve_transform_to_machine(id)):
			return _fail("invalid_composed_origin_frame")
	return {"valid": true, "registry": registry}


func _id(value: Variant) -> StringName:
	return StringName(value) if value is String or value is StringName else StringName()


func _valid_frame(value: Variant) -> bool:
	if not value is Transform3D:
		return false
	var frame: Transform3D = value
	return frame.is_finite() and is_finite(frame.basis.determinant()) and absf(frame.basis.determinant()) > 1.0e-12


func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details,
		"production_pose_written": false, "actual_3d_grip_verified": false}
