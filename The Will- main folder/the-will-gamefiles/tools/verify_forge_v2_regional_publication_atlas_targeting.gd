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
	"C:/WORKSPACE/godot_runs/forge_v2_regional_publication_atlas_prototype.json"
)
const EXPECTED_INPUT_SHA256 := (
	"9D5E3D4D3FFBE41A792CB12DE37BA206BEC063C9344C34CE28D5FD3D8A10D012"
)
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_regional_publication_atlas_targeting_2026-08-15_run2.json"
)

const EXPECTED_PAGE_COUNT := 27
const EXPECTED_TRIANGLE_COUNT := 1726
const EXPECTED_ATOM_COUNT := 1603
const TRIANGLE_CROSS_SQUARED_MIN := 0.0000000000000001
const WELD_QUANTUM_METERS := 0.0000001
const EXACT_EDGE_QUANTUM_METERS := 0.00000001
const SURFACE_TARGET_ID := &"forge_v2_regional_publication_atlas_target_v1"
const LOGICAL_BODY_ID := &"forge_v2_regional_publication_atlas_workpiece_v1"
const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const CLEAN_SOURCE_ORIGINAL_ID := 1
const DIRTY_SOURCE_ORIGINAL_ID := 2
const MIN_PAGE_SEAM_PAIRS := 3
const MIN_DIRTY_CLEAN_PAIRS := 3
const HIT_POSITION_TOLERANCE_METERS := 0.00020
const STABLE_POSITION_TOLERANCE_METERS := 0.00001
const NORMAL_DOT_MIN := 0.999
const ABC_DOT_MAX := -0.999
const MIN_PROBE_EDGE_CLEARANCE_METERS := 0.00004
const DIRECT_RAY_OFFSET_METERS := 0.003

