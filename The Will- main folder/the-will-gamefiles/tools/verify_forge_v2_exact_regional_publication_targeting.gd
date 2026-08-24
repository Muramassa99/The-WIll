extends SceneTree

const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2PlacementTargetResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_placement_target_resolver.gd"
)
const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)
const ForgeV2VolumePreviewPresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const ForgeV2WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const ForgeV2WorkpieceBenchmarkMeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const INPUT_PATH := (
	"C:/WORKSPACE/godot_runs/forge_v2_exact_regional_manifold_prototype.json"
)
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_exact_regional_publication_targeting_2026-08-15_run5.json"
)

const EXPECTED_FRAGMENT_COUNT := 20
const CHUNK_SIZE_METERS := 0.064
const SURFACE_TARGET_ID := &"forge_v2_exact_regional_publication_target_v1"
const LOGICAL_BODY_ID := &"forge_v2_exact_regional_workpiece_v1"
const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const WRONG_TARGET_ID := &"forge_v2_intentionally_wrong_target"

const PLANE_TOLERANCE_METERS := 0.00000035
const SEAM_GAP_TOLERANCE_METERS := 0.000001
const HIT_POSITION_TOLERANCE_METERS := 0.00020
const STABLE_POSITION_TOLERANCE_METERS := 0.00001
const NORMAL_DOT_MIN := 0.999
const ABC_DOT_MAX := -0.999
const ADJACENT_NORMAL_DOT_MIN := 0.90
const MIN_PROBE_EDGE_CLEARANCE_METERS := 0.00008
const MIN_SEAM_PROBE_OFFSET_METERS := 0.00004
const DIRECT_RAY_OFFSET_METERS := 0.004
const MIN_DISTINCT_SEAMS := 3
const MIN_OBLIQUE_AXIS_COMPONENT_MAX := 0.94
const CAMERA_DISTANCE_METERS := 0.75
const MAX_CAMERA_GROUP_ATTEMPTS := 48

