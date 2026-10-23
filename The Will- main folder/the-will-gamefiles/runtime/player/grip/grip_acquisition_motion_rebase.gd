extends RefCounted

## A completed fixed-Hand solve may follow motion only when the hand's relevant
## skin and the weapon are still the same local problem. This is not a relaxed
## stale-pose check: a changed wrist/skin relationship still rejects the result.
const SkinCapture = preload("res://runtime/player/grip/capture_coherent_skin_pose.gd")
const Rules = preload("res://runtime/player/player_digit_hinge_rules.gd")
const FRAME_GUARD_M := 0.000005
const BASIS_GUARD := 0.00001
const REVISION := &"rigid_hand_acquisition_rebase_v1"


static func capture(skeleton: Skeleton3D, mesh: MeshInstance3D, reference: Dictionary, slot: StringName, weapon_to_world: Transform3D) -> Dictionary:
	if not _valid_skin(skeleton, mesh):
		return _fail("missing_current_character_skin")
	var correspondence: Dictionary = SkinCapture.new()._reference_matches(skeleton, mesh, reference)
	if not correspondence.get("valid", false):
		return correspondence
	var hand_name: StringName = &"CC_Base_R_Hand" if slot == &"hand_right" else &"CC_Base_L_Hand"
	if slot not in [&"hand_right", &"hand_left"] or skeleton.find_bone(hand_name) < 0:
		return _fail("missing_motion_rebase_hand")
	var selected: Array[StringName] = Rules.get_finger_bone_names(slot)
	if selected.size() != 15:
		return _fail("missing_motion_rebase_digit_layout")
	for bone: StringName in selected:
		if skeleton.find_bone(bone) < 0:
			return _fail("missing_motion_rebase_digit", {"bone": bone})
	var domain := _skin_domain(skeleton, reference, hand_name)
	if not domain.get("valid", false):
		return domain
	# A selected joint can have an unweighted intermediate ancestor. Its pose
	# still affects calibrated FK, so skin weights alone are not the full chain.
	for bone: StringName in selected:
		var index := skeleton.get_bone_parent(skeleton.find_bone(bone))
		for _step: int in skeleton.get_bone_count():
			if index < 0 or StringName(skeleton.get_bone_name(index)) == hand_name:
				break
			var name := StringName(skeleton.get_bone_name(index))
			if name not in domain.contributors:
				domain.contributors.append(name)
			index = skeleton.get_bone_parent(index)
	var state := _snapshot(skeleton, mesh, hand_name, selected, domain.contributors, weapon_to_world)
	if not state.get("valid", false):
		return state
	return {"valid": true, "revision": REVISION, "identity": _identity(skeleton, mesh),
		"reference": reference.duplicate(true), "hand_name": hand_name, "selected": selected,
		"contributors": domain.contributors, "max_residual_weight": domain.max_residual_weight,
		"relevant_vertex_count": domain.relevant_vertex_count, "source": state}


static func validate(captured: Dictionary, skeleton: Skeleton3D, mesh: MeshInstance3D, weapon_to_world: Transform3D) -> Dictionary:
	if not captured.get("valid", false) or captured.get("revision") != REVISION or not _valid_skin(skeleton, mesh):
		return _fail("missing_motion_rebase_capture")
	if captured.identity != _identity(skeleton, mesh):
		return _fail("character_skin_identity_changed")
	# Bone version alone does not detect edits to mesh arrays, bind poses or morphs.
	var correspondence: Dictionary = SkinCapture.new()._reference_matches(skeleton, mesh, captured.reference)
	if not correspondence.get("valid", false):
		return correspondence
	var current := _snapshot(skeleton, mesh, captured.hand_name, captured.selected, captured.contributors, weapon_to_world)
	if not current.get("valid", false):
		return current
	return compare_snapshots(captured.source, current, captured.max_residual_weight)