var _artifact: Dictionary = {}
var _workspace: Node3D = null
var _staged_root: Node3D = null
var _pages: Array = []
var _page_records: Array = []
var _triangle_records: Array = []
var _publication_meshes: Array[ArrayMesh] = []
var _revision_id := StringName()
var _publication_metrics := {
	"page_count": 0,
	"triangle_count": 0,
	"atom_count": 0,
	"minimum_cross_squared": INF,
	"manifold_signed_volume_m3": 0.0,
	"godot_signed_volume_m3": 0.0,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var actual_sha256 := FileAccess.get_sha256(INPUT_PATH).to_upper()
	if actual_sha256 != EXPECTED_INPUT_SHA256:
		_fail("publication atlas artifact SHA256 changed")
		return
	_artifact = _read_json_dictionary(INPUT_PATH)
	if _artifact.is_empty():
		_fail("publication atlas artifact could not be read")
		return
	if (
		String(_artifact.get("outcome", "")) != "pass"
		or not bool(_artifact.get("proof_passed", false))
		or bool(_artifact.get("production_ready", true))
	):
		_fail("publication atlas artifact is not the passing tools-only proof")
		return
	var hard_gates := _artifact.get("hard_gates", {}) as Dictionary
	for gate_name: String in [
		"atoms_are_indivisible_and_paging_does_not_clip",
		"emitted_exact_page_arrays_roundtrip_and_hash",
		"publication_double_cross_squared_strictly_above_1e_16",
		"publication_float32_cross_squared_strictly_above_1e_16",
		"watertight_oriented_one_component_at_1e_7",
		"watertight_oriented_one_component_at_1e_8",
		"zero_compiler_caps",
	]:
		if not bool(hard_gates.get(gate_name, false)):
			_fail("required atlas hard gate is false: %s" % gate_name)
			return
	var atlas_stage := (_artifact.get("stages", {}) as Dictionary).get(
		"atlas", {}
	) as Dictionary
	if (
		int(atlas_stage.get("page_count", -1)) != EXPECTED_PAGE_COUNT
		or int(atlas_stage.get("atom_count", -1)) != EXPECTED_ATOM_COUNT
		or int(atlas_stage.get("geometric_clip_operation_count", -1)) != 0
		or bool(atlas_stage.get("paging_vertices_created", true))
		or bool(atlas_stage.get("paging_vertices_moved", true))
	):
		_fail("atlas is not an uncut non-geometric page assignment")
		return
	var publication := _artifact.get("publication", {}) as Dictionary
	var quality := publication.get("quality", {}) as Dictionary
	var provenance := publication.get("provenance", {}) as Dictionary
	if (
		int(quality.get("triangle_count", -1)) != EXPECTED_TRIANGLE_COUNT
		or int(quality.get("double_subthreshold_triangle_count", -1)) != 0
		or int(quality.get("float32_subthreshold_triangle_count", -1)) != 0
		or float(quality.get("minimum_float32_cross_squared_m4", 0.0))
		<= TRIANGLE_CROSS_SQUARED_MIN
		or int(provenance.get("compiler_cap_triangle_count", -1)) != 0
		or not bool(provenance.get("passed", false))
	):
		_fail("publication summary does not satisfy quality/provenance gates")
		return
	_pages = _artifact.get("organic_publication_pages", []) as Array
	if _pages.size() != EXPECTED_PAGE_COUNT:
		_fail("artifact did not contain exactly 27 publication pages")
		return
	_revision_id = StringName(
		"atlas_revision_%s" % EXPECTED_INPUT_SHA256.left(16).to_lower()
	)

	_workspace = ForgeV2WorkspacePreviewScript.new()
	_workspace.name = "RegionalPublicationAtlasWorkspace"
	root.add_child(_workspace)
	await process_frame
	if _workspace.get("camera") == null:
		_fail("real Forge workspace camera was not created")
		return

	var build_result := _build_staged_pages()
	if not bool(build_result.get("ok", false)):
		_fail(String(build_result.get("error", "page build failed")))
		return
	var topology_result := _validate_combined_page_topology()
	if not bool(topology_result.get("ok", false)):
		_fail(String(topology_result.get("error", "combined page topology failed")))
		return
	var edge_analysis := _build_half_edge_analysis(WELD_QUANTUM_METERS)
	if not bool(edge_analysis.get("ok", false)):
		_fail(String(edge_analysis.get("error", "1e-7 half-edge analysis failed")))
		return
	var exact_edge_analysis := _build_half_edge_analysis(EXACT_EDGE_QUANTUM_METERS)
	if not bool(exact_edge_analysis.get("ok", false)):
		_fail(String(exact_edge_analysis.get("error", "1e-8 half-edge analysis failed")))
		return
	if (
		(edge_analysis.get("cross_page_edges", []) as Array).is_empty()
		or (edge_analysis.get("dirty_clean_edges", []) as Array).is_empty()
	):
		_fail("atlas did not exercise page and dirty-clean half-edge boundaries")
		return

	# Build and validate every resource while detached.  Publication is the one
	# add_child call below: no individual page can enter the physics world first.
	var staged_identity := _snapshot_page_identity(false)
	if not bool(staged_identity.get("ok", false)):
		_fail(String(staged_identity.get("error", "detached page identity failed")))
		return
	_workspace.add_child(_staged_root)
	if _staged_root.get_parent() != _workspace:
		_fail("atomic atlas root publication failed")
		return
	await physics_frame
	await physics_frame
	var published_identity := _snapshot_page_identity(true)
	if (
		not bool(published_identity.get("ok", false))
		or staged_identity.get("identity", {}) != published_identity.get("identity", {})
	):
		_fail("page resources/revision changed during atomic physics publication")
		return

	var probe_selection := _select_physical_boundary_probes(edge_analysis)
	if not bool(probe_selection.get("ok", false)):
		_fail(String(probe_selection.get("error", "physical seam probes failed")))
		return
	var probes := probe_selection.get("probes", []) as Array
	var first_capture: Dictionary = await _capture_strict_hits(probes)
	if not bool(first_capture.get("ok", false)):
		_fail(String(first_capture.get("error", "first resolver capture failed")))
		return
	await physics_frame
	var second_capture: Dictionary = await _capture_strict_hits(probes)
	if not bool(second_capture.get("ok", false)):
		_fail(String(second_capture.get("error", "second resolver capture failed")))
		return
	var stability := _validate_hit_stability(
		first_capture.get("hits", []) as Array,
		second_capture.get("hits", []) as Array
	)
	if not bool(stability.get("ok", false)):
		_fail(String(stability.get("error", "physical hits were unstable")))
		return
	var feedback := _build_feedback_sweep(
		probes,
		second_capture.get("hits", []) as Array
	)
	if not bool(feedback.get("ok", false)):
		_fail(String(feedback.get("error", "feedback sweep failed")))
		return

	var result := {
		"schema": "forge_v2_regional_publication_atlas_targeting_verifier",
		"schema_version": 1,
		"ok": true,
		"production_ready": false,
		"production_readiness_reason": "verifier-only atlas publication gate",
		"input_path": INPUT_PATH,
		"input_sha256": actual_sha256,
		"publication": {
			"revision_id": String(_revision_id),
			"page_count": int(_publication_metrics.get("page_count", 0)),
			"triangle_count": int(_publication_metrics.get("triangle_count", 0)),
			"atom_count": int(_publication_metrics.get("atom_count", 0)),
			"compiler_cap_triangle_count": 0,
			"minimum_float32_cross_squared_m4": float(_publication_metrics.get(
				"minimum_cross_squared", 0.0
			)),
			"one_atomic_root_publish": true,
			"all_resources_and_revisions_stable": true,
			"individual_page_closed_mesh_required": false,
			"page_geometry_clipping_used": false,
		},
		"combined_topology": topology_result,
		"half_edges_1e_7": _strip_edge_arrays(edge_analysis),
		"half_edges_1e_8": _strip_edge_arrays(exact_edge_analysis),
		"physical_targeting": {
			"real_forge_resolver": true,
			"probe_count": probes.size(),
			"page_seam_pair_count": int(probe_selection.get("page_pair_count", 0)),
			"dirty_clean_pair_count": int(probe_selection.get("dirty_clean_pair_count", 0)),
			"same_logical_target_id": true,
			"minimum_normal_dot": float(second_capture.get("minimum_normal_dot", 0.0)),
			"maximum_abc_dot": float(second_capture.get("maximum_abc_dot", 1.0)),
			"maximum_hit_error_meters": float(second_capture.get(
				"maximum_position_error_meters", INF
			)),
			"two_capture_maximum_position_delta_meters": float(stability.get(
				"maximum_position_delta_meters", INF
			)),
		},
		"feedback_exact_sweep": feedback,
	}
	_write_json(result)
	print("Forge V2 regional publication atlas targeting passed: %s" % RESULT_PATH)
	quit(0)


func _build_staged_pages() -> Dictionary:
	_staged_root = Node3D.new()
	_staged_root.name = "AtomicOrganicPublicationAtlas"
	_staged_root.set_meta("forge_v2_publication_revision_id", _revision_id)
	_staged_root.set_meta("forge_v2_surface_target_id", SURFACE_TARGET_ID)
	_staged_root.set_meta("forge_v2_page_count", _pages.size())
	var render_material := StandardMaterial3D.new()
	render_material.albedo_color = Color(0.43, 0.72, 0.67, 1.0)
	render_material.roughness = 0.72
	var seen_page_ids := {}
	for page_index in range(_pages.size()):
		var page := _pages[page_index] as Dictionary
		if (
			String(page.get("schema", ""))
			!= "forge_v2_organic_publication_owner_page"
			or int(page.get("schema_version", -1)) != 1
			or String(page.get("coordinate_units", "")) != "meters"
		):
			return {"ok": false, "error": "page %d has invalid schema" % page_index}
		var page_id := String(page.get("page_id", ""))
		if page_id.is_empty() or seen_page_ids.has(page_id):
			return {"ok": false, "error": "page identity is empty or duplicated"}
		seen_page_ids[page_id] = true
		var mesh64 := page.get("mesh64", {}) as Dictionary
		var vertex_rows := mesh64.get("vert_properties", []) as Array
		var triangle_rows := mesh64.get("tri_verts", []) as Array
		var triangle_atom_indices := mesh64.get("triangle_atom_index", []) as Array
		var face_ids := mesh64.get("face_id", []) as Array
		var surface_indices := mesh64.get("surface_index", []) as Array
		var material_indices := mesh64.get("material_index", []) as Array
		if (
			triangle_rows.is_empty()
			or vertex_rows.is_empty()
			or triangle_rows.size() != int(page.get("triangle_count", -1))
			or triangle_atom_indices.size() != triangle_rows.size()
			or face_ids.size() != triangle_rows.size()
			or surface_indices.size() != triangle_rows.size()
			or material_indices.size() != triangle_rows.size()
		):
			return {"ok": false, "error": "page %s Mesh64 arrays disagree" % page_id}
		var atoms := page.get("atoms", []) as Array
		if atoms.size() != int(page.get("atom_count", -1)):
			return {"ok": false, "error": "page %s atom count disagrees" % page_id}
		var atoms_by_index := {}
		var atom_triangle_tallies := {}
		for atom_variant: Variant in atoms:
			var atom := atom_variant as Dictionary
			var atom_index := int(atom.get("atom_index", -1))
			var source_id := int(atom.get("source_original_id", -1))
			if (
				atom_index < 0
				or atoms_by_index.has(atom_index)
				or source_id not in [CLEAN_SOURCE_ORIGINAL_ID, DIRTY_SOURCE_ORIGINAL_ID]
				or int(atom.get("source_face_id", -1)) < 0
				or int(atom.get("triangle_count", 0)) <= 0
			):
				return {"ok": false, "error": "page %s has invalid organic atom" % page_id}
			atoms_by_index[atom_index] = atom
			atom_triangle_tallies[atom_index] = 0

		var vertices := PackedVector3Array()
		for row_variant: Variant in vertex_rows:
			var row := row_variant as Array
			if row.size() < 3:
				return {"ok": false, "error": "page %s has short vertex property row" % page_id}
			var vertex := Vector3(float(row[0]), float(row[1]), float(row[2]))
			if not vertex.is_finite():
				return {"ok": false, "error": "page %s contains non-finite vertex" % page_id}
			vertices.append(vertex)
		var render_vertices := PackedVector3Array()
		var render_normals := PackedVector3Array()
		var collision_faces := PackedVector3Array()
		var records: Array = []
		for triangle_index in range(triangle_rows.size()):
			var indices := triangle_rows[triangle_index] as Array
			if indices.size() != 3:
				return {"ok": false, "error": "page %s has non-triangle row" % page_id}
			var ia := int(indices[0])
			var ib := int(indices[1])
			var ic := int(indices[2])
			if (
				ia < 0 or ia >= vertices.size()
				or ib < 0 or ib >= vertices.size()
				or ic < 0 or ic >= vertices.size()
			):
				return {"ok": false, "error": "page %s triangle index out of range" % page_id}
			var atom_index := int(triangle_atom_indices[triangle_index])
			if not atoms_by_index.has(atom_index):
				return {"ok": false, "error": "page %s triangle lacks atom" % page_id}
			var atom := atoms_by_index[atom_index] as Dictionary
			if int(face_ids[triangle_index]) != int(atom.get("source_face_id", -1)):
				return {"ok": false, "error": "page %s face/atom provenance differs" % page_id}
			if int(material_indices[triangle_index]) != 0:
				return {"ok": false, "error": "page %s contains unexpected material/cap run" % page_id}
			atom_triangle_tallies[atom_index] = int(atom_triangle_tallies[atom_index]) + 1
			var point_a := vertices[ia]
			var point_b := vertices[ib]
			var point_c := vertices[ic]
			var cross := (point_b - point_a).cross(point_c - point_a)
			var cross_squared := cross.length_squared()
			if cross_squared <= TRIANGLE_CROSS_SQUARED_MIN:
				return {
					"ok": false,
					"error": "page %s triangle %d cross_squared=%s <= 1e-16" % [
						page_id,
						triangle_index,
						String.num_scientific(cross_squared),
					],
				}
			var outward := cross.normalized()
			# Manifold is positive winding; Forge/Godot uses the established
			# clockwise outward convention, so publish [a,c,b].
			for point: Vector3 in [point_a, point_c, point_b]:
				render_vertices.append(point)
				render_normals.append(outward)
				collision_faces.append(point)
			_publication_metrics["minimum_cross_squared"] = minf(
				float(_publication_metrics["minimum_cross_squared"]),
				cross_squared
			)
			_publication_metrics["manifold_signed_volume_m3"] = (
				float(_publication_metrics["manifold_signed_volume_m3"])
				+ point_a.dot(point_b.cross(point_c)) / 6.0
			)
			_publication_metrics["godot_signed_volume_m3"] = (
				float(_publication_metrics["godot_signed_volume_m3"])
				+ point_a.dot(point_c.cross(point_b)) / 6.0
			)
			var record := {
				"page_index": page_index,
				"page_id": page_id,
				"triangle_index": triangle_index,
				"atom_index": atom_index,
				"source_original_id": int(atom.get("source_original_id", -1)),
				"source_face_id": int(atom.get("source_face_id", -1)),
				"point_a": point_a,
				"point_b": point_b,
				"point_c": point_c,
				"centroid": (point_a + point_b + point_c) / 3.0,
				"expected_normal_local": outward,
			}
			records.append(record)
			_triangle_records.append(record)
		for atom_index_variant: Variant in atoms_by_index.keys():
			var atom_index := int(atom_index_variant)
			var atom := atoms_by_index[atom_index] as Dictionary
			if int(atom_triangle_tallies[atom_index]) != int(atom.get("triangle_count", -1)):
				return {"ok": false, "error": "page %s atom triangle tally differs" % page_id}

		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = render_vertices
		arrays[Mesh.ARRAY_NORMAL] = render_normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, render_material)
		_publication_meshes.append(mesh)
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "AtlasPageMesh_%02d" % page_index
		mesh_instance.mesh = mesh
		_set_publication_meta(mesh_instance, page_id)
		_staged_root.add_child(mesh_instance)
		var static_body := StaticBody3D.new()
		static_body.name = "AtlasPageCollider_%02d" % page_index
		static_body.collision_layer = (
			ForgeV2PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		)
		static_body.collision_mask = 0
		_set_publication_meta(static_body, page_id)
		var collision_shape := CollisionShape3D.new()
		collision_shape.name = "OrganicOnlyConcaveShape"
		var concave := ConcavePolygonShape3D.new()
		concave.backface_collision = false
		concave.set_faces(collision_faces)
		collision_shape.shape = concave
		static_body.add_child(collision_shape)
		_staged_root.add_child(static_body)
		if (
			not mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY)
			or not static_body.transform.is_equal_approx(Transform3D.IDENTITY)
			or not collision_shape.transform.is_equal_approx(Transform3D.IDENTITY)
		):
			return {"ok": false, "error": "page %s used non-identity transform" % page_id}
		for record_variant: Variant in records:
			var record := record_variant as Dictionary
			record["collider"] = static_body
		_page_records.append({
			"page_index": page_index,
			"page_id": page_id,
			"mesh_instance": mesh_instance,
			"static_body": static_body,
			"collision_shape": collision_shape,
			"records": records,
		})
		_publication_metrics["page_count"] = int(_publication_metrics["page_count"]) + 1
		_publication_metrics["triangle_count"] = (
			int(_publication_metrics["triangle_count"]) + triangle_rows.size()
		)
		_publication_metrics["atom_count"] = (
			int(_publication_metrics["atom_count"]) + atoms.size()
		)
	if (
		int(_publication_metrics["page_count"]) != EXPECTED_PAGE_COUNT
		or int(_publication_metrics["triangle_count"]) != EXPECTED_TRIANGLE_COUNT
		or int(_publication_metrics["atom_count"]) != EXPECTED_ATOM_COUNT
		or float(_publication_metrics["manifold_signed_volume_m3"]) <= 0.0
		or float(_publication_metrics["godot_signed_volume_m3"]) >= 0.0
	):
		return {"ok": false, "error": "combined page counts or winding are invalid"}
	return {"ok": true}