var _workspace: Node3D = null
var _publication_root: Node3D = null
var _packets: Array = []
var _packet_by_coord: Dictionary = {}
var _triangle_records: Array = []
var _publication_meshes: Array[ArrayMesh] = []
var _expected_organic_triangle_count := 0
var _publication_topology: Dictionary = {}
var _publication_metrics := {
	"fragment_count": 0,
	"organic_triangle_count": 0,
	"compiler_cap_triangle_count": 0,
	"manifold_signed_volume_m3": 0.0,
	"godot_signed_volume_m3": 0.0,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var artifact := _read_json_dictionary(INPUT_PATH)
	if artifact.is_empty():
		_fail("prototype artifact could not be read")
		return
	if not bool(artifact.get("proof_passed", false)):
		_fail("prototype artifact is not a passing proof")
		return
	var publication := artifact.get("publication", {}) as Dictionary
	if not bool(publication.get("compiler_caps_are_storage_only", false)):
		_fail("prototype does not declare compiler caps storage-only")
		return
	var counters := publication.get("counters", {}) as Dictionary
	if (
		int(counters.get("fragment_count", -1)) != EXPECTED_FRAGMENT_COUNT
		or int(counters.get("organic_triangles", -1)) <= 0
		or int(counters.get("published_cap_triangles", -1)) != 0
	):
		_fail("prototype publication counters do not match the fixed gate")
		return
	_expected_organic_triangle_count = int(counters.get("organic_triangles", 0))
	_packets = publication.get("organic_fragment_packets", []) as Array
	if _packets.size() != EXPECTED_FRAGMENT_COUNT:
		_fail("prototype did not contain exactly 20 organic fragment packets")
		return

	_workspace = ForgeV2WorkspacePreviewScript.new()
	_workspace.name = "ExactRegionalPublicationWorkspace"
	root.add_child(_workspace)
	await process_frame
	if _workspace.get("camera") == null:
		_fail("real Forge workspace camera was not created")
		return
	_publication_root = Node3D.new()
	_publication_root.name = "ExactRegionalOrganicFragments"
	_workspace.add_child(_publication_root)
	if not _publication_root.transform.is_equal_approx(Transform3D.IDENTITY):
		_fail("publication root did not retain identity transform")
		return

	var publication_result := _publish_fragments()
	if not bool(publication_result.get("ok", false)):
		_fail(String(publication_result.get("error", "fragment publication failed")))
		return
	if int(_publication_metrics.get("fragment_count", 0)) != EXPECTED_FRAGMENT_COUNT:
		_fail("not every packet produced one MeshInstance and StaticBody")
		return
	if (
		int(_publication_metrics.get("organic_triangle_count", 0))
		!= _expected_organic_triangle_count
		or int(_publication_metrics.get("compiler_cap_triangle_count", -1)) != 0
	):
		_fail("publication did not remain organic-only")
		return
	_publication_topology = (
		ForgeV2WorkpieceBenchmarkMeshAnalyzerScript.analyze_meshes(
			_publication_meshes
		)
	)
	if (
		not bool(_publication_topology.get("strict_watertight", false))
		or int(_publication_topology.get("strict_component_count", -1)) != 1
		or int(_publication_topology.get("strict_boundary_edge_count", -1)) != 0
		or int(_publication_topology.get("strict_nonmanifold_edge_count", -1)) != 0
		or int(_publication_topology.get("strict_directed_edge_mismatch_count", -1)) != 0
	):
		_fail("emitted organic fragment packets are not one watertight Godot surface")
		return
	if (
		float(_publication_metrics.get("manifold_signed_volume_m3", 0.0)) <= 0.0
		or float(_publication_metrics.get("godot_signed_volume_m3", 0.0)) >= 0.0
		or not is_equal_approx(
			absf(float(_publication_metrics.get("manifold_signed_volume_m3", 0.0))),
			absf(float(_publication_metrics.get("godot_signed_volume_m3", 0.0)))
		)
	):
		_fail("Manifold-positive to Godot-outward winding conversion was not proven")
		return

	# Give every newly published ConcavePolygonShape two full physics frames before
	# using it.  Prove all twenty published resource identities survive that sync;
	# later, selected physical hits are compared across two more frames.
	var publication_identity_before := _snapshot_publication_identity()
	await physics_frame
	await physics_frame
	var publication_identity_after := _snapshot_publication_identity()
	if publication_identity_before != publication_identity_after:
		_fail("fragment render/collision resource identity changed during physics sync")
		return

	var seam_result := _build_and_validate_seam_candidates()
	if not bool(seam_result.get("ok", false)):
		_fail(String(seam_result.get("error", "seam candidate gate failed")))
		return
	var seam_candidates := seam_result.get("candidates", []) as Array
	var central_candidates := _build_central_oblique_candidates()
	if central_candidates.is_empty():
		_fail("no physically targetable central oblique organic triangle was found")
		return

	var selection: Dictionary = await _select_one_camera_probe_group(
		seam_candidates,
		central_candidates
	)
	if not bool(selection.get("ok", false)):
		_fail(String(selection.get("error", "one-camera probe selection failed")))
		return
	var probes := selection.get("probes", []) as Array
	var seam_pairs := selection.get("seam_pairs", []) as Array
	if seam_pairs.size() < MIN_DISTINCT_SEAMS:
		_fail("fewer than three distinct chunk seams were selected")
		return

	await physics_frame
	var frame_one := _capture_strict_camera_hits(probes)
	if not bool(frame_one.get("ok", false)):
		_fail(String(frame_one.get("error", "first stable physics capture failed")))
		return
	await physics_frame
	var frame_two := _capture_strict_camera_hits(probes)
	if not bool(frame_two.get("ok", false)):
		_fail(String(frame_two.get("error", "second stable physics capture failed")))
		return
	var stable_result := _validate_hit_batch_stability(
		frame_one.get("hits", []) as Array,
		frame_two.get("hits", []) as Array
	)
	if not bool(stable_result.get("ok", false)):
		_fail(String(stable_result.get("error", "collision publication was unstable")))
		return

	var wrong_target_probe := probes[0] as Dictionary
	var wrong_projection := _workspace.call(
		"project_workspace_local_to_screen",
		wrong_target_probe.get("target_local", Vector3.ZERO) as Vector3
	) as Dictionary
	var wrong_target_result := _workspace.call(
		"resolve_strict_surface_target",
		wrong_projection.get("screen_position", Vector2.ZERO) as Vector2,
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
		WRONG_TARGET_ID
	) as Dictionary
	if (
		bool(wrong_target_result.get("valid", true))
		or StringName(wrong_target_result.get("reject_reason", StringName()))
		!= ForgeV2WorkspacePreviewScript.REJECT_SURFACE_TARGET_ID_MISMATCH
	):
		_fail("real strict target resolver did not reject a mismatched target ID")
		return

	var feedback_result := _build_and_validate_feedback_sweep(
		probes,
		frame_two.get("hits", []) as Array
	)
	if not bool(feedback_result.get("ok", false)):
		_fail(String(feedback_result.get("error", "feedback sweep gate failed")))
		return

	var selected_seam_labels: Array[String] = []
	for pair_variant: Variant in seam_pairs:
		var pair := pair_variant as Dictionary
		selected_seam_labels.append(String(pair.get("seam_label", "")))
	var output := {
		"schema": "forge_v2_exact_regional_publication_targeting_verifier",
		"schema_version": 1,
		"ok": true,
		"production_ready": false,
		"production_readiness_reason": (
			"verifier-only Godot publication and placement feedback gate; "
			+ "native regional engine publication is not integrated"
		),
		"input_path": INPUT_PATH,
		"publication": {
			"fragment_count": int(_publication_metrics.get("fragment_count", 0)),
			"mesh_instance_count": int(_publication_metrics.get("fragment_count", 0)),
			"static_body_count": int(_publication_metrics.get("fragment_count", 0)),
			"organic_triangle_count": int(_publication_metrics.get(
				"organic_triangle_count", 0
			)),
			"compiler_cap_triangles": int(_publication_metrics.get(
				"compiler_cap_triangle_count", -1
			)),
			"strict_watertight": bool(_publication_topology.get(
				"strict_watertight", false
			)),
			"strict_component_count": int(_publication_topology.get(
				"strict_component_count", -1
			)),
			"strict_boundary_edge_count": int(_publication_topology.get(
				"strict_boundary_edge_count", -1
			)),
			"strict_nonmanifold_edge_count": int(_publication_topology.get(
				"strict_nonmanifold_edge_count", -1
			)),
			"strict_directed_edge_mismatch_count": int(_publication_topology.get(
				"strict_directed_edge_mismatch_count", -1
			)),
			"identity_transforms": true,
			"collision_layer_mask": (
				ForgeV2PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
			),
			"surface_target_id": String(SURFACE_TARGET_ID),
			"logical_body_id": String(LOGICAL_BODY_ID),
			"material_variant_id": String(MATERIAL_VARIANT_ID),
			"all_fragment_resource_identity_stable": true,
		},
		"winding": {
			"source": "Manifold positive",
			"published_indices": "[a,c,b] Godot outward",
			"manifold_signed_volume_m3": float(_publication_metrics.get(
				"manifold_signed_volume_m3", 0.0
			)),
			"godot_signed_volume_m3": float(_publication_metrics.get(
				"godot_signed_volume_m3", 0.0
			)),
			"minimum_physical_normal_dot": float(frame_two.get(
				"minimum_normal_dot", 0.0
			)),
		},
		"seams": {
			"all_adjacent_edge_sets_match": true,
			"adjacent_chunk_pair_count": int(seam_result.get(
				"adjacent_chunk_pair_count", 0
			)),
			"paired_boundary_edge_count": int(seam_result.get(
				"paired_boundary_edge_count", 0
			)),
			"maximum_boundary_edge_gap_meters": float(seam_result.get(
				"maximum_boundary_edge_gap_meters", INF
			)),
			"selected_distinct_seams": selected_seam_labels,
			"selected_pair_count": seam_pairs.size(),
			"minimum_adjacent_normal_dot": float(frame_two.get(
				"minimum_adjacent_normal_dot", 0.0
			)),
		},
		"targeting": {
			"real_forge_v2_placement_target_resolver": true,
			"one_camera": true,
			"physical_probe_count": probes.size(),
			"central_oblique_probe": true,
			"same_target_id_across_fragment_colliders": true,
			"strict_detail_like_identity_across_seams": true,
			"wrong_target_id_rejected": true,
			"minimum_abc_normal_dot_bc": float(frame_two.get(
				"minimum_abc_dot", 0.0
			)),
			"maximum_abc_normal_dot_bc": float(frame_two.get(
				"maximum_abc_dot", 0.0
			)),
			"maximum_hit_position_error_meters": float(frame_two.get(
				"maximum_position_error_meters", INF
			)),
			"two_physics_frame_stable": true,
			"maximum_two_frame_position_delta_meters": float(stable_result.get(
				"maximum_position_delta_meters", INF
			)),
			"minimum_two_frame_normal_dot": float(stable_result.get(
				"minimum_normal_dot", 0.0
			)),
		},
		"feedback_exact_sweep": feedback_result,
	}
	_write_json(output)
	print("Forge V2 exact regional publication targeting verifier passed: %s" % RESULT_PATH)
	quit(0)


func _publish_fragments() -> Dictionary:
	var render_material := StandardMaterial3D.new()
	render_material.albedo_color = Color(0.43, 0.72, 0.67, 1.0)
	render_material.roughness = 0.72
	for packet_index in range(_packets.size()):
		var packet := _packets[packet_index] as Dictionary
		if int(packet.get("compiler_cap_triangles_published", -1)) != 0:
			return {"ok": false, "error": "packet %d publishes compiler caps" % packet_index}
		var coord := _array_to_vector3i(packet.get("chunk_coordinate", []) as Array)
		var coord_key := _coord_key(coord)
		if _packet_by_coord.has(coord_key):
			return {"ok": false, "error": "duplicate packet coordinate %s" % coord_key}
		var vertices_json := packet.get("vertices", []) as Array
		var triangles_json := packet.get("triangles", []) as Array
		if vertices_json.is_empty() or triangles_json.is_empty():
			return {"ok": false, "error": "empty organic packet %s" % coord_key}
		var vertices := PackedVector3Array()
		for vertex_variant: Variant in vertices_json:
			vertices.append(_array_to_vector3(vertex_variant as Array))

		var render_vertices := PackedVector3Array()
		var render_normals := PackedVector3Array()
		var collision_faces := PackedVector3Array()
		var packet_records: Array = []
		for triangle_index in range(triangles_json.size()):
			var triangle := triangles_json[triangle_index] as Dictionary
			var indices := triangle.get("indices", []) as Array
			if indices.size() != 3:
				return {"ok": false, "error": "non-triangle packet face"}
			var index_a := int(indices[0])
			var index_b := int(indices[1])
			var index_c := int(indices[2])
			if (
				index_a < 0 or index_a >= vertices.size()
				or index_b < 0 or index_b >= vertices.size()
				or index_c < 0 or index_c >= vertices.size()
			):
				return {"ok": false, "error": "packet triangle index out of range"}
			var source_original_id := int(triangle.get("source_original_id", -1))
			var source_face_id := int(triangle.get("source_face_id", -1))
			if source_original_id not in [1, 2] or source_face_id < 0:
				return {
					"ok": false,
					"error": "organic packet contains invalid source provenance",
				}
			var point_a := vertices[index_a]
			var point_b := vertices[index_b]
			var point_c := vertices[index_c]
			var cross := (point_b - point_a).cross(point_c - point_a)
			if cross.length_squared() <= 0.0000000000000001:
				return {
					"ok": false,
					"error": (
						"organic packet %d coord %s triangle %d contains a "
						+ "Godot-degenerate face (cross_squared=%s)"
					) % [
						packet_index,
						coord_key,
						triangle_index,
						String.num_scientific(cross.length_squared()),
					],
				}
			var outward := cross.normalized()
			# The native packet is positive Manifold winding.  Forge/Godot emitted
			# meshes use the opposite order, so publish [a,c,b].  Godot's clockwise
			# front face then reports `outward` through the physics ray result.
			for point: Vector3 in [point_a, point_c, point_b]:
				render_vertices.append(point)
				render_normals.append(outward)
				collision_faces.append(point)
			_publication_metrics["manifold_signed_volume_m3"] = (
				float(_publication_metrics["manifold_signed_volume_m3"])
				+ point_a.dot(point_b.cross(point_c)) / 6.0
			)
			_publication_metrics["godot_signed_volume_m3"] = (
				float(_publication_metrics["godot_signed_volume_m3"])
				+ point_a.dot(point_c.cross(point_b)) / 6.0
			)
			var record := {
				"packet_index": packet_index,
				"triangle_index": triangle_index,
				"chunk_coordinate": coord,
				"point_a": point_a,
				"point_b": point_b,
				"point_c": point_c,
				"centroid": (point_a + point_b + point_c) / 3.0,
				"expected_normal_local": outward,
				"minimum_centroid_edge_distance": _minimum_point_edge_distance(
					(point_a + point_b + point_c) / 3.0,
					point_a,
					point_b,
					point_c
				),
				"source_original_id": source_original_id,
				"source_face_id": source_face_id,
			}
			packet_records.append(record)
			_triangle_records.append(record)

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = render_vertices
		arrays[Mesh.ARRAY_NORMAL] = render_normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, render_material)
		_publication_meshes.append(mesh)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "OrganicMesh_%s" % coord_key
		mesh_instance.mesh = mesh
		mesh_instance.set_meta("forge_v2_surface_target_id", SURFACE_TARGET_ID)
		mesh_instance.set_meta("forge_v2_body_id", LOGICAL_BODY_ID)
		mesh_instance.set_meta("forge_v2_material_variant_id", MATERIAL_VARIANT_ID)
		mesh_instance.set_meta("forge_v2_chunk_coordinate", coord)
		_publication_root.add_child(mesh_instance)

		var static_body := StaticBody3D.new()
		static_body.name = "OrganicCollider_%s" % coord_key
		static_body.collision_layer = (
			ForgeV2PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		)
		static_body.collision_mask = 0
		static_body.set_meta("forge_v2_surface_target_id", SURFACE_TARGET_ID)
		static_body.set_meta("forge_v2_body_id", LOGICAL_BODY_ID)
		static_body.set_meta("forge_v2_material_variant_id", MATERIAL_VARIANT_ID)
		static_body.set_meta("forge_v2_chunk_coordinate", coord)
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "OrganicOnlyConcaveShape"
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = false
		concave.set_faces(collision_faces)
		collision_shape.shape = concave
		static_body.add_child(collision_shape)
		_publication_root.add_child(static_body)

		if (
			not mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY)
			or not static_body.transform.is_equal_approx(Transform3D.IDENTITY)
			or not collision_shape.transform.is_equal_approx(Transform3D.IDENTITY)
		):
			return {"ok": false, "error": "fragment publication used a non-identity transform"}
		for record_variant: Variant in packet_records:
			var record := record_variant as Dictionary
			record["collider"] = static_body
		_packet_by_coord[coord_key] = {
			"coordinate": coord,
			"records": packet_records,
			"mesh_instance": mesh_instance,
			"static_body": static_body,
		}
		_publication_metrics["fragment_count"] = (
			int(_publication_metrics["fragment_count"]) + 1
		)
		_publication_metrics["organic_triangle_count"] = (
			int(_publication_metrics["organic_triangle_count"])
			+ triangles_json.size()
		)
		_publication_metrics["compiler_cap_triangle_count"] = (
			int(_publication_metrics["compiler_cap_triangle_count"])
			+ int(packet.get("compiler_cap_triangles_published", 0))
		)
	return {"ok": true}


