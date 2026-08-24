extends SceneTree

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2StageControllerScript = preload(
	"res://runtime/forge_v2/forge_v2_stage_controller.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_csg_organic_surface_feedback_2026-08-15.txt"
)
const PROFILE_SIDE_COUNT := 32
const NORMAL_FIDELITY_DOT_MIN := 0.94
const MAX_NORMAL_CONTINUITY_ERROR_DEGREES := 6.0
const HIT_POSITION_TOLERANCE_METERS := 0.004
const STABLE_POSITION_TOLERANCE_METERS := 0.0002
const MAX_COLLISION_WAIT_STEPS := 40
const MIN_EXTERIOR_WITNESS_SHIFT_METERS := 0.006


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var controller: Node = ForgeV2StageControllerScript.new()
	controller.name = "OrganicFeedbackStageController"
	root.add_child(controller)
	var workspace: Node3D = ForgeV2WorkspacePreviewScript.new()
	workspace.name = "OrganicFeedbackWorkspace"
	root.add_child(workspace)
	workspace.call("bind_stage_controller", controller)
	controller.call("start_new_draft", "Organic CSG Surface Feedback Verify")
	await process_frame

	var source_profile := _build_ellipse_profile(
		&"organic_feedback_source_profile",
		"Organic Feedback Source",
		0.030,
		0.040,
		deg_to_rad(135.0),
		0.001
	)
	if not _expect(
		bool(controller.call("select_active_saved_basic_profile", source_profile)),
		"source saved profile could not be selected"
	):
		return

	var source_points := PackedVector3Array()
	for angle_degrees: float in [-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]:
		var angle := deg_to_rad(angle_degrees)
		source_points.append(Vector3(
			0.26 * sin(angle),
			-0.18 + 0.26 * cos(angle),
			0.0
		))
	var source_normals := _filled_vectors(source_points.size(), Vector3.BACK)
	var source_contacts := _filled_vectors(source_points.size(), Vector3.FORWARD)
	var source_body_id: StringName = controller.call(
		"begin_material_body_path",
		source_points[0],
		source_normals[0],
		source_contacts[0]
	)
	if not _expect(source_body_id != StringName(), "source stroke did not begin"):
		return
	var accepted_source_count := int(controller.call(
		"extend_material_body_path_samples",
		source_points.slice(1),
		source_normals.slice(1),
		true,
		source_contacts.slice(1)
	))
	if not _expect(
		accepted_source_count == source_points.size() - 1,
		"source stroke did not retain every organic arc sample"
	):
		return
	var source_body := _find_body(
		controller.call("get_active_authoring_state") as Resource,
		source_body_id
	)
	if not _expect(source_body != null, "source material body was not retained"):
		return
	if not _expect(
		bool(source_body.call("uses_explicit_surface_contact_authority")),
		"source body did not use explicit surface contact authority"
	):
		return
	var presenter: Node3D = workspace.get("volume_preview_presenter") as Node3D
	if not _expect(presenter != null, "workspace presenter was not created"):
		return
	var probes := _build_profile_seam_probes(presenter, source_body)
	if not _expect(
		probes.size() == source_points.size() - 1,
		"organic seam probes could not be constructed"
	):
		return
	var camera_setup := _aim_camera_at_probes(workspace, probes)
	if not _expect(bool(camera_setup.get("ok", false)), "probe camera setup failed"):
		return

	if not _expect(
		bool(controller.call(
			"finish_material_body_path",
			Vector3.ZERO,
			false,
			Vector3.FORWARD
		)),
		"source organic stroke did not commit"
	):
		return
	var source_hits: Array = await _wait_for_stable_hits(
		workspace,
		probes,
		source_body_id,
		StringName(),
		HIT_POSITION_TOLERANCE_METERS
	)
	if not _expect(
		source_hits.size() == probes.size(),
		"committed source CSG collision did not become stably targetable"
	):
		return
	var source_target_id := StringName(source_hits[0].get(
		"surface_target_id",
		StringName()
	))
	if not _expect(source_target_id != StringName(), "source target identity was empty"):
		return

	var hit_metrics := _validate_source_hits(
		workspace,
		probes,
		source_hits,
		source_body_id,
		source_target_id
	)
	if not _expect(
		bool(hit_metrics.get("ok", false)),
		String(hit_metrics.get("error", "source hit validation failed"))
	):
		return

	var feedback_profile := _build_ellipse_profile(
		&"organic_feedback_deposit_profile",
		"Organic Feedback Deposit",
		0.008,
		0.014,
		deg_to_rad(90.0),
		0.001
	)
	if not _expect(
		bool(controller.call("select_active_saved_basic_profile", feedback_profile)),
		"feedback saved profile could not be selected"
	):
		return
	var feedback_positions := PackedVector3Array()
	var feedback_normals := PackedVector3Array()
	var feedback_contacts := PackedVector3Array()
	for hit_variant: Variant in source_hits:
		var hit := hit_variant as Dictionary
		feedback_positions.append(hit.get("local_position", Vector3.ZERO) as Vector3)
		feedback_normals.append(hit.get("local_normal", Vector3.ZERO) as Vector3)
		feedback_contacts.append(
			hit.get("local_contact_direction", Vector3.ZERO) as Vector3
		)
	var feedback_body_id: StringName = controller.call(
		"begin_material_body_path",
		feedback_positions[0],
		feedback_normals[0],
		feedback_contacts[0]
	)
	if not _expect(feedback_body_id != StringName(), "feedback stroke did not begin"):
		return
	var accepted_feedback_count := int(controller.call(
		"extend_material_body_path_samples",
		feedback_positions.slice(1),
		feedback_normals.slice(1),
		true,
		feedback_contacts.slice(1)
	))
	if not _expect(
		accepted_feedback_count == feedback_positions.size() - 1,
		"feedback stroke did not consume every real CSG hit"
	):
		return
	var feedback_body := _find_body(
		controller.call("get_active_authoring_state") as Resource,
		feedback_body_id
	)
	if not _expect(feedback_body != null, "feedback body was not retained"):
		return
	var exterior_metrics := _validate_feedback_body(
		presenter,
		feedback_body,
		feedback_positions,
		feedback_normals,
		feedback_contacts
	)
	if not _expect(
		bool(exterior_metrics.get("ok", false)),
		String(exterior_metrics.get("error", "feedback body validation failed"))
	):
		return
	if not _expect(
		bool(controller.call(
			"finish_material_body_path",
			Vector3.ZERO,
			false,
			Vector3.FORWARD
		)),
		"feedback stroke did not commit"
	):
		return

	var combined_hits: Array = await _wait_for_stable_hits(
		workspace,
		probes,
		StringName(),
		source_target_id,
		0.05
	)
	if not _expect(
		combined_hits.size() == source_hits.size(),
		"combined A+B CSG collision did not become stably targetable"
	):
		return
	var shifted_witness_count := 0
	var minimum_shift := INF
	var maximum_shift := -INF
	for hit_index in range(source_hits.size()):
		var old_hit := source_hits[hit_index] as Dictionary
		var new_hit := combined_hits[hit_index] as Dictionary
		var old_position := old_hit.get("local_position", Vector3.ZERO) as Vector3
		var old_outward := old_hit.get("local_normal", Vector3.ZERO) as Vector3
		var new_position := new_hit.get("local_position", Vector3.ZERO) as Vector3
		var exterior_shift := (new_position - old_position).dot(old_outward)
		minimum_shift = minf(minimum_shift, exterior_shift)
		maximum_shift = maxf(maximum_shift, exterior_shift)
		if exterior_shift >= MIN_EXTERIOR_WITNESS_SHIFT_METERS:
			shifted_witness_count += 1
	if not _expect(
		shifted_witness_count >= ceili(float(source_hits.size()) * 0.6),
		(
			"committed feedback stroke did not move the visible CSG surface "
			+ "primarily outward"
		)
	):
		return
	var static_root := presenter.get_node_or_null(
		"MaterialBodyCsgRoot/StaticMaterialBodyCsgRoot"
	)
	if not _expect(
		static_root != null and static_root.get_child_count() > 0,
		"combined feedback result was not authoritative static CSG"
	):
		return

	_write_result([
		"ok=true",
		"source_profile_side_count=%d" % PROFILE_SIDE_COUNT,
		"real_collision_hit_count=%d" % source_hits.size(),
		"profile_seam_probes=true",
		"bend_adjacent_probe_pairs=true",
		"raw_normal_min_fidelity_dot=%.6f" % float(hit_metrics.get(
			"minimum_normal_dot",
			0.0
		)),
		"max_normal_continuity_error_degrees=%.6f" % float(hit_metrics.get(
			"maximum_continuity_error_degrees",
			INF
		)),
		"oblique_normal_count=%d" % int(hit_metrics.get("oblique_count", 0)),
		"actual_hit_B_raw_normal_ABC_BC_reused=true",
		"feedback_min_outward_extent_meters=%.6f" % float(
			exterior_metrics.get("minimum_outward_extent", 0.0)
		),
		"feedback_max_buried_depth_meters=%.6f" % float(
			exterior_metrics.get("maximum_buried_depth", INF)
		),
		"exterior_shifted_witness_count=%d" % shifted_witness_count,
		"minimum_exterior_shift_meters=%.6f" % minimum_shift,
		"maximum_exterior_shift_meters=%.6f" % maximum_shift,
		"source_surface_target_id=%s" % String(source_target_id),
		"combined_surface_target_id=%s" % StringName(combined_hits[0].get(
			"surface_target_id",
			StringName()
		)),
		"committed_result_is_static_csg=true",
	])
	quit(0)


