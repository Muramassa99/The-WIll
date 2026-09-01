extends RefCounted
class_name PlayerFingerSurfaceGripSolver

const PlayerFingerCapsuleSurfaceQueryScript = preload(
	"res://runtime/player/player_finger_capsule_surface_query.gd"
)

## Pure, deterministic cosmetic finger solver.
##
## This object never writes to the skeleton, the held item, or any macro pose node.
## It snapshots the settled pose, queries the final weapon surface, back-solves three
## serial one-axis hinges per digit, and returns local pose rotations for the caller
## to cache/apply at an explicit lifecycle boundary.

const SOLVER_REVISION: StringName = &"serial_hinge_capsule_surface_v8"
const MAX_ALLOWED_OVERLAP_METERS := 0.0005
const THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED := false
const THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS := 0.005
const DEFAULT_PREFERRED_OVERLAP_METERS := 0.00025
const DEFAULT_SWEEP_STEPS := 20
const DEFAULT_BACKSOLVE_PASSES := 10
const DEFAULT_BVH_LEAF_TRIANGLES := 8
const DEFAULT_CAPSULE_SECTION_SAMPLES := 3
const DEFAULT_PHASE_PATH_SAFETY_SAMPLES := 20
const DEFAULT_FINAL_REACCOMMODATION_PASSES := 5
const DEFAULT_FINAL_REACCOMMODATION_ANGLE_SAMPLES := 9
const DEFAULT_TARGET_ERROR_METERS := 0.00035
const DEFAULT_MAX_ACCEPTABLE_CONTACT_ERROR_METERS := 0.0015
const DEFAULT_ANGLE_REGULARIZATION_WEIGHT := 0.00000002
const OVERLAP_NUMERIC_EPSILON_METERS := 0.00000005
const SECTION_TARGET_TOLERANCE_METERS := 0.00008
const HARD_CAP_TARGET_GUARD_METERS := 0.00000025
const THUMB_CLEARANCE_DEFAULT_STEP_DEGREES := 20.0
const THUMB_CLEARANCE_DEFAULT_MAX_DEGREES := 130.0
const DEFAULT_DIGIT_HINGE_LIMIT_DEGREES := 130.0
const COLLINEAR_SECTION_MAX_ANGLE_DEGREES := 0.25
const RAY_EPSILON := 0.0000001
const ANGLE_EPSILON := 0.000001

var capsule_surface_query = PlayerFingerCapsuleSurfaceQueryScript.new()