## Pure counterpart used by focused tests. All frames carry the same scene-world
## reference. Local digit rotations are intentionally absent: the solver replaces
## those 15 rotations with calibrated hinge FK. Their dimensions remain guarded.
static func compare_snapshots(source: Dictionary, current: Dictionary, max_residual_weight: float) -> Dictionary:
	for state: Dictionary in [source, current]:
		for field: String in ["hand_to_world", "weapon_to_world"]:
			if not state.get(field) is Transform3D or not _valid_frame(state[field]):
				return _fail("invalid_motion_rebase_frame", {"field": field})
		if not state.get("mesh_origin") is Vector3 or not (state.mesh_origin as Vector3).is_finite() or not state.get("dimensions") is Dictionary or not state.get("contributors") is Dictionary:
			return _fail("incomplete_motion_rebase_state")
	if not is_finite(max_residual_weight) or max_residual_weight < 0.0:
		return _fail("invalid_residual_skin_weight_bound")
	var delta: Transform3D = current.hand_to_world * (source.hand_to_world as Transform3D).affine_inverse()
	if not _valid_frame(delta) or not _basis_close(delta.basis.transposed() * delta.basis, Basis.IDENTITY) or absf(delta.basis.determinant() - 1.0) > BASIS_GUARD:
		return _fail("hand_motion_is_not_rigid")
	if not _frame_close(current.weapon_to_world, delta * source.weapon_to_world):
		return _fail("weapon_in_hand_changed_during_acquisition")
	if source.dimensions.size() != current.dimensions.size() or source.contributors.size() != current.contributors.size():
		return _fail("hand_motion_dependency_layout_changed")
	for bone: StringName in source.dimensions:
		if not current.dimensions.has(bone):
			return _fail("digit_dimensions_changed", {"bone": bone})
		var a: Dictionary = source.dimensions[bone]
		var b: Dictionary = current.dimensions[bone]
		if a.parent != b.parent or (a.position as Vector3).distance_to(b.position) > FRAME_GUARD_M or not _basis_close(a.metric, b.metric):
			return _fail("digit_dimensions_changed", {"bone": bone})
	for bone: StringName in source.contributors:
		if not current.contributors.has(bone):
			return _fail("skin_contributor_changed", {"bone": bone})
		var a: Dictionary = source.contributors[bone]
		var b: Dictionary = current.contributors[bone]
		if a.anchor != b.anchor or not _frame_close(a.relative, b.relative):
			return _fail("skin_contributor_changed", {"bone": bone})
	# The renderer retains non-unit skin sums. Its residual term is mesh origin,
	# not an extra unskinned vertex. Bound the complete term rather than silently
	# normalizing weights or requiring unrelated torso presentation to move too.
	var residual_error: float = max_residual_weight * (current.mesh_origin as Vector3).distance_to(delta * source.mesh_origin)
	if residual_error > FRAME_GUARD_M:
		return _fail("residual_skin_motion_changed", {"maximum_error_m": residual_error})
	return {"valid": true, "delta": delta, "motion_rebased": not delta.is_equal_approx(Transform3D.IDENTITY),
		"revision": REVISION, "maximum_residual_error_m": residual_error,
		"local_skin_relationship_preserved": true, "source_diagnostics_reference_preserved": true}


static func _snapshot(skeleton: Skeleton3D, mesh: MeshInstance3D, hand_name: StringName, selected: Array[StringName], contributors: Array[StringName], weapon_to_world: Transform3D) -> Dictionary:
	var hand_index := skeleton.find_bone(hand_name)
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
	if not _valid_frame(hand) or not _valid_frame(weapon_to_world):
		return _fail("invalid_motion_rebase_frame")
	var dimensions: Dictionary = {}
	for name: StringName in selected:
		var index := skeleton.find_bone(name)
		var local := skeleton.get_bone_pose(index)
		if not _valid_frame(local):
			return _fail("invalid_digit_dimension_frame")
		var parent_index := skeleton.get_bone_parent(index)
		dimensions[name] = {"parent": StringName(skeleton.get_bone_name(parent_index)) if parent_index >= 0 else StringName(),
			"position": local.origin, "metric": local.basis.transposed() * local.basis}
	var frames: Dictionary = {}
	for name: StringName in contributors:
		if name in selected:
			continue # These exact local rotations are overwritten by calibrated FK.
		var index := skeleton.find_bone(name)
		var anchor_name := hand_name
		var parent_index := skeleton.get_bone_parent(index)
		# Extra skin bones may descend from a selected finger. Their local relation
		# to that selected ancestor must stay fixed, not their current closed pose.
		for _step: int in skeleton.get_bone_count():
			if parent_index < 0 or parent_index == hand_index:
				break
			var parent_name := StringName(skeleton.get_bone_name(parent_index))
			if parent_name in selected:
				anchor_name = parent_name
				break
			parent_index = skeleton.get_bone_parent(parent_index)
		var anchor: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(anchor_name))
		var frame: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(index)
		if not _valid_frame(anchor) or not _valid_frame(frame):
			return _fail("invalid_skin_dependency_frame", {"bone": name})
		frames[name] = {"anchor": anchor_name, "relative": anchor.affine_inverse() * frame}
	return {"valid": true, "hand_to_world": hand, "weapon_to_world": weapon_to_world,
		"mesh_origin": mesh.global_position, "dimensions": dimensions, "contributors": frames}