func _build_ellipse_profile(
	profile_id: StringName,
	label: String,
	radius_x: float,
	radius_y: float,
	start_angle_radians: float,
	anchor_clearance_meters: float
) -> Dictionary:
	var polygon := PackedVector2Array()
	for side_index in range(PROFILE_SIDE_COUNT):
		var angle := (
			start_angle_radians
			+ TAU * float(side_index) / float(PROFILE_SIDE_COUNT)
		)
		polygon.append(Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		))
	var anchor := Vector2(0.0, -radius_y + anchor_clearance_meters)
	return ForgeV2ProfileShapeLibraryScript.compile_basic_profile_runtime_data({
		"profile_id": profile_id,
		"id": profile_id,
		"label": label,
		"family": ForgeV2ProfileShapeLibraryScript.PROFILE_FAMILY_BASIC,
		"base_polygon_2d_meters": polygon,
		"polygon_2d_meters": polygon,
		"base_anchor_2d_meters": anchor,
		"anchor_x_meters": anchor.x,
		"anchor_y_meters": anchor.y,
		"rotation_degrees": 0.0,
	})


func _build_profile_seam_probes(presenter: Node, body: Resource) -> Array:
	var path_points: PackedVector3Array = body.get("path_points")
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if path_points.size() < 2 or polygon.size() < 3:
		return []
	var rings: Array = []
	for point_index in range(path_points.size()):
		var tangent: Vector3 = (
			ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
				path_points,
				point_index
			)
		)
		rings.append(presenter.call(
			"_build_profile_sweep_ring",
			body,
			polygon,
			point_index,
			tangent
		) as PackedVector3Array)
	var seam_index := polygon.size() - 1
	var next_index := 0
	var probes: Array = []
	for segment_index in range(path_points.size() - 1):
		var from_ring := rings[segment_index] as PackedVector3Array
		var to_ring := rings[segment_index + 1] as PackedVector3Array
		var use_toward_end_triangle := segment_index % 2 == 0
		var point_a := from_ring[seam_index]
		var point_b: Vector3
		var point_c: Vector3
		var centerline_point: Vector3
		var from_center := _average_points(from_ring)
		var to_center := _average_points(to_ring)
		if use_toward_end_triangle:
			point_b = to_ring[next_index]
			point_c = to_ring[seam_index]
			centerline_point = (from_center + to_center * 2.0) / 3.0
		else:
			point_b = from_ring[next_index]
			point_c = to_ring[next_index]
			centerline_point = (from_center * 2.0 + to_center) / 3.0
		var target := (point_a + point_b + point_c) / 3.0
		var normal := (point_b - point_a).cross(point_c - point_a).normalized()
		var radial := (target - centerline_point).normalized()
		# SurfaceTool/physics winding is an implementation detail.  The verifier
		# needs the exact triangle plane with the organic solid's exterior
		# hemisphere, so orient that plane normal away from the sweep centerline.
		if normal.dot(radial) < 0.0:
			normal = -normal
		if (
			normal.length_squared() <= 0.9
			or radial.length_squared() <= 0.9
			or normal.dot(radial) <= 0.5
		):
			return []
		probes.append({
			"segment_index": segment_index,
			"target_local": target,
			"expected_normal_local": normal,
			"radial_local": radial,
		})
	return probes