func _set_publication_meta(node: Node, page_id: String) -> void:
	node.set_meta("forge_v2_surface_target_id", SURFACE_TARGET_ID)
	node.set_meta("forge_v2_body_id", LOGICAL_BODY_ID)
	node.set_meta("forge_v2_material_variant_id", MATERIAL_VARIANT_ID)
	node.set_meta("forge_v2_publication_revision_id", _revision_id)
	node.set_meta("forge_v2_publication_page_id", page_id)


func _validate_combined_page_topology() -> Dictionary:
	var analysis := ForgeV2WorkpieceBenchmarkMeshAnalyzerScript.analyze_meshes(
		_publication_meshes
	)
	if (
		int(analysis.get("triangle_count", -1)) != EXPECTED_TRIANGLE_COUNT
		or int(analysis.get("degenerate_triangle_count", -1)) != 0
		or int(analysis.get("nonfinite_vertex_count", -1)) != 0
		or not bool(analysis.get("strict_watertight", false))
		or int(analysis.get("strict_component_count", -1)) != 1
		or int(analysis.get("strict_boundary_edge_count", -1)) != 0
		or int(analysis.get("strict_nonmanifold_edge_count", -1)) != 0
		or int(analysis.get("strict_directed_edge_mismatch_count", -1)) != 0
		or int(analysis.get("strict_degenerate_triangle_collapse_count", -1)) != 0
	):
		return {
			"ok": false,
			"error": "combined page ArrayMeshes fail the established 1e-7 analyzer",
		}
	return {
		"ok": true,
		"triangle_count": int(analysis.get("triangle_count", -1)),
		"strict_weld_quantum_meters": float(analysis.get(
			"strict_topology_weld_tolerance_meters", 0.0
		)),
		"strict_component_count": int(analysis.get("strict_component_count", -1)),
		"strict_boundary_edge_count": int(analysis.get("strict_boundary_edge_count", -1)),
		"strict_nonmanifold_edge_count": int(analysis.get("strict_nonmanifold_edge_count", -1)),
		"strict_directed_edge_mismatch_count": int(analysis.get(
			"strict_directed_edge_mismatch_count", -1
		)),
		"strict_genus": float(analysis.get("strict_genus", INF)),
		"minimum_cross_squared_m4": float(_publication_metrics.get(
			"minimum_cross_squared", 0.0
		)),
		"cross_squared_threshold_m4": TRIANGLE_CROSS_SQUARED_MIN,
	}