func _snapshot_publication_identity() -> Dictionary:
	var snapshot := {}
	var coordinate_keys := _packet_by_coord.keys()
	coordinate_keys.sort()
	for coordinate_key_variant: Variant in coordinate_keys:
		var coordinate_key := String(coordinate_key_variant)
		var packet := _packet_by_coord[coordinate_key] as Dictionary
		var mesh_instance := packet.get("mesh_instance", null) as MeshInstance3D
		var static_body := packet.get("static_body", null) as StaticBody3D
		var collision_shape := static_body.get_node_or_null(
			"OrganicOnlyConcaveShape"
		) as CollisionShape3D
		var shape_resource := collision_shape.shape if collision_shape != null else null
		snapshot[coordinate_key] = {
			"mesh_instance_id": mesh_instance.get_instance_id() if mesh_instance != null else 0,
			"mesh_resource_id": (
				mesh_instance.mesh.get_instance_id()
				if mesh_instance != null and mesh_instance.mesh != null
				else 0
			),
			"static_body_id": static_body.get_instance_id() if static_body != null else 0,
			"collision_shape_id": (
				collision_shape.get_instance_id() if collision_shape != null else 0
			),
			"shape_resource_id": (
				shape_resource.get_instance_id() if shape_resource != null else 0
			),
		}
	return snapshot