func _aim_camera_at_probes(workspace: Node3D, probes: Array) -> Dictionary:
	var camera: Camera3D = workspace.get("camera") as Camera3D
	if camera == null or probes.is_empty():
		return {"ok": false}
	var target_center := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	for probe_variant: Variant in probes:
		var probe := probe_variant as Dictionary
		target_center += probe.get("target_local", Vector3.ZERO) as Vector3
		normal_sum += probe.get("expected_normal_local", Vector3.ZERO) as Vector3
	target_center /= float(probes.size())
	var average_normal := normal_sum.normalized()
	if average_normal.length_squared() <= 0.9:
		return {"ok": false}
	var camera_local := target_center + average_normal * 0.65
	camera.global_position = workspace.to_global(camera_local)
	camera.look_at(workspace.to_global(target_center), Vector3.UP)
	camera.current = true
	camera.far = 4.0
	return {
		"ok": true,
		"camera_local": camera_local,
		"target_center": target_center,
		"average_normal": average_normal,
	}


func _wait_for_stable_hits(
	workspace: Node3D,
	probes: Array,
	required_source_body_id: StringName,
	forbidden_surface_target_id: StringName,
	max_target_distance: float
) -> Array:
	var previous_hits: Array = []
	for _wait_step in range(MAX_COLLISION_WAIT_STEPS):
		await process_frame
		await physics_frame
		var hits: Array = []
		var shared_target_id := StringName()
		var valid_batch := true
		for probe_variant: Variant in probes:
			var probe := probe_variant as Dictionary
			var target_local := probe.get("target_local", Vector3.ZERO) as Vector3
			var projection: Dictionary = workspace.call(
				"project_workspace_local_to_screen",
				target_local
			) as Dictionary
			if not bool(projection.get("valid", false)):
				valid_batch = false
				break
			var hit: Dictionary = workspace.call(
				"resolve_material_surface_target",
				projection.get("screen_position", Vector2.ZERO) as Vector2
			) as Dictionary
			var target_id := StringName(hit.get("surface_target_id", StringName()))
			if (
				not bool(hit.get("valid", false))
				or target_id == StringName()
				or target_id == forbidden_surface_target_id
				or (hit.get("local_position", Vector3.ZERO) as Vector3).distance_to(
					target_local
				) > max_target_distance
				or (
					required_source_body_id != StringName()
					and StringName(hit.get("source_body_id", StringName()))
					!= required_source_body_id
				)
			):
				valid_batch = false
				break
			if shared_target_id == StringName():
				shared_target_id = target_id
			elif target_id != shared_target_id:
				valid_batch = false
				break
			hits.append(hit)
		if valid_batch and hits.size() == probes.size():
			if _hit_batches_are_stable(previous_hits, hits):
				return hits
			previous_hits = hits
		else:
			previous_hits = []
	return []