func _build_half_edge_analysis(quantum: float) -> Dictionary:
	var edge_map := {}
	for record_variant: Variant in _triangle_records:
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
			var first_key := _vector_key(first, quantum)
			var second_key := _vector_key(second, quantum)
			if first_key == second_key:
				return {"ok": false, "error": "quantized publication edge collapsed"}
			var undirected_key := (
				"%s|%s" % [first_key, second_key]
				if first_key < second_key
				else "%s|%s" % [second_key, first_key]
			)
			if not edge_map.has(undirected_key):
				edge_map[undirected_key] = []
			(edge_map[undirected_key] as Array).append({
				"record": record,
				"first": first,
				"second": second,
				"third": third,
				"first_key": first_key,
				"second_key": second_key,
				"edge_key": undirected_key,
			})
	var cross_page_edges: Array = []
	var dirty_clean_edges: Array = []
	var directed_mismatch_count := 0
	for edge_key_variant: Variant in edge_map.keys():
		var edge_key := String(edge_key_variant)
		var occurrences := edge_map[edge_key] as Array
		if occurrences.size() != 2:
			return {
				"ok": false,
				"error": "half-edge %s has %d occurrences" % [edge_key, occurrences.size()],
			}
		var first := occurrences[0] as Dictionary
		var second := occurrences[1] as Dictionary
		if (
			String(first.get("first_key", "")) != String(second.get("second_key", ""))
			or String(first.get("second_key", "")) != String(second.get("first_key", ""))
		):
			directed_mismatch_count += 1
			continue
		var first_record := first.get("record", {}) as Dictionary
		var second_record := second.get("record", {}) as Dictionary
		var pair := {
			"edge_key": edge_key,
			"occurrences": occurrences,
			"first_page_index": int(first_record.get("page_index", -1)),
			"second_page_index": int(second_record.get("page_index", -1)),
			"first_source_original_id": int(first_record.get("source_original_id", -1)),
			"second_source_original_id": int(second_record.get("source_original_id", -1)),
		}
		if int(pair["first_page_index"]) != int(pair["second_page_index"]):
			cross_page_edges.append(pair)
		if int(pair["first_source_original_id"]) != int(pair["second_source_original_id"]):
			dirty_clean_edges.append(pair)
	if directed_mismatch_count != 0:
		return {"ok": false, "error": "combined page half-edge winding is not opposite"}
	return {
		"ok": true,
		"quantum_meters": quantum,
		"undirected_edge_count": edge_map.size(),
		"boundary_edge_count": 0,
		"nonmanifold_edge_count": 0,
		"directed_mismatch_edge_count": 0,
		"cross_page_half_edge_pair_count": cross_page_edges.size(),
		"dirty_clean_half_edge_pair_count": dirty_clean_edges.size(),
		"cross_page_edges": cross_page_edges,
		"dirty_clean_edges": dirty_clean_edges,
	}