func solve(
	skeleton: Skeleton3D,
	mesh_instance: MeshInstance3D,
	slot_id: StringName,
	side_rules: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var invalid_result: Dictionary = _make_empty_result(slot_id)
	if skeleton == null or mesh_instance == null or mesh_instance.mesh == null:
		invalid_result["diagnostics"] = {
			"status": &"missing_solver_input",
			"solver_revision": SOLVER_REVISION,
		}
		return invalid_result
	var prepared_surface: Dictionary = options.get("prepared_surface", {}) as Dictionary
	if not bool(prepared_surface.get("valid", false)):
		prepared_surface = prepare_surface(mesh_instance.mesh, mesh_instance.global_transform, options)
	return solve_prepared(skeleton, prepared_surface, slot_id, side_rules, options)


func prepare_surface(
	mesh: Mesh,
	mesh_global_transform: Transform3D,
	options: Dictionary = {}
) -> Dictionary:
	var result := {
		"valid": false,
		"solver_revision": SOLVER_REVISION,
		"triangles_world": PackedVector3Array(),
		"triangle_normals_world": PackedVector3Array(),
		"triangle_bounds_world": [],
		"triangle_centroids_world": PackedVector3Array(),
		"bvh_nodes": [],
		"bvh_triangle_order": [],
		"triangle_count": 0,
		"source_surface_count": 0,
		"surface_signature": "",
		"mesh_local_geometry_hash": 0,
		"mesh_world_transform_hash": hash(mesh_global_transform),
		"filtered_triangle_count": 0,
		"surface_source_origin_id": options.get(
			"surface_source_origin_id",
			StringName()
		),
		"resolved_world_origin_id": options.get(
			"resolved_world_origin_id",
			StringName()
		),
		"capsule_surface_topology": {},
		"status": &"missing_mesh",
	}
	if mesh == null:
		return result
	var triangles_world := PackedVector3Array()
	var normals_world := PackedVector3Array()
	var triangle_bounds: Array[AABB] = []
	var triangle_centroids := PackedVector3Array()
	var local_geometry_digest: Array = []
	var accepted_surface_indices: Array[int] = _resolve_accepted_surface_indices(mesh, options)
	for surface_index: int in accepted_surface_indices:
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		result["source_surface_count"] = int(result.get("source_surface_count", 0)) + 1
		var arrays: Array = mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_VERTEX:
			continue
		var vertices_variant: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not vertices_variant is PackedVector3Array:
			continue
		var vertices: PackedVector3Array = vertices_variant as PackedVector3Array
		var indices := PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var element_count: int = indices.size() if not indices.is_empty() else vertices.size()
		for element_index: int in range(0, element_count - 2, 3):
			var index_a: int = indices[element_index] if not indices.is_empty() else element_index
			var index_b: int = indices[element_index + 1] if not indices.is_empty() else element_index + 1
			var index_c: int = indices[element_index + 2] if not indices.is_empty() else element_index + 2
			if index_a < 0 or index_b < 0 or index_c < 0:
				continue
			if index_a >= vertices.size() or index_b >= vertices.size() or index_c >= vertices.size():
				continue
			var local_a: Vector3 = vertices[index_a]
			var local_b: Vector3 = vertices[index_b]
			var local_c: Vector3 = vertices[index_c]
			var world_a: Vector3 = mesh_global_transform * local_a
			var world_b: Vector3 = mesh_global_transform * local_b
			var world_c: Vector3 = mesh_global_transform * local_c
			var cross: Vector3 = (world_b - world_a).cross(world_c - world_a)
			if (
				cross.length_squared()
				<= PlayerFingerCapsuleSurfaceQueryScript.TRIANGLE_AREA_EPSILON_SQUARED_M4
			):
				continue
			if not _triangle_passes_grip_filter(
				local_a,
				local_b,
				local_c,
				world_a,
				world_b,
				world_c,
				options
			):
				result["filtered_triangle_count"] = int(result.get("filtered_triangle_count", 0)) + 1
				continue
			triangles_world.append(world_a)
			triangles_world.append(world_b)
			triangles_world.append(world_c)
			normals_world.append(cross.normalized())
			triangle_bounds.append(_triangle_aabb(world_a, world_b, world_c).grow(RAY_EPSILON))
			triangle_centroids.append((world_a + world_b + world_c) / 3.0)
			local_geometry_digest.append(local_a)
			local_geometry_digest.append(local_b)
			local_geometry_digest.append(local_c)
	result["triangles_world"] = triangles_world
	result["triangle_normals_world"] = normals_world
	result["triangle_bounds_world"] = triangle_bounds
	result["triangle_centroids_world"] = triangle_centroids
	result["triangle_count"] = normals_world.size()
	result["mesh_local_geometry_hash"] = hash(local_geometry_digest)
	if normals_world.is_empty():
		result["status"] = &"empty_grip_surface"
		return result
	var bvh: Dictionary = _build_bvh(
		triangle_bounds,
		triangle_centroids,
		clampi(int(options.get("bvh_leaf_triangles", DEFAULT_BVH_LEAF_TRIANGLES)), 2, 32)
	)
	result["bvh_nodes"] = bvh.get("nodes", [])
	result["bvh_triangle_order"] = bvh.get("triangle_order", [])
	var filter_signature: Variant = options.get("grip_filter_signature", _build_filter_signature(options))
	result["surface_signature"] = "%s:%s:%s:%s:%s" % [
		String(SOLVER_REVISION),
		str(result.get("mesh_local_geometry_hash", 0)),
		str(result.get("mesh_world_transform_hash", 0)),
		str(normals_world.size()),
		str(hash(filter_signature)),
	]
	result["valid"] = true
	result["status"] = &"ready"
	result["capsule_surface_topology"] = (
		capsule_surface_query.analyze_prepared_surface_topology(result)
	)
	return result


func solve_prepared(
	skeleton: Skeleton3D,
	prepared_surface: Dictionary,
	slot_id: StringName,
	side_rules: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = _make_empty_result(slot_id)
	result["surface_signature"] = String(prepared_surface.get("surface_signature", ""))
	var diagnostics := {
		"status": &"invalid_input",
		"solver_revision": SOLVER_REVISION,
		"slot_id": slot_id,
		"side_id": StringName(side_rules.get("side_id", slot_id)),
		"surface_signature": result["surface_signature"],
		"surface_triangle_count": int(prepared_surface.get("triangle_count", 0)),
		"ray_count": 0,
		"ray_bvh_node_test_count": 0,
		"ray_triangle_test_count": 0,
		"contacted_section_count": 0,
		"accepted_section_count": 0,
		"expected_section_count": 15,
		"solved_digit_count": 0,
		"degraded_digit_count": 0,
		"unsafe_digit_count": 0,
		"max_contact_error_meters": 0.0,
		"max_penetration_meters": 0.0,
		"max_allowed_overlap_meters": 0.0,
		"overlap_limit_respected": true,
		"digit_results": {},
		"writes_performed": 0,
	}
	result["diagnostics"] = diagnostics
	if skeleton == null:
		diagnostics["status"] = &"missing_skeleton"
		return result
	if not bool(prepared_surface.get("valid", false)):
		diagnostics["status"] = &"invalid_prepared_surface"
		return result
	var rules_validation: Dictionary = _validate_rule_pack(skeleton, side_rules)
	if not bool(rules_validation.get("valid", false)):
		diagnostics["status"] = &"invalid_side_rules"
		diagnostics["rule_errors"] = rules_validation.get("errors", [])
		return result
	var rule_max_overlap: float = float(side_rules.get("max_overlap_meters", MAX_ALLOWED_OVERLAP_METERS))
	var max_overlap: float = clampf(
		float(options.get("max_overlap_meters", rule_max_overlap)),
		0.0,
		MAX_ALLOWED_OVERLAP_METERS
	)
	var preferred_overlap: float = clampf(
		float(options.get(
			"preferred_overlap_meters",
			side_rules.get("preferred_overlap_meters", DEFAULT_PREFERRED_OVERLAP_METERS)
		)),
		0.0,
		max_overlap
	)
	diagnostics["max_allowed_overlap_meters"] = max_overlap
	diagnostics["preferred_overlap_meters"] = preferred_overlap
	var ray_stats := {
		"ray_count": 0,
		"bvh_node_test_count": 0,
		"triangle_test_count": 0,
		"surface_query_count": 0,
		"surface_query_bvh_node_test_count": 0,
		"surface_query_triangle_test_count": 0,
		"inside_ray_count": 0,
	}
	var rotations: Dictionary = {}
	var zero_rotations: Dictionary = {}
	var digit_results: Dictionary = {}
	var baseline_digest: Array = []
	var supplied_base_pose_rotations: Dictionary = options.get(
		"base_pose_rotations",
		{}
	) as Dictionary
	var digits: Array = side_rules.get("digits", []) as Array
	for digit_variant: Variant in digits:
		var digit_rules: Dictionary = digit_variant as Dictionary
		var snapshot: Dictionary = _capture_digit_snapshot(
			skeleton,
			digit_rules,
			supplied_base_pose_rotations
		)
		if not bool(snapshot.get("valid", false)):
			var invalid_digit_id: StringName = StringName(digit_rules.get("digit_id", &"unknown"))
			digit_results[invalid_digit_id] = {
				"status": &"invalid_chain_snapshot",
				"contacted_section_count": 0,
			}
			diagnostics["degraded_digit_count"] = int(diagnostics.get("degraded_digit_count", 0)) + 1
			continue
		for bone_index: int in range(3):
			var bone_name: StringName = (snapshot.get("bone_names", []) as Array)[bone_index]
			var baseline_rotation: Quaternion = (snapshot.get("base_pose_rotations", []) as Array)[bone_index]
			rotations[bone_name] = baseline_rotation
			baseline_digest.append(bone_name)
			baseline_digest.append(baseline_rotation)
			baseline_digest.append((snapshot.get("base_bone_world", []) as Array)[bone_index])
		var digit_result: Dictionary = _solve_digit(
			snapshot,
			prepared_surface,
			preferred_overlap,
			max_overlap,
			options,
			ray_stats
		)
		var digit_id: StringName = StringName(snapshot.get("digit_id", &"unknown"))
		digit_results[digit_id] = digit_result.get("diagnostics", {})
		var digit_rotations: Dictionary = digit_result.get("rotations", {}) as Dictionary
		for bone_name_variant: Variant in digit_rotations.keys():
			rotations[bone_name_variant] = digit_rotations[bone_name_variant]
		var digit_zero_rotations: Dictionary = digit_result.get(
			"zero_rotations",
			{}
		) as Dictionary
		for bone_name_variant: Variant in digit_zero_rotations.keys():
			zero_rotations[bone_name_variant] = digit_zero_rotations[bone_name_variant]
		var digit_diagnostics: Dictionary = digit_result.get("diagnostics", {}) as Dictionary
		if not bool(digit_diagnostics.get("overlap_limit_respected", false)):
			diagnostics["unsafe_digit_count"] = int(
				diagnostics.get("unsafe_digit_count", 0)
			) + 1
		var section_contacts: int = int(digit_diagnostics.get("contacted_section_count", 0))
		diagnostics["contacted_section_count"] = int(diagnostics.get("contacted_section_count", 0)) + section_contacts
		diagnostics["accepted_section_count"] = int(
			diagnostics.get("accepted_section_count", 0)
		) + int(digit_diagnostics.get("accepted_section_count", 0))
		if bool(digit_result.get("solved", false)):
			diagnostics["solved_digit_count"] = int(diagnostics.get("solved_digit_count", 0)) + 1
		else:
			diagnostics["degraded_digit_count"] = int(diagnostics.get("degraded_digit_count", 0)) + 1
		diagnostics["max_contact_error_meters"] = maxf(
			float(diagnostics.get("max_contact_error_meters", 0.0)),
			float(digit_diagnostics.get("max_contact_error_meters", 0.0))
		)
		diagnostics["max_penetration_meters"] = maxf(
			float(diagnostics.get("max_penetration_meters", 0.0)),
			float(digit_diagnostics.get("max_penetration_meters", 0.0))
		)
	diagnostics["digit_results"] = digit_results
	diagnostics["overlap_limit_respected"] = int(
		diagnostics.get("unsafe_digit_count", 0)
	) == 0
	diagnostics["ray_count"] = int(ray_stats.get("ray_count", 0))
	diagnostics["ray_bvh_node_test_count"] = int(ray_stats.get("bvh_node_test_count", 0))
	diagnostics["ray_triangle_test_count"] = int(ray_stats.get("triangle_test_count", 0))
	diagnostics["capsule_surface_query_count"] = int(ray_stats.get(
		"surface_query_count",
		0
	))
	diagnostics["capsule_surface_bvh_node_test_count"] = int(ray_stats.get(
		"surface_query_bvh_node_test_count",
		0
	))
	diagnostics["capsule_surface_triangle_test_count"] = int(ray_stats.get(
		"surface_query_triangle_test_count",
		0
	))
	diagnostics["capsule_surface_inside_ray_count"] = int(ray_stats.get(
		"inside_ray_count",
		0
	))
	var expected_rotation_count: int = digits.size() * 3
	result["rotations"] = rotations
	result["zero_rotations"] = zero_rotations
	result["valid"] = expected_rotation_count == 15 and rotations.size() == expected_rotation_count
	result["all_sections_contacted"] = int(diagnostics.get("contacted_section_count", 0)) == expected_rotation_count
	result["all_stages_accepted"] = int(diagnostics.get("accepted_section_count", 0)) == expected_rotation_count
	result["all_digits_solved"] = int(diagnostics.get("solved_digit_count", 0)) == digits.size()
	result["safe_to_apply"] = int(diagnostics.get("unsafe_digit_count", 0)) == 0
	if bool(result["all_digits_solved"]):
		diagnostics["status"] = &"solved"
	elif bool(result["safe_to_apply"]):
		diagnostics["status"] = &"degraded_safe_fallback"
	else:
		diagnostics["status"] = &"unsafe_no_verified_fallback"
	var calibration_revision: String = String(side_rules.get("calibration_revision", "unknown"))
	var context_signature: Variant = options.get("cache_context_signature", "")
	result["cache_key"] = "%s|%s|%s|%s|%s|%s" % [
		String(SOLVER_REVISION),
		String(slot_id),
		calibration_revision,
		String(result.get("surface_signature", "")),
		str(hash(baseline_digest)),
		str(hash(context_signature)),
	]
	return result


func _solve_digit(
	snapshot: Dictionary,
	surface: Dictionary,
	preferred_overlap: float,
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var digit_id: StringName = StringName(snapshot.get("digit_id", &"unknown"))
	var has_grip_center: bool = (
		options.has("fallback_ray_target_world")
		or options.has("grip_center_world")
		or (options.has("grip_span_start_world") and options.has("grip_span_end_world"))
	)
	var thumb_collinear_reset: Dictionary = {
		"attempted": false,
		"valid": false,
		"status": &"not_a_thumb",
	}
	if bool(snapshot.get("is_thumb", false)) and has_grip_center:
		thumb_collinear_reset = _build_exact_collinear_thumb_snapshot(snapshot)
		if bool(thumb_collinear_reset.get("valid", false)):
			snapshot = thumb_collinear_reset.get("snapshot", snapshot) as Dictionary
	elif bool(snapshot.get("is_thumb", false)):
		thumb_collinear_reset["status"] = &"missing_grip_center"
	var thumb_collinear_reset_diagnostic: Dictionary = thumb_collinear_reset.duplicate(true)
	thumb_collinear_reset_diagnostic.erase("snapshot")
	var diagnostic := {
		"digit_id": digit_id,
		"status": &"no_reachable_surface_safe_fallback",
		"contacted_section_count": 0,
		"ray_hit_section_count": 0,
		"expected_section_count": 3,
		"section_contacts": [],
		"joint_angles_rad": [0.0, 0.0, 0.0],
		"backsolve_pass_count": 0,
		"max_contact_error_meters": 0.0,
		"max_penetration_meters": 0.0,
		"overlap_limit_respected": true,
		"neutral_fallback_evaluated": false,
		"neutral_fallback_safe": true,
		"neutral_fallback_sections": [],
		"thumb_collinear_reset": thumb_collinear_reset_diagnostic,
	}
	var open_angles: Array[float] = _resolve_open_angles(snapshot)
	var closed_angles: Array[float] = _resolve_closed_angles(snapshot, open_angles)
	var solved_angles: Array[float] = open_angles.duplicate()
	var configured_targets: Array = snapshot.get(
		"section_target_overlaps_meters",
		[preferred_overlap, preferred_overlap, preferred_overlap]
	) as Array
	if (
		has_grip_center
		and bool(snapshot.get("is_thumb", false))
		and configured_targets.size() > 1
	):
		# The ordinary 0.5 mm cap remains the default for every finger section.
		# Thumb section 2 owns a larger authored target, so only this thumb digit's
		# serial target/cap calculations need the extra tolerance headroom.
		max_overlap = clampf(
			maxf(
				max_overlap,
				float(configured_targets[1]) + SECTION_TARGET_TOLERANCE_METERS
			),
			0.0,
			THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS
		)
	var section_targets: Array[float] = []
	for section_index: int in range(3):
		section_targets.append(clampf(
			float(configured_targets[section_index]) if section_index < configured_targets.size() else preferred_overlap,
			0.0,
			max_overlap
		))
	diagnostic["section_target_overlaps_meters"] = section_targets.duplicate()
	var section_target_bounds: Array[Dictionary] = []
	var section_max_allowed_overlaps: Array[float] = []
	for section_index: int in range(section_targets.size()):
		var section_target: float = section_targets[section_index]
		section_target_bounds.append(_resolve_section_target_overlap_bounds(
			section_target,
			max_overlap
		))
		section_max_allowed_overlaps.append(_resolve_serial_section_max_allowed_overlap(
			snapshot,
			section_index,
			section_target,
			max_overlap
		))
	diagnostic["section_target_overlap_tolerance_meters"] = SECTION_TARGET_TOLERANCE_METERS
	diagnostic["section_target_overlap_bounds_meters"] = section_target_bounds
	diagnostic["section_max_allowed_overlaps_meters"] = section_max_allowed_overlaps
	diagnostic["thumb_proximal_contact_target_required"] = (
		THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED
		if bool(snapshot.get("is_thumb", false))
		else true
	)
	var grip_center_world: Vector3 = _resolve_fallback_ray_target(options)
	if not has_grip_center:
		return _solve_digit_motion_sweep_fallback(
			snapshot,
			surface,
			preferred_overlap,
			max_overlap,
			options,
			ray_stats,
			diagnostic,
			open_angles,
			closed_angles
		)
	if not has_grip_center:
		return {
			"solved": false,
			"rotations": _build_output_rotations(snapshot, solved_angles),
			"zero_rotations": _build_output_zero_rotations(snapshot),
			"diagnostics": diagnostic,
		}
	var maximum_ray_distance: float = clampf(float(options.get(
		"max_fallback_ray_distance_meters",
		maxf(_resolve_digit_reach_meters(snapshot) * 0.75, 0.03)
	)), 0.005, 0.2)
	var thumb_clearance: Dictionary = {
		"attempted": false,
		"clearance_established": false,
		"status": &"not_a_thumb",
		"clearance_angles_rad": open_angles.duplicate(),
	}
	if (
		bool(snapshot.get("is_thumb", false))
		and bool(thumb_collinear_reset.get("valid", false))
	):
		thumb_clearance = _find_thumb_strict_clearance_pose(
			snapshot,
			surface,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			ray_stats
		)
		var clearance_angles: Array = thumb_clearance.get(
			"clearance_angles_rad",
			open_angles
		) as Array
		if clearance_angles.size() == 3:
			open_angles.clear()
			for clearance_angle_variant: Variant in clearance_angles:
				open_angles.append(float(clearance_angle_variant))
			_extend_thumb_root_angle_bound(snapshot, open_angles[0])
			closed_angles = _resolve_closed_angles(snapshot, open_angles)
			solved_angles = open_angles.duplicate()
	diagnostic["thumb_clearance"] = thumb_clearance.duplicate(true)
	if (
		bool(snapshot.get("is_thumb", false))
		and (
			not bool(thumb_collinear_reset.get("valid", false))
			or not bool(thumb_clearance.get("clearance_established", false))
		)
	):
		# Clearance is a gate, not a hint. If the authored open range cannot place
		# all three collinear thumb sections clear of the Handle, never seek back
		# through the shell. Publish the furthest tested open pose diagnostically.
		var clearance_evaluation: Dictionary = _evaluate_serial_pose_safety(
			snapshot,
			surface,
			open_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			DEFAULT_MAX_ACCEPTABLE_CONTACT_ERROR_METERS,
			ray_stats
		)
		diagnostic["status"] = &"thumb_clearance_gate_failed"
		diagnostic["joint_angles_rad"] = open_angles.duplicate()
		diagnostic["final_sections"] = (
			clearance_evaluation.get("section_states", []) as Array
		).duplicate(true)
		diagnostic["ray_hit_section_count"] = int(clearance_evaluation.get(
			"ray_hit_section_count",
			0
		))
		diagnostic["contacted_section_count"] = 0
		diagnostic["accepted_section_count"] = 0
		diagnostic["max_contact_error_meters"] = float(clearance_evaluation.get(
			"max_contact_error_meters",
			0.0
		))
		diagnostic["max_penetration_meters"] = float(clearance_evaluation.get(
			"max_penetration_meters",
			0.0
		))
		diagnostic["overlap_limit_respected"] = bool(clearance_evaluation.get(
			"overlap_limit_respected",
			false
		))
		return {
			"solved": false,
			"rotations": _build_output_rotations(snapshot, open_angles),
			"zero_rotations": _build_output_zero_rotations(snapshot),
			"diagnostics": diagnostic,
		}
	var radii: Array = snapshot.get("capsule_radii_m", [0.0, 0.0, 0.0]) as Array
	var stage_diagnostics: Array[Dictionary] = []
	var total_refinement_steps := 0
	var upstream_stage_accepted := true
	var all_serial_targets_reached := true
	var accepted_section_count := 0
	var constrained_serial_gap_accepted := false
	for joint_index: int in range(3):
		if not upstream_stage_accepted:
			var blocked_bounds: Dictionary = _resolve_section_target_overlap_bounds(
				section_targets[joint_index],
				max_overlap
			)
			stage_diagnostics.append({
				"section_index": joint_index,
				"status": &"blocked_by_upstream_target",
				"angle_rad": solved_angles[joint_index],
				"open_angle_rad": solved_angles[joint_index],
				"target_overlap_meters": section_targets[joint_index],
				"target_tolerance_meters": SECTION_TARGET_TOLERANCE_METERS,
				"target_lower_bound_meters": float(blocked_bounds.get("lower_meters", 0.0)),
				"target_upper_bound_meters": float(blocked_bounds.get("upper_meters", max_overlap)),
				"target_reached": false,
				"stage_accepted": false,
			})
			all_serial_targets_reached = false
			continue
		var thumb_proximal_contact_target_bypassed: bool = (
			bool(snapshot.get("is_thumb", false))
			and joint_index == 0
			and not THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED
		)
		var stage: Dictionary
		if thumb_proximal_contact_target_bypassed:
			stage = _try_accept_proximal_downstream_limit(
				snapshot,
				surface,
				solved_angles,
				joint_index,
				closed_angles[joint_index],
				grip_center_world,
				maximum_ray_distance,
				section_targets,
				max_overlap,
				options,
				ray_stats
			)
		else:
			stage = _solve_serial_hinge_contact_stage(
				snapshot,
				surface,
				solved_angles,
				joint_index,
				closed_angles[joint_index],
				maxf(float(radii[joint_index]), 0.0),
				grip_center_world,
				maximum_ray_distance,
				section_targets[joint_index],
				section_targets,
				max_overlap,
				options,
				ray_stats
			)
		if (
			not thumb_proximal_contact_target_bypassed
			and not bool(stage.get("stage_accepted", false))
			and joint_index == 0
		):
			var constrained_proximal_stage: Dictionary = (
				_try_accept_proximal_downstream_limit(
					snapshot,
					surface,
					solved_angles,
					joint_index,
					closed_angles[joint_index],
					grip_center_world,
					maximum_ray_distance,
					section_targets,
					max_overlap,
					options,
					ray_stats
				)
			)
			if bool(constrained_proximal_stage.get("stage_accepted", false)):
				stage = constrained_proximal_stage
		if not bool(stage.get("stage_accepted", false)) and joint_index == 1:
			var constrained_stage: Dictionary = _try_accept_collinear_middle_downstream_limit(
				snapshot,
				surface,
				solved_angles,
				joint_index,
				closed_angles[joint_index],
				grip_center_world,
				maximum_ray_distance,
				section_targets,
				max_overlap,
				options,
				ray_stats
			)
			if bool(constrained_stage.get("stage_accepted", false)):
				stage = constrained_stage
		stage_diagnostics.append(stage.get("diagnostics", {}) as Dictionary)
		total_refinement_steps += int(stage.get("refinement_step_count", 0))
		var stage_accepted: bool = bool(stage.get(
			"stage_accepted",
			stage.get("target_reached", false)
		))
		if stage_accepted:
			solved_angles[joint_index] = float(stage.get("angle_rad", solved_angles[joint_index]))
			accepted_section_count += 1
			if not bool(stage.get("target_reached", false)):
				all_serial_targets_reached = false
				constrained_serial_gap_accepted = true
		else:
			# Serial means serial: a distal hinge cannot compensate for an upstream
			# phalanx unless a verified downstream-limit boundary accepted that stage
			# without pretending the upstream section made surface contact.
			upstream_stage_accepted = false
			all_serial_targets_reached = false
	var acceptable_error: float = clampf(float(options.get(
		"max_acceptable_contact_error_meters",
		DEFAULT_MAX_ACCEPTABLE_CONTACT_ERROR_METERS
	)), 0.0001, 0.005)
	var serial_acquired_angles: Array[float] = solved_angles.duplicate()
	var serial_acquisition_evaluation: Dictionary = _evaluate_serial_pose_safety(
		snapshot,
		surface,
		serial_acquired_angles,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		acceptable_error,
		ray_stats
	)
	diagnostic["serial_acquired_joint_angles_rad"] = serial_acquired_angles.duplicate()
	diagnostic["serial_acquired_sections"] = (
		serial_acquisition_evaluation.get("section_states", []) as Array
	).duplicate(true)
	diagnostic["accepted_section_count"] = accepted_section_count
	diagnostic["constrained_serial_gap_accepted"] = constrained_serial_gap_accepted
	diagnostic["serial_acquisition_all_stages_accepted"] = (
		upstream_stage_accepted
		and accepted_section_count == 3
		and bool(serial_acquisition_evaluation.get("overlap_limit_respected", false))
	)
	diagnostic["serial_acquisition_all_targets_reached"] = (
		all_serial_targets_reached
		and int(serial_acquisition_evaluation.get("feasible_section_count", 0)) == 3
		and bool(serial_acquisition_evaluation.get("overlap_limit_respected", false))
	)
	var final_reaccommodation: Dictionary = {
		"attempted": false,
		"accepted": false,
		"status": &"serial_acquisition_incomplete",
		"serial_acquired_angles_rad": serial_acquired_angles.duplicate(),
		"post_unlock_angles_rad": serial_acquired_angles.duplicate(),
		"post_unlock_sections": (
			serial_acquisition_evaluation.get("section_states", []) as Array
		).duplicate(true),
	}
	if bool(diagnostic["serial_acquisition_all_targets_reached"]):
		final_reaccommodation = _solve_final_serial_reaccommodation(
			snapshot,
			surface,
			serial_acquired_angles,
			open_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			acceptable_error,
			options,
			ray_stats
		)
		var post_unlock_angles: Array[float] = []
		for angle_variant: Variant in final_reaccommodation.get(
			"post_unlock_angles_rad",
			serial_acquired_angles
		):
			post_unlock_angles.append(float(angle_variant))
		if post_unlock_angles.size() == 3:
			solved_angles = post_unlock_angles
	diagnostic["final_reaccommodation"] = final_reaccommodation
	diagnostic["post_unlock_joint_angles_rad"] = solved_angles.duplicate()
	diagnostic["post_unlock_sections"] = (
		final_reaccommodation.get(
			"post_unlock_sections",
			serial_acquisition_evaluation.get("section_states", [])
		) as Array
	).duplicate(true)
	# Re-query the shell from the final serial pose. These are the applied-pose
	# metrics; discarded candidates never leak into the hard-cap diagnostic.
	var applied_evaluation: Dictionary = _evaluate_serial_pose_safety(
		snapshot,
		surface,
		solved_angles,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		acceptable_error,
		ray_stats
	)
	var final_sections: Array[Dictionary] = []
	for state_variant: Variant in applied_evaluation.get("section_states", []):
		final_sections.append(state_variant as Dictionary)
	var ray_hit_section_count: int = int(applied_evaluation.get("ray_hit_section_count", 0))
	var feasible_section_count: int = int(applied_evaluation.get("feasible_section_count", 0))
	var max_contact_error: float = float(applied_evaluation.get("max_contact_error_meters", 0.0))
	var max_penetration: float = float(applied_evaluation.get("max_penetration_meters", 0.0))
	var overlap_limit_respected: bool = bool(applied_evaluation.get("overlap_limit_respected", false))
	var unsafe_attempt_rejected := not overlap_limit_respected
	var attempted_max_penetration: float = max_penetration
	var attempted_max_contact_error: float = max_contact_error
	var attempted_final_sections: Array[Dictionary] = final_sections.duplicate(true)
	if unsafe_attempt_rejected:
		# A digit is transactional: never mix two safe hinge stops with one unsafe
		# downstream section. Re-query the captured neutral pose instead of assuming
		# it is safe: a broad handle can already contain an open phalanx.
		solved_angles = open_angles.duplicate()
		var neutral_evaluation: Dictionary = _evaluate_serial_pose_safety(
			snapshot,
			surface,
			solved_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			acceptable_error,
			ray_stats
		)
		final_sections.clear()
		for state_variant: Variant in neutral_evaluation.get("section_states", []):
			final_sections.append(state_variant as Dictionary)
		ray_hit_section_count = int(neutral_evaluation.get("ray_hit_section_count", 0))
		feasible_section_count = int(neutral_evaluation.get("feasible_section_count", 0))
		max_contact_error = float(neutral_evaluation.get("max_contact_error_meters", 0.0))
		max_penetration = float(neutral_evaluation.get("max_penetration_meters", 0.0))
		overlap_limit_respected = bool(neutral_evaluation.get("overlap_limit_respected", false))
		diagnostic["neutral_fallback_evaluated"] = true
		diagnostic["neutral_fallback_safe"] = overlap_limit_respected
		diagnostic["neutral_fallback_sections"] = final_sections.duplicate(true)
	diagnostic["section_contacts"] = stage_diagnostics
	diagnostic["ray_hit_section_count"] = ray_hit_section_count
	diagnostic["contacted_section_count"] = feasible_section_count
	diagnostic["max_acceptable_contact_error_meters"] = acceptable_error
	diagnostic["contact_error_feasible"] = max_contact_error <= acceptable_error
	diagnostic["joint_angles_rad"] = solved_angles
	diagnostic["backsolve_pass_count"] = total_refinement_steps
	diagnostic["max_contact_error_meters"] = max_contact_error
	diagnostic["max_penetration_meters"] = max_penetration
	diagnostic["overlap_limit_respected"] = overlap_limit_respected
	diagnostic["final_sections"] = final_sections
	diagnostic["unsafe_attempt_rejected"] = unsafe_attempt_rejected
	diagnostic["attempted_max_penetration_meters"] = attempted_max_penetration
	diagnostic["attempted_max_contact_error_meters"] = attempted_max_contact_error
	diagnostic["attempted_final_sections"] = attempted_final_sections
	diagnostic["applied_surface_contact"] = overlap_limit_respected and feasible_section_count > 0
	var changed_from_open := false
	for joint_index: int in range(3):
		if absf(solved_angles[joint_index] - open_angles[joint_index]) > ANGLE_EPSILON:
			changed_from_open = true
			break
	var solved: bool = not unsafe_attempt_rejected and overlap_limit_respected and feasible_section_count == 3
	if unsafe_attempt_rejected:
		diagnostic["status"] = (
			&"unsafe_attempt_neutral_fallback"
			if overlap_limit_respected
			else &"unsafe_attempt_unsafe_neutral_fallback"
		)
	elif solved:
		diagnostic["status"] = &"solved"
	elif (
		constrained_serial_gap_accepted
		and bool(diagnostic.get("serial_acquisition_all_stages_accepted", false))
		and overlap_limit_respected
	):
		diagnostic["status"] = &"constrained_safe_grip"
	elif overlap_limit_respected and changed_from_open:
		diagnostic["status"] = &"partial_surface_contact"
	else:
		diagnostic["status"] = &"no_reachable_surface_safe_fallback"
	return {
		"solved": solved,
		"rotations": _build_output_rotations(snapshot, solved_angles),
		"zero_rotations": _build_output_zero_rotations(snapshot),
		"diagnostics": diagnostic,
	}


func _solve_digit_motion_sweep_fallback(
	snapshot: Dictionary,
	surface: Dictionary,
	preferred_overlap: float,
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary,
	diagnostic: Dictionary,
	open_angles: Array[float],
	closed_angles: Array[float]
) -> Dictionary:
	var contact_resolution: Dictionary = _trace_digit_section_contacts(
		snapshot,
		surface,
		open_angles,
		closed_angles,
		preferred_overlap,
		options,
		ray_stats
	)
	var contacts: Array[Dictionary] = []
	for contact_variant: Variant in contact_resolution.get("contacts", []):
		contacts.append(contact_variant as Dictionary)
	diagnostic["section_contacts"] = contact_resolution.get("diagnostics", [])
	diagnostic["ray_hit_section_count"] = contacts.size()
	if contacts.is_empty():
		return {
			"solved": false,
			"rotations": _build_output_rotations(snapshot, open_angles),
			"zero_rotations": _build_output_zero_rotations(snapshot),
			"diagnostics": diagnostic,
		}
	var seed_fraction: float = float(contact_resolution.get("seed_fraction", 0.0))
	var seed_angles: Array[float] = []
	for joint_index: int in range(3):
		seed_angles.append(lerpf(open_angles[joint_index], closed_angles[joint_index], seed_fraction))
	var solve_result: Dictionary = _backsolve_contact_targets(
		snapshot,
		contacts,
		seed_angles,
		open_angles,
		max_overlap,
		options
	)
	var solved_angles: Array[float] = []
	for angle_variant: Variant in solve_result.get("angles", open_angles):
		solved_angles.append(float(angle_variant))
	var final_evaluation: Dictionary = _evaluate_contact_solution(
		snapshot,
		solved_angles,
		contacts,
		max_overlap,
		options
	)
	var acceptable_error: float = clampf(float(options.get(
		"max_acceptable_contact_error_meters",
		DEFAULT_MAX_ACCEPTABLE_CONTACT_ERROR_METERS
	)), 0.0001, 0.005)
	var feasible_section_count := 0
	for section_variant: Variant in final_evaluation.get("section_results", []):
		var section_result: Dictionary = section_variant as Dictionary
		if (
			bool(section_result.get("within_overlap_limit", false))
			and float(section_result.get("contact_error_meters", INF)) <= acceptable_error
		):
			feasible_section_count += 1
	diagnostic["contacted_section_count"] = feasible_section_count
	diagnostic["max_acceptable_contact_error_meters"] = acceptable_error
	diagnostic["joint_angles_rad"] = solved_angles
	diagnostic["backsolve_pass_count"] = int(solve_result.get("pass_count", 0))
	diagnostic["max_contact_error_meters"] = float(final_evaluation.get("max_contact_error_meters", 0.0))
	diagnostic["max_penetration_meters"] = float(final_evaluation.get("max_penetration_meters", 0.0))
	diagnostic["overlap_limit_respected"] = bool(final_evaluation.get("overlap_limit_respected", false))
	diagnostic["final_sections"] = final_evaluation.get("section_results", [])
	var solved: bool = (
		bool(final_evaluation.get("overlap_limit_respected", false))
		and feasible_section_count == 3
	)
	diagnostic["status"] = &"solved" if solved else &"partial_surface_contact"
	return {
		"solved": solved,
		"rotations": _build_output_rotations(snapshot, solved_angles),
		"zero_rotations": _build_output_zero_rotations(snapshot),
		"diagnostics": diagnostic,
	}


func _solve_serial_hinge_contact_stage(
	snapshot: Dictionary,
	surface: Dictionary,
	locked_angles: Array[float],
	joint_index: int,
	closed_angle: float,
	radius: float,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	target_overlap: float,
	section_targets: Array[float],
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var start_angle: float = locked_angles[joint_index]
	var target_bounds: Dictionary = _resolve_section_target_overlap_bounds(
		target_overlap,
		max_overlap
	)
	var target_lower_bound: float = float(target_bounds.get("lower_meters", 0.0))
	var target_upper_bound: float = float(target_bounds.get("upper_meters", max_overlap))
	# A target equal to the hard penetration cap is solved a fraction below the
	# boundary. The requested value remains the contract; this guard prevents
	# floating-point/refinement noise from publishing 0.5001 mm as legal.
	var solve_overlap: float = minf(
		target_overlap,
		maxf(max_overlap - HARD_CAP_TARGET_GUARD_METERS, 0.0)
	)
	var sweep_steps: int = clampi(int(options.get("serial_hinge_sweep_steps", DEFAULT_SWEEP_STEPS)), 8, 64)
	var refinement_steps: int = clampi(int(options.get("serial_hinge_refinement_steps", 14)), 6, 24)
	var best_state: Dictionary = {}
	var best_angle := start_angle
	var best_error := INF
	var previous_fraction := 0.0
	var start_safety: Dictionary = _query_downstream_section_safety(
		snapshot,
		surface,
		locked_angles,
		joint_index,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		ray_stats
	)
	var start_section_states: Array = start_safety.get("section_states", []) as Array
	var start_pose_safe: bool = bool(start_safety.get("safe", false))
	var previous_state: Dictionary = (
		start_section_states[0] as Dictionary
		if not start_section_states.is_empty()
		else _query_serial_section_surface_state(
			snapshot,
			surface,
			locked_angles,
			joint_index,
			radius,
			grip_center_world,
			maximum_ray_distance,
			solve_overlap,
			target_upper_bound,
			ray_stats
		)
	)
	var best_endpoint_safety: Dictionary = start_safety
	if (
		_serial_surface_state_is_legal(previous_state, target_upper_bound)
		and bool(previous_state.get("in_contact", false))
	):
		best_state = previous_state
		best_error = float(previous_state.get("contact_error_meters", INF))
	if (
		start_pose_safe
		and _serial_surface_state_reaches_target(
			previous_state,
			target_overlap,
			max_overlap
		)
	):
		return {
			"has_safe_angle": true,
			"target_reached": true,
			"stage_accepted": true,
			"angle_rad": start_angle,
			"refinement_step_count": 0,
			"diagnostics": {
				"section_index": joint_index,
				"status": &"target_already_satisfied",
				"angle_rad": start_angle,
				"open_angle_rad": start_angle,
				"closed_angle_rad": closed_angle,
				"used_ray_backtrack": false,
				"refinement_step_count": 0,
				"target_overlap_meters": target_overlap,
				"solve_overlap_meters": solve_overlap,
				"target_tolerance_meters": SECTION_TARGET_TOLERANCE_METERS,
				"target_lower_bound_meters": target_lower_bound,
				"target_upper_bound_meters": target_upper_bound,
				"target_reached": true,
				"stage_accepted": true,
				"start_pose_safe": true,
				"downstream_endpoint_safe": true,
				"phase_path_safe": true,
				"start_safety": start_safety,
				"endpoint_safety": start_safety,
				"phase_path_safety": {
					"safe": true,
					"sample_count": 1,
					"tested_sample_count": 1,
				},
				"surface_state": previous_state,
			},
		}
	var crossing_low_fraction := -1.0
	var crossing_high_fraction := -1.0
	for sweep_index: int in range(1, sweep_steps + 1):
		var fraction: float = float(sweep_index) / float(sweep_steps)
		var sample_angles: Array[float] = locked_angles.duplicate()
		sample_angles[joint_index] = lerpf(start_angle, closed_angle, fraction)
		var sample_state: Dictionary = _query_serial_section_surface_state(
			snapshot,
			surface,
			sample_angles,
			joint_index,
			radius,
			grip_center_world,
			maximum_ray_distance,
			solve_overlap,
			max_overlap,
			ray_stats
		)
		if (
			_serial_surface_state_is_legal(sample_state, target_upper_bound)
			and bool(sample_state.get("in_contact", false))
		):
			var sample_error: float = float(sample_state.get("contact_error_meters", INF))
			var sample_endpoint_safety: Dictionary = _query_serial_stage_endpoint_safety(
				snapshot,
				surface,
				sample_angles,
				joint_index,
				grip_center_world,
				maximum_ray_distance,
				section_targets,
				max_overlap,
				options,
				ray_stats
			)
			if sample_error < best_error and bool(sample_endpoint_safety.get("safe", false)):
				best_error = sample_error
				best_angle = sample_angles[joint_index]
				best_state = sample_state
				best_endpoint_safety = sample_endpoint_safety
		if (
			bool(sample_state.get("ray_hit", false))
			and not bool(previous_state.get("inside_solid", false))
			and float(previous_state.get("signed_overlap_meters", -INF)) < solve_overlap
			and float(sample_state.get("signed_overlap_meters", -INF)) >= solve_overlap
		):
			crossing_low_fraction = previous_fraction
			crossing_high_fraction = fraction
			break
		previous_fraction = fraction
		previous_state = sample_state
	var used_backtrack := crossing_low_fraction >= 0.0
	var performed_refinements := 0
	if used_backtrack:
		for _refinement_index: int in range(refinement_steps):
			performed_refinements += 1
			var middle_fraction: float = (crossing_low_fraction + crossing_high_fraction) * 0.5
			var middle_angles: Array[float] = locked_angles.duplicate()
			middle_angles[joint_index] = lerpf(start_angle, closed_angle, middle_fraction)
			var middle_state: Dictionary = _query_serial_section_surface_state(
				snapshot,
				surface,
				middle_angles,
				joint_index,
				radius,
				grip_center_world,
				maximum_ray_distance,
				solve_overlap,
				max_overlap,
				ray_stats
			)
			if (
				bool(middle_state.get("ray_hit", false))
				and float(middle_state.get("signed_overlap_meters", -INF)) >= solve_overlap
			):
				crossing_high_fraction = middle_fraction
				var middle_endpoint_safety: Dictionary = _query_serial_stage_endpoint_safety(
					snapshot,
					surface,
					middle_angles,
					joint_index,
					grip_center_world,
					maximum_ray_distance,
					section_targets,
					max_overlap,
					options,
					ray_stats
				)
				if (
					_serial_surface_state_is_legal(middle_state, target_upper_bound)
					and bool(middle_endpoint_safety.get("safe", false))
				):
					best_state = middle_state
					best_angle = middle_angles[joint_index]
					best_error = float(middle_state.get("contact_error_meters", INF))
					best_endpoint_safety = middle_endpoint_safety
			else:
				crossing_low_fraction = middle_fraction
	var target_reached: bool = (
		not best_state.is_empty()
		and _serial_surface_state_reaches_target(best_state, target_overlap, max_overlap)
		and bool(best_endpoint_safety.get("safe", false))
	)
	var phase_path_safety: Dictionary = {}
	var phase_path_safe := true
	if target_reached:
		if bool(options.get("require_transient_path_safety", false)):
			var target_angles: Array[float] = locked_angles.duplicate()
			target_angles[joint_index] = best_angle
			phase_path_safety = _query_serial_phase_path_safety(
				snapshot,
				surface,
				locked_angles,
				target_angles,
				joint_index,
				grip_center_world,
				maximum_ray_distance,
				section_targets,
				max_overlap,
				options,
				ray_stats
			)
			phase_path_safe = bool(phase_path_safety.get("safe", false))
		else:
			phase_path_safety = {
				"safe": true,
				"skipped": true,
				"reason": &"direct_final_pose",
			}
		target_reached = phase_path_safe
	var stage_status: StringName = &"no_reachable_surface_contact"
	if not best_state.is_empty():
		if target_reached:
			stage_status = &"target_contact_stop"
		elif not phase_path_safety.is_empty():
			stage_status = &"unsafe_phase_path"
		else:
			stage_status = &"target_overlap_not_reached"
	return {
		"has_safe_angle": target_reached,
		"target_reached": target_reached,
		"stage_accepted": target_reached,
		"angle_rad": best_angle if target_reached else start_angle,
		"refinement_step_count": performed_refinements,
		"diagnostics": {
			"section_index": joint_index,
			"status": stage_status,
			"angle_rad": best_angle if target_reached else start_angle,
			"open_angle_rad": start_angle,
			"closed_angle_rad": closed_angle,
			"used_ray_backtrack": used_backtrack,
			"refinement_step_count": performed_refinements,
			"target_overlap_meters": target_overlap,
			"solve_overlap_meters": solve_overlap,
			"target_tolerance_meters": SECTION_TARGET_TOLERANCE_METERS,
			"target_lower_bound_meters": target_lower_bound,
			"target_upper_bound_meters": target_upper_bound,
			"target_reached": target_reached,
			"stage_accepted": target_reached,
			"start_pose_safe": start_pose_safe,
			"downstream_endpoint_safe": bool(best_endpoint_safety.get("safe", false)),
			"phase_path_safe": phase_path_safe,
			"start_safety": start_safety,
			"endpoint_safety": best_endpoint_safety,
			"phase_path_safety": phase_path_safety,
			"surface_state": best_state,
		},
	}


func _try_accept_proximal_downstream_limit(
	snapshot: Dictionary,
	surface: Dictionary,
	locked_angles: Array[float],
	joint_index: int,
	closed_angle: float,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var start_angle: float = locked_angles[joint_index] if joint_index < locked_angles.size() else 0.0
	var rejected := {
		"has_safe_angle": false,
		"target_reached": false,
		"stage_accepted": false,
		"angle_rad": start_angle,
		"refinement_step_count": 0,
		"diagnostics": {
			"section_index": joint_index,
			"status": &"proximal_downstream_policy_not_applicable",
			"target_reached": false,
			"stage_accepted": false,
			"angle_rad": start_angle,
			"open_angle_rad": start_angle,
			"closed_angle_rad": closed_angle,
		},
	}
	if joint_index != 0 or locked_angles.size() != 3 or section_targets.size() != 3:
		return rejected
	var thumb_proximal_contact_target_bypassed: bool = (
		not THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED
		and bool(snapshot.get("is_thumb", false))
	)
	var start_safety: Dictionary = _query_downstream_section_safety(
		snapshot,
		surface,
		locked_angles,
		0,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		ray_stats
	)
	if not bool(start_safety.get("safe", false)):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
			&"proximal_downstream_unsafe_start"
		)
		(rejected.get("diagnostics", {}) as Dictionary)["start_safety"] = start_safety
		return rejected
	var sweep_steps: int = clampi(int(options.get(
		"serial_hinge_sweep_steps",
		DEFAULT_SWEEP_STEPS
	)), 8, 64)
	var refinement_steps: int = clampi(int(options.get(
		"serial_hinge_refinement_steps",
		14
	)), 6, 24)
	var safe_low_fraction := 0.0
	var unsafe_high_fraction := -1.0
	var safe_low_safety: Dictionary = start_safety
	var unsafe_high_safety: Dictionary = {}
	var blocking_section_index := -1
	for sweep_index: int in range(1, sweep_steps + 1):
		var fraction: float = float(sweep_index) / float(sweep_steps)
		var sample_angles: Array[float] = locked_angles.duplicate()
		sample_angles[joint_index] = lerpf(start_angle, closed_angle, fraction)
		var sample_safety: Dictionary = _query_downstream_section_safety(
			snapshot,
			surface,
			sample_angles,
			0,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			ray_stats
		)
		if bool(sample_safety.get("safe", false)):
			safe_low_fraction = fraction
			safe_low_safety = sample_safety
			continue
		blocking_section_index = _resolve_downstream_limit_blocker(
			sample_safety,
			1,
			section_targets,
			max_overlap
		)
		if blocking_section_index < 0 and thumb_proximal_contact_target_bypassed:
			# Thumb section 1 is not a contact stop, but its enlarged 5 mm hard cap
			# remains an emergency boundary if sections 2/3 do not stop it first.
			blocking_section_index = _resolve_downstream_limit_blocker(
				sample_safety,
				0,
				section_targets,
				max_overlap
			)
		if blocking_section_index < 0:
			(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
				&"proximal_limit_preceded_downstream_limit"
			)
			(rejected.get("diagnostics", {}) as Dictionary)["unsafe_safety"] = sample_safety
			return rejected
		unsafe_high_fraction = fraction
		unsafe_high_safety = sample_safety
		break
	if unsafe_high_fraction < 0.0:
		if thumb_proximal_contact_target_bypassed:
			var accepted_angles: Array[float] = locked_angles.duplicate()
			accepted_angles[joint_index] = closed_angle
			var phase_path_safety: Dictionary = {
				"safe": true,
				"skipped": true,
				"reason": &"direct_final_pose",
			}
			if bool(options.get("require_transient_path_safety", false)):
				phase_path_safety = _query_serial_phase_path_safety(
					snapshot,
					surface,
					locked_angles,
					accepted_angles,
					0,
					grip_center_world,
					maximum_ray_distance,
					section_targets,
					max_overlap,
					options,
					ray_stats
				)
			if not bool(phase_path_safety.get("safe", false)):
				(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
					&"thumb_proximal_unsafe_phase_path"
				)
				(rejected.get("diagnostics", {}) as Dictionary)["phase_path_safety"] = (
					phase_path_safety
				)
				return rejected
			var accepted_states: Array = safe_low_safety.get("section_states", []) as Array
			var proximal_state: Dictionary = (
				accepted_states[0] as Dictionary
				if not accepted_states.is_empty()
				else {}
			)
			return {
				"has_safe_angle": true,
				"target_reached": false,
				"stage_accepted": true,
				"angle_rad": closed_angle,
				"refinement_step_count": 0,
				"diagnostics": {
					"section_index": joint_index,
					"status": &"thumb_proximal_angle_limit_downstream_safe",
					"angle_rad": closed_angle,
					"open_angle_rad": start_angle,
					"closed_angle_rad": closed_angle,
					"target_overlap_meters": section_targets[joint_index],
					"target_reached": false,
					"stage_accepted": true,
					"contact_target_bypassed": true,
					"max_allowed_overlap_meters": THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS,
					"downstream_endpoint_safe": true,
					"phase_path_safe": true,
					"endpoint_safety": safe_low_safety,
					"phase_path_safety": phase_path_safety,
					"surface_state": proximal_state,
				},
			}
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
			&"proximal_downstream_upper_limit_not_reached"
		)
		return rejected
	var performed_refinements := 0
	for _refinement_index: int in range(refinement_steps):
		performed_refinements += 1
		var middle_fraction: float = (safe_low_fraction + unsafe_high_fraction) * 0.5
		var middle_angles: Array[float] = locked_angles.duplicate()
		middle_angles[joint_index] = lerpf(start_angle, closed_angle, middle_fraction)
		var middle_safety: Dictionary = _query_downstream_section_safety(
			snapshot,
			surface,
			middle_angles,
			0,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			ray_stats
		)
		if bool(middle_safety.get("safe", false)):
			safe_low_fraction = middle_fraction
			safe_low_safety = middle_safety
			continue
		var middle_blocker: int = _resolve_downstream_limit_blocker(
			middle_safety,
			1,
			section_targets,
			max_overlap
		)
		if middle_blocker < 0 and thumb_proximal_contact_target_bypassed:
			middle_blocker = _resolve_downstream_limit_blocker(
				middle_safety,
				0,
				section_targets,
				max_overlap
			)
		if middle_blocker < 0:
			(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
				&"proximal_limit_during_downstream_refinement"
			)
			(rejected.get("diagnostics", {}) as Dictionary)["unsafe_safety"] = middle_safety
			return rejected
		blocking_section_index = middle_blocker
		unsafe_high_fraction = middle_fraction
		unsafe_high_safety = middle_safety
	var accepted_angles: Array[float] = locked_angles.duplicate()
	accepted_angles[joint_index] = lerpf(start_angle, closed_angle, safe_low_fraction)
	var accepted_safety: Dictionary = _query_downstream_section_safety(
		snapshot,
		surface,
		accepted_angles,
		0,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		ray_stats
	)
	if not bool(accepted_safety.get("safe", false)):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
			&"proximal_downstream_refined_endpoint_unsafe"
		)
		(rejected.get("diagnostics", {}) as Dictionary)["endpoint_safety"] = accepted_safety
		return rejected
	var safe_states: Array = accepted_safety.get("section_states", []) as Array
	var unsafe_states: Array = unsafe_high_safety.get("section_states", []) as Array
	if safe_states.size() != 3 or unsafe_states.size() != 3:
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
			&"proximal_downstream_missing_section_states"
		)
		return rejected
	var proximal_safe_state: Dictionary = safe_states[0] as Dictionary
	var blocker_safe_state: Dictionary = safe_states[blocking_section_index] as Dictionary
	var blocker_unsafe_state: Dictionary = unsafe_states[blocking_section_index] as Dictionary
	if (
		blocking_section_index != 0
		and not _serial_surface_state_reaches_target(
			blocker_safe_state,
			section_targets[blocking_section_index],
			max_overlap
		)
	):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
			&"proximal_downstream_safe_boundary_not_in_target_band"
		)
		(rejected.get("diagnostics", {}) as Dictionary)["blocked_by_section_index"] = (
			blocking_section_index
		)
		(rejected.get("diagnostics", {}) as Dictionary)["endpoint_safety"] = accepted_safety
		return rejected
	var phase_path_safety: Dictionary = {
		"safe": true,
		"skipped": true,
		"reason": &"direct_final_pose",
	}
	if bool(options.get("require_transient_path_safety", false)):
		phase_path_safety = _query_serial_phase_path_safety(
			snapshot,
			surface,
			locked_angles,
			accepted_angles,
			0,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			options,
			ray_stats
		)
	if not bool(phase_path_safety.get("safe", false)):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = (
			&"proximal_downstream_unsafe_phase_path"
		)
		(rejected.get("diagnostics", {}) as Dictionary)["phase_path_safety"] = phase_path_safety
		return rejected
	var accepted_angle: float = accepted_angles[joint_index]
	return {
		"has_safe_angle": true,
		"target_reached": false,
		"stage_accepted": true,
		"angle_rad": accepted_angle,
		"refinement_step_count": performed_refinements,
		"diagnostics": {
			"section_index": joint_index,
			"status": (
				&"accepted_thumb_proximal_downstream_upper_limit"
				if thumb_proximal_contact_target_bypassed
				else &"accepted_proximal_gap_downstream_upper_limit"
			),
			"angle_rad": accepted_angle,
			"open_angle_rad": start_angle,
			"closed_angle_rad": closed_angle,
			"target_overlap_meters": section_targets[joint_index],
			"target_reached": false,
			"stage_accepted": true,
			"accepted_safe_gap": float(proximal_safe_state.get(
				"signed_overlap_meters",
				-INF
			)) < 0.0,
			"contact_target_bypassed": thumb_proximal_contact_target_bypassed,
			"max_allowed_overlap_meters": (
				THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS
				if thumb_proximal_contact_target_bypassed
				else _resolve_section_max_allowed_overlap(
					section_targets[joint_index],
					max_overlap
				)
			),
			"surface_gap_meters": float(proximal_safe_state.get(
				"surface_gap_meters",
				0.0
			)),
			"blocked_by_section_index": blocking_section_index,
			"downstream_limit_penetration_meters": float(
				blocker_unsafe_state.get("penetration_meters", 0.0)
			),
			"downstream_safe_penetration_meters": float(
				blocker_safe_state.get("penetration_meters", 0.0)
			),
			"downstream_max_allowed_overlap_meters": (
				_resolve_serial_section_max_allowed_overlap(
					snapshot,
					blocking_section_index,
					section_targets[blocking_section_index],
					max_overlap
				)
			),
			"refinement_step_count": performed_refinements,
			"start_pose_safe": true,
			"downstream_endpoint_safe": true,
			"phase_path_safe": true,
			"start_safety": start_safety,
			"endpoint_safety": accepted_safety,
			"unsafe_boundary_safety": unsafe_high_safety,
			"phase_path_safety": phase_path_safety,
			"surface_state": proximal_safe_state,
		},
	}