func _hit_batches_are_stable(first: Array, second: Array) -> bool:
	if first.size() != second.size() or first.is_empty():
		return false
	for hit_index in range(first.size()):
		var first_hit := first[hit_index] as Dictionary
		var second_hit := second[hit_index] as Dictionary
		if (
			StringName(first_hit.get("surface_target_id", StringName()))
			!= StringName(second_hit.get("surface_target_id", StringName()))
			or (first_hit.get("local_position", Vector3.ZERO) as Vector3).distance_to(
				second_hit.get("local_position", Vector3.ZERO) as Vector3
			) > STABLE_POSITION_TOLERANCE_METERS
			or (first_hit.get("local_normal", Vector3.ZERO) as Vector3).dot(
				second_hit.get("local_normal", Vector3.ZERO) as Vector3
			) < 0.999
		):
			return false
	return true


func _validate_source_hits(
	workspace: Node3D,
	probes: Array,
	hits: Array,
	source_body_id: StringName,
	source_target_id: StringName
) -> Dictionary:
	var camera: Camera3D = workspace.get("camera") as Camera3D
	var minimum_normal_dot := 1.0
	var maximum_continuity_error := 0.0
	var oblique_count := 0
	for hit_index in range(hits.size()):
		var probe := probes[hit_index] as Dictionary
		var hit := hits[hit_index] as Dictionary
		var expected_position := probe.get("target_local", Vector3.ZERO) as Vector3
		var expected_normal := (
			probe.get("expected_normal_local", Vector3.ZERO) as Vector3
		).normalized()
		var actual_position := hit.get("local_position", Vector3.ZERO) as Vector3
		var raw_position := hit.get("raw_local_position", Vector3.ZERO) as Vector3
		var actual_normal := (
			hit.get("local_normal", Vector3.ZERO) as Vector3
		).normalized()
		var contact := (
			hit.get("local_contact_direction", Vector3.ZERO) as Vector3
		).normalized()
		var normal_dot := expected_normal.dot(actual_normal)
		minimum_normal_dot = minf(minimum_normal_dot, normal_dot)
		var maximum_axis_component := maxf(
			absf(expected_normal.x),
			maxf(absf(expected_normal.y), absf(expected_normal.z))
		)
		if maximum_axis_component < 0.93:
			oblique_count += 1
		var b_to_a := (
			workspace.to_local(camera.global_position) - actual_position
		).normalized()
		if (
			StringName(hit.get("surface_target_id", StringName())) != source_target_id
			or StringName(hit.get("source_body_id", StringName())) != source_body_id
			or bool(hit.get("is_clamped", true))
			or actual_position.distance_to(raw_position) > 0.00001
			or actual_position.distance_to(expected_position)
			> HIT_POSITION_TOLERANCE_METERS
			or normal_dot < NORMAL_FIDELITY_DOT_MIN
			or actual_normal.dot(contact) > -0.94
			or b_to_a.dot(contact) > 0.000001
		):
			return {
				"ok": false,
				"error": "real CSG hit %d lost exact position/normal/ABC authority" % hit_index,
			}
		if hit_index <= 0:
			continue
		var previous_expected := (
			(probes[hit_index - 1] as Dictionary).get(
				"expected_normal_local",
				Vector3.ZERO
			) as Vector3
		).normalized()
		var previous_actual := (
			(hits[hit_index - 1] as Dictionary).get(
				"local_normal",
				Vector3.ZERO
			) as Vector3
		).normalized()
		var expected_angle := previous_expected.angle_to(expected_normal)
		var actual_angle := previous_actual.angle_to(actual_normal)
		var continuity_error := absf(actual_angle - expected_angle)
		maximum_continuity_error = maxf(
			maximum_continuity_error,
			rad_to_deg(continuity_error)
		)
		if (
			previous_actual.dot(actual_normal) < 0.5
			or rad_to_deg(continuity_error)
			> MAX_NORMAL_CONTINUITY_ERROR_DEGREES
		):
			return {
				"ok": false,
				"error": "real CSG normals broke organic continuity at hit %d" % hit_index,
			}
	if oblique_count < 4:
		return {
			"ok": false,
			"error": "organic fixture did not exercise enough non-axis normals",
		}
	return {
		"ok": true,
		"minimum_normal_dot": minimum_normal_dot,
		"maximum_continuity_error_degrees": maximum_continuity_error,
		"oblique_count": oblique_count,
	}