func _strip_edge_arrays(analysis: Dictionary) -> Dictionary:
	var result := analysis.duplicate(false)
	result.erase("cross_page_edges")
	result.erase("dirty_clean_edges")
	return result


func _snapshot_page_identity(expected_inside_tree: bool) -> Dictionary:
	if _staged_root == null or _page_records.size() != EXPECTED_PAGE_COUNT:
		return {"ok": false, "error": "atlas page records are incomplete"}
	if _staged_root.is_inside_tree() != expected_inside_tree:
		return {"ok": false, "error": "atomic atlas root tree state is wrong"}
	if StringName(_staged_root.get_meta(
		"forge_v2_publication_revision_id", StringName()
	)) != _revision_id:
		return {"ok": false, "error": "atlas root revision changed"}
	var identity := {}
	for page_variant: Variant in _page_records:
		var page := page_variant as Dictionary
		var page_id := String(page.get("page_id", ""))
		var mesh_instance := page.get("mesh_instance", null) as MeshInstance3D
		var static_body := page.get("static_body", null) as StaticBody3D
		var collision_shape := page.get("collision_shape", null) as CollisionShape3D
		if (
			mesh_instance == null or static_body == null or collision_shape == null
			or mesh_instance.is_inside_tree() != expected_inside_tree
			or static_body.is_inside_tree() != expected_inside_tree
			or collision_shape.is_inside_tree() != expected_inside_tree
			or StringName(mesh_instance.get_meta(
				"forge_v2_publication_revision_id", StringName()
			)) != _revision_id
			or StringName(static_body.get_meta(
				"forge_v2_publication_revision_id", StringName()
			)) != _revision_id
			or StringName(static_body.get_meta(
				"forge_v2_surface_target_id", StringName()
			)) != SURFACE_TARGET_ID
		):
			return {"ok": false, "error": "page %s identity/revision is mixed" % page_id}
		identity[page_id] = {
			"mesh_instance_id": mesh_instance.get_instance_id(),
			"mesh_resource_id": mesh_instance.mesh.get_instance_id(),
			"static_body_id": static_body.get_instance_id(),
			"collision_shape_id": collision_shape.get_instance_id(),
			"shape_resource_id": collision_shape.shape.get_instance_id(),
			"revision_id": String(_revision_id),
		}
	return {"ok": true, "identity": identity}


func _select_physical_boundary_probes(edge_analysis: Dictionary) -> Dictionary:
	var selected_page_pairs: Array = []
	var selected_dirty_pairs: Array = []
	var used_edge_keys := {}
	for category: String in ["page", "dirty"]:
		var source_pairs := (
			edge_analysis.get("cross_page_edges", []) as Array
			if category == "page"
			else edge_analysis.get("dirty_clean_edges", []) as Array
		)
		var target_count := (
			MIN_PAGE_SEAM_PAIRS if category == "page" else MIN_DIRTY_CLEAN_PAIRS
		)
		var selected := selected_page_pairs if category == "page" else selected_dirty_pairs
		for pair_variant: Variant in source_pairs:
			if selected.size() >= target_count:
				break
			var pair := pair_variant as Dictionary
			var edge_key := String(pair.get("edge_key", ""))
			if used_edge_keys.has(edge_key):
				continue
			var probe_pair := _build_probe_pair_from_half_edge(pair, category)
			if probe_pair.is_empty():
				continue
			var first_probe := probe_pair.get("first_probe", {}) as Dictionary
			var second_probe := probe_pair.get("second_probe", {}) as Dictionary
			if (
				not bool(_validate_direct_probe(first_probe).get("ok", false))
				or not bool(_validate_direct_probe(second_probe).get("ok", false))
			):
				continue
			selected.append(probe_pair)
			used_edge_keys[edge_key] = true
	if selected_page_pairs.size() < MIN_PAGE_SEAM_PAIRS:
		return {"ok": false, "error": "fewer than three page seams are physically rayable"}
	if selected_dirty_pairs.size() < MIN_DIRTY_CLEAN_PAIRS:
		return {"ok": false, "error": "fewer than three dirty-clean seams are physically rayable"}
	var probes: Array = []
	for pair_variant: Variant in selected_page_pairs + selected_dirty_pairs:
		var pair := pair_variant as Dictionary
		probes.append(pair.get("first_probe", {}) as Dictionary)
		probes.append(pair.get("second_probe", {}) as Dictionary)
	var central_probe := _find_central_oblique_probe()
	if central_probe.is_empty():
		return {"ok": false, "error": "central oblique atlas probe was unavailable"}
	probes.append(central_probe)
	return {
		"ok": true,
		"probes": probes,
		"page_pair_count": selected_page_pairs.size(),
		"dirty_clean_pair_count": selected_dirty_pairs.size(),
	}