## Same domain as PreparedSurfaceGripAnatomy: every corner of every triangle
## touched by a Hand-descendant influence. Non-hand corners still shape normals.
static func _skin_domain(skeleton: Skeleton3D, reference: Dictionary, hand_name: StringName) -> Dictionary:
	var hand_index := skeleton.find_bone(hand_name)
	var descendants: Dictionary = {}
	for name: StringName in reference.bind_bone_names:
		var index := skeleton.find_bone(name)
		for _step: int in skeleton.get_bone_count():
			if index == hand_index:
				descendants[name] = true
				break
			if index < 0:
				break
			index = skeleton.get_bone_parent(index)
	var contributors: Dictionary = {}
	var max_residual := 0.0
	var relevant_count := 0
	for surface: Dictionary in reference.surfaces:
		var points: PackedVector3Array = surface.vertices
		var bones: PackedInt32Array = surface.bones
		var weights: PackedFloat32Array = surface.weights
		if points.is_empty() or weights.size() % points.size() != 0 or weights.size() != bones.size():
			return _fail("invalid_motion_rebase_skin_arrays")
		var count: int = weights.size() / points.size()
		var affected: Dictionary = {}
		for vertex: int in points.size():
			for influence: int in count:
				var offset := vertex * count + influence
				if weights[offset] <= 0.0:
					continue
				if bones[offset] < 0 or bones[offset] >= reference.bind_bone_names.size():
					return _fail("invalid_motion_rebase_skin_bind")
				if descendants.has(reference.bind_bone_names[bones[offset]]):
					affected[vertex] = true
		var indices: PackedInt32Array = surface.indices.duplicate()
		if indices.is_empty():
			for vertex: int in points.size():
				indices.append(vertex)
		if indices.size() % 3 != 0:
			return _fail("invalid_motion_rebase_skin_triangles")
		var relevant: Dictionary = {}
		for offset: int in range(0, indices.size(), 3):
			if affected.has(indices[offset]) or affected.has(indices[offset + 1]) or affected.has(indices[offset + 2]):
				for corner: int in 3:
					relevant[indices[offset + corner]] = true
		for vertex: int in relevant:
			if vertex < 0 or vertex >= points.size():
				return _fail("invalid_motion_rebase_skin_triangle_index")
			var sum := 0.0
			for influence: int in count:
				var offset := vertex * count + influence
				var weight: float = weights[offset]
				if not is_finite(weight) or weight < 0.0:
					return _fail("invalid_motion_rebase_skin_weight")
				if weight == 0.0:
					continue
				contributors[StringName(reference.bind_bone_names[bones[offset]])] = true
				sum += weight
			max_residual = maxf(max_residual, absf(1.0 - sum))
		relevant_count += relevant.size()
	if relevant_count == 0:
		return _fail("missing_hand_skin_motion_domain")
	var names: Array[StringName] = []
	for name: StringName in contributors:
		names.append(name)
	return {"valid": true, "contributors": names, "max_residual_weight": max_residual, "relevant_vertex_count": relevant_count}


static func _identity(skeleton: Skeleton3D, mesh: MeshInstance3D) -> Array:
	return [skeleton.get_instance_id(), skeleton.get_version(), mesh.get_instance_id(), mesh.mesh.get_instance_id(), mesh.skin.get_instance_id()]


static func _valid_skin(skeleton: Skeleton3D, mesh: MeshInstance3D) -> bool:
	return is_instance_valid(skeleton) and is_instance_valid(mesh) and mesh.mesh != null and mesh.skin != null and mesh.is_inside_tree() and mesh.get_node_or_null(mesh.skeleton) == skeleton


static func _valid_frame(frame: Transform3D) -> bool:
	return frame.is_finite() and frame.basis.determinant() > 1.0e-12


static func _frame_close(a: Transform3D, b: Transform3D) -> bool:
	return _valid_frame(a) and _valid_frame(b) and a.origin.distance_to(b.origin) <= FRAME_GUARD_M and _basis_close(a.basis, b.basis)


static func _basis_close(a: Basis, b: Basis) -> bool:
	return a.is_finite() and b.is_finite() and a.x.distance_to(b.x) <= BASIS_GUARD and a.y.distance_to(b.y) <= BASIS_GUARD and a.z.distance_to(b.z) <= BASIS_GUARD


static func _fail(reason: String, details: Dictionary = {}) -> Dictionary:
	return {"valid": false, "reason": reason, "details": details}