func _try_accept_collinear_middle_downstream_limit(
	snapshot: Dictionary,
	surface: Dictionary,
	locked_angles: Array[float],
	joint_index: int,
	closed_angle: float,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var start_angle: float = locked_angles[joint_index] if joint_index < locked_angles.size() else 0.0
	var rejected := {
		"has_safe_angle": false,
		"target_reached": false,
		"stage_accepted": false,
		"angle_rad": start_angle,
		"refinement_step_count": 0,
		"diagnostics": {
			"section_index": joint_index,
			"status": &"constrained_middle_policy_not_applicable",
			"target_reached": false,
			"stage_accepted": false,
			"angle_rad": start_angle,
			"open_angle_rad": start_angle,
			"closed_angle_rad": closed_angle,
		},
	}
	if joint_index != 1 or locked_angles.size() != 3 or section_targets.size() != 3:
		return rejected
	var collinearity: Dictionary = _query_serial_section_collinearity(
		snapshot,
		locked_angles,
		1,
		2
	)
	var requires_geometric_collinearity := bool(snapshot.get("is_thumb", false))
	var authored_open_angles: Array[float] = _resolve_open_angles(snapshot)
	var distal_joint_locked_at_authored_open := (
		authored_open_angles.size() == 3
		and absf(
			float(locked_angles[2])
			- float(authored_open_angles[2])
		) <= ANGLE_EPSILON
	)
	var rejected_diagnostics: Dictionary = rejected.get("diagnostics", {}) as Dictionary
	rejected_diagnostics["collinearity"] = collinearity
	rejected_diagnostics["distal_alignment_policy"] = (
		&"thumb_geometric_collinearity"
		if requires_geometric_collinearity
		else &"finger_authored_open_joint_lock"
	)
	rejected_diagnostics["distal_joint_locked_at_authored_open"] = (
		distal_joint_locked_at_authored_open
	)
	rejected_diagnostics["distal_authored_open_angle_rad"] = (
		float(authored_open_angles[2])
		if authored_open_angles.size() == 3
		else 0.0
	)
	if (
		requires_geometric_collinearity
		and not bool(collinearity.get("within_tolerance", false))
	):
		rejected_diagnostics["status"] = &"distal_section_not_collinear"
		return rejected
	if not requires_geometric_collinearity and not distal_joint_locked_at_authored_open:
		rejected_diagnostics["status"] = &"distal_joint_not_locked_at_authored_open"
		return rejected
	var start_safety: Dictionary = _query_downstream_section_safety(
		snapshot,
		surface,
		locked_angles,
		1,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		ray_stats
	)
	if not bool(start_safety.get("safe", false)):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = &"constrained_middle_unsafe_start"
		(rejected.get("diagnostics", {}) as Dictionary)["start_safety"] = start_safety
		return rejected
	var sweep_steps: int = clampi(int(options.get(
		"serial_hinge_sweep_steps",
		DEFAULT_SWEEP_STEPS
	)), 8, 64)
	var refinement_steps: int = clampi(int(options.get(
		"serial_hinge_refinement_steps",
		14
	)), 6, 24)
	var safe_low_fraction := 0.0
	var unsafe_high_fraction := -1.0
	var safe_low_safety: Dictionary = start_safety
	var unsafe_high_safety: Dictionary = {}
	for sweep_index: int in range(1, sweep_steps + 1):
		var fraction: float = float(sweep_index) / float(sweep_steps)
		var sample_angles: Array[float] = locked_angles.duplicate()
		sample_angles[joint_index] = lerpf(start_angle, closed_angle, fraction)
		var sample_safety: Dictionary = _query_downstream_section_safety(
			snapshot,
			surface,
			sample_angles,
			1,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			ray_stats
		)
		if bool(sample_safety.get("safe", false)):
			safe_low_fraction = fraction
			safe_low_safety = sample_safety
			continue
		if _downstream_safety_exceeds_section_upper(
			sample_safety,
			2,
			section_targets,
			max_overlap
		):
			unsafe_high_fraction = fraction
			unsafe_high_safety = sample_safety
			break
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = &"middle_section_limit_preceded_distal_limit"
		(rejected.get("diagnostics", {}) as Dictionary)["unsafe_safety"] = sample_safety
		return rejected
	if unsafe_high_fraction < 0.0:
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = &"distal_upper_limit_not_reached"
		return rejected
	var performed_refinements := 0
	for _refinement_index: int in range(refinement_steps):
		performed_refinements += 1
		var middle_fraction: float = (safe_low_fraction + unsafe_high_fraction) * 0.5
		var middle_angles: Array[float] = locked_angles.duplicate()
		middle_angles[joint_index] = lerpf(start_angle, closed_angle, middle_fraction)
		var middle_safety: Dictionary = _query_downstream_section_safety(
			snapshot,
			surface,
			middle_angles,
			1,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			ray_stats
		)
		if bool(middle_safety.get("safe", false)):
			safe_low_fraction = middle_fraction
			safe_low_safety = middle_safety
		elif _downstream_safety_exceeds_section_upper(
			middle_safety,
			2,
			section_targets,
			max_overlap
		):
			unsafe_high_fraction = middle_fraction
			unsafe_high_safety = middle_safety
		else:
			(rejected.get("diagnostics", {}) as Dictionary)["status"] = &"non_distal_limit_during_refinement"
			return rejected
	var safe_states: Array = safe_low_safety.get("section_states", []) as Array
	var unsafe_states: Array = unsafe_high_safety.get("section_states", []) as Array
	if safe_states.size() != 2 or unsafe_states.size() != 2:
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = &"missing_middle_distal_states"
		return rejected
	var middle_safe_state: Dictionary = safe_states[0] as Dictionary
	var distal_safe_state: Dictionary = safe_states[1] as Dictionary
	var distal_unsafe_state: Dictionary = unsafe_states[1] as Dictionary
	var policy: Dictionary = _evaluate_constrained_middle_gap_policy(
		joint_index,
		float(collinearity.get("dot", -1.0)),
		requires_geometric_collinearity,
		distal_joint_locked_at_authored_open,
		middle_safe_state,
		distal_safe_state,
		distal_unsafe_state,
		section_targets,
		max_overlap
	)
	if not bool(policy.get("accepted", false)):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = policy.get(
			"status",
			&"constrained_middle_policy_rejected"
		)
		(rejected.get("diagnostics", {}) as Dictionary)["policy"] = policy
		return rejected
	var accepted_angles: Array[float] = locked_angles.duplicate()
	accepted_angles[joint_index] = lerpf(start_angle, closed_angle, safe_low_fraction)
	var phase_path_safety: Dictionary = {
		"safe": true,
		"skipped": true,
		"reason": &"direct_final_pose",
	}
	if bool(options.get("require_transient_path_safety", false)):
		phase_path_safety = _query_serial_phase_path_safety(
			snapshot,
			surface,
			locked_angles,
			accepted_angles,
			1,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			options,
			ray_stats
		)
	if not bool(phase_path_safety.get("safe", false)):
		(rejected.get("diagnostics", {}) as Dictionary)["status"] = &"constrained_middle_unsafe_phase_path"
		(rejected.get("diagnostics", {}) as Dictionary)["phase_path_safety"] = phase_path_safety
		return rejected
	var accepted_angle: float = accepted_angles[joint_index]
	return {
		"has_safe_angle": true,
		"target_reached": false,
		"stage_accepted": true,
		"angle_rad": accepted_angle,
		"refinement_step_count": performed_refinements,
		"diagnostics": {
			"section_index": joint_index,
			"status": &"accepted_middle_gap_downstream_upper_limit",
			"angle_rad": accepted_angle,
			"open_angle_rad": start_angle,
			"closed_angle_rad": closed_angle,
			"target_overlap_meters": section_targets[joint_index],
			"target_reached": false,
			"stage_accepted": true,
			"accepted_safe_gap": true,
			"surface_gap_meters": float(middle_safe_state.get("surface_gap_meters", 0.0)),
			"distal_alignment_policy": (
				&"thumb_geometric_collinearity"
				if requires_geometric_collinearity
				else &"finger_authored_open_joint_lock"
			),
			"distal_joint_locked_at_authored_open": (
				distal_joint_locked_at_authored_open
			),
			"collinear_dot": float(collinearity.get("dot", -1.0)),
			"collinearity": collinearity,
			"blocked_by_section_index": 2,
			"downstream_limit_penetration_meters": float(
				distal_unsafe_state.get("penetration_meters", 0.0)
			),
			"downstream_safe_penetration_meters": float(
				distal_safe_state.get("penetration_meters", 0.0)
			),
			"downstream_max_allowed_overlap_meters": _resolve_section_max_allowed_overlap(
				section_targets[2],
				max_overlap
			),
			"refinement_step_count": performed_refinements,
			"start_pose_safe": true,
			"downstream_endpoint_safe": true,
			"phase_path_safe": true,
			"start_safety": start_safety,
			"endpoint_safety": safe_low_safety,
			"unsafe_boundary_safety": unsafe_high_safety,
			"phase_path_safety": phase_path_safety,
			"surface_state": middle_safe_state,
			"policy": policy,
		},
	}


func _query_serial_section_collinearity(
	snapshot: Dictionary,
	angles: Array[float],
	first_section_index: int,
	second_section_index: int
) -> Dictionary:
	var fk: Dictionary = _forward_kinematics(snapshot, angles)
	var first_endpoints: Dictionary = _resolve_section_segment_endpoints(
		fk,
		first_section_index
	)
	var second_endpoints: Dictionary = _resolve_section_segment_endpoints(
		fk,
		second_section_index
	)
	if first_endpoints.is_empty() or second_endpoints.is_empty():
		return {"valid": false, "within_tolerance": false, "dot": -1.0}
	var first_direction: Vector3 = (
		(first_endpoints.get("end_world", Vector3.ZERO) as Vector3)
		- (first_endpoints.get("start_world", Vector3.ZERO) as Vector3)
	)
	var second_direction: Vector3 = (
		(second_endpoints.get("end_world", Vector3.ZERO) as Vector3)
		- (second_endpoints.get("start_world", Vector3.ZERO) as Vector3)
	)
	if (
		first_direction.length_squared() <= RAY_EPSILON * RAY_EPSILON
		or second_direction.length_squared() <= RAY_EPSILON * RAY_EPSILON
	):
		return {"valid": false, "within_tolerance": false, "dot": -1.0}
	var collinear_dot: float = clampf(
		first_direction.normalized().dot(second_direction.normalized()),
		-1.0,
		1.0
	)
	var angle_degrees: float = rad_to_deg(acos(collinear_dot))
	return {
		"valid": true,
		"within_tolerance": angle_degrees <= COLLINEAR_SECTION_MAX_ANGLE_DEGREES,
		"dot": collinear_dot,
		"angle_degrees": angle_degrees,
		"maximum_angle_degrees": COLLINEAR_SECTION_MAX_ANGLE_DEGREES,
	}


func _downstream_safety_exceeds_section_upper(
	safety: Dictionary,
	section_index: int,
	section_targets: Array[float],
	max_overlap: float
) -> bool:
	if section_index < 0 or section_index >= section_targets.size():
		return false
	var section_limit: float = _resolve_section_max_allowed_overlap(
		section_targets[section_index],
		max_overlap
	)
	for state_variant: Variant in safety.get("section_states", []):
		var state: Dictionary = state_variant as Dictionary
		if int(state.get("section_index", -1)) != section_index:
			continue
		section_limit = float(state.get(
			"section_max_allowed_overlap_meters",
			section_limit
		))
		if (
			not bool(state.get("surface_query_hit", false))
			or not bool(state.get("inside_classification_valid", false))
		):
			return false
		return (
			bool(state.get("inside_solid", false))
			or float(state.get("penetration_meters", 0.0))
				> section_limit + OVERLAP_NUMERIC_EPSILON_METERS
		)
	return false


func _resolve_downstream_limit_blocker(
	safety: Dictionary,
	first_section_index: int,
	section_targets: Array[float],
	max_overlap: float
) -> int:
	for section_index: int in range(maxi(first_section_index, 0), section_targets.size()):
		if _downstream_safety_exceeds_section_upper(
			safety,
			section_index,
			section_targets,
			max_overlap
		):
			return section_index
	return -1


func _evaluate_constrained_middle_gap_policy(
	joint_index: int,
	collinear_dot: float,
	requires_geometric_collinearity: bool,
	distal_joint_locked_at_authored_open: bool,
	middle_safe_state: Dictionary,
	distal_safe_state: Dictionary,
	distal_unsafe_state: Dictionary,
	section_targets: Array[float],
	max_overlap: float
) -> Dictionary:
	var result := {
		"accepted": false,
		"status": &"constrained_middle_policy_rejected",
		"joint_index": joint_index,
		"collinear_dot": collinear_dot,
		"distal_alignment_policy": (
			&"thumb_geometric_collinearity"
			if requires_geometric_collinearity
			else &"finger_authored_open_joint_lock"
		),
		"distal_joint_locked_at_authored_open": (
			distal_joint_locked_at_authored_open
		),
		"blocked_by_section_index": 2,
	}
	if joint_index != 1 or section_targets.size() != 3:
		result["status"] = &"wrong_middle_joint"
		return result
	if requires_geometric_collinearity:
		var minimum_collinear_dot: float = cos(
			deg_to_rad(COLLINEAR_SECTION_MAX_ANGLE_DEGREES)
		)
		if collinear_dot < minimum_collinear_dot:
			result["status"] = &"not_collinear"
			return result
	elif not distal_joint_locked_at_authored_open:
		result["status"] = &"distal_joint_not_locked_at_authored_open"
		return result
	var middle_limit: float = _resolve_section_max_allowed_overlap(
		section_targets[1],
		max_overlap
	)
	var distal_limit: float = _resolve_section_max_allowed_overlap(
		section_targets[2],
		max_overlap
	)
	var middle_penetration: float = float(middle_safe_state.get("penetration_meters", 0.0))
	var middle_is_safe_gap: bool = (
		not bool(middle_safe_state.get("inside_solid", false))
		and int(middle_safe_state.get("inside_solid_sample_count", 0)) == 0
		and not bool(middle_safe_state.get("in_contact", false))
		and bool(middle_safe_state.get("within_overlap_limit", true))
		and middle_penetration <= middle_limit + OVERLAP_NUMERIC_EPSILON_METERS
	)
	if not middle_is_safe_gap:
		result["status"] = &"middle_is_not_safe_gap"
		return result
	var distal_safe_penetration: float = float(distal_safe_state.get(
		"penetration_meters",
		INF
	))
	var distal_unsafe_penetration: float = float(distal_unsafe_state.get(
		"penetration_meters",
		0.0
	))
	var distal_safe: bool = (
		not bool(distal_safe_state.get("inside_solid", false))
		and int(distal_safe_state.get("inside_solid_sample_count", 0)) == 0
		and bool(distal_safe_state.get("within_overlap_limit", false))
		and distal_safe_penetration <= distal_limit + OVERLAP_NUMERIC_EPSILON_METERS
		and _serial_surface_state_reaches_target(
			distal_safe_state,
			section_targets[2],
			max_overlap
		)
	)
	if not distal_safe:
		result["status"] = &"distal_safe_boundary_not_in_target_band"
		return result
	var distal_crossed_upper: bool = (
		bool(distal_unsafe_state.get("inside_solid", false))
		or int(distal_unsafe_state.get("inside_solid_sample_count", 0)) > 0
		or distal_unsafe_penetration > distal_limit + OVERLAP_NUMERIC_EPSILON_METERS
		or not bool(distal_unsafe_state.get("within_overlap_limit", false))
	)
	if not distal_crossed_upper:
		result["status"] = &"distal_upper_not_crossed"
		return result
	result["accepted"] = true
	result["status"] = &"accepted_middle_gap_downstream_upper_limit"
	result["middle_surface_gap_meters"] = float(middle_safe_state.get(
		"surface_gap_meters",
		0.0
	))
	result["middle_max_allowed_overlap_meters"] = middle_limit
	result["distal_safe_penetration_meters"] = distal_safe_penetration
	result["distal_unsafe_penetration_meters"] = distal_unsafe_penetration
	result["distal_max_allowed_overlap_meters"] = distal_limit
	return result


func _query_serial_section_surface_state(
	snapshot: Dictionary,
	surface: Dictionary,
	angles: Array[float],
	section_index: int,
	radius: float,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	preferred_overlap: float,
	max_overlap: float,
	ray_stats: Dictionary
) -> Dictionary:
	var fk: Dictionary = _forward_kinematics(snapshot, angles)
	var endpoints: Dictionary = _resolve_section_segment_endpoints(fk, section_index)
	if endpoints.is_empty():
		return {
			"ray_hit": false,
			"surface_query_hit": false,
			"status": &"missing_section_segment",
			"section_index": section_index,
			"within_overlap_limit": false,
		}
	var bone_names: Array = snapshot.get("bone_names", []) as Array
	var resolved_world_origin_id: StringName = snapshot.get(
		"bone_root_origin_id",
		StringName()
	) as StringName
	var prepared_world_origin_id: StringName = surface.get(
		"resolved_world_origin_id",
		StringName()
	) as StringName
	var surface_source_origin_id: StringName = surface.get(
		"surface_source_origin_id",
		StringName()
	) as StringName
	if (
		bone_names.size() != 3
		or resolved_world_origin_id == StringName()
		or prepared_world_origin_id != resolved_world_origin_id
		or surface_source_origin_id == StringName()
	):
		return {
			"ray_hit": false,
			"surface_query_hit": false,
			"status": &"section_surface_origin_contract_invalid",
			"section_index": section_index,
			"resolved_world_origin_id": resolved_world_origin_id,
			"prepared_world_origin_id": prepared_world_origin_id,
			"surface_source_origin_id": surface_source_origin_id,
			"within_overlap_limit": false,
		}
	var start_source_index: int = clampi(section_index, 0, 2)
	var end_source_index: int = clampi(section_index + 1, 0, 2)
	var start_source_origin_id := StringName(bone_names[start_source_index])
	var end_source_origin_id := StringName(bone_names[end_source_index])
	var segment_start_world: Vector3 = endpoints.get(
		"start_world",
		Vector3.ZERO
	) as Vector3
	var segment_end_world: Vector3 = endpoints.get(
		"end_world",
		Vector3.ZERO
	) as Vector3
	var query_result: Dictionary = capsule_surface_query.query_prepared_surface(
		surface,
		segment_start_world,
		start_source_origin_id,
		segment_end_world,
		end_source_origin_id,
		radius,
		surface_source_origin_id,
		resolved_world_origin_id,
		{
			"classify_inside_solid": true,
			"surface_topology_state": surface.get(
				"capsule_surface_topology",
				{}
			),
		}
	)
	_accumulate_capsule_surface_query_counts(
		ray_stats,
		query_result.get("counts", {}) as Dictionary
	)
	if not bool(query_result.get("valid", false)):
		return {
			"ray_hit": false,
			"surface_query_hit": false,
			"status": query_result.get("status", &"surface_query_failed"),
			"section_index": section_index,
			"within_overlap_limit": false,
			"surface_query_result": query_result,
		}
	var signed_distance_valid: bool = bool(query_result.get(
		"signed_distance_valid",
		false
	))
	var axis_inside_solid: bool = bool(query_result.get(
		"segment_axis_inside_solid",
		false
	))
	var inside_or_unclassified: bool = axis_inside_solid or not signed_distance_valid
	var signed_overlap: float = float(query_result.get(
		"signed_overlap_meters",
		-INF
	))
	var penetration: float = float(query_result.get("penetration_meters", 0.0))
	var within_limit: bool = (
		signed_distance_valid
		and not axis_inside_solid
		and penetration <= max_overlap + OVERLAP_NUMERIC_EPSILON_METERS
	)
	var closest_axis_world: Vector3 = query_result.get(
		"closest_segment_point_world",
		segment_start_world
	) as Vector3
	var surface_to_axis_world: Vector3 = query_result.get(
		"surface_to_axis_direction_world",
		Vector3.UP
	) as Vector3
	if surface_to_axis_world.length_squared() <= RAY_EPSILON * RAY_EPSILON:
		surface_to_axis_world = Vector3.UP
	else:
		surface_to_axis_world = surface_to_axis_world.normalized()
	var axis_to_surface_world: Vector3 = -surface_to_axis_world
	var surface_state_status: StringName = &"surface_gap"
	if not signed_distance_valid:
		surface_state_status = &"inside_classification_invalid"
	elif axis_inside_solid:
		surface_state_status = &"inside_solid_unsafe"
	elif not within_limit:
		surface_state_status = &"capsule_penetration_unsafe"
	elif signed_overlap >= 0.0:
		surface_state_status = &"contact"
	return {
		"ray_hit": true,
		"surface_query_hit": true,
		"status": surface_state_status,
		"section_index": section_index,
		"sample_index": -1,
		"sample_count": 1,
		"ray_hit_sample_count": 1,
		"unsafe_sample_count": 0 if within_limit else 1,
		"inside_solid_sample_count": 1 if inside_or_unclassified else 0,
		"maximum_sample_penetration_meters": penetration,
		"section_segment_start_world": segment_start_world,
		"section_segment_start_world_origin_id": resolved_world_origin_id,
		"section_segment_start_source_origin_id": start_source_origin_id,
		"section_segment_end_world": segment_end_world,
		"section_segment_end_world_origin_id": resolved_world_origin_id,
		"section_segment_end_source_origin_id": end_source_origin_id,
		"probe_center_world": closest_axis_world,
		"probe_center_world_origin_id": resolved_world_origin_id,
		"skin_contact_world": closest_axis_world + axis_to_surface_world * radius,
		"skin_contact_world_origin_id": resolved_world_origin_id,
		"surface_hit_world": query_result.get(
			"closest_triangle_point_world",
			closest_axis_world
		),
		"surface_hit_world_origin_id": resolved_world_origin_id,
		"surface_normal_world": query_result.get(
			"contact_escape_normal_world",
			surface_to_axis_world
		),
		"surface_normal_world_origin_id": resolved_world_origin_id,
		"inward_ray_direction_world": axis_to_surface_world,
		"inward_ray_direction_world_origin_id": resolved_world_origin_id,
		"surface_distance_meters": float(query_result.get(
			"nearest_distance_meters",
			INF
		)),
		"maximum_ray_distance_meters": maximum_ray_distance,
		"capsule_radius_meters": radius,
		"signed_overlap_meters": signed_overlap,
		"penetration_meters": penetration,
		"surface_gap_meters": float(query_result.get("surface_gap_meters", INF)),
		"preferred_overlap_meters": preferred_overlap,
		"contact_error_meters": absf(signed_overlap - preferred_overlap),
		"within_overlap_limit": within_limit,
		"in_contact": signed_overlap >= 0.0 and within_limit,
		"inside_solid": inside_or_unclassified,
		"inside_classification_valid": signed_distance_valid,
		"triangle_index": int(query_result.get("closest_triangle_index", -1)),
		"surface_query_revision": query_result.get("query_revision", StringName()),
		"surface_query_counts": query_result.get("counts", {}),
		"surface_topology_status": query_result.get(
			"surface_topology_status",
			&"not_checked"
		),
	}


func _accumulate_capsule_surface_query_counts(
	stats: Dictionary,
	query_counts: Dictionary
) -> void:
	stats["surface_query_count"] = int(stats.get("surface_query_count", 0)) + 1
	var nearest_bvh_tests: int = int(query_counts.get("bvh_node_test_count", 0))
	var inside_bvh_tests: int = int(query_counts.get(
		"inside_ray_bvh_node_test_count",
		0
	))
	var nearest_triangle_tests: int = int(query_counts.get("triangle_test_count", 0))
	var inside_triangle_tests: int = int(query_counts.get(
		"inside_ray_triangle_test_count",
		0
	))
	var inside_ray_count: int = int(query_counts.get("inside_ray_count", 0))
	stats["surface_query_bvh_node_test_count"] = int(stats.get(
		"surface_query_bvh_node_test_count",
		0
	)) + nearest_bvh_tests + inside_bvh_tests
	stats["surface_query_triangle_test_count"] = int(stats.get(
		"surface_query_triangle_test_count",
		0
	)) + nearest_triangle_tests + inside_triangle_tests
	stats["inside_ray_count"] = int(stats.get("inside_ray_count", 0)) + inside_ray_count
	# Keep the established aggregate telemetry fields populated for diagnostics
	# that predate the exact capsule query.
	stats["ray_count"] = int(stats.get("ray_count", 0)) + inside_ray_count
	stats["bvh_node_test_count"] = int(stats.get(
		"bvh_node_test_count",
		0
	)) + nearest_bvh_tests + inside_bvh_tests
	stats["triangle_test_count"] = int(stats.get(
		"triangle_test_count",
		0
	)) + nearest_triangle_tests + inside_triangle_tests


func _query_capsule_sample_surface_state(
	surface: Dictionary,
	probe_world: Vector3,
	section_index: int,
	sample_index: int,
	radius: float,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	preferred_overlap: float,
	max_overlap: float,
	ray_stats: Dictionary
) -> Dictionary:
	var inward_vector: Vector3 = grip_center_world - probe_world
	if inward_vector.length_squared() <= RAY_EPSILON:
		return {
			"ray_hit": false,
			"status": &"probe_at_grip_center",
			"section_index": section_index,
			"sample_index": sample_index,
			"probe_center_world": probe_world,
			"inside_solid": true,
			"penetration_meters": radius,
			"within_overlap_limit": radius <= max_overlap,
		}
	var inward_direction: Vector3 = inward_vector.normalized()
	var bounded_distance: float = minf(inward_vector.length(), maximum_ray_distance)
	var hit: Dictionary = _trace_surface_segment(
		surface,
		probe_world,
		probe_world + inward_direction * bounded_distance,
		ray_stats
	)
	if hit.is_empty():
		var outward_probe_distance: float = minf(
			maximum_ray_distance,
			maxf(radius * 4.0, 0.03)
		)
		var outward_hit: Dictionary = _trace_surface_segment(
			surface,
			probe_world,
			probe_world - inward_direction * outward_probe_distance,
			ray_stats
		)
		var inside_solid: bool = (
			not outward_hit.is_empty()
			and bool(outward_hit.get("exited_surface", false))
		)
		var estimated_inside_penetration: float = (
			radius + float(outward_hit.get("distance_meters", 0.0))
			if inside_solid
			else 0.0
		)
		return {
			"ray_hit": false,
			"status": &"inside_solid_unsafe" if inside_solid else &"surface_out_of_reach",
			"section_index": section_index,
			"sample_index": sample_index,
			"probe_center_world": probe_world,
			"maximum_ray_distance_meters": maximum_ray_distance,
			"inside_solid": inside_solid,
			"outward_exit_hit": outward_hit,
			"penetration_meters": estimated_inside_penetration,
			"within_overlap_limit": not inside_solid,
		}
	var surface_distance: float = float(hit.get("distance_meters", INF))
	var signed_overlap: float = radius - surface_distance
	var penetration: float = maxf(signed_overlap, 0.0)
	var contact_error: float = absf(signed_overlap - preferred_overlap)
	var within_limit: bool = penetration <= max_overlap
	var hit_world: Vector3 = hit.get("position_world", Vector3.ZERO) as Vector3
	var normal_world: Vector3 = hit.get("normal_world", -inward_direction) as Vector3
	var skin_contact_world: Vector3 = probe_world + inward_direction * radius
	return {
		"ray_hit": true,
		"status": &"contact" if signed_overlap >= 0.0 else &"surface_gap",
		"section_index": section_index,
		"sample_index": sample_index,
		"probe_center_world": probe_world,
		"skin_contact_world": skin_contact_world,
		"surface_hit_world": hit_world,
		"surface_normal_world": normal_world,
		"inward_ray_direction_world": inward_direction,
		"surface_distance_meters": surface_distance,
		"capsule_radius_meters": radius,
		"signed_overlap_meters": signed_overlap,
		"penetration_meters": penetration,
		"surface_gap_meters": maxf(-signed_overlap, 0.0),
		"preferred_overlap_meters": preferred_overlap,
		"contact_error_meters": contact_error,
		"within_overlap_limit": within_limit,
		"in_contact": signed_overlap >= 0.0 and within_limit,
		"inside_solid": false,
		"triangle_index": int(hit.get("triangle_index", -1)),
	}


func _serial_surface_state_is_legal(state: Dictionary, max_overlap: float) -> bool:
	return (
		bool(state.get("ray_hit", false))
		and bool(state.get("within_overlap_limit", false))
		and not bool(state.get("inside_solid", false))
		and float(state.get("penetration_meters", INF))
			<= max_overlap
	)


func _resolve_section_target_overlap_bounds(
	target_overlap: float,
	max_overlap: float
) -> Dictionary:
	var clamped_target: float = clampf(target_overlap, 0.0, max_overlap)
	return {
		"target_meters": clamped_target,
		"tolerance_meters": SECTION_TARGET_TOLERANCE_METERS,
		"lower_meters": maxf(clamped_target - SECTION_TARGET_TOLERANCE_METERS, 0.0),
		"upper_meters": minf(clamped_target + SECTION_TARGET_TOLERANCE_METERS, max_overlap),
	}


func _resolve_section_max_allowed_overlap(
	target_overlap: float,
	max_overlap: float
) -> float:
	return float(_resolve_section_target_overlap_bounds(
		target_overlap,
		max_overlap
	).get("upper_meters", max_overlap))


func _resolve_serial_section_max_allowed_overlap(
	snapshot: Dictionary,
	section_index: int,
	target_overlap: float,
	max_overlap: float
) -> float:
	if (
		not THUMB_PROXIMAL_CONTACT_TARGET_REQUIRED
		and bool(snapshot.get("is_thumb", false))
		and section_index == 0
	):
		return THUMB_PROXIMAL_MAX_ALLOWED_OVERLAP_METERS
	return _resolve_section_max_allowed_overlap(target_overlap, max_overlap)


func _serial_surface_state_reaches_target(
	state: Dictionary,
	target_overlap: float,
	max_overlap: float
) -> bool:
	var target_bounds: Dictionary = _resolve_section_target_overlap_bounds(
		target_overlap,
		max_overlap
	)
	var signed_overlap: float = float(state.get("signed_overlap_meters", -INF))
	return (
		_serial_surface_state_is_legal(state, max_overlap)
		and bool(state.get("in_contact", false))
		and signed_overlap
			>= float(target_bounds.get("lower_meters", 0.0)) - OVERLAP_NUMERIC_EPSILON_METERS
		and signed_overlap
			<= float(target_bounds.get("upper_meters", max_overlap)) + OVERLAP_NUMERIC_EPSILON_METERS
	)


func _query_downstream_section_safety(
	snapshot: Dictionary,
	surface: Dictionary,
	angles: Array[float],
	first_section_index: int,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	ray_stats: Dictionary
) -> Dictionary:
	if first_section_index > 2:
		return {"safe": true, "section_states": []}
	var radii: Array = snapshot.get("capsule_radii_m", [0.0, 0.0, 0.0]) as Array
	var section_states: Array[Dictionary] = []
	var safe := true
	var maximum_penetration := 0.0
	for section_index: int in range(maxi(first_section_index, 0), 3):
		var section_target: float = (
			section_targets[section_index]
			if section_index < section_targets.size()
			else DEFAULT_PREFERRED_OVERLAP_METERS
		)
		var section_max_overlap: float = _resolve_serial_section_max_allowed_overlap(
			snapshot,
			section_index,
			section_target,
			max_overlap
		)
		var state: Dictionary = _query_serial_section_surface_state(
			snapshot,
			surface,
			angles,
			section_index,
			maxf(float(radii[section_index]), 0.0),
			grip_center_world,
			maximum_ray_distance,
			section_target,
			section_max_overlap,
			ray_stats
		)
		state["section_max_allowed_overlap_meters"] = section_max_overlap
		section_states.append(state)
		maximum_penetration = maxf(
			maximum_penetration,
			float(state.get("penetration_meters", 0.0))
		)
		if (
			not bool(state.get("within_overlap_limit", false))
			or float(state.get("penetration_meters", 0.0))
				> section_max_overlap + OVERLAP_NUMERIC_EPSILON_METERS
		):
			safe = false
	return {
		"safe": safe,
		"maximum_penetration_meters": maximum_penetration,
		"section_states": section_states,
	}


func _query_serial_stage_endpoint_safety(
	snapshot: Dictionary,
	surface: Dictionary,
	angles: Array[float],
	joint_index: int,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	# The direct solve skips transient animation-path checks, but it never skips
	# the endpoint hard cap. An unsolved rigid downstream section is the next
	# serial constraint: if it reaches its upper overlap first, the current hinge
	# must stop at that boundary and hand control to the following hinge.
	var _unused_options: Dictionary = options
	return _query_downstream_section_safety(
		snapshot,
		surface,
		angles,
		joint_index + 1,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		ray_stats
	)


func _query_serial_phase_path_safety(
	snapshot: Dictionary,
	surface: Dictionary,
	start_angles: Array[float],
	end_angles: Array[float],
	first_section_index: int,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var sample_count: int = clampi(int(options.get(
		"serial_phase_path_safety_samples",
		DEFAULT_PHASE_PATH_SAFETY_SAMPLES
	)), 8, 64)
	var maximum_penetration := 0.0
	for sample_index: int in range(sample_count + 1):
		var fraction: float = float(sample_index) / float(sample_count)
		var sample_angles: Array[float] = []
		for joint_index: int in range(3):
			sample_angles.append(lerpf(
				start_angles[joint_index],
				end_angles[joint_index],
				fraction
			))
		var sample_safety: Dictionary = _query_downstream_section_safety(
			snapshot,
			surface,
			sample_angles,
			first_section_index,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			ray_stats
		)
		maximum_penetration = maxf(
			maximum_penetration,
			float(sample_safety.get("maximum_penetration_meters", 0.0))
		)
		if not bool(sample_safety.get("safe", false)):
			return {
				"safe": false,
				"sample_count": sample_count + 1,
				"tested_sample_count": sample_index + 1,
				"unsafe_fraction": fraction,
				"maximum_penetration_meters": maximum_penetration,
				"unsafe_sample_safety": sample_safety,
			}
	return {
		"safe": true,
		"sample_count": sample_count + 1,
		"tested_sample_count": sample_count + 1,
		"unsafe_fraction": -1.0,
		"maximum_penetration_meters": maximum_penetration,
	}


func _solve_final_serial_reaccommodation(
	snapshot: Dictionary,
	surface: Dictionary,
	serial_acquired_angles: Array[float],
	open_angles: Array[float],
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	acceptable_error: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var acquired_evaluation: Dictionary = _evaluate_serial_pose_safety(
		snapshot,
		surface,
		serial_acquired_angles,
		grip_center_world,
		maximum_ray_distance,
		section_targets,
		max_overlap,
		acceptable_error,
		ray_stats
	)
	var diagnostic := {
		"attempted": true,
		"accepted": false,
		"status": &"serial_acquisition_not_band_safe",
		"serial_acquired_angles_rad": serial_acquired_angles.duplicate(),
		"serial_acquired_sections": (
			acquired_evaluation.get("section_states", []) as Array
		).duplicate(true),
		"post_unlock_angles_rad": serial_acquired_angles.duplicate(),
		"post_unlock_sections": (
			acquired_evaluation.get("section_states", []) as Array
		).duplicate(true),
		"target_tolerance_meters": SECTION_TARGET_TOLERANCE_METERS,
		"candidate_evaluation_count": 0,
		"completed_pass_count": 0,
		"angles_changed": false,
		"post_unlock_target_bands_respected": false,
		"post_unlock_overlap_limit_respected": bool(
			acquired_evaluation.get("overlap_limit_respected", false)
		),
	}
	if not _serial_evaluation_holds_all_target_bands(acquired_evaluation):
		return diagnostic
	if not bool(options.get("enable_final_serial_reaccommodation", true)):
		diagnostic["status"] = &"disabled"
		diagnostic["post_unlock_target_bands_respected"] = true
		return diagnostic
	var min_angles: Array = snapshot.get("min_angles_rad", []) as Array
	var max_angles: Array = snapshot.get("max_angles_rad", []) as Array
	var preferred_angles: Array = snapshot.get("preferred_angles_rad", []) as Array
	if min_angles.size() != 3 or max_angles.size() != 3 or preferred_angles.size() != 3:
		diagnostic["status"] = &"missing_authored_angle_bounds"
		diagnostic["post_unlock_target_bands_respected"] = true
		return diagnostic
	diagnostic["authored_min_angles_rad"] = min_angles.duplicate()
	diagnostic["authored_max_angles_rad"] = max_angles.duplicate()
	diagnostic["preferred_angles_rad"] = preferred_angles.duplicate()
	var pass_count: int = clampi(int(options.get(
		"final_reaccommodation_passes",
		DEFAULT_FINAL_REACCOMMODATION_PASSES
	)), 1, 7)
	var angle_sample_count: int = clampi(int(options.get(
		"final_reaccommodation_angle_samples",
		DEFAULT_FINAL_REACCOMMODATION_ANGLE_SAMPLES
	)), 5, 17)
	if angle_sample_count % 2 == 0:
		angle_sample_count += 1
	var best_angles: Array[float] = serial_acquired_angles.duplicate()
	var best_evaluation: Dictionary = acquired_evaluation
	var best_score: float = _score_final_reaccommodation_angles(snapshot, best_angles)
	var candidate_evaluation_count := 0
	var completed_pass_count := 0
	for pass_index: int in range(pass_count):
		completed_pass_count = pass_index + 1
		var radius_scale: float = pow(0.25, float(pass_index + 1))
		var joint_order: Array[int] = []
		if pass_index % 2 == 0:
			joint_order.append_array([0, 1, 2])
		else:
			joint_order.append_array([2, 1, 0])
		for joint_index: int in joint_order:
			var minimum_angle: float = float(min_angles[joint_index])
			var maximum_angle: float = float(max_angles[joint_index])
			var authored_span: float = maxf(maximum_angle - minimum_angle, ANGLE_EPSILON)
			var search_radius: float = authored_span * radius_scale
			var search_lower: float = maxf(minimum_angle, best_angles[joint_index] - search_radius)
			var search_upper: float = minf(maximum_angle, best_angles[joint_index] + search_radius)
			var angle_candidates: Array[float] = [best_angles[joint_index]]
			var preferred_angle: float = clampf(
				float(preferred_angles[joint_index]),
				minimum_angle,
				maximum_angle
			)
			if preferred_angle >= search_lower and preferred_angle <= search_upper:
				angle_candidates.append(preferred_angle)
			for sample_index: int in range(angle_sample_count):
				var fraction: float = float(sample_index) / float(angle_sample_count - 1)
				angle_candidates.append(lerpf(search_lower, search_upper, fraction))
			var joint_best_angles: Array[float] = best_angles
			var joint_best_evaluation: Dictionary = best_evaluation
			var joint_best_score: float = best_score
			for candidate_angle: float in angle_candidates:
				if absf(candidate_angle - best_angles[joint_index]) <= ANGLE_EPSILON:
					continue
				var candidate_angles: Array[float] = best_angles.duplicate()
				candidate_angles[joint_index] = clampf(
					candidate_angle,
					minimum_angle,
					maximum_angle
				)
				var candidate_evaluation: Dictionary = _evaluate_serial_pose_safety(
					snapshot,
					surface,
					candidate_angles,
					grip_center_world,
					maximum_ray_distance,
					section_targets,
					max_overlap,
					acceptable_error,
					ray_stats
				)
				candidate_evaluation_count += 1
				if not _serial_evaluation_holds_all_target_bands(candidate_evaluation):
					continue
				var candidate_score: float = _score_final_reaccommodation_angles(
					snapshot,
					candidate_angles
				)
				if candidate_score + 0.000000000001 < joint_best_score:
					joint_best_angles = candidate_angles
					joint_best_evaluation = candidate_evaluation
					joint_best_score = candidate_score
			best_angles = joint_best_angles
			best_evaluation = joint_best_evaluation
			best_score = joint_best_score
	var searched_candidate_angles: Array[float] = best_angles.duplicate()
	var candidate_unlock_path: Dictionary = {
		"safe": true,
		"skipped": true,
		"reason": &"direct_final_pose",
	}
	var candidate_presentation_path: Dictionary = candidate_unlock_path.duplicate(
		true
	)
	if bool(options.get("require_transient_path_safety", false)):
		candidate_unlock_path = _query_final_target_band_path_safety(
			snapshot,
			surface,
			serial_acquired_angles,
			best_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			acceptable_error,
			options,
			ray_stats
		)
		candidate_presentation_path = _query_serial_presentation_path_safety(
			snapshot,
			surface,
			open_angles,
			best_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			acceptable_error,
			options,
			ray_stats
		)
	var angles_changed: bool = _serial_angles_differ(best_angles, serial_acquired_angles)
	var candidate_paths_safe: bool = (
		bool(candidate_unlock_path.get("safe", false))
		and bool(candidate_presentation_path.get("safe", false))
	)
	if not candidate_paths_safe:
		best_angles = serial_acquired_angles.duplicate()
		best_evaluation = acquired_evaluation
	diagnostic["candidate_evaluation_count"] = candidate_evaluation_count
	diagnostic["completed_pass_count"] = completed_pass_count
	diagnostic["candidate_angles_rad"] = searched_candidate_angles
	diagnostic["candidate_unlock_path_safety"] = candidate_unlock_path
	diagnostic["candidate_presentation_path_safety"] = candidate_presentation_path
	diagnostic["post_unlock_angles_rad"] = best_angles.duplicate()
	diagnostic["post_unlock_sections"] = (
		best_evaluation.get("section_states", []) as Array
	).duplicate(true)
	diagnostic["post_unlock_target_bands_respected"] = (
		_serial_evaluation_holds_all_target_bands(best_evaluation)
	)
	diagnostic["post_unlock_overlap_limit_respected"] = bool(
		best_evaluation.get("overlap_limit_respected", false)
	)
	diagnostic["angles_changed"] = angles_changed and candidate_paths_safe
	diagnostic["accepted"] = angles_changed and candidate_paths_safe
	if not candidate_paths_safe:
		diagnostic["status"] = &"candidate_rejected_unsafe_path"
	elif angles_changed:
		diagnostic["status"] = &"accepted"
	else:
		diagnostic["status"] = &"no_improving_band_safe_candidate"
	return diagnostic


func _serial_evaluation_holds_all_target_bands(evaluation: Dictionary) -> bool:
	return (
		bool(evaluation.get("overlap_limit_respected", false))
		and int(evaluation.get("unsafe_section_count", 0)) == 0
		and int(evaluation.get("inside_solid_section_count", 0)) == 0
		and int(evaluation.get("feasible_section_count", 0)) == 3
	)


func _score_final_reaccommodation_angles(
	snapshot: Dictionary,
	angles: Array[float]
) -> float:
	var min_angles: Array = snapshot.get("min_angles_rad", []) as Array
	var max_angles: Array = snapshot.get("max_angles_rad", []) as Array
	var preferred_angles: Array = snapshot.get("preferred_angles_rad", []) as Array
	var score := 0.0
	for joint_index: int in range(3):
		var authored_span: float = maxf(
			float(max_angles[joint_index]) - float(min_angles[joint_index]),
			ANGLE_EPSILON
		)
		var normalized_delta: float = (
			angles[joint_index] - float(preferred_angles[joint_index])
		) / authored_span
		score += normalized_delta * normalized_delta
	return score


func _serial_angles_differ(first: Array[float], second: Array[float]) -> bool:
	for joint_index: int in range(3):
		if absf(first[joint_index] - second[joint_index]) > ANGLE_EPSILON:
			return true
	return false


func _query_final_target_band_path_safety(
	snapshot: Dictionary,
	surface: Dictionary,
	start_angles: Array[float],
	end_angles: Array[float],
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	acceptable_error: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var sample_count: int = clampi(int(options.get(
		"serial_phase_path_safety_samples",
		DEFAULT_PHASE_PATH_SAFETY_SAMPLES
	)), 8, 64)
	var maximum_penetration := 0.0
	for sample_index: int in range(sample_count + 1):
		var fraction: float = float(sample_index) / float(sample_count)
		var sample_angles: Array[float] = []
		for joint_index: int in range(3):
			sample_angles.append(lerpf(
				start_angles[joint_index],
				end_angles[joint_index],
				fraction
			))
		var evaluation: Dictionary = _evaluate_serial_pose_safety(
			snapshot,
			surface,
			sample_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			acceptable_error,
			ray_stats
		)
		maximum_penetration = maxf(
			maximum_penetration,
			float(evaluation.get("max_penetration_meters", 0.0))
		)
		if not _serial_evaluation_holds_all_target_bands(evaluation):
			return {
				"safe": false,
				"sample_count": sample_count + 1,
				"tested_sample_count": sample_index + 1,
				"unsafe_fraction": fraction,
				"maximum_penetration_meters": maximum_penetration,
				"unsafe_evaluation": evaluation,
			}
	return {
		"safe": true,
		"sample_count": sample_count + 1,
		"tested_sample_count": sample_count + 1,
		"unsafe_fraction": -1.0,
		"maximum_penetration_meters": maximum_penetration,
	}


func _query_serial_presentation_path_safety(
	snapshot: Dictionary,
	surface: Dictionary,
	open_angles: Array[float],
	final_angles: Array[float],
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	acceptable_error: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var phase_start: Array[float] = open_angles.duplicate()
	var phase_results: Array[Dictionary] = []
	for joint_index: int in range(3):
		var phase_end: Array[float] = phase_start.duplicate()
		phase_end[joint_index] = final_angles[joint_index]
		var path_safety: Dictionary = _query_serial_phase_path_safety(
			snapshot,
			surface,
			phase_start,
			phase_end,
			0,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			options,
			ray_stats
		)
		var endpoint_evaluation: Dictionary = _evaluate_serial_pose_safety(
			snapshot,
			surface,
			phase_end,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			acceptable_error,
			ray_stats
		)
		var acquired_prefix_safe := true
		var endpoint_states: Array = endpoint_evaluation.get("section_states", []) as Array
		for acquired_section_index: int in range(joint_index + 1):
			if (
				acquired_section_index >= endpoint_states.size()
				or not _serial_surface_state_reaches_target(
					endpoint_states[acquired_section_index] as Dictionary,
					section_targets[acquired_section_index],
					max_overlap
				)
			):
				acquired_prefix_safe = false
				break
		var phase_safe: bool = (
			bool(path_safety.get("safe", false))
			and bool(endpoint_evaluation.get("overlap_limit_respected", false))
			and acquired_prefix_safe
		)
		phase_results.append({
			"joint_index": joint_index,
			"safe": phase_safe,
			"path_safety": path_safety,
			"acquired_prefix_target_bands_respected": acquired_prefix_safe,
			"endpoint_evaluation": endpoint_evaluation,
		})
		if not phase_safe:
			return {
				"safe": false,
				"failed_phase_index": joint_index,
				"phases": phase_results,
			}
		phase_start = phase_end
	return {
		"safe": true,
		"failed_phase_index": -1,
		"phases": phase_results,
	}


func _evaluate_serial_pose_safety(
	snapshot: Dictionary,
	surface: Dictionary,
	angles: Array[float],
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	acceptable_error: float,
	ray_stats: Dictionary
) -> Dictionary:
	var radii: Array = snapshot.get("capsule_radii_m", [0.0, 0.0, 0.0]) as Array
	var section_states: Array[Dictionary] = []
	for section_index: int in range(3):
		var section_target: float = (
			section_targets[section_index]
			if section_index < section_targets.size()
			else DEFAULT_PREFERRED_OVERLAP_METERS
		)
		var section_max_overlap: float = _resolve_serial_section_max_allowed_overlap(
			snapshot,
			section_index,
			section_target,
			max_overlap
		)
		var section_state: Dictionary = _query_serial_section_surface_state(
			snapshot,
			surface,
			angles,
			section_index,
			maxf(float(radii[section_index]), 0.0),
			grip_center_world,
			maximum_ray_distance,
			section_target,
			section_max_overlap,
			ray_stats
		)
		section_state["section_max_allowed_overlap_meters"] = section_max_overlap
		section_states.append(section_state)
	var summary: Dictionary = _summarize_serial_section_states(
		section_states,
		section_targets,
		max_overlap,
		acceptable_error
	)
	summary["section_states"] = section_states
	return summary


func _summarize_serial_section_states(
	section_states: Array,
	section_targets: Array,
	max_overlap: float,
	acceptable_error: float
) -> Dictionary:
	var ray_hit_section_count := 0
	var feasible_section_count := 0
	var unsafe_section_count := 0
	var inside_solid_section_count := 0
	var max_contact_error := 0.0
	var max_penetration := 0.0
	var overlap_limit_respected := true
	for section_index: int in range(section_states.size()):
		var state: Dictionary = section_states[section_index] as Dictionary
		var penetration: float = maxf(float(state.get("penetration_meters", 0.0)), 0.0)
		max_penetration = maxf(max_penetration, penetration)
		var section_target: float = (
			float(section_targets[section_index])
			if section_index < section_targets.size()
			else DEFAULT_PREFERRED_OVERLAP_METERS
		)
		var section_max_overlap: float = float(state.get(
			"section_max_allowed_overlap_meters",
			_resolve_section_max_allowed_overlap(section_target, max_overlap)
		))
		state["section_max_allowed_overlap_meters"] = section_max_overlap
		var section_within_limit: bool = (
			bool(state.get("within_overlap_limit", false))
			and penetration <= section_max_overlap + OVERLAP_NUMERIC_EPSILON_METERS
		)
		if not section_within_limit:
			overlap_limit_respected = false
			unsafe_section_count += 1
		if int(state.get("inside_solid_sample_count", 0)) > 0 or bool(state.get("inside_solid", false)):
			inside_solid_section_count += 1
		if not bool(state.get("ray_hit", false)):
			continue
		ray_hit_section_count += 1
		var contact_error: float = float(state.get("contact_error_meters", INF))
		max_contact_error = maxf(max_contact_error, contact_error)
		if (
			section_within_limit
			and _serial_surface_state_reaches_target(state, section_target, max_overlap)
			and contact_error <= acceptable_error
		):
			feasible_section_count += 1
	return {
		"ray_hit_section_count": ray_hit_section_count,
		"feasible_section_count": feasible_section_count,
		"unsafe_section_count": unsafe_section_count,
		"inside_solid_section_count": inside_solid_section_count,
		"max_contact_error_meters": max_contact_error,
		"max_penetration_meters": max_penetration,
		"overlap_limit_respected": overlap_limit_respected,
	}


func _trace_digit_section_contacts(
	snapshot: Dictionary,
	surface: Dictionary,
	open_angles: Array[float],
	closed_angles: Array[float],
	preferred_overlap: float,
	options: Dictionary,
	ray_stats: Dictionary
) -> Dictionary:
	var contacts: Array[Dictionary] = []
	var contact_diagnostics: Array[Dictionary] = []
	var sweep_steps: int = clampi(int(options.get("sweep_steps", DEFAULT_SWEEP_STEPS)), 4, 64)
	var radii: Array = snapshot.get("capsule_radii_m", [0.0, 0.0, 0.0]) as Array
	var fallback_target: Vector3 = _resolve_fallback_ray_target(options)
	var maximum_fallback_ray_distance: float = clampf(float(options.get(
		"max_fallback_ray_distance_meters",
		maxf(_resolve_digit_reach_meters(snapshot) * 0.75, 0.03)
	)), 0.005, 0.2)
	var seed_fraction: float = 0.0
	for section_index: int in range(3):
		var previous_fk: Dictionary = _forward_kinematics(snapshot, open_angles)
		var previous_probe: Vector3 = (_resolve_section_probe_positions(previous_fk) as Array)[section_index]
		var section_hit: Dictionary = {}
		var section_fraction: float = 0.0
		for sweep_index: int in range(1, sweep_steps + 1):
			var fraction: float = float(sweep_index) / float(sweep_steps)
			var sweep_angles: Array[float] = []
			for joint_index: int in range(3):
				sweep_angles.append(lerpf(open_angles[joint_index], closed_angles[joint_index], fraction))
			var sweep_fk: Dictionary = _forward_kinematics(snapshot, sweep_angles)
			var probe_world: Vector3 = (_resolve_section_probe_positions(sweep_fk) as Array)[section_index]
			var hit: Dictionary = _trace_surface_segment(surface, previous_probe, probe_world, ray_stats)
			if not hit.is_empty():
				var local_fraction: float = float(hit.get("fraction", 0.0))
				section_fraction = (float(sweep_index - 1) + local_fraction) / float(sweep_steps)
				section_hit = hit
				break
			previous_probe = probe_world
		var fallback_rejected_as_remote := false
		if section_hit.is_empty() and fallback_target.length_squared() > RAY_EPSILON:
			var closed_fk: Dictionary = _forward_kinematics(snapshot, closed_angles)
			var closed_probe: Vector3 = (_resolve_section_probe_positions(closed_fk) as Array)[section_index]
			var fallback_vector: Vector3 = fallback_target - closed_probe
			var bounded_fallback_target: Vector3 = fallback_target
			if fallback_vector.length() > maximum_fallback_ray_distance:
				bounded_fallback_target = closed_probe + fallback_vector.normalized() * maximum_fallback_ray_distance
				fallback_rejected_as_remote = true
			section_hit = _trace_surface_segment(surface, closed_probe, bounded_fallback_target, ray_stats)
			section_fraction = 1.0
		if section_hit.is_empty():
			contact_diagnostics.append({
				"section_index": section_index,
				"status": &"remote_fallback_bounded" if fallback_rejected_as_remote else &"no_ray_hit",
				"max_fallback_ray_distance_meters": maximum_fallback_ray_distance,
			})
			continue
		seed_fraction = maxf(seed_fraction, section_fraction)
		var hit_position: Vector3 = section_hit.get("position_world", Vector3.ZERO) as Vector3
		var hit_normal: Vector3 = section_hit.get("normal_world", Vector3.ZERO) as Vector3
		if hit_normal.length_squared() <= RAY_EPSILON:
			contact_diagnostics.append({
				"section_index": section_index,
				"status": &"invalid_hit_normal",
			})
			continue
		hit_normal = hit_normal.normalized()
		var radius: float = maxf(float(radii[section_index]), 0.0)
		var target_center: Vector3 = hit_position + hit_normal * (radius - preferred_overlap)
		var contact := {
			"section_index": section_index,
			"surface_hit_world": hit_position,
			"surface_normal_world": hit_normal,
			"target_center_world": target_center,
			"capsule_radius_meters": radius,
			"preferred_overlap_meters": minf(preferred_overlap, radius),
			"sweep_fraction": section_fraction,
			"triangle_index": int(section_hit.get("triangle_index", -1)),
			"weight": float(options.get("section_%d_weight" % section_index, 1.0)),
		}
		contacts.append(contact)
		contact_diagnostics.append({
			"section_index": section_index,
			"status": &"ray_hit",
			"surface_hit_world": hit_position,
			"surface_normal_world": hit_normal,
			"target_center_world": target_center,
			"capsule_radius_meters": radius,
			"preferred_overlap_meters": minf(preferred_overlap, radius),
			"sweep_fraction": section_fraction,
			"triangle_index": int(section_hit.get("triangle_index", -1)),
		})
	return {
		"contacts": contacts,
		"diagnostics": contact_diagnostics,
		"seed_fraction": seed_fraction,
	}


func _backsolve_contact_targets(
	snapshot: Dictionary,
	contacts: Array[Dictionary],
	seed_angles: Array[float],
	open_angles: Array[float],
	max_overlap: float,
	options: Dictionary
) -> Dictionary:
	var angles: Array[float] = seed_angles.duplicate()
	var min_angles: Array = snapshot.get("min_angles_rad", []) as Array
	var max_angles: Array = snapshot.get("max_angles_rad", []) as Array
	var max_passes: int = clampi(int(options.get("backsolve_passes", DEFAULT_BACKSOLVE_PASSES)), 1, 24)
	var target_error: float = clampf(float(options.get("target_error_meters", DEFAULT_TARGET_ERROR_METERS)), 0.00005, 0.003)
	var previous_score: float = INF
	var completed_passes := 0
	for pass_index: int in range(max_passes):
		completed_passes = pass_index + 1
		for joint_order_variant: Variant in [[2, 1, 0], [0, 1, 2]]:
			var joint_order: Array = joint_order_variant as Array
			for joint_variant: Variant in joint_order:
				var joint_index: int = int(joint_variant)
				var fk: Dictionary = _forward_kinematics(snapshot, angles)
				var joint_world: Vector3 = (fk.get("joint_origins_world", []) as Array)[joint_index]
				var hinge_axis_world: Vector3 = (fk.get("hinge_axes_world", []) as Array)[joint_index]
				if hinge_axis_world.length_squared() <= RAY_EPSILON:
					continue
				hinge_axis_world = hinge_axis_world.normalized()
				var probe_positions: Array = _resolve_section_probe_positions(fk)
				var angle_candidates: Array[float] = [angles[joint_index]]
				for contact: Dictionary in contacts:
					var section_index: int = int(contact.get("section_index", -1))
					if section_index < joint_index or section_index >= probe_positions.size():
						continue
					var current_vector: Vector3 = (probe_positions[section_index] as Vector3) - joint_world
					var target_vector: Vector3 = (contact.get("target_center_world", joint_world) as Vector3) - joint_world
					current_vector -= hinge_axis_world * current_vector.dot(hinge_axis_world)
					target_vector -= hinge_axis_world * target_vector.dot(hinge_axis_world)
					if current_vector.length_squared() <= RAY_EPSILON or target_vector.length_squared() <= RAY_EPSILON:
						continue
					current_vector = current_vector.normalized()
					target_vector = target_vector.normalized()
					var delta: float = atan2(
						hinge_axis_world.dot(current_vector.cross(target_vector)),
						clampf(current_vector.dot(target_vector), -1.0, 1.0)
					)
					for line_scale: float in [1.0, 0.5, 0.25]:
						angle_candidates.append(clampf(
							angles[joint_index] + delta * line_scale,
							float(min_angles[joint_index]),
							float(max_angles[joint_index])
						))
				angle_candidates.append(float(min_angles[joint_index]))
				angle_candidates.append(float(max_angles[joint_index]))
				var best_angle: float = angles[joint_index]
				var best_score: float = _evaluate_contact_solution(
					snapshot,
					angles,
					contacts,
					max_overlap,
					options
				).get("score", INF)
				for candidate_angle: float in angle_candidates:
					var candidate_angles: Array[float] = angles.duplicate()
					candidate_angles[joint_index] = candidate_angle
					var candidate_score: float = float(_evaluate_contact_solution(
						snapshot,
						candidate_angles,
						contacts,
						max_overlap,
						options
					).get("score", INF))
					if candidate_score + 0.000000000001 < best_score:
						best_score = candidate_score
						best_angle = candidate_angle
				angles[joint_index] = best_angle
		var evaluation: Dictionary = _evaluate_contact_solution(snapshot, angles, contacts, max_overlap, options)
		var score: float = float(evaluation.get("score", INF))
		if float(evaluation.get("max_contact_error_meters", INF)) <= target_error and bool(evaluation.get("overlap_limit_respected", false)):
			break
		if previous_score < INF and previous_score - score <= 0.00000000001:
			break
		previous_score = score
	var legal_choice: Dictionary = _select_legal_solution(
		snapshot,
		contacts,
		angles,
		seed_angles,
		open_angles,
		max_overlap,
		options
	)
	return {
		"angles": legal_choice.get("angles", open_angles),
		"pass_count": completed_passes,
		"used_overlap_backtrack": bool(legal_choice.get("used_overlap_backtrack", false)),
	}


func _select_legal_solution(
	snapshot: Dictionary,
	contacts: Array[Dictionary],
	solved_angles: Array[float],
	seed_angles: Array[float],
	open_angles: Array[float],
	max_overlap: float,
	options: Dictionary
) -> Dictionary:
	var solved_evaluation: Dictionary = _evaluate_contact_solution(
		snapshot,
		solved_angles,
		contacts,
		max_overlap,
		options
	)
	if bool(solved_evaluation.get("overlap_limit_respected", false)):
		return {"angles": solved_angles, "used_overlap_backtrack": false}
	var best_angles: Array[float] = open_angles.duplicate()
	var best_score: float = INF
	var found_legal := false
	for start_angles: Array[float] in [seed_angles, open_angles]:
		for sample_index: int in range(33):
			var fraction: float = float(sample_index) / 32.0
			var candidate_angles: Array[float] = []
			for joint_index: int in range(3):
				candidate_angles.append(lerpf(start_angles[joint_index], solved_angles[joint_index], fraction))
			var evaluation: Dictionary = _evaluate_contact_solution(
				snapshot,
				candidate_angles,
				contacts,
				max_overlap,
				options
			)
			if not bool(evaluation.get("overlap_limit_respected", false)):
				continue
			var score: float = float(evaluation.get("score", INF))
			if score < best_score:
				best_score = score
				best_angles = candidate_angles
				found_legal = true
	return {
		"angles": best_angles,
		"used_overlap_backtrack": found_legal,
	}


func _evaluate_contact_solution(
	snapshot: Dictionary,
	angles: Array[float],
	contacts: Array[Dictionary],
	max_overlap: float,
	options: Dictionary
) -> Dictionary:
	var fk: Dictionary = _forward_kinematics(snapshot, angles)
	var probes: Array = _resolve_section_probe_positions(fk)
	var section_results: Array[Dictionary] = []
	var score := 0.0
	var max_error := 0.0
	var max_penetration := 0.0
	var overlap_limit_respected := true
	var overlap_slack: float = clampf(float(options.get(
		"overlap_numeric_slack_meters",
		OVERLAP_NUMERIC_EPSILON_METERS
	)), 0.0, 0.000001)
	for contact: Dictionary in contacts:
		var section_index: int = int(contact.get("section_index", -1))
		if section_index < 0 or section_index >= probes.size():
			continue
		var probe_world: Vector3 = probes[section_index]
		var target_world: Vector3 = contact.get("target_center_world", probe_world) as Vector3
		var normal_world: Vector3 = (contact.get("surface_normal_world", Vector3.UP) as Vector3).normalized()
		var hit_world: Vector3 = contact.get("surface_hit_world", target_world) as Vector3
		var radius: float = maxf(float(contact.get("capsule_radius_meters", 0.0)), 0.0)
		var skin_contact_world: Vector3 = probe_world - normal_world * radius
		var penetration: float = maxf((hit_world - skin_contact_world).dot(normal_world), 0.0)
		var error: float = probe_world.distance_to(target_world)
		var weight: float = maxf(float(contact.get("weight", 1.0)), 0.0)
		var overlap_excess: float = maxf(penetration - max_overlap, 0.0)
		score += error * error * weight + overlap_excess * overlap_excess * 10000.0
		max_error = maxf(max_error, error)
		max_penetration = maxf(max_penetration, penetration)
		if penetration > max_overlap + overlap_slack:
			overlap_limit_respected = false
		section_results.append({
			"section_index": section_index,
			"probe_center_world": probe_world,
			"skin_contact_world": skin_contact_world,
			"target_center_world": target_world,
			"contact_error_meters": error,
			"penetration_meters": penetration,
			"within_overlap_limit": penetration <= max_overlap + overlap_slack,
		})
	var preferred_angles: Array = snapshot.get("preferred_angles_rad", [0.0, 0.0, 0.0]) as Array
	var regularization_weight: float = maxf(float(options.get(
		"angle_regularization_weight",
		DEFAULT_ANGLE_REGULARIZATION_WEIGHT
	)), 0.0)
	for joint_index: int in range(3):
		var angle_delta: float = angles[joint_index] - float(preferred_angles[joint_index])
		score += angle_delta * angle_delta * regularization_weight
	return {
		"score": score,
		"max_contact_error_meters": max_error,
		"max_penetration_meters": max_penetration,
		"overlap_limit_respected": overlap_limit_respected,
		"section_results": section_results,
	}


func _capture_digit_snapshot(
	skeleton: Skeleton3D,
	digit_rules: Dictionary,
	supplied_base_pose_rotations: Dictionary = {}
) -> Dictionary:
	var bone_names: Array = digit_rules.get("bone_names", []) as Array
	if bone_names.size() != 3:
		return {"valid": false}
	var skeleton_world_transform: Transform3D = (
		skeleton.global_transform
		if skeleton.is_inside_tree()
		else skeleton.transform
	)
	var bone_indices: Array[int] = []
	var current_bone_world: Array[Transform3D] = []
	var current_pose_rotations: Array[Quaternion] = []
	var base_pose_rotations: Array[Quaternion] = []
	for bone_name_variant: Variant in bone_names:
		var bone_name: StringName = StringName(bone_name_variant)
		var bone_index: int = skeleton.find_bone(String(bone_name))
		if bone_index < 0:
			return {"valid": false, "missing_bone": bone_name}
		bone_indices.append(bone_index)
		var bone_global_skeleton: Transform3D = skeleton.get_bone_global_pose(bone_index)
		current_bone_world.append(skeleton_world_transform * bone_global_skeleton)
		var current_pose_rotation: Quaternion = skeleton.get_bone_pose_rotation(bone_index).normalized()
		current_pose_rotations.append(current_pose_rotation)
		var supplied_rotation_variant: Variant = supplied_base_pose_rotations.get(
			bone_name,
			supplied_base_pose_rotations.get(String(bone_name), current_pose_rotation)
		)
		var base_pose_rotation: Quaternion = current_pose_rotation
		if supplied_rotation_variant is Quaternion:
			base_pose_rotation = (supplied_rotation_variant as Quaternion).normalized()
		base_pose_rotations.append(base_pose_rotation)
	for child_index: int in range(1, 3):
		if skeleton.get_bone_parent(bone_indices[child_index]) != bone_indices[child_index - 1]:
			return {"valid": false, "status": &"non_serial_bone_chain"}
	var root_parent_index: int = skeleton.get_bone_parent(bone_indices[0])
	if root_parent_index < 0:
		return {"valid": false, "status": &"missing_root_parent"}
	var root_parent_world: Transform3D = skeleton_world_transform * skeleton.get_bone_global_pose(root_parent_index)
	var current_relative_transforms: Array[Transform3D] = []
	current_relative_transforms.append(root_parent_world.affine_inverse() * current_bone_world[0])
	current_relative_transforms.append(current_bone_world[0].affine_inverse() * current_bone_world[1])
	current_relative_transforms.append(current_bone_world[1].affine_inverse() * current_bone_world[2])
	var relative_transforms: Array[Transform3D] = []
	for joint_index: int in range(3):
		var neutral_relative: Transform3D = current_relative_transforms[joint_index]
		# Godot composes a bone's local pose rotation after its rest basis. Remove
		# the settled animation rotation and insert the caller's cached Idle-open
		# rotation entirely in local math; the live Skeleton3D is never advanced.
		var current_pose_rotation: Quaternion = current_pose_rotations[joint_index]
		var base_pose_rotation: Quaternion = base_pose_rotations[joint_index]
		var pose_delta: Quaternion = (
			current_pose_rotation.inverse() * base_pose_rotation
		).normalized()
		neutral_relative.basis = neutral_relative.basis * Basis(pose_delta)
		relative_transforms.append(neutral_relative)
	var base_bone_world: Array[Transform3D] = []
	var neutral_parent_world: Transform3D = root_parent_world
	for neutral_relative: Transform3D in relative_transforms:
		var neutral_bone_world: Transform3D = neutral_parent_world * neutral_relative
		base_bone_world.append(neutral_bone_world)
		neutral_parent_world = neutral_bone_world
	var tip_offset_local: Vector3 = digit_rules.get("tip_offset_local", Vector3.ZERO) as Vector3
	if tip_offset_local.length_squared() <= RAY_EPSILON:
		var terminal_length: float = float(digit_rules.get("terminal_length_m", 0.02))
		tip_offset_local = Vector3(0.0, maxf(terminal_length, 0.001), 0.0)
	return {
		"valid": true,
		"digit_id": StringName(digit_rules.get("digit_id", &"unknown")),
		"bone_names": bone_names.duplicate(),
		"bone_root_origin_id": digit_rules.get(
			"bone_root_origin_id",
			StringName()
		),
		"bone_indices": bone_indices,
		"base_pose_rotations": base_pose_rotations,
		"source_current_pose_rotations": current_pose_rotations,
		"base_bone_world": base_bone_world,
		"root_parent_world": root_parent_world,
		"relative_transforms": relative_transforms,
		"neutral_local_rotations": (digit_rules.get("neutral_local_rotations", [
			Quaternion.IDENTITY,
			Quaternion.IDENTITY,
			Quaternion.IDENTITY,
		]) as Array).duplicate(),
		"hinge_axes_local": (digit_rules.get("hinge_axes_local", [Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD]) as Array).duplicate(),
		"min_angles_rad": (digit_rules.get("min_angles_rad", [
			-deg_to_rad(DEFAULT_DIGIT_HINGE_LIMIT_DEGREES),
			-deg_to_rad(DEFAULT_DIGIT_HINGE_LIMIT_DEGREES),
			-deg_to_rad(DEFAULT_DIGIT_HINGE_LIMIT_DEGREES),
		]) as Array).duplicate(),
		"max_angles_rad": (digit_rules.get("max_angles_rad", [
			deg_to_rad(DEFAULT_DIGIT_HINGE_LIMIT_DEGREES),
			deg_to_rad(DEFAULT_DIGIT_HINGE_LIMIT_DEGREES),
			deg_to_rad(DEFAULT_DIGIT_HINGE_LIMIT_DEGREES),
		]) as Array).duplicate(),
		"preferred_angles_rad": (digit_rules.get("preferred_angles_rad", [0.0, 0.0, 0.0]) as Array).duplicate(),
		"capsule_radii_m": (digit_rules.get("capsule_radii_m", [0.006, 0.005, 0.004]) as Array).duplicate(),
		"section_target_overlaps_meters": (digit_rules.get(
			"section_target_overlaps_meters",
			[DEFAULT_PREFERRED_OVERLAP_METERS, DEFAULT_PREFERRED_OVERLAP_METERS, DEFAULT_PREFERRED_OVERLAP_METERS]
		) as Array).duplicate(),
		"is_thumb": bool(digit_rules.get("is_thumb", false)),
		"contact_strategy": StringName(digit_rules.get("contact_strategy", StringName())),
		"thumb_clearance_open_sign": float(digit_rules.get("thumb_clearance_open_sign", 0.0)),
		"thumb_clearance_step_degrees": float(digit_rules.get(
			"thumb_clearance_step_degrees",
			THUMB_CLEARANCE_DEFAULT_STEP_DEGREES
		)),
		"thumb_clearance_max_degrees": float(digit_rules.get(
			"thumb_clearance_max_degrees",
			THUMB_CLEARANCE_DEFAULT_MAX_DEGREES
		)),
		"tip_offset_local": tip_offset_local,
	}


func _build_exact_collinear_thumb_snapshot(source_snapshot: Dictionary) -> Dictionary:
	var result := {
		"attempted": true,
		"valid": false,
		"status": &"invalid_thumb_chain",
	}
	if not bool(source_snapshot.get("is_thumb", false)):
		result["status"] = &"not_a_thumb"
		return result
	var snapshot: Dictionary = source_snapshot.duplicate(true)
	var relative_transforms: Array = snapshot.get("relative_transforms", []) as Array
	var neutral_rotations: Array = (
		snapshot.get("neutral_local_rotations", []) as Array
	).duplicate()
	var base_pose_rotations: Array = snapshot.get("base_pose_rotations", []) as Array
	var source_hinge_axes: Array = snapshot.get("hinge_axes_local", []) as Array
	var tip_offset_local: Vector3 = snapshot.get("tip_offset_local", Vector3.ZERO) as Vector3
	if (
		relative_transforms.size() != 3
		or neutral_rotations.size() != 3
		or base_pose_rotations.size() != 3
		or source_hinge_axes.size() != 3
		or tip_offset_local.length_squared() <= RAY_EPSILON * RAY_EPSILON
	):
		return result
	for source_axis_variant: Variant in source_hinge_axes:
		var source_axis: Vector3 = source_axis_variant as Vector3
		if source_axis.length_squared() <= RAY_EPSILON * RAY_EPSILON:
			result["status"] = &"degenerate_thumb_hinge"
			return result

	# Josie's Thumb2/Thumb3 child offsets and the authored terminal offset are
	# already local +Y. The Idle animation adds X/Y swing to those two local pose
	# rotations, and a +Z hinge cannot remove that swing. Establish the requested
	# collinear zero frame by neutralizing only those animation pose rotations.
	# Runtime clearance and closure still use the untouched local +Z hinge rules.
	var thumb2_neutralization: Quaternion = (
		base_pose_rotations[1] as Quaternion
	).inverse().normalized()
	var thumb3_neutralization: Quaternion = (
		base_pose_rotations[2] as Quaternion
	).inverse().normalized()
	neutral_rotations[1] = thumb2_neutralization
	neutral_rotations[2] = thumb3_neutralization
	snapshot["neutral_local_rotations"] = neutral_rotations.duplicate()
	var thumb2_alignment := {
		"valid": true,
		"status": &"absolute_local_pose_zero_ready",
		"rotation": thumb2_neutralization,
		"angle_degrees": rad_to_deg(2.0 * acos(clampf(
			absf(thumb2_neutralization.w),
			0.0,
			1.0
		))),
	}
	var thumb3_alignment := {
		"valid": true,
		"status": &"absolute_local_pose_zero_ready",
		"rotation": thumb3_neutralization,
		"angle_degrees": rad_to_deg(2.0 * acos(clampf(
			absf(thumb3_neutralization.w),
			0.0,
			1.0
		))),
	}
	var zero_angles: Array[float] = [0.0, 0.0, 0.0]

	# Verify the three sections after the constrained local-hinge preload. The
	# authored hinge axes remain byte-for-byte unchanged in the solved snapshot.
	var aligned_fk: Dictionary = _forward_kinematics(snapshot, zero_angles)
	var aligned_transforms: Array = aligned_fk.get("joint_transforms_world", []) as Array
	var aligned_origins: Array = aligned_fk.get("joint_origins_world", []) as Array
	if aligned_transforms.size() != 3 or aligned_origins.size() != 3:
		result["status"] = &"invalid_thumb_aligned_fk"
		return result
	var verified_fk: Dictionary = _forward_kinematics(snapshot, zero_angles)
	var verified_origins: Array = verified_fk.get("joint_origins_world", []) as Array
	var verified_axes: Array = verified_fk.get("hinge_axes_world", []) as Array
	var verified_tip: Vector3 = verified_fk.get("tip_world", Vector3.ZERO) as Vector3
	if verified_origins.size() != 3 or verified_axes.size() != 3:
		result["status"] = &"invalid_thumb_verification_fk"
		return result
	var section_directions: Array[Vector3] = [
		((verified_origins[1] as Vector3) - (verified_origins[0] as Vector3)).normalized(),
		((verified_origins[2] as Vector3) - (verified_origins[1] as Vector3)).normalized(),
		(verified_tip - (verified_origins[2] as Vector3)).normalized(),
	]
	var collinearity_residual_degrees: Array[float] = [
		rad_to_deg(acos(clampf(section_directions[0].dot(section_directions[1]), -1.0, 1.0))),
		rad_to_deg(acos(clampf(section_directions[1].dot(section_directions[2]), -1.0, 1.0))),
	]
	var hinge_axis_local_z_residual_degrees: Array[float] = []
	for hinge_axis_variant: Variant in source_hinge_axes:
		var hinge_axis_local: Vector3 = hinge_axis_variant as Vector3
		hinge_axis_local_z_residual_degrees.append(rad_to_deg(acos(clampf(
			hinge_axis_local.normalized().dot(Vector3(0.0, 0.0, 1.0)),
			-1.0,
			1.0
		))))
	var valid_alignment: bool = (
		collinearity_residual_degrees[0] <= COLLINEAR_SECTION_MAX_ANGLE_DEGREES
		and collinearity_residual_degrees[1] <= COLLINEAR_SECTION_MAX_ANGLE_DEGREES
		and hinge_axis_local_z_residual_degrees[0] <= COLLINEAR_SECTION_MAX_ANGLE_DEGREES
		and hinge_axis_local_z_residual_degrees[1] <= COLLINEAR_SECTION_MAX_ANGLE_DEGREES
		and hinge_axis_local_z_residual_degrees[2] <= COLLINEAR_SECTION_MAX_ANGLE_DEGREES
	)
	result["valid"] = valid_alignment
	result["status"] = &"local_z_collinear_ready" if valid_alignment else &"local_z_collinear_verification_failed"
	result["snapshot"] = snapshot
	result["collinearity_residual_degrees"] = collinearity_residual_degrees
	result["hinge_axis_local_z_residual_degrees"] = hinge_axis_local_z_residual_degrees
	result["thumb2_straightening_angle_degrees"] = float(thumb2_alignment.get("angle_degrees", 0.0))
	result["thumb3_straightening_angle_degrees"] = float(thumb3_alignment.get("angle_degrees", 0.0))
	result["thumb2_alignment"] = thumb2_alignment
	result["thumb3_alignment"] = thumb3_alignment
	return result


func _resolve_single_hinge_alignment(
	from_direction_local: Vector3,
	to_direction_local: Vector3,
	hinge_axis_local: Vector3
) -> Dictionary:
	var axis: Vector3 = hinge_axis_local.normalized()
	var from_direction: Vector3 = from_direction_local.normalized()
	var to_direction: Vector3 = to_direction_local.normalized()
	if (
		axis.length_squared() <= RAY_EPSILON * RAY_EPSILON
		or from_direction.length_squared() <= RAY_EPSILON * RAY_EPSILON
		or to_direction.length_squared() <= RAY_EPSILON * RAY_EPSILON
	):
		return {"valid": false, "status": &"degenerate_alignment_input"}
	var from_planar: Vector3 = from_direction - axis * from_direction.dot(axis)
	var to_planar: Vector3 = to_direction - axis * to_direction.dot(axis)
	if (
		from_planar.length_squared() <= RAY_EPSILON * RAY_EPSILON
		or to_planar.length_squared() <= RAY_EPSILON * RAY_EPSILON
	):
		return {"valid": false, "status": &"direction_parallel_to_hinge"}
	from_planar = from_planar.normalized()
	to_planar = to_planar.normalized()
	var signed_angle: float = atan2(
		axis.dot(from_planar.cross(to_planar)),
		clampf(from_planar.dot(to_planar), -1.0, 1.0)
	)
	var rotation := Quaternion(axis, signed_angle).normalized()
	var rotated_direction: Vector3 = (Basis(rotation) * from_direction).normalized()
	var residual_degrees: float = rad_to_deg(acos(clampf(
		rotated_direction.dot(to_direction),
		-1.0,
		1.0
	)))
	return {
		"valid": true,
		"status": &"local_hinge_alignment_ready",
		"rotation": rotation,
		"angle_rad": signed_angle,
		"angle_degrees": rad_to_deg(signed_angle),
		"residual_degrees": residual_degrees,
	}


func _shortest_arc_quaternion(
	from_direction: Vector3,
	to_direction: Vector3,
	stable_axis: Vector3
) -> Quaternion:
	var from_normalized: Vector3 = from_direction.normalized()
	var to_normalized: Vector3 = to_direction.normalized()
	var arc_dot: float = clampf(from_normalized.dot(to_normalized), -1.0, 1.0)
	if arc_dot >= 1.0 - 0.000001:
		return Quaternion.IDENTITY
	if arc_dot <= -1.0 + 0.000001:
		var fallback_axis: Vector3 = stable_axis
		fallback_axis -= from_normalized * fallback_axis.dot(from_normalized)
		if fallback_axis.length_squared() <= RAY_EPSILON * RAY_EPSILON:
			fallback_axis = from_normalized.cross(Vector3.RIGHT)
		if fallback_axis.length_squared() <= RAY_EPSILON * RAY_EPSILON:
			fallback_axis = from_normalized.cross(Vector3.UP)
		return Quaternion(fallback_axis.normalized(), PI)
	var arc_axis: Vector3 = from_normalized.cross(to_normalized).normalized()
	return Quaternion(arc_axis, acos(arc_dot)).normalized()


func _find_thumb_strict_clearance_pose(
	snapshot: Dictionary,
	surface: Dictionary,
	grip_center_world: Vector3,
	maximum_ray_distance: float,
	section_targets: Array[float],
	max_overlap: float,
	ray_stats: Dictionary
) -> Dictionary:
	var open_sign: float = signf(float(snapshot.get("thumb_clearance_open_sign", 0.0)))
	var step_degrees: float = clampf(float(snapshot.get(
		"thumb_clearance_step_degrees",
		THUMB_CLEARANCE_DEFAULT_STEP_DEGREES
	)), 1.0, 45.0)
	var maximum_degrees: float = clampf(float(snapshot.get(
		"thumb_clearance_max_degrees",
		THUMB_CLEARANCE_DEFAULT_MAX_DEGREES
	)), step_degrees, THUMB_CLEARANCE_DEFAULT_MAX_DEGREES)
	var result := {
		"attempted": true,
		"clearance_established": false,
		"status": &"invalid_authored_clearance_direction",
		"authored_open_sign": open_sign,
		"step_degrees": step_degrees,
		"maximum_degrees": maximum_degrees,
		"sample_results": [],
		"clearance_angles_rad": [0.0, 0.0, 0.0],
		"transition_observed": false,
	}
	if absf(open_sign) < 0.5:
		return result
	var sample_results: Array[Dictionary] = []
	var initial_colliding := false
	var sample_degrees := 0.0
	while true:
		var sample_angles: Array[float] = [deg_to_rad(sample_degrees) * open_sign, 0.0, 0.0]
		var evaluation: Dictionary = _evaluate_serial_pose_safety(
			snapshot,
			surface,
			sample_angles,
			grip_center_world,
			maximum_ray_distance,
			section_targets,
			max_overlap,
			DEFAULT_MAX_ACCEPTABLE_CONTACT_ERROR_METERS,
			ray_stats
		)
		var strict_clear: bool = _serial_evaluation_is_strictly_clear(evaluation)
		var sample_diagnostic := {
			"open_degrees": sample_degrees * open_sign,
			"strict_clear": strict_clear,
			"max_penetration_meters": float(evaluation.get("max_penetration_meters", 0.0)),
			"inside_solid_section_count": int(evaluation.get("inside_solid_section_count", 0)),
			"section_states": (evaluation.get("section_states", []) as Array).duplicate(true),
		}
		sample_results.append(sample_diagnostic)
		if sample_degrees <= 0.0:
			initial_colliding = not strict_clear
		if strict_clear:
			result["clearance_established"] = true
			result["status"] = &"already_clear" if sample_degrees <= 0.0 else &"collision_to_clear_gate"
			result["clearance_angle_degrees"] = sample_degrees * open_sign
			result["clearance_angles_rad"] = sample_angles
			result["transition_observed"] = initial_colliding and sample_degrees > 0.0
			result["sample_results"] = sample_results
			return result
		if sample_degrees >= maximum_degrees - 0.000001:
			result["status"] = &"no_strict_clearance_within_authored_range"
			result["clearance_angle_degrees"] = sample_degrees * open_sign
			result["clearance_angles_rad"] = sample_angles
			result["sample_results"] = sample_results
			return result
		sample_degrees = minf(sample_degrees + step_degrees, maximum_degrees)
	return result


func _serial_evaluation_is_strictly_clear(evaluation: Dictionary) -> bool:
	var section_states: Array = evaluation.get("section_states", []) as Array
	if section_states.size() != 3:
		return false
	for state_variant: Variant in section_states:
		var state: Dictionary = state_variant as Dictionary
		if (
			bool(state.get("inside_solid", false))
			or int(state.get("inside_solid_sample_count", 0)) > 0
			or float(state.get("penetration_meters", 0.0)) > OVERLAP_NUMERIC_EPSILON_METERS
			or bool(state.get("in_contact", false))
		):
			return false
	return true


func _extend_thumb_root_angle_bound(snapshot: Dictionary, clearance_angle: float) -> void:
	var minimums: Array = (snapshot.get("min_angles_rad", []) as Array).duplicate()
	var maximums: Array = (snapshot.get("max_angles_rad", []) as Array).duplicate()
	if minimums.size() != 3 or maximums.size() != 3:
		return
	minimums[0] = minf(float(minimums[0]), clearance_angle)
	maximums[0] = maxf(float(maximums[0]), clearance_angle)
	snapshot["min_angles_rad"] = minimums
	snapshot["max_angles_rad"] = maximums


func _forward_kinematics(snapshot: Dictionary, angles: Array[float]) -> Dictionary:
	var parent_world: Transform3D = snapshot.get("root_parent_world", Transform3D.IDENTITY) as Transform3D
	var relative_transforms: Array = snapshot.get("relative_transforms", []) as Array
	var neutral_rotations: Array = snapshot.get("neutral_local_rotations", []) as Array
	var hinge_axes_local: Array = snapshot.get("hinge_axes_local", []) as Array
	var joint_transforms: Array[Transform3D] = []
	var joint_origins: Array[Vector3] = []
	var hinge_axes_world: Array[Vector3] = []
	for joint_index: int in range(3):
		var relative: Transform3D = relative_transforms[joint_index]
		var pre_hinge_world: Transform3D = parent_world * relative
		var neutral_rotation: Quaternion = (neutral_rotations[joint_index] as Quaternion).normalized()
		var neutral_basis: Basis = pre_hinge_world.basis * Basis(neutral_rotation)
		var hinge_axis_local: Vector3 = hinge_axes_local[joint_index]
		if hinge_axis_local.length_squared() <= RAY_EPSILON:
			hinge_axis_local = Vector3.FORWARD
		hinge_axis_local = hinge_axis_local.normalized()
		var hinge_axis_world: Vector3 = (neutral_basis * hinge_axis_local).normalized()
		var resolved_basis: Basis = neutral_basis * Basis(hinge_axis_local, angles[joint_index])
		var resolved_world := Transform3D(resolved_basis, pre_hinge_world.origin)
		joint_transforms.append(resolved_world)
		joint_origins.append(resolved_world.origin)
		hinge_axes_world.append(hinge_axis_world)
		parent_world = resolved_world
	var tip_offset_local: Vector3 = snapshot.get("tip_offset_local", Vector3(0.0, 0.02, 0.0)) as Vector3
	var tip_world: Vector3 = joint_transforms[2] * tip_offset_local
	return {
		"joint_transforms_world": joint_transforms,
		"joint_origins_world": joint_origins,
		"hinge_axes_world": hinge_axes_world,
		"tip_world": tip_world,
	}


func _resolve_section_probe_positions(fk: Dictionary) -> Array[Vector3]:
	var origins: Array = fk.get("joint_origins_world", []) as Array
	if origins.size() != 3:
		return []
	var tip_world: Vector3 = fk.get("tip_world", origins[2]) as Vector3
	return [
		(origins[0] as Vector3).lerp(origins[1] as Vector3, 0.5),
		(origins[1] as Vector3).lerp(origins[2] as Vector3, 0.5),
		(origins[2] as Vector3).lerp(tip_world, 0.5),
	]


func _resolve_section_segment_endpoints(fk: Dictionary, section_index: int) -> Dictionary:
	var origins: Array = fk.get("joint_origins_world", []) as Array
	if origins.size() != 3 or section_index < 0 or section_index > 2:
		return {}
	var tip_world: Vector3 = fk.get("tip_world", origins[2]) as Vector3
	if section_index == 0:
		return {"start_world": origins[0], "end_world": origins[1]}
	if section_index == 1:
		return {"start_world": origins[1], "end_world": origins[2]}
	return {"start_world": origins[2], "end_world": tip_world}


func _resolve_section_capsule_sample_positions(
	fk: Dictionary,
	section_index: int,
	sample_count: int
) -> Array[Vector3]:
	var endpoints: Dictionary = _resolve_section_segment_endpoints(fk, section_index)
	if endpoints.is_empty():
		return []
	var start_world: Vector3 = endpoints.get("start_world", Vector3.ZERO) as Vector3
	var end_world: Vector3 = endpoints.get("end_world", start_world) as Vector3
	var resolved_count: int = clampi(sample_count, 3, 7)
	var samples: Array[Vector3] = []
	# Avoid shared joint centers: adjacent capsule sections already cover them,
	# and sampling slightly inward keeps each hinge's contact authority local.
	for sample_index: int in range(resolved_count):
		var fraction: float = lerpf(0.18, 0.82, float(sample_index) / float(resolved_count - 1))
		samples.append(start_world.lerp(end_world, fraction))
	return samples


func _build_output_rotations(snapshot: Dictionary, angles: Array[float]) -> Dictionary:
	var rotations: Dictionary = {}
	var bone_names: Array = snapshot.get("bone_names", []) as Array
	var base_rotations: Array = snapshot.get("base_pose_rotations", []) as Array
	var neutral_rotations: Array = snapshot.get("neutral_local_rotations", []) as Array
	var hinge_axes: Array = snapshot.get("hinge_axes_local", []) as Array
	for joint_index: int in range(mini(3, bone_names.size())):
		var base_rotation: Quaternion = (base_rotations[joint_index] as Quaternion).normalized()
		var neutral_rotation: Quaternion = (neutral_rotations[joint_index] as Quaternion).normalized()
		var axis: Vector3 = hinge_axes[joint_index]
		if axis.length_squared() <= RAY_EPSILON:
			axis = Vector3.FORWARD
		var hinge_rotation := Quaternion(axis.normalized(), angles[joint_index])
		rotations[StringName(bone_names[joint_index])] = (base_rotation * neutral_rotation * hinge_rotation).normalized()
	return rotations


func _build_output_zero_rotations(snapshot: Dictionary) -> Dictionary:
	return _build_output_rotations(snapshot, [0.0, 0.0, 0.0])


func _resolve_open_angles(snapshot: Dictionary) -> Array[float]:
	var min_angles: Array = snapshot.get("min_angles_rad", []) as Array
	var max_angles: Array = snapshot.get("max_angles_rad", []) as Array
	var open_angles: Array[float] = []
	for joint_index: int in range(3):
		open_angles.append(clampf(0.0, float(min_angles[joint_index]), float(max_angles[joint_index])))
	return open_angles


func _resolve_closed_angles(snapshot: Dictionary, open_angles: Array[float]) -> Array[float]:
	var min_angles: Array = snapshot.get("min_angles_rad", []) as Array
	var max_angles: Array = snapshot.get("max_angles_rad", []) as Array
	var preferred_angles: Array = snapshot.get("preferred_angles_rad", []) as Array
	var closed_angles: Array[float] = []
	for joint_index: int in range(3):
		var min_angle: float = float(min_angles[joint_index])
		var max_angle: float = float(max_angles[joint_index])
		var preferred: float = float(preferred_angles[joint_index])
		if absf(preferred - open_angles[joint_index]) > ANGLE_EPSILON:
			closed_angles.append(max_angle if preferred > open_angles[joint_index] else min_angle)
		elif absf(max_angle - open_angles[joint_index]) >= absf(min_angle - open_angles[joint_index]):
			closed_angles.append(max_angle)
		else:
			closed_angles.append(min_angle)
	return closed_angles


func _trace_surface_segment(
	surface: Dictionary,
	from_world: Vector3,
	to_world: Vector3,
	stats: Dictionary
) -> Dictionary:
	stats["ray_count"] = int(stats.get("ray_count", 0)) + 1
	var direction: Vector3 = to_world - from_world
	var ray_length: float = direction.length()
	if ray_length <= RAY_EPSILON:
		return {}
	var triangles: PackedVector3Array = surface.get("triangles_world", PackedVector3Array()) as PackedVector3Array
	var normals: PackedVector3Array = surface.get("triangle_normals_world", PackedVector3Array()) as PackedVector3Array
	var bvh_nodes: Array = surface.get("bvh_nodes", []) as Array
	var triangle_order: Array = surface.get("bvh_triangle_order", []) as Array
	if triangles.is_empty() or normals.is_empty():
		return {}
	var best_fraction := INF
	var best_triangle := -1
	var stack: Array[int] = []
	if not bvh_nodes.is_empty():
		stack.append(0)
	while not stack.is_empty():
		var node_index: int = stack.pop_back()
		if node_index < 0 or node_index >= bvh_nodes.size():
			continue
		stats["bvh_node_test_count"] = int(stats.get("bvh_node_test_count", 0)) + 1
		var node: Dictionary = bvh_nodes[node_index] as Dictionary
		if not _segment_intersects_aabb(from_world, direction, node.get("bounds", AABB()) as AABB, best_fraction):
			continue
		var count: int = int(node.get("count", 0))
		if count > 0:
			var start: int = int(node.get("start", 0))
			for order_index: int in range(start, start + count):
				var triangle_index: int = int(triangle_order[order_index])
				var vertex_offset: int = triangle_index * 3
				stats["triangle_test_count"] = int(stats.get("triangle_test_count", 0)) + 1
				var fraction: float = _ray_triangle_fraction(
					from_world,
					direction,
					triangles[vertex_offset],
					triangles[vertex_offset + 1],
					triangles[vertex_offset + 2]
				)
				if fraction >= 0.0 and fraction < best_fraction:
					best_fraction = fraction
					best_triangle = triangle_index
			continue
		var left_index: int = int(node.get("left", -1))
		var right_index: int = int(node.get("right", -1))
		if right_index >= 0:
			stack.append(right_index)
		if left_index >= 0:
			stack.append(left_index)
	if bvh_nodes.is_empty():
		for triangle_index: int in range(normals.size()):
			var vertex_offset: int = triangle_index * 3
			stats["triangle_test_count"] = int(stats.get("triangle_test_count", 0)) + 1
			var fraction: float = _ray_triangle_fraction(
				from_world,
				direction,
				triangles[vertex_offset],
				triangles[vertex_offset + 1],
				triangles[vertex_offset + 2]
			)
			if fraction >= 0.0 and fraction < best_fraction:
				best_fraction = fraction
				best_triangle = triangle_index
	if best_triangle < 0:
		return {}
	var mesh_normal: Vector3 = normals[best_triangle].normalized()
	var mesh_normal_dot_ray: float = mesh_normal.dot(direction.normalized())
	var hit_normal: Vector3 = mesh_normal
	if mesh_normal_dot_ray > 0.0:
		hit_normal = -hit_normal
	return {
		"fraction": best_fraction,
		"distance_meters": ray_length * best_fraction,
		"position_world": from_world + direction * best_fraction,
		"normal_world": hit_normal.normalized(),
		"mesh_normal_world": mesh_normal,
		"entered_surface": mesh_normal_dot_ray < 0.0,
		"exited_surface": mesh_normal_dot_ray > 0.0,
		"triangle_index": best_triangle,
	}


func _ray_triangle_fraction(
	origin: Vector3,
	direction: Vector3,
	a: Vector3,
	b: Vector3,
	c: Vector3
) -> float:
	var edge_ab: Vector3 = b - a
	var edge_ac: Vector3 = c - a
	var p_vector: Vector3 = direction.cross(edge_ac)
	var determinant: float = edge_ab.dot(p_vector)
	if absf(determinant) <= RAY_EPSILON:
		return -1.0
	var inverse_determinant: float = 1.0 / determinant
	var t_vector: Vector3 = origin - a
	var u: float = t_vector.dot(p_vector) * inverse_determinant
	if u < -RAY_EPSILON or u > 1.0 + RAY_EPSILON:
		return -1.0
	var q_vector: Vector3 = t_vector.cross(edge_ab)
	var v: float = direction.dot(q_vector) * inverse_determinant
	if v < -RAY_EPSILON or u + v > 1.0 + RAY_EPSILON:
		return -1.0
	var fraction: float = edge_ac.dot(q_vector) * inverse_determinant
	if fraction < -RAY_EPSILON or fraction > 1.0 + RAY_EPSILON:
		return -1.0
	return clampf(fraction, 0.0, 1.0)


func _segment_intersects_aabb(
	origin: Vector3,
	direction: Vector3,
	bounds: AABB,
	maximum_fraction: float
) -> bool:
	var minimum_t := 0.0
	var maximum_t: float = minf(1.0, maximum_fraction)
	var bounds_end: Vector3 = bounds.end
	for axis_index: int in range(3):
		var origin_component: float = origin[axis_index]
		var direction_component: float = direction[axis_index]
		var minimum_component: float = bounds.position[axis_index]
		var maximum_component: float = bounds_end[axis_index]
		if absf(direction_component) <= RAY_EPSILON:
			if origin_component < minimum_component or origin_component > maximum_component:
				return false
			continue
		var inverse_direction: float = 1.0 / direction_component
		var first_t: float = (minimum_component - origin_component) * inverse_direction
		var second_t: float = (maximum_component - origin_component) * inverse_direction
		if first_t > second_t:
			var swap_t: float = first_t
			first_t = second_t
			second_t = swap_t
		minimum_t = maxf(minimum_t, first_t)
		maximum_t = minf(maximum_t, second_t)
		if minimum_t > maximum_t:
			return false
	return true


func _build_bvh(
	triangle_bounds: Array[AABB],
	triangle_centroids: PackedVector3Array,
	leaf_triangle_count: int
) -> Dictionary:
	var order: Array[int] = []
	for triangle_index: int in range(triangle_bounds.size()):
		order.append(triangle_index)
	var nodes: Array[Dictionary] = []
	if not order.is_empty():
		_build_bvh_node(
			triangle_bounds,
			triangle_centroids,
			order,
			nodes,
			0,
			order.size(),
			leaf_triangle_count
		)
	return {"nodes": nodes, "triangle_order": order}


func _build_bvh_node(
	triangle_bounds: Array[AABB],
	triangle_centroids: PackedVector3Array,
	order: Array[int],
	nodes: Array[Dictionary],
	start: int,
	count: int,
	leaf_triangle_count: int
) -> int:
	var node_bounds: AABB = triangle_bounds[order[start]]
	var centroid_min: Vector3 = triangle_centroids[order[start]]
	var centroid_max: Vector3 = centroid_min
	for order_index: int in range(start + 1, start + count):
		var triangle_index: int = order[order_index]
		node_bounds = node_bounds.merge(triangle_bounds[triangle_index])
		centroid_min = centroid_min.min(triangle_centroids[triangle_index])
		centroid_max = centroid_max.max(triangle_centroids[triangle_index])
	var node_index: int = nodes.size()
	nodes.append({
		"bounds": node_bounds,
		"left": -1,
		"right": -1,
		"start": start,
		"count": count,
	})
	if count <= leaf_triangle_count:
		return node_index
	var centroid_size: Vector3 = centroid_max - centroid_min
	var split_axis := 0
	if centroid_size.y > centroid_size.x:
		split_axis = 1
	if centroid_size.z > centroid_size[split_axis]:
		split_axis = 2
	_sort_triangle_order_range(order, triangle_centroids, start, start + count - 1, split_axis)
	var left_count: int = count / 2
	var right_count: int = count - left_count
	var left_index: int = _build_bvh_node(
		triangle_bounds,
		triangle_centroids,
		order,
		nodes,
		start,
		left_count,
		leaf_triangle_count
	)
	var right_index: int = _build_bvh_node(
		triangle_bounds,
		triangle_centroids,
		order,
		nodes,
		start + left_count,
		right_count,
		leaf_triangle_count
	)
	var branch: Dictionary = nodes[node_index]
	branch["left"] = left_index
	branch["right"] = right_index
	branch["count"] = 0
	nodes[node_index] = branch
	return node_index


func _sort_triangle_order_range(
	order: Array[int],
	centroids: PackedVector3Array,
	left: int,
	right: int,
	axis_index: int
) -> void:
	var low := left
	var high := right
	var pivot: float = centroids[order[(left + right) / 2]][axis_index]
	while low <= high:
		while centroids[order[low]][axis_index] < pivot:
			low += 1
		while centroids[order[high]][axis_index] > pivot:
			high -= 1
		if low <= high:
			var swap_index: int = order[low]
			order[low] = order[high]
			order[high] = swap_index
			low += 1
			high -= 1
	if left < high:
		_sort_triangle_order_range(order, centroids, left, high, axis_index)
	if low < right:
		_sort_triangle_order_range(order, centroids, low, right, axis_index)


func _resolve_accepted_surface_indices(mesh: Mesh, options: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	var requested_variant: Variant = options.get("grip_surface_indices", [])
	if requested_variant is Array and not (requested_variant as Array).is_empty():
		for index_variant: Variant in requested_variant as Array:
			var surface_index: int = int(index_variant)
			if surface_index >= 0 and surface_index < mesh.get_surface_count() and not indices.has(surface_index):
				indices.append(surface_index)
		return indices
	for surface_index: int in range(mesh.get_surface_count()):
		indices.append(surface_index)
	return indices


func _triangle_passes_grip_filter(
	local_a: Vector3,
	local_b: Vector3,
	local_c: Vector3,
	world_a: Vector3,
	world_b: Vector3,
	world_c: Vector3,
	options: Dictionary
) -> bool:
	var local_triangle_bounds: AABB = _triangle_aabb(local_a, local_b, local_c)
	var world_triangle_bounds: AABB = _triangle_aabb(world_a, world_b, world_c)
	if options.has("grip_band_local_aabb"):
		var local_band: AABB = options.get("grip_band_local_aabb", AABB()) as AABB
		if not local_band.intersects(local_triangle_bounds) and not local_band.encloses(local_triangle_bounds):
			return false
	if options.has("grip_band_world_aabb"):
		var world_band: AABB = options.get("grip_band_world_aabb", AABB()) as AABB
		if not world_band.intersects(world_triangle_bounds) and not world_band.encloses(world_triangle_bounds):
			return false
	if options.has("grip_axis_local"):
		var axis: Vector3 = options.get("grip_axis_local", Vector3.UP) as Vector3
		if axis.length_squared() > RAY_EPSILON:
			axis = axis.normalized()
			var origin: Vector3 = options.get("grip_axis_origin_local", Vector3.ZERO) as Vector3
			var span_min: float = float(options.get("grip_axis_min_meters", -INF))
			var span_max: float = float(options.get("grip_axis_max_meters", INF))
			var projection_a: float = (local_a - origin).dot(axis)
			var projection_b: float = (local_b - origin).dot(axis)
			var projection_c: float = (local_c - origin).dot(axis)
			var triangle_min: float = minf(projection_a, minf(projection_b, projection_c))
			var triangle_max: float = maxf(projection_a, maxf(projection_b, projection_c))
			if triangle_max < span_min or triangle_min > span_max:
				return false
	if options.has("grip_span_start_world") and options.has("grip_span_end_world"):
		var span_start: Vector3 = options.get("grip_span_start_world", Vector3.ZERO) as Vector3
		var span_end: Vector3 = options.get("grip_span_end_world", Vector3.ZERO) as Vector3
		var span_vector: Vector3 = span_end - span_start
		var span_length: float = span_vector.length()
		if span_length > RAY_EPSILON:
			var span_axis: Vector3 = span_vector / span_length
			var span_padding: float = maxf(float(options.get("grip_span_padding_meters", 0.005)), 0.0)
			var span_projection_a: float = (world_a - span_start).dot(span_axis)
			var span_projection_b: float = (world_b - span_start).dot(span_axis)
			var span_projection_c: float = (world_c - span_start).dot(span_axis)
			var projected_min: float = minf(span_projection_a, minf(span_projection_b, span_projection_c))
			var projected_max: float = maxf(span_projection_a, maxf(span_projection_b, span_projection_c))
			if projected_max < -span_padding or projected_min > span_length + span_padding:
				return false
			if options.has("grip_band_radius_meters"):
				var band_radius: float = maxf(float(options.get("grip_band_radius_meters", 0.0)), 0.0)
				var triangle_center: Vector3 = (world_a + world_b + world_c) / 3.0
				var center_projection: float = clampf(
					(triangle_center - span_start).dot(span_axis),
					0.0,
					span_length
				)
				var closest_axis_point: Vector3 = span_start + span_axis * center_projection
				var triangle_extent: float = maxf(
					triangle_center.distance_to(world_a),
					maxf(triangle_center.distance_to(world_b), triangle_center.distance_to(world_c))
				)
				if triangle_center.distance_to(closest_axis_point) > band_radius + triangle_extent:
					return false
	return true


func _build_filter_signature(options: Dictionary) -> Array:
	var signature: Array = []
	for key: String in [
		"grip_surface_indices",
		"grip_band_local_aabb",
		"grip_band_world_aabb",
		"grip_axis_local",
		"grip_axis_origin_local",
		"grip_axis_min_meters",
		"grip_axis_max_meters",
		"grip_span_start_world",
		"grip_span_end_world",
		"grip_span_padding_meters",
		"grip_band_radius_meters",
	]:
		if options.has(key):
			signature.append(key)
			signature.append(options[key])
	return signature


func _triangle_aabb(a: Vector3, b: Vector3, c: Vector3) -> AABB:
	var minimum: Vector3 = a.min(b).min(c)
	var maximum: Vector3 = a.max(b).max(c)
	return AABB(minimum, maximum - minimum)


func _resolve_fallback_ray_target(options: Dictionary) -> Vector3:
	if options.has("fallback_ray_target_world"):
		return options.get("fallback_ray_target_world", Vector3.ZERO) as Vector3
	if options.has("grip_center_world"):
		return options.get("grip_center_world", Vector3.ZERO) as Vector3
	if options.has("grip_span_start_world") and options.has("grip_span_end_world"):
		var start_world: Vector3 = options.get("grip_span_start_world", Vector3.ZERO) as Vector3
		var end_world: Vector3 = options.get("grip_span_end_world", Vector3.ZERO) as Vector3
		return start_world.lerp(end_world, 0.5)
	return Vector3.ZERO


func _resolve_prepared_surface_center(surface: Dictionary) -> Vector3:
	var bvh_nodes: Array = surface.get("bvh_nodes", []) as Array
	if not bvh_nodes.is_empty():
		var root_node: Dictionary = bvh_nodes[0] as Dictionary
		var bounds: AABB = root_node.get("bounds", AABB()) as AABB
		return bounds.get_center()
	var triangles: PackedVector3Array = surface.get(
		"triangles_world",
		PackedVector3Array()
	) as PackedVector3Array
	if triangles.is_empty():
		return Vector3.INF
	var minimum: Vector3 = triangles[0]
	var maximum: Vector3 = triangles[0]
	for vertex: Vector3 in triangles:
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
	return (minimum + maximum) * 0.5


func _resolve_digit_reach_meters(snapshot: Dictionary) -> float:
	var relative_transforms: Array = snapshot.get("relative_transforms", []) as Array
	var reach := 0.0
	for relative_variant: Variant in relative_transforms:
		var relative: Transform3D = relative_variant as Transform3D
		reach += relative.origin.length()
	var tip_offset: Vector3 = snapshot.get("tip_offset_local", Vector3.ZERO) as Vector3
	reach += tip_offset.length()
	return maxf(reach, tip_offset.length())


func _validate_rule_pack(skeleton: Skeleton3D, side_rules: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var digits_variant: Variant = side_rules.get("digits", [])
	if not digits_variant is Array:
		return {"valid": false, "errors": ["digits must be an Array"]}
	var digits: Array = digits_variant as Array
	if digits.size() != 5:
		errors.append("expected exactly five digits")
	var seen_bones: Dictionary = {}
	for digit_variant: Variant in digits:
		if not digit_variant is Dictionary:
			errors.append("digit rule is not a Dictionary")
			continue
		var digit: Dictionary = digit_variant as Dictionary
		var bone_names: Array = digit.get("bone_names", []) as Array
		if bone_names.size() != 3:
			errors.append("%s does not define three bones" % String(digit.get("digit_id", "unknown")))
			continue
		for bone_variant: Variant in bone_names:
			var bone_name: StringName = StringName(bone_variant)
			if seen_bones.has(bone_name):
				errors.append("duplicate finger bone: %s" % String(bone_name))
			seen_bones[bone_name] = true
			if skeleton.find_bone(String(bone_name)) < 0:
				errors.append("missing skeleton bone: %s" % String(bone_name))
		for array_key: String in [
			"neutral_local_rotations",
			"hinge_axes_local",
			"min_angles_rad",
			"max_angles_rad",
			"preferred_angles_rad",
			"capsule_radii_m",
			"section_target_overlaps_meters",
		]:
			var value_variant: Variant = digit.get(array_key, [])
			if not value_variant is Array or (value_variant as Array).size() != 3:
				errors.append("%s.%s must contain three entries" % [String(digit.get("digit_id", "unknown")), array_key])
	return {"valid": errors.is_empty(), "errors": errors}


func _make_empty_result(slot_id: StringName) -> Dictionary:
	return {
		"valid": false,
		"rotations": {},
		"zero_rotations": {},
		"diagnostics": {},
		"surface_signature": "",
		"cache_key": "",
		"slot_id": slot_id,
		"all_sections_contacted": false,
		"all_digits_solved": false,
	}