func _build_probe_pair_from_half_edge(pair: Dictionary, category: String) -> Dictionary:
	var occurrences := pair.get("occurrences", []) as Array
	if occurrences.size() != 2:
		return {}
	var probes: Array = []
	for occurrence_variant: Variant in occurrences:
		var occurrence := occurrence_variant as Dictionary
		var record := occurrence.get("record", {}) as Dictionary
		var first := occurrence.get("first", Vector3.ZERO) as Vector3
		var second := occurrence.get("second", Vector3.ZERO) as Vector3
		var third := occurrence.get("third", Vector3.ZERO) as Vector3
		var position := (first + second) * 0.40 + third * 0.20
		var clearance := _minimum_point_edge_distance(
			position,
			record.get("point_a", Vector3.ZERO) as Vector3,
			record.get("point_b", Vector3.ZERO) as Vector3,
			record.get("point_c", Vector3.ZERO) as Vector3
		)
		if clearance < MIN_PROBE_EDGE_CLEARANCE_METERS:
			return {}
		probes.append(_probe_from_record(
			record,
			position,
			"%s_seam" % category,
			clearance
		))
	return {
		"edge_key": String(pair.get("edge_key", "")),
		"category": category,
		"first_probe": probes[0],
		"second_probe": probes[1],
	}


func _find_central_oblique_probe() -> Dictionary:
	var publication_bounds := (_artifact.get("publication", {}) as Dictionary).get(
		"bounds", []
	) as Array
	var center := Vector3.ZERO
	if publication_bounds.size() == 6:
		center = Vector3(
			(float(publication_bounds[0]) + float(publication_bounds[3])) * 0.5,
			(float(publication_bounds[1]) + float(publication_bounds[4])) * 0.5,
			(float(publication_bounds[2]) + float(publication_bounds[5])) * 0.5
		)
	var ranked: Array = []
	for record_variant: Variant in _triangle_records:
		var record := record_variant as Dictionary
		var normal := record.get("expected_normal_local", Vector3.ZERO) as Vector3
		var axis_max := maxf(absf(normal.x), maxf(absf(normal.y), absf(normal.z)))
		if axis_max >= 0.94:
			continue
		var centroid := record.get("centroid", Vector3.ZERO) as Vector3
		var clearance := _minimum_point_edge_distance(
			centroid,
			record.get("point_a", Vector3.ZERO) as Vector3,
			record.get("point_b", Vector3.ZERO) as Vector3,
			record.get("point_c", Vector3.ZERO) as Vector3
		)
		if clearance < MIN_PROBE_EDGE_CLEARANCE_METERS:
			continue
		ranked.append({
			"record": record,
			"centroid": centroid,
			"clearance": clearance,
			"distance": centroid.distance_to(center),
		})
	ranked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return float(first.get("distance", INF)) < float(second.get("distance", INF))
	)
	for candidate_variant: Variant in ranked:
		var candidate := candidate_variant as Dictionary
		var probe := _probe_from_record(
			candidate.get("record", {}) as Dictionary,
			candidate.get("centroid", Vector3.ZERO) as Vector3,
			"central_oblique",
			float(candidate.get("clearance", 0.0))
		)
		if bool(_validate_direct_probe(probe).get("ok", false)):
			return probe
	return {}


func _probe_from_record(
	record: Dictionary,
	position: Vector3,
	kind: String,
	clearance: float
) -> Dictionary:
	return {
		"probe_kind": kind,
		"target_local": position,
		"expected_normal_local": record.get("expected_normal_local", Vector3.ZERO),
		"collider": record.get("collider", null),
		"page_index": int(record.get("page_index", -1)),
		"page_id": String(record.get("page_id", "")),
		"source_original_id": int(record.get("source_original_id", -1)),
		"source_face_id": int(record.get("source_face_id", -1)),
		"triangle_index": int(record.get("triangle_index", -1)),
		"edge_clearance_meters": clearance,
	}


func _validate_direct_probe(probe: Dictionary) -> Dictionary:
	var target := probe.get("target_local", Vector3.ZERO) as Vector3
	var expected_normal := (
		probe.get("expected_normal_local", Vector3.ZERO) as Vector3
	).normalized()
	var query := PhysicsRayQueryParameters3D.create(
		_workspace.to_global(target + expected_normal * DIRECT_RAY_OFFSET_METERS),
		_workspace.to_global(target - expected_normal * DIRECT_RAY_OFFSET_METERS),
		ForgeV2PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _workspace.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"ok": false}
	var actual_position := _workspace.to_local(hit.get("position", Vector3.ZERO) as Vector3)
	var actual_normal := (
		_workspace.global_transform.basis.inverse()
		* (hit.get("normal", Vector3.ZERO) as Vector3)
	).normalized()
	var actual_collider: Object = hit.get("collider", null) as Object
	var expected_collider: Object = probe.get("collider", null) as Object
	return {
		"ok": (
			actual_collider == expected_collider
			and actual_position.distance_to(target) <= HIT_POSITION_TOLERANCE_METERS
			and actual_normal.dot(expected_normal) >= NORMAL_DOT_MIN
		),
	}