func _build_and_validate_seam_candidates() -> Dictionary:
	var candidates: Array = []
	var adjacent_chunk_pair_count := 0
	var paired_boundary_edge_count := 0
	var maximum_boundary_edge_gap := 0.0
	for packet_key_variant: Variant in _packet_by_coord.keys():
		var packet_key := String(packet_key_variant)
		var packet := _packet_by_coord[packet_key] as Dictionary
		var low_coord := packet.get("coordinate", Vector3i.ZERO) as Vector3i
		for axis in range(3):
			var high_coord := low_coord
			high_coord[axis] += 1
			var high_key := _coord_key(high_coord)
			if not _packet_by_coord.has(high_key):
				continue
			adjacent_chunk_pair_count += 1
			var high_packet := _packet_by_coord[high_key] as Dictionary
			var plane := float(high_coord[axis]) * CHUNK_SIZE_METERS
			var low_edges := _collect_packet_plane_edges(packet, axis, plane)
			var high_edges := _collect_packet_plane_edges(high_packet, axis, plane)
			if low_edges.is_empty() and high_edges.is_empty():
				continue
			var low_keys := low_edges.keys()
			var high_keys := high_edges.keys()
			low_keys.sort()
			high_keys.sort()
			if low_keys != high_keys:
				return {
					"ok": false,
					"error": (
						"organic seam edge sets differ at %s -> %s axis %d"
						% [packet_key, high_key, axis]
					),
				}
			var seam_label := "%s|%s|axis_%d|%.9f" % [
				packet_key,
				high_key,
				axis,
				plane,
			]
			for edge_key_variant: Variant in low_keys:
				var edge_key := String(edge_key_variant)
				var low_edge := (low_edges[edge_key] as Array)[0] as Dictionary
				var high_edge := (high_edges[edge_key] as Array)[0] as Dictionary
				var edge_gap := _paired_edge_gap(low_edge, high_edge)
				maximum_boundary_edge_gap = maxf(maximum_boundary_edge_gap, edge_gap)
				if edge_gap > SEAM_GAP_TOLERANCE_METERS:
					return {"ok": false, "error": "organic chunk seam contains a geometric gap"}
				paired_boundary_edge_count += 1
				var candidate := _build_seam_probe_pair(
					low_edge,
					high_edge,
					axis,
					plane,
					seam_label
				)
				if candidate.is_empty():
					continue
				var low_probe := candidate.get("low_probe", {}) as Dictionary
				var high_probe := candidate.get("high_probe", {}) as Dictionary
				var low_direct := _validate_direct_physics_probe(low_probe)
				var high_direct := _validate_direct_physics_probe(high_probe)
				if not bool(low_direct.get("ok", false)) or not bool(high_direct.get("ok", false)):
					continue
				candidate["low_direct_hit"] = low_direct.get("hit", {})
				candidate["high_direct_hit"] = high_direct.get("hit", {})
				candidates.append(candidate)
	if adjacent_chunk_pair_count <= 0 or paired_boundary_edge_count <= 0:
		return {"ok": false, "error": "no populated adjacent chunk seam was proven"}
	var distinct_seams := {}
	for candidate_variant: Variant in candidates:
		var candidate := candidate_variant as Dictionary
		distinct_seams[String(candidate.get("seam_label", ""))] = true
	if distinct_seams.size() < MIN_DISTINCT_SEAMS:
		return {"ok": false, "error": "fewer than three seams have physical probe pairs"}
	return {
		"ok": true,
		"candidates": candidates,
		"adjacent_chunk_pair_count": adjacent_chunk_pair_count,
		"paired_boundary_edge_count": paired_boundary_edge_count,
		"maximum_boundary_edge_gap_meters": maximum_boundary_edge_gap,
	}


func _collect_packet_plane_edges(
	packet: Dictionary,
	axis: int,
	plane: float
) -> Dictionary:
	var edges := {}
	for record_variant: Variant in packet.get("records", []) as Array:
		var record := record_variant as Dictionary
		var points: Array[Vector3] = [
			record.get("point_a", Vector3.ZERO) as Vector3,
			record.get("point_b", Vector3.ZERO) as Vector3,
			record.get("point_c", Vector3.ZERO) as Vector3,
		]
		for edge_index in range(3):
			var first := points[edge_index]
			var second := points[(edge_index + 1) % 3]
			var third := points[(edge_index + 2) % 3]
			if (
				absf(_component(first, axis) - plane) > PLANE_TOLERANCE_METERS
				or absf(_component(second, axis) - plane) > PLANE_TOLERANCE_METERS
				or absf(_component(third, axis) - plane) <= PLANE_TOLERANCE_METERS
			):
				continue
			var key := _edge_key(first, second)
			if not edges.has(key):
				edges[key] = []
			(edges[key] as Array).append({
				"first": first,
				"second": second,
				"third": third,
				"record": record,
			})
	return edges


func _build_seam_probe_pair(
	low_edge: Dictionary,
	high_edge: Dictionary,
	axis: int,
	plane: float,
	seam_label: String
) -> Dictionary:
	var low_first := low_edge.get("first", Vector3.ZERO) as Vector3
	var low_second := low_edge.get("second", Vector3.ZERO) as Vector3
	var low_third := low_edge.get("third", Vector3.ZERO) as Vector3
	var high_first := high_edge.get("first", Vector3.ZERO) as Vector3
	var high_second := high_edge.get("second", Vector3.ZERO) as Vector3
	var high_third := high_edge.get("third", Vector3.ZERO) as Vector3
	var low_offset := plane - _component(low_third, axis)
	var high_offset := _component(high_third, axis) - plane
	if low_offset <= 0.0 or high_offset <= 0.0:
		return {}
	var low_probe_position := (low_first + low_second) * 0.425 + low_third * 0.15
	var high_probe_position := (high_first + high_second) * 0.425 + high_third * 0.15
	if (
		plane - _component(low_probe_position, axis) < MIN_SEAM_PROBE_OFFSET_METERS
		or _component(high_probe_position, axis) - plane < MIN_SEAM_PROBE_OFFSET_METERS
	):
		return {}
	var low_record := low_edge.get("record", {}) as Dictionary
	var high_record := high_edge.get("record", {}) as Dictionary
	var low_normal := low_record.get("expected_normal_local", Vector3.ZERO) as Vector3
	var high_normal := high_record.get("expected_normal_local", Vector3.ZERO) as Vector3
	if low_normal.dot(high_normal) < ADJACENT_NORMAL_DOT_MIN:
		return {}
	var low_probe := _probe_from_record(low_record, low_probe_position, "seam_low")
	var high_probe := _probe_from_record(high_record, high_probe_position, "seam_high")
	if (
		float(low_probe.get("edge_clearance_meters", 0.0))
		< MIN_PROBE_EDGE_CLEARANCE_METERS
		or float(high_probe.get("edge_clearance_meters", 0.0))
		< MIN_PROBE_EDGE_CLEARANCE_METERS
	):
		return {}
	return {
		"seam_label": seam_label,
		"axis": axis,
		"plane": plane,
		"edge_key": _edge_key(low_first, low_second),
		"edge_length_meters": low_first.distance_to(low_second),
		"low_probe": low_probe,
		"high_probe": high_probe,
		"average_normal": (low_normal + high_normal).normalized(),
		"adjacent_normal_dot": low_normal.dot(high_normal),
	}