func _validate_feedback_body(
	presenter: Node,
	body: Resource,
	expected_positions: PackedVector3Array,
	expected_normals: PackedVector3Array,
	expected_contacts: PackedVector3Array
) -> Dictionary:
	var path_points: PackedVector3Array = body.get("path_points")
	var path_normals: PackedVector3Array = body.get("path_surface_normals")
	var path_contacts: PackedVector3Array = body.get("path_contact_directions")
	var polygon: PackedVector2Array = body.get("profile_polygon_2d_meters")
	if (
		path_points.size() != expected_positions.size()
		or path_normals.size() != expected_normals.size()
		or path_contacts.size() != expected_contacts.size()
		or polygon.size() < 3
	):
		return {"ok": false, "error": "feedback body lost hit triples"}
	var minimum_outward_extent := INF
	var maximum_buried_depth := 0.0
	for point_index in range(path_points.size()):
		if (
			path_points[point_index].distance_to(expected_positions[point_index])
			> STABLE_POSITION_TOLERANCE_METERS
			or path_normals[point_index].dot(expected_normals[point_index]) < 0.999
			or path_contacts[point_index].dot(expected_contacts[point_index]) < 0.999
		):
			return {
				"ok": false,
				"error": "feedback body rewrote real hit triple %d" % point_index,
			}
		var tangent := (
			ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
				path_points,
				point_index
			)
		)
		var ring := presenter.call(
			"_build_profile_sweep_ring",
			body,
			polygon,
			point_index,
			tangent
		) as PackedVector3Array
		var outward := -path_contacts[point_index].normalized()
		var maximum_signed := -INF
		var minimum_signed := INF
		var signed_sum := 0.0
		var exterior_vertex_count := 0
		for vertex: Vector3 in ring:
			var signed_distance := (
				vertex - path_points[point_index]
			).dot(outward)
			maximum_signed = maxf(maximum_signed, signed_distance)
			minimum_signed = minf(minimum_signed, signed_distance)
			signed_sum += signed_distance
			if signed_distance > 0.0005:
				exterior_vertex_count += 1
		var exterior_ratio := float(exterior_vertex_count) / float(ring.size())
		minimum_outward_extent = minf(minimum_outward_extent, maximum_signed)
		maximum_buried_depth = maxf(
			maximum_buried_depth,
			maxf(-minimum_signed, 0.0)
		)
		if (
			maximum_signed < 0.015
			or minimum_signed < -0.003
			or signed_sum / float(ring.size()) < 0.006
			or exterior_ratio < 0.65
		):
			return {
				"ok": false,
				"error": "feedback ring %d was buried instead of exterior" % point_index,
			}
	return {
		"ok": true,
		"minimum_outward_extent": minimum_outward_extent,
		"maximum_buried_depth": maximum_buried_depth,
	}


func _filled_vectors(count: int, value: Vector3) -> PackedVector3Array:
	var values := PackedVector3Array()
	for _index in range(count):
		values.append(value)
	return values


func _average_points(points: PackedVector3Array) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var average := Vector3.ZERO
	for point: Vector3 in points:
		average += point
	return average / float(points.size())


func _find_body(state: Resource, body_id: StringName) -> Resource:
	if state == null or body_id == StringName():
		return null
	var bodies: Array = state.get("material_bodies") as Array
	for body_variant: Variant in bodies:
		if not body_variant is Resource:
			continue
		var body := body_variant as Resource
		if StringName(body.get("body_id")) == body_id:
			return body
	return null


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)
	return false


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