func _capture_strict_hits(probes: Array) -> Dictionary:
	var hits: Array = []
	var minimum_normal_dot := 1.0
	var maximum_abc_dot := -1.0
	var maximum_position_error := 0.0
	for probe_index in range(probes.size()):
		var probe := probes[probe_index] as Dictionary
		var camera := _workspace.get("camera") as Camera3D
		var target := probe.get("target_local", Vector3.ZERO) as Vector3
		var expected_normal := (
			probe.get("expected_normal_local", Vector3.ZERO) as Vector3
		).normalized()
		var up := Vector3.UP
		if absf(expected_normal.dot(up)) > 0.94:
			up = Vector3.RIGHT
		camera.global_position = _workspace.to_global(target + expected_normal * 0.025)
		camera.look_at(_workspace.to_global(target), up)
		camera.current = true
		camera.near = 0.0005
		camera.far = 2.0
		await process_frame
		var projection := _workspace.call(
			"project_workspace_local_to_screen",
			target
		) as Dictionary
		if not bool(projection.get("valid", false)):
			return {"ok": false, "error": "probe %d projection failed" % probe_index}
		var hit := _workspace.call(
			"resolve_strict_surface_target",
			projection.get("screen_position", Vector2.ZERO) as Vector2,
			ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
			SURFACE_TARGET_ID
		) as Dictionary
		var validation := _validate_resolver_hit(probe, hit)
		if not bool(validation.get("ok", false)):
			return {
				"ok": false,
				"error": "strict resolver probe %d: %s" % [
					probe_index,
					String(validation.get("error", "invalid")),
				],
			}
		minimum_normal_dot = minf(
			minimum_normal_dot,
			float(validation.get("normal_dot", 0.0))
		)
		maximum_abc_dot = maxf(
			maximum_abc_dot,
			float(validation.get("abc_dot", 1.0))
		)
		maximum_position_error = maxf(
			maximum_position_error,
			float(validation.get("position_error_meters", INF))
		)
		hits.append(hit)
	return {
		"ok": true,
		"hits": hits,
		"minimum_normal_dot": minimum_normal_dot,
		"maximum_abc_dot": maximum_abc_dot,
		"maximum_position_error_meters": maximum_position_error,
	}


func _validate_resolver_hit(probe: Dictionary, hit: Dictionary) -> Dictionary:
	if not bool(hit.get("valid", false)):
		return {"ok": false, "error": "resolver returned invalid"}
	var expected_position := probe.get("target_local", Vector3.ZERO) as Vector3
	var expected_normal := (
		probe.get("expected_normal_local", Vector3.ZERO) as Vector3
	).normalized()
	var position := hit.get("local_position", Vector3.ZERO) as Vector3
	var raw_position := hit.get("raw_local_position", Vector3.ZERO) as Vector3
	var normal := (hit.get("local_normal", Vector3.ZERO) as Vector3).normalized()
	var bc := (
		hit.get("local_contact_direction", Vector3.ZERO) as Vector3
	).normalized()
	var position_error := position.distance_to(expected_position)
	var normal_dot := normal.dot(expected_normal)
	var abc_dot := normal.dot(bc)
	var collider := hit.get("collider", null) as Object
	var expected_collider := probe.get("collider", null) as Object
	if collider != expected_collider:
		return {"ok": false, "error": "ray hit a different atlas page"}
	if position_error > HIT_POSITION_TOLERANCE_METERS:
		return {"ok": false, "error": "ray missed triangle interior"}
	if position.distance_to(raw_position) > STABLE_POSITION_TOLERANCE_METERS:
		return {"ok": false, "error": "resolver rewrote raw B"}
	if normal_dot < NORMAL_DOT_MIN:
		return {"ok": false, "error": "physical normal lost outward winding"}
	if abc_dot > ABC_DOT_MAX:
		return {"ok": false, "error": "ABC BC is not inward"}
	if (
		StringName(hit.get("surface_target_id", StringName())) != SURFACE_TARGET_ID
		or StringName(hit.get("source_body_id", StringName())) != LOGICAL_BODY_ID
		or StringName(hit.get("source_record_id", StringName())) != MATERIAL_VARIANT_ID
		or StringName(hit.get("target_kind", StringName()))
		!= ForgeV2PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
		or bool(hit.get("is_clamped", true))
		or StringName(collider.get_meta(
			"forge_v2_publication_revision_id", StringName()
		)) != _revision_id
	):
		return {"ok": false, "error": "logical target/material/revision metadata differs"}
	return {
		"ok": true,
		"position_error_meters": position_error,
		"normal_dot": normal_dot,
		"abc_dot": abc_dot,
	}


func _validate_hit_stability(first: Array, second: Array) -> Dictionary:
	if first.size() != second.size() or first.is_empty():
		return {"ok": false, "error": "resolver capture sizes differ"}
	var maximum_position_delta := 0.0
	var minimum_normal_dot := 1.0
	for index in range(first.size()):
		var first_hit := first[index] as Dictionary
		var second_hit := second[index] as Dictionary
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
		var first_collider := first_hit.get("collider", null) as Object
		var second_collider := second_hit.get("collider", null) as Object
		if (
			first_collider != second_collider
			or position_delta > STABLE_POSITION_TOLERANCE_METERS
			or normal_dot < NORMAL_DOT_MIN
			or StringName(first_hit.get("surface_target_id", StringName()))
			!= StringName(second_hit.get("surface_target_id", StringName()))
		):
			return {"ok": false, "error": "page collision changed between captures"}
	return {
		"ok": true,
		"maximum_position_delta_meters": maximum_position_delta,
		"minimum_normal_dot": minimum_normal_dot,
	}