func _build_central_oblique_candidates() -> Array:
	var bounds_center := Vector3(0.0015, 0.0026, 0.0107)
	var candidates: Array = []
	for record_variant: Variant in _triangle_records:
		var record := record_variant as Dictionary
		var centroid := record.get("centroid", Vector3.ZERO) as Vector3
		var normal := record.get("expected_normal_local", Vector3.ZERO) as Vector3
		var axis_max := maxf(absf(normal.x), maxf(absf(normal.y), absf(normal.z)))
		if (
			absf(centroid.x - bounds_center.x) > 0.040
			or axis_max >= MIN_OBLIQUE_AXIS_COMPONENT_MAX
			or float(record.get("minimum_centroid_edge_distance", 0.0))
			< MIN_PROBE_EDGE_CLEARANCE_METERS
			or _distance_to_nearest_chunk_plane(centroid) < 0.00030
		):
			continue
		var probe := _probe_from_record(record, centroid, "central_oblique")
		var direct_result := _validate_direct_physics_probe(probe)
		if not bool(direct_result.get("ok", false)):
			continue
		probe["center_distance_meters"] = centroid.distance_to(bounds_center)
		probe["direct_hit"] = direct_result.get("hit", {})
		candidates.append(probe)
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("center_distance_meters", INF)) < float(
			second.get("center_distance_meters", INF)
		)
	)
	return candidates


func _select_one_camera_probe_group(
	seam_candidates: Array,
	central_candidates: Array
) -> Dictionary:
	var attempts := 0
	for seed_variant: Variant in seam_candidates:
		if attempts >= MAX_CAMERA_GROUP_ATTEMPTS:
			break
		attempts += 1
		var seed := seed_variant as Dictionary
		var seed_normal := seed.get("average_normal", Vector3.ZERO) as Vector3
		if seed_normal.length_squared() <= 0.9:
			continue
		var seed_center := _seam_pair_center(seed)
		var best_by_seam := {}
		for pair_variant: Variant in seam_candidates:
			var pair := pair_variant as Dictionary
			var label := String(pair.get("seam_label", ""))
			var pair_normal := pair.get("average_normal", Vector3.ZERO) as Vector3
			var normal_dot := seed_normal.dot(pair_normal)
			if normal_dot < 0.94:
				continue
			var score := (
				seed_center.distance_to(_seam_pair_center(pair))
				+ (1.0 - normal_dot) * 0.10
			)
			if (
				not best_by_seam.has(label)
				or score < float((best_by_seam[label] as Dictionary).get("score", INF))
			):
				best_by_seam[label] = {"pair": pair, "score": score}
		var ranked_pairs: Array = best_by_seam.values()
		ranked_pairs.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
			return float(first.get("score", INF)) < float(second.get("score", INF))
		)
		var compatible_pairs: Array = []
		for ranked_variant: Variant in ranked_pairs:
			compatible_pairs.append((ranked_variant as Dictionary).get("pair", {}) as Dictionary)
			if compatible_pairs.size() >= 8:
				break
		if compatible_pairs.size() < MIN_DISTINCT_SEAMS:
			continue
		var central := {}
		for central_variant: Variant in central_candidates:
			var candidate := central_variant as Dictionary
			var candidate_normal := candidate.get(
				"expected_normal_local", Vector3.ZERO
			) as Vector3
			if seed_normal.dot(candidate_normal) >= 0.94:
				central = candidate
				break
		if central.is_empty():
			continue
		var group_probes: Array = []
		for pair_variant: Variant in compatible_pairs:
			var pair := pair_variant as Dictionary
			group_probes.append(pair.get("low_probe", {}) as Dictionary)
			group_probes.append(pair.get("high_probe", {}) as Dictionary)
		group_probes.append(central)
		_aim_one_camera(group_probes)
		await process_frame
		var visible_pairs: Array = []
		var visible_probes: Array = []
		for pair_variant: Variant in compatible_pairs:
			var pair := pair_variant as Dictionary
			var low_probe := pair.get("low_probe", {}) as Dictionary
			var high_probe := pair.get("high_probe", {}) as Dictionary
			if (
				_camera_probe_is_exact(low_probe)
				and _camera_probe_is_exact(high_probe)
			):
				visible_pairs.append(pair)
				visible_probes.append(low_probe)
				visible_probes.append(high_probe)
				if visible_pairs.size() >= MIN_DISTINCT_SEAMS:
					break
		if visible_pairs.size() < MIN_DISTINCT_SEAMS:
			continue
		if not _camera_probe_is_exact(central):
			continue
		visible_probes.append(central)
		# Re-aim only once, using the exact selected subset, and require that the
		# same subset remains visible.  This is the single camera used by the gate.
		_aim_one_camera(visible_probes)
		await process_frame
		var final_visible := true
		for probe_variant: Variant in visible_probes:
			if not _camera_probe_is_exact(probe_variant as Dictionary):
				final_visible = false
				break
		if final_visible:
			return {
				"ok": true,
				"probes": visible_probes,
				"seam_pairs": visible_pairs,
				"camera_attempt_count": attempts,
			}
	return {
		"ok": false,
		"error": (
			"one real camera could not see exact organic probes on three seams "
			+ "and the central oblique surface"
		),
	}


func _seam_pair_center(pair: Dictionary) -> Vector3:
	var low_probe := pair.get("low_probe", {}) as Dictionary
	var high_probe := pair.get("high_probe", {}) as Dictionary
	return (
		(low_probe.get("target_local", Vector3.ZERO) as Vector3)
		+ (high_probe.get("target_local", Vector3.ZERO) as Vector3)
	) * 0.5


func _aim_one_camera(probes: Array) -> void:
	var camera := _workspace.get("camera") as Camera3D
	var center := Vector3.ZERO
	var normal_sum := Vector3.ZERO
	for probe_variant: Variant in probes:
		var probe := probe_variant as Dictionary
		center += probe.get("target_local", Vector3.ZERO) as Vector3
		normal_sum += probe.get("expected_normal_local", Vector3.ZERO) as Vector3
	center /= float(probes.size())
	var average_normal := normal_sum.normalized()
	var up := Vector3.UP
	if absf(average_normal.dot(up)) > 0.94:
		up = Vector3.RIGHT
	camera.global_position = _workspace.to_global(
		center + average_normal * CAMERA_DISTANCE_METERS
	)
	camera.look_at(_workspace.to_global(center), up)
	camera.current = true
	camera.near = 0.01
	camera.far = 4.0