func _build_feedback_sweep(probes: Array, hits: Array) -> Dictionary:
	if probes.size() != hits.size() or hits.size() < 7:
		return {"ok": false, "error": "feedback lacks physical B/normal/BC triples"}
	var ordered: Array = []
	for index in range(hits.size()):
		ordered.append({"probe": probes[index], "hit": hits[index]})
	ordered.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		var a := (first.get("hit", {}) as Dictionary).get(
			"local_position", Vector3.ZERO
		) as Vector3
		var b := (second.get("hit", {}) as Dictionary).get(
			"local_position", Vector3.ZERO
		) as Vector3
		if not is_equal_approx(a.x, b.x):
			return a.x < b.x
		if not is_equal_approx(a.y, b.y):
			return a.y < b.y
		return a.z < b.z
	)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for entry_variant: Variant in ordered:
		var hit := (entry_variant as Dictionary).get("hit", {}) as Dictionary
		var position := hit.get("local_position", Vector3.ZERO) as Vector3
		if not positions.is_empty() and positions[positions.size() - 1].distance_to(position) < 0.00008:
			continue
		positions.append(position)
		normals.append((hit.get("local_normal", Vector3.ZERO) as Vector3).normalized())
		contacts.append((
			hit.get("local_contact_direction", Vector3.ZERO) as Vector3
		).normalized())
	if positions.size() < 4:
		return {"ok": false, "error": "feedback hit path collapsed below four samples"}
	var profile := _build_asymmetric_feedback_profile()
	if profile.is_empty():
		return {"ok": false, "error": "feedback profile could not compile"}
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", &"regional_atlas_feedback_sweep")
	body.set("source_record_id", &"regional_atlas_feedback_source")
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
	body.set("profile_display_name", "Regional atlas feedback profile")
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
	if (
		not bool(body.call("uses_explicit_surface_contact_authority"))
		or StringName(body.get("surface_target_id")) != SURFACE_TARGET_ID
	):
		return {"ok": false, "error": "feedback body lost strict surface authority"}
	var retained_positions := body.get("path_points") as PackedVector3Array
	var retained_normals := body.get("path_surface_normals") as PackedVector3Array
	var retained_contacts := body.get("path_contact_directions") as PackedVector3Array
	if (
		retained_positions.size() != positions.size()
		or retained_normals.size() != normals.size()
		or retained_contacts.size() != contacts.size()
	):
		return {"ok": false, "error": "feedback body dropped hit triples"}
	for index in range(positions.size()):
		if (
			retained_positions[index].distance_to(positions[index])
			> STABLE_POSITION_TOLERANCE_METERS
			or retained_normals[index].dot(normals[index]) < NORMAL_DOT_MIN
			or retained_contacts[index].dot(contacts[index]) < NORMAL_DOT_MIN
			or retained_normals[index].dot(retained_contacts[index]) > ABC_DOT_MAX
		):
			return {"ok": false, "error": "feedback body rewrote hit triple %d" % index}
	var presenter := _workspace.get("volume_preview_presenter") as Node3D
	if presenter == null:
		presenter = ForgeV2VolumePreviewPresenterScript.new()
	var mesh := presenter.call("_build_active_material_body_sweep_mesh", body) as ArrayMesh
	if mesh == null or mesh.get_surface_count() <= 0:
		return {"ok": false, "error": "existing exact sweep builder returned empty"}
	var analysis := ForgeV2WorkpieceBenchmarkMeshAnalyzerScript.analyze_mesh(mesh)
	if (
		int(analysis.get("triangle_count", 0)) <= 0
		or int(analysis.get("nonfinite_vertex_count", -1)) != 0
		or int(analysis.get("boundary_edge_count", -1)) != 0
		or int(analysis.get("nonmanifold_edge_count", -1)) != 0
	):
		return {"ok": false, "error": "feedback sweep is not finite/watertight"}
	var polygon := body.get("profile_polygon_2d_meters") as PackedVector2Array
	var minimum_outward_extent := INF
	var maximum_buried_depth := 0.0
	var minimum_exterior_ratio := 1.0
	for index in range(positions.size()):
		var tangent := ForgeV2ProfileShapeLibraryScript.resolve_linear_path_point_tangent(
			positions, index
		)
		var ring := presenter.call(
			"_build_profile_sweep_ring", body, polygon, index, tangent
		) as PackedVector3Array
		if ring.size() != polygon.size():
			return {"ok": false, "error": "feedback ring is incomplete"}
		var maximum_signed := -INF
		var minimum_signed := INF
		var signed_sum := 0.0
		var exterior_count := 0
		for vertex: Vector3 in ring:
			var signed_distance := (vertex - positions[index]).dot(normals[index])
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
			return {"ok": false, "error": "feedback profile is buried at ring %d" % index}
	return {
		"ok": true,
		"built_with_existing_exact_sweep_builder": true,
		"returned_B_raw_normal_BC_triplets_retained": true,
		"physical_hit_triple_count": positions.size(),
		"triangle_count": int(analysis.get("triangle_count", 0)),
		"minimum_outward_extent_meters": minimum_outward_extent,
		"maximum_buried_depth_meters": maximum_buried_depth,
		"minimum_exterior_vertex_ratio": minimum_exterior_ratio,
		"meaningful_exterior_profile_extent": true,
		"boolean_commit_attempted": false,
	}


func _build_asymmetric_feedback_profile() -> Dictionary:
	var base_polygon := PackedVector2Array()
	for index in range(21):
		var theta := TAU * float(index) / 21.0
		var radial_bias := 1.0 + 0.10 * sin(theta) + 0.05 * cos(3.0 * theta)
		base_polygon.append(Vector2(
			0.0085 * radial_bias * cos(theta) + 0.0005 * sin(2.0 * theta),
			0.0140 * (1.0 + 0.04 * cos(theta)) * sin(theta)
		))
	var clearance := ForgeV2ProfileShapeLibraryScript.constrain_point_inside_polygon_with_clearance(
		Vector2(0.0, -1.0), base_polygon, 0.0008
	)
	if not bool(clearance.get("valid", false)):
		return {}
	var anchor := clearance.get("point", Vector2.ZERO) as Vector2
	var contact := ForgeV2ProfileShapeLibraryScript.resolve_profile_anchor_contact(
		base_polygon, anchor
	)
	if not bool(contact.get("valid", false)):
		return {}
	var deposition_polygon := PackedVector2Array()
	for point: Vector2 in base_polygon:
		deposition_polygon.append(point - anchor)
	var contact_point := contact.get("point", anchor) as Vector2
	return {
		"profile_id": &"regional_atlas_feedback_asymmetric_21",
		"deposition_polygon": deposition_polygon,
		"anchor": anchor,
		"contact_point_relative": contact_point - anchor,
		"contact_direction": contact.get("direction", Vector2.DOWN) as Vector2,
		"contact_distance_meters": float(contact.get("distance_meters", 0.0)),
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


func _vector_key(value: Vector3, quantum: float) -> String:
	return "%d,%d,%d" % [
		roundi(value.x / quantum),
		roundi(value.y / quantum),
		roundi(value.z / quantum),
	]


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
		"schema": "forge_v2_regional_publication_atlas_targeting_verifier",
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
		push_error("could not write atlas verifier result: %s" % RESULT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t", true, true) + "\n")
	file.close()