func _camera_probe_is_exact(probe: Dictionary) -> bool:
	var projection := _workspace.call(
		"project_workspace_local_to_screen",
		probe.get("target_local", Vector3.ZERO) as Vector3
	) as Dictionary
	if not bool(projection.get("valid", false)):
		return false
	var hit := _workspace.call(
		"resolve_material_surface_target",
		projection.get("screen_position", Vector2.ZERO) as Vector2
	) as Dictionary
	return bool(_validate_resolved_hit(probe, hit).get("ok", false))


func _capture_strict_camera_hits(probes: Array) -> Dictionary:
	var hits: Array = []
	var maximum_position_error := 0.0
	var minimum_normal_dot := 1.0
	var minimum_abc_dot := 1.0
	var maximum_abc_dot := -1.0
	for probe_index in range(probes.size()):
		var probe := probes[probe_index] as Dictionary
		var projection := _workspace.call(
			"project_workspace_local_to_screen",
			probe.get("target_local", Vector3.ZERO) as Vector3
		) as Dictionary
		if not bool(projection.get("valid", false)):
			return {"ok": false, "error": "probe projection became invalid"}
		var hit := _workspace.call(
			"resolve_strict_surface_target",
			projection.get("screen_position", Vector2.ZERO) as Vector2,
			ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
			SURFACE_TARGET_ID
		) as Dictionary
		var validation := _validate_resolved_hit(probe, hit)
		if not bool(validation.get("ok", false)):
			return {
				"ok": false,
				"error": "strict physical hit %d: %s" % [
					probe_index,
					String(validation.get("error", "invalid")),
				],
			}
		maximum_position_error = maxf(
			maximum_position_error,
			float(validation.get("position_error_meters", INF))
		)
		minimum_normal_dot = minf(
			minimum_normal_dot,
			float(validation.get("normal_dot", 0.0))
		)
		var abc_dot := float(validation.get("abc_dot", 1.0))
		minimum_abc_dot = minf(minimum_abc_dot, abc_dot)
		maximum_abc_dot = maxf(maximum_abc_dot, abc_dot)
		hits.append(hit)
	var minimum_adjacent_normal_dot := 1.0
	for probe_index in range(0, probes.size() - 1, 2):
		if String((probes[probe_index] as Dictionary).get("probe_kind", "")) != "seam_low":
			break
		var first_normal := (
			(hits[probe_index] as Dictionary).get("local_normal", Vector3.ZERO) as Vector3
		).normalized()
		var second_normal := (
			(hits[probe_index + 1] as Dictionary).get("local_normal", Vector3.ZERO) as Vector3
		).normalized()
		var adjacent_dot := first_normal.dot(second_normal)
		minimum_adjacent_normal_dot = minf(minimum_adjacent_normal_dot, adjacent_dot)
		if adjacent_dot < ADJACENT_NORMAL_DOT_MIN:
			return {"ok": false, "error": "physical normals are discontinuous across seam"}
	return {
		"ok": true,
		"hits": hits,
		"maximum_position_error_meters": maximum_position_error,
		"minimum_normal_dot": minimum_normal_dot,
		"minimum_abc_dot": minimum_abc_dot,
		"maximum_abc_dot": maximum_abc_dot,
		"minimum_adjacent_normal_dot": minimum_adjacent_normal_dot,
	}


func _validate_resolved_hit(probe: Dictionary, hit: Dictionary) -> Dictionary:
	if not bool(hit.get("valid", false)):
		return {"ok": false, "error": "resolver returned invalid"}
	var expected_collider := probe.get("collider", null) as Object
	var actual_collider := hit.get("collider", null) as Object
	var expected_position := probe.get("target_local", Vector3.ZERO) as Vector3
	var actual_position := hit.get("local_position", Vector3.ZERO) as Vector3
	var expected_normal := (
		probe.get("expected_normal_local", Vector3.ZERO) as Vector3
	).normalized()
	var actual_normal := (
		hit.get("local_normal", Vector3.ZERO) as Vector3
	).normalized()
	var contact := (
		hit.get("local_contact_direction", Vector3.ZERO) as Vector3
	).normalized()
	var position_error := expected_position.distance_to(actual_position)
	var normal_dot := expected_normal.dot(actual_normal)
	var abc_dot := actual_normal.dot(contact)
	if actual_collider != expected_collider:
		return {"ok": false, "error": "camera ray hit a different fragment collider"}
	if position_error > HIT_POSITION_TOLERANCE_METERS:
		return {"ok": false, "error": "camera ray missed the interior triangle probe"}
	if normal_dot < NORMAL_DOT_MIN:
		return {"ok": false, "error": "Godot physical normal lost packet outward winding"}
	if abc_dot > ABC_DOT_MAX:
		return {"ok": false, "error": "ABC contact direction is not inward"}
	if (
		StringName(hit.get("surface_target_id", StringName())) != SURFACE_TARGET_ID
		or StringName(hit.get("source_body_id", StringName())) != LOGICAL_BODY_ID
		or StringName(hit.get("source_record_id", StringName()))
		!= MATERIAL_VARIANT_ID
		or StringName(hit.get("target_kind", StringName()))
		!= ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
		or bool(hit.get("is_clamped", true))
	):
		return {"ok": false, "error": "logical workpiece metadata was not shared"}
	return {
		"ok": true,
		"position_error_meters": position_error,
		"normal_dot": normal_dot,
		"abc_dot": abc_dot,
	}


func _validate_hit_batch_stability(first: Array, second: Array) -> Dictionary:
	if first.size() != second.size() or first.is_empty():
		return {"ok": false, "error": "physics hit batch sizes differ"}
	var maximum_position_delta := 0.0
	var minimum_normal_dot := 1.0
	for hit_index in range(first.size()):
		var first_hit := first[hit_index] as Dictionary
		var second_hit := second[hit_index] as Dictionary
		var first_collider := first_hit.get("collider", null) as Object
		var second_collider := second_hit.get("collider", null) as Object
		var position_delta := (
			(first_hit.get("local_position", Vector3.ZERO) as Vector3).distance_to(
				second_hit.get("local_position", Vector3.ZERO) as Vector3
			)
		)
		var normal_dot := (
			(first_hit.get("local_normal", Vector3.ZERO) as Vector3).normalized().dot(
				(second_hit.get("local_normal", Vector3.ZERO) as Vector3).normalized()
			)
		)
		maximum_position_delta = maxf(maximum_position_delta, position_delta)
		minimum_normal_dot = minf(minimum_normal_dot, normal_dot)
		if (
			first_collider != second_collider
			or StringName(first_hit.get("surface_target_id", StringName()))
			!= StringName(second_hit.get("surface_target_id", StringName()))
			or position_delta > STABLE_POSITION_TOLERANCE_METERS
			or normal_dot < NORMAL_DOT_MIN
		):
			return {"ok": false, "error": "fragment collision changed between physics frames"}
	return {
		"ok": true,
		"maximum_position_delta_meters": maximum_position_delta,
		"minimum_normal_dot": minimum_normal_dot,
	}


func _build_and_validate_feedback_sweep(probes: Array, hits: Array) -> Dictionary:
	if probes.size() != hits.size() or hits.size() < 7:
		return {"ok": false, "error": "feedback sweep lacks physical hit triples"}
	var ordered: Array = []
	for index in range(hits.size()):
		ordered.append({"probe": probes[index], "hit": hits[index]})
	ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var first_position := (
			(first.get("hit", {}) as Dictionary).get("local_position", Vector3.ZERO)
			as Vector3
		)
		var second_position := (
			(second.get("hit", {}) as Dictionary).get("local_position", Vector3.ZERO)
			as Vector3
		)
		if not is_equal_approx(first_position.x, second_position.x):
			return first_position.x < second_position.x
		if not is_equal_approx(first_position.y, second_position.y):
			return first_position.y < second_position.y
		return first_position.z < second_position.z
	)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for entry_variant: Variant in ordered:
		var entry := entry_variant as Dictionary
		var hit := entry.get("hit", {}) as Dictionary
		positions.append(hit.get("local_position", Vector3.ZERO) as Vector3)
		normals.append(
			(hit.get("local_normal", Vector3.ZERO) as Vector3).normalized()
		)
		contacts.append(
			(hit.get("local_contact_direction", Vector3.ZERO) as Vector3).normalized()
		)
	var profile := _build_asymmetric_feedback_profile()
	if profile.is_empty():
		return {"ok": false, "error": "asymmetric feedback profile could not compile"}
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", &"exact_regional_publication_feedback_sweep")
	body.set("source_record_id", &"exact_regional_publication_feedback_source")
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_DETAILING_BRUSH)
	body.set("material_variant_id", MATERIAL_VARIANT_ID)
	body.set("shape_kind", ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
	body.set("path_points", positions)
	body.set("path_surface_normals", normals)
	body.set("path_contact_directions", contacts)
	body.set(
		"surface_target_kind",
		ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
	)
	body.set("surface_target_id", SURFACE_TARGET_ID)
	body.set("profile_id", profile.get("profile_id", StringName()))
	body.set("profile_display_name", "Exact regional feedback profile")
	body.set("profile_polygon_2d_meters", profile.get(
		"deposition_polygon", PackedVector2Array()
	))
	body.set("profile_anchor_2d_meters", profile.get("anchor", Vector2.ZERO))
	body.set("profile_contact_point_relative_2d_meters", profile.get(
		"contact_point_relative", Vector2.ZERO
	))
	body.set("profile_contact_direction_2d", profile.get(
		"contact_direction", Vector2.DOWN
	))
	body.set("profile_contact_distance_meters", float(profile.get(
		"contact_distance_meters", 0.0
	)))
	body.set("profile_runtime_schema_version", 1)
	body.set("profile_rotation_bias_degrees", 13.0)
	body.call("normalize")
	if not bool(body.call("uses_explicit_surface_contact_authority")):
		return {"ok": false, "error": "feedback body lost explicit ABC authority"}
	if StringName(body.get("surface_target_id")) != SURFACE_TARGET_ID:
		return {"ok": false, "error": "Detail-like feedback body lost strict target ID"}
	var retained_positions := body.get("path_points") as PackedVector3Array
	var retained_normals := body.get("path_surface_normals") as PackedVector3Array
	var retained_contacts := body.get("path_contact_directions") as PackedVector3Array
	if (
		retained_positions.size() != positions.size()
		or retained_normals.size() != normals.size()
		or retained_contacts.size() != contacts.size()
	):
		return {"ok": false, "error": "feedback body did not retain every hit triple"}
	for point_index in range(positions.size()):
		if (
			retained_positions[point_index].distance_to(positions[point_index])
			> STABLE_POSITION_TOLERANCE_METERS
			or retained_normals[point_index].dot(normals[point_index]) < NORMAL_DOT_MIN
			or retained_contacts[point_index].dot(contacts[point_index]) < NORMAL_DOT_MIN
			or retained_normals[point_index].dot(retained_contacts[point_index])
			> ABC_DOT_MAX
		):
			return {"ok": false, "error": "feedback body rewrote hit triple %d" % point_index}
	var presenter := _workspace.get("volume_preview_presenter") as Node3D
	if presenter == null:
		presenter = ForgeV2VolumePreviewPresenterScript.new()
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	if mesh == null or mesh.get_surface_count() <= 0:
		return {"ok": false, "error": "existing exact Forge sweep builder returned empty"}
	var analysis := ForgeV2WorkpieceBenchmarkMeshAnalyzerScript.analyze_mesh(mesh)
	if (
		int(analysis.get("triangle_count", 0)) <= 0
		or int(analysis.get("nonfinite_vertex_count", -1)) != 0
		or int(analysis.get("boundary_edge_count", -1)) != 0
		or int(analysis.get("nonmanifold_edge_count", -1)) != 0
	):
		return {"ok": false, "error": "feedback exact sweep is not finite and watertight"}
	var polygon := body.get("profile_polygon_2d_meters") as PackedVector2Array
	var minimum_outward_extent := INF
	var maximum_buried_depth := 0.0
	var minimum_exterior_ratio := 1.0
	for point_index in range(positions.size()):
		var tangent := ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
			positions,
			point_index
		)
		var ring := presenter.call(
			"_build_profile_sweep_ring",
			body,
			polygon,
			point_index,
			tangent
		) as PackedVector3Array
		if ring.size() != polygon.size():
			return {"ok": false, "error": "feedback exact sweep ring was incomplete"}
		var outward := normals[point_index]
		var maximum_signed := -INF
		var minimum_signed := INF
		var exterior_count := 0
		var signed_sum := 0.0
		for vertex: Vector3 in ring:
			var signed_distance := (vertex - positions[point_index]).dot(outward)
			maximum_signed = maxf(maximum_signed, signed_distance)
			minimum_signed = minf(minimum_signed, signed_distance)
			signed_sum += signed_distance
			if signed_distance > 0.0004:
				exterior_count += 1
		var exterior_ratio := float(exterior_count) / float(ring.size())
		minimum_outward_extent = minf(minimum_outward_extent, maximum_signed)
		maximum_buried_depth = maxf(maximum_buried_depth, maxf(-minimum_signed, 0.0))
		minimum_exterior_ratio = minf(minimum_exterior_ratio, exterior_ratio)
		if (
			maximum_signed < 0.012
			or minimum_signed < -0.0015
			or signed_sum / float(ring.size()) < 0.004
			or exterior_ratio < 0.60
		):
			return {
				"ok": false,
				"error": "feedback profile was buried at physical hit %d" % point_index,
			}
	return {
		"built_with_existing_exact_sweep_builder": true,
		"returned_B_raw_normal_BC_triplets_retained": true,
		"physical_hit_triple_count": positions.size(),
		"triangle_count": int(analysis.get("triangle_count", 0)),
		"boundary_edge_count": int(analysis.get("boundary_edge_count", -1)),
		"nonmanifold_edge_count": int(analysis.get("nonmanifold_edge_count", -1)),
		"minimum_outward_extent_meters": minimum_outward_extent,
		"maximum_buried_depth_meters": maximum_buried_depth,
		"minimum_exterior_vertex_ratio": minimum_exterior_ratio,
		"meaningful_exterior_profile_extent": true,
		"boolean_commit_attempted": false,
	}


func _build_asymmetric_feedback_profile() -> Dictionary:
	var base_polygon := PackedVector2Array()
	for point_index in range(21):
		var theta := TAU * float(point_index) / 21.0
		var radial_bias := 1.0 + 0.10 * sin(theta) + 0.05 * cos(3.0 * theta)
		base_polygon.append(Vector2(
			0.0085 * radial_bias * cos(theta) + 0.0005 * sin(2.0 * theta),
			0.0140 * (1.0 + 0.04 * cos(theta)) * sin(theta)
		))
	var clearance := ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
		Vector2(0.0, -1.0),
		base_polygon,
		0.0008
	)
	if not bool(clearance.get("valid", false)):
		return {}
	var anchor := clearance.get("point", Vector2.ZERO) as Vector2
	var contact := ForgeV2ProfileShapeLibraryScript.resolve_profile_anchor_contact(
		base_polygon,
		anchor
	)
	if not bool(contact.get("valid", false)):
		return {}
	var deposition_polygon := PackedVector2Array()
	for point: Vector2 in base_polygon:
		deposition_polygon.append(point - anchor)
	var contact_point := contact.get("point", anchor) as Vector2
	return {
		"profile_id": &"exact_regional_feedback_asymmetric_21",
		"deposition_polygon": deposition_polygon,
		"anchor": anchor,
		"contact_point_relative": contact_point - anchor,
		"contact_direction": contact.get("direction", Vector2.DOWN) as Vector2,
		"contact_distance_meters": float(contact.get("distance_meters", 0.0)),
	}


func _validate_direct_physics_probe(probe: Dictionary) -> Dictionary:
	var target := probe.get("target_local", Vector3.ZERO) as Vector3
	var expected_normal := (
		probe.get("expected_normal_local", Vector3.ZERO) as Vector3
	).normalized()
	var ray_start := _workspace.to_global(target + expected_normal * DIRECT_RAY_OFFSET_METERS)
	var ray_end := _workspace.to_global(target - expected_normal * DIRECT_RAY_OFFSET_METERS)
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		ForgeV2PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _workspace.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"ok": false, "error": "short physical ray missed"}
	var hit_position := _workspace.to_local(hit.get("position", Vector3.ZERO) as Vector3)
	var hit_normal := (
		_workspace.global_transform.basis.inverse()
		* (hit.get("normal", Vector3.ZERO) as Vector3)
	).normalized()
	if (
		hit.get("collider", null) as Object != probe.get("collider", null) as Object
		or hit_position.distance_to(target) > HIT_POSITION_TOLERANCE_METERS
		or hit_normal.dot(expected_normal) < NORMAL_DOT_MIN
	):
		return {"ok": false, "error": "short physical ray lost position/winding"}
	return {"ok": true, "hit": hit}


func _probe_from_record(record: Dictionary, position: Vector3, kind: String) -> Dictionary:
	return {
		"probe_kind": kind,
		"target_local": position,
		"expected_normal_local": record.get("expected_normal_local", Vector3.ZERO),
		"collider": record.get("collider", null),
		"chunk_coordinate": record.get("chunk_coordinate", Vector3i.ZERO),
		"triangle_index": record.get("triangle_index", -1),
		"edge_clearance_meters": _minimum_point_edge_distance(
			position,
			record.get("point_a", Vector3.ZERO) as Vector3,
			record.get("point_b", Vector3.ZERO) as Vector3,
			record.get("point_c", Vector3.ZERO) as Vector3
		),
	}


func _minimum_point_edge_distance(
	point: Vector3,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3
) -> float:
	return minf(
		Geometry3D.get_closest_point_to_segment(point, point_a, point_b).distance_to(point),
		minf(
			Geometry3D.get_closest_point_to_segment(point, point_b, point_c).distance_to(point),
			Geometry3D.get_closest_point_to_segment(point, point_c, point_a).distance_to(point)
		)
	)


func _paired_edge_gap(first: Dictionary, second: Dictionary) -> float:
	var first_a := first.get("first", Vector3.ZERO) as Vector3
	var first_b := first.get("second", Vector3.ZERO) as Vector3
	var second_a := second.get("first", Vector3.ZERO) as Vector3
	var second_b := second.get("second", Vector3.ZERO) as Vector3
	return minf(
		maxf(first_a.distance_to(second_a), first_b.distance_to(second_b)),
		maxf(first_a.distance_to(second_b), first_b.distance_to(second_a))
	)


func _distance_to_nearest_chunk_plane(point: Vector3) -> float:
	var minimum_distance := INF
	for component: float in [point.x, point.y, point.z]:
		var scaled := component / CHUNK_SIZE_METERS
		minimum_distance = minf(
			minimum_distance,
			absf(scaled - roundf(scaled)) * CHUNK_SIZE_METERS
		)
	return minimum_distance


func _edge_key(first: Vector3, second: Vector3) -> String:
	var first_key := _vector_key(first)
	var second_key := _vector_key(second)
	return "%s|%s" % [first_key, second_key] if first_key < second_key else "%s|%s" % [second_key, first_key]


func _vector_key(value: Vector3) -> String:
	return "%d,%d,%d" % [
		int(round(value.x * 10000000.0)),
		int(round(value.y * 10000000.0)),
		int(round(value.z * 10000000.0)),
	]


func _coord_key(coord: Vector3i) -> String:
	return "%d,%d,%d" % [coord.x, coord.y, coord.z]


func _component(value: Vector3, axis: int) -> float:
	match axis:
		0:
			return value.x
		1:
			return value.y
		_:
			return value.z


func _array_to_vector3(values: Array) -> Vector3:
	if values.size() != 3:
		return Vector3.ZERO
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


func _array_to_vector3i(values: Array) -> Vector3i:
	if values.size() != 3:
		return Vector3i.ZERO
	return Vector3i(int(values[0]), int(values[1]), int(values[2]))


func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed as Dictionary if parsed is Dictionary else {}


func _fail(message: String) -> void:
	_write_json({
		"schema": "forge_v2_exact_regional_publication_targeting_verifier",
		"schema_version": 1,
		"ok": false,
		"production_ready": false,
		"input_path": INPUT_PATH,
		"error": message,
	})
	push_error(message)
	quit(1)


func _write_json(payload: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("could not write verifier result: %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t", true, true) + "\n")
	file.close()
