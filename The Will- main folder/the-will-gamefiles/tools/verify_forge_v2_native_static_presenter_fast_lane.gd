extends SceneTree

const AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const PlacementTargetResolverScript = preload(
	"res://runtime/forge_v2/forge_v2_placement_target_resolver.gd"
)
const WorkspacePreviewScript = preload(
	"res://runtime/forge_v2/forge_v2_workspace_preview.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_native_static_presenter_fast_lane.json"
)
const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const SURFACE_DISTANCE_LIMIT_METERS := 0.00002
const BOUNDS_LIMIT_METERS := 0.00001
const HIT_POSITION_LIMIT_METERS := 0.00020
const NORMAL_DOT_MIN := 0.995
const ABC_DOT_MAX := -0.999
const DIRECT_RAY_OFFSET_METERS := 0.004
const CAMERA_DISTANCE_METERS := 0.30
const READINESS_FRAME_LIMIT := 180


class TestStageController:
	extends Node

	signal authoring_state_changed(state)
	signal material_body_preview_changed(state)
	signal placement_cursor_changed(
		local_position: Vector3,
		is_valid: bool,
		radius_meters: float
	)

	var state: Resource = AuthoringStateScript.new()

	func _init() -> void:
		var empty_bodies: Array[Resource] = []
		state.set("material_bodies", empty_bodies)

	func get_active_authoring_state() -> Resource:
		return state

	func get_active_placement_body_id() -> StringName:
		return StringName()

	func get_placement_cursor_state() -> Dictionary:
		return {
			"local_position": Vector3.ZERO,
			"is_valid": false,
			"radius_meters": 0.02,
		}

	func publish(next_bodies: Array[Resource]) -> void:
		state.set("material_bodies", next_bodies.duplicate())
		authoring_state_changed.emit(state)


var _workspace: Node3D
var _presenter: Node3D
var _controller: TestStageController
var _failures: Array[String] = []
var _report := {
	"schema": "forge_v2_native_static_presenter_fast_lane",
	"schema_version": 1,
	"ok": false,
	"production_files_touched": false,
	"runtime_executed_during_authoring": false,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	_workspace = WorkspacePreviewScript.new()
	_workspace.name = "NativeStaticPresenterFastLaneWorkspace"
	root.add_child(_workspace)
	await process_frame
	_presenter = _workspace.get("volume_preview_presenter") as Node3D
	if _presenter == null:
		_finish_failure("workspace did not create the production presenter")
		return
	if not _presenter.has_method("get_native_static_sync_diagnostics"):
		_finish_failure("presenter native static diagnostic contract is missing")
		return
	_controller = TestStageController.new()
	root.add_child(_controller)
	_workspace.call("bind_stage_controller", _controller)
	await process_frame
	await physics_frame

	var empty_diagnostics := _native_diagnostics()
	_require(
		String(empty_diagnostics.get("last_mode", "")) == "armed_empty"
		and String(empty_diagnostics.get("lifecycle", "")) == "armed_empty"
		and not bool(empty_diagnostics.get("authoritative", true))
		and int(empty_diagnostics.get("prefix_body_count", -1)) == 0,
		"empty presenter did not arm the native lane"
	)

	var bodies := _build_connected_explicit_bodies()
	if bodies.size() != 3:
		_finish_failure("three-body explicit profile fixture construction failed")
		return
	var steps: Array[Dictionary] = []
	var expected_modes := PackedStringArray(["reset", "append", "append"])
	var probe_labels := PackedStringArray(["A", "B", "C"])
	var final_publication: Dictionary = {}
	for body_count in range(1, bodies.size() + 1):
		var prefix := _body_prefix(bodies, body_count)
		_controller.publish(prefix)
		var ready := await _await_native_publication_ready(
			expected_modes[body_count - 1],
			body_count
		)
		_require(
			bool(ready.get("ok", false)),
			"native revision %d did not become physics-ready" % body_count
		)
		if not bool(ready.get("ok", false)):
			_finish_failure("native publication readiness failed")
			return
		var identity := _expected_surface_identity(prefix)
		var publication := _capture_native_publication()
		var contract := _validate_native_publication_contract(
			publication,
			identity,
			body_count
		)
		_require(
			bool(contract.get("ok", false)),
			"native revision %d violated its render/collision contract" % body_count
		)
		var mesh_instance := publication.get("mesh", null) as MeshInstance3D
		var collision_body := publication.get("body", null) as StaticBody3D
		var targeting := await _capture_resolver_abc_probe(
			(mesh_instance.mesh as ArrayMesh) if mesh_instance != null else null,
			mesh_instance,
			[collision_body] if collision_body != null else [],
			identity,
			probe_labels[body_count - 1]
		)
		_require(
			bool(targeting.get("ok", false)),
			"real placement resolver missed native revision %d" % body_count
		)
		var diagnostics := _native_diagnostics()
		steps.append({
			"body_count": body_count,
			"expected_mode": expected_modes[body_count - 1],
			"diagnostics": _diagnostic_summary(diagnostics),
			"contract": _strip_runtime_objects(contract),
			"targeting": targeting,
		})
		final_publication = publication

	var final_diagnostics := _native_diagnostics()
	_require(
		int(final_diagnostics.get("reset_count", -1)) == 1
		and int(final_diagnostics.get("append_count", -1)) == 2
		and int(final_diagnostics.get("publication_count", -1)) == 3
		and int(final_diagnostics.get("fallback_count", -1)) == 0,
		"native diagnostics were not exactly reset then two appends"
	)

	var pre_noop_identity := _publication_resource_identity(final_publication)
	_controller.publish(_body_prefix(bodies, 3))
	await process_frame
	await physics_frame
	var no_op_diagnostics := _native_diagnostics()
	var no_op_publication := _capture_native_publication()
	var post_noop_identity := _publication_resource_identity(no_op_publication)
	_require(
		String(no_op_diagnostics.get("last_mode", "")) == "no_op"
		and int(no_op_diagnostics.get("reset_count", -1)) == 1
		and int(no_op_diagnostics.get("append_count", -1)) == 2
		and int(no_op_diagnostics.get("publication_count", -1)) == 3
		and pre_noop_identity == post_noop_identity,
		"no-op sync rebuilt or republished native resources"
	)
	var no_op_identity := _expected_surface_identity(_body_prefix(bodies, 3))
	var no_op_targeting := await _capture_resolver_abc_probe(
		(no_op_publication.get("mesh", null) as MeshInstance3D).mesh as ArrayMesh,
		no_op_publication.get("mesh", null) as MeshInstance3D,
		[no_op_publication.get("body", null)],
		no_op_identity,
		"no_op"
	)
	_require(
		bool(no_op_targeting.get("ok", false)),
		"no-op publication stopped being targetable"
	)

	var native_mesh_instance := no_op_publication.get(
		"mesh", null
	) as MeshInstance3D
	var native_mesh := (
		native_mesh_instance.mesh as ArrayMesh
		if native_mesh_instance != null
		else null
	)
	var oracle_mesh := await _build_independent_current_csg_oracle(bodies)
	if native_mesh == null or oracle_mesh == null:
		_finish_failure("native or independent current-CSG parity mesh is missing")
		return
	var native_analysis := MeshAnalyzerScript.analyze_mesh(native_mesh)
	var oracle_analysis := MeshAnalyzerScript.analyze_mesh(oracle_mesh)
	var surface_comparison := MeshAnalyzerScript.compare_surfaces(
		native_analysis,
		oracle_analysis
	)
	var volume_delta := absf(
		float(native_analysis.get("absolute_volume_cubic_meters", 0.0))
		- float(oracle_analysis.get("absolute_volume_cubic_meters", 0.0))
	)
	var volume_limit := maxf(
		0.0000000005,
		float(oracle_analysis.get("absolute_volume_cubic_meters", 0.0))
		* 0.0001
	)
	var bounds_delta := _bounds_delta(native_analysis, oracle_analysis)
	var parity_gates := {
		"native_strict_topology": _strict_topology_passes(native_analysis),
		"csg_oracle_strict_topology": _strict_topology_passes(oracle_analysis),
		"surface_within_20um": (
			float(surface_comparison.get("bidirectional_max_meters", INF))
			<= SURFACE_DISTANCE_LIMIT_METERS
		),
		"bounds_within_10um": bounds_delta <= BOUNDS_LIMIT_METERS,
		"volume_within_tolerance": volume_delta <= volume_limit,
	}
	for parity_gate: Variant in parity_gates.values():
		_require(bool(parity_gate), "final native/current-CSG parity gate failed")

	var stale_native_body_weak: WeakRef = weakref(
		no_op_publication.get("body", null) as StaticBody3D
	)
	var stale_native_revision_weak: WeakRef = weakref(
		no_op_publication.get("revision", null) as Node3D
	)
	var reordered: Array[Resource] = [bodies[1], bodies[0], bodies[2]]
	_controller.publish(reordered)
	var fallback_ready := await _await_csg_fallback_ready()
	_require(
		bool(fallback_ready.get("ok", false)),
		"body reorder did not publish the existing full-CSG fallback"
	)
	await _await_native_fallback_retirement()
	var fallback_diagnostics := _native_diagnostics()
	var csg_diagnostics := (
		_presenter.call("get_csg_static_sync_diagnostics") as Dictionary
	)
	var native_root := _presenter.get_node_or_null(
		"MaterialBodyCsgRoot/NativeStaticMaterialBodyRoot"
	) as Node3D
	var stale_native_collider_absent := (
		stale_native_body_weak.get_ref() == null
		and stale_native_revision_weak.get_ref() == null
		and native_root != null
		and not native_root.visible
		and native_root.get_child_count() == 0
		and _count_targetable_native_colliders(_presenter) == 0
	)
	_require(
		String(fallback_diagnostics.get("last_mode", "")) == "fallback_csg"
		and String(fallback_diagnostics.get("lifecycle", ""))
		== "disabled_until_empty"
		and not bool(fallback_diagnostics.get("authoritative", true))
		and String(fallback_diagnostics.get("last_failure_reason", ""))
		== "body_order_changed"
		and int(fallback_diagnostics.get("fallback_count", -1)) == 1
		and String(csg_diagnostics.get("last_mode", "")) == "full_rebuild",
		"reorder did not invalidate native state into full-CSG fallback"
	)
	_require(
		stale_native_collider_absent,
		"fallback retained a stale native revision or targetable collider"
	)
	var fallback_identity := _expected_surface_identity(reordered)
	var fallback_colliders := _collect_targetable_csg_colliders()
	var fallback_targeting := await _capture_resolver_abc_probe(
		oracle_mesh,
		null,
		fallback_colliders,
		fallback_identity,
		"fallback"
	)
	_require(
		bool(fallback_targeting.get("ok", false))
		and fallback_targeting.get("collider_class", "")
		== "CSGCombiner3D",
		"full-CSG fallback was not targetable through the real resolver"
	)

	var gates := {
		"empty_arms_native_lane": (
			String(empty_diagnostics.get("last_mode", "")) == "armed_empty"
		),
		"diagnostic_sequence_reset_append_append": (
			int(final_diagnostics.get("reset_count", -1)) == 1
			and int(final_diagnostics.get("append_count", -1)) == 2
		),
		"three_native_publications_targetable": (
			steps.size() == 3
			and bool(steps[0].get("targeting", {}).get("ok", false))
			and bool(steps[1].get("targeting", {}).get("ok", false))
			and bool(steps[2].get("targeting", {}).get("ok", false))
		),
		"native_no_op_preserves_resources": (
			pre_noop_identity == post_noop_identity
		),
		"final_geometry_matches_current_csg": (
			bool(parity_gates.get("native_strict_topology", false))
			and bool(parity_gates.get("csg_oracle_strict_topology", false))
			and bool(parity_gates.get("surface_within_20um", false))
			and bool(parity_gates.get("bounds_within_10um", false))
			and bool(parity_gates.get("volume_within_tolerance", false))
		),
		"reorder_uses_full_csg_fallback": (
			String(fallback_diagnostics.get("last_mode", ""))
			== "fallback_csg"
			and String(csg_diagnostics.get("last_mode", ""))
			== "full_rebuild"
		),
		"fallback_has_no_stale_native_collider": stale_native_collider_absent,
		"fallback_is_targetable": bool(fallback_targeting.get("ok", false)),
	}
	var passed := _failures.is_empty()
	for gate_value: Variant in gates.values():
		passed = passed and bool(gate_value)
	_report.merge({
		"ok": passed,
		"outcome": "pass" if passed else "fail",
		"scope": {
			"production_presenter_driven": true,
			"fake_controller_only": true,
			"connected_same_material_explicit_profile_body_count": 3,
			"fallback_trigger": "body_order_changed",
		},
		"steps": steps,
		"no_op": {
			"diagnostics": _diagnostic_summary(no_op_diagnostics),
			"resource_identity_before": pre_noop_identity,
			"resource_identity_after": post_noop_identity,
			"targeting": no_op_targeting,
		},
		"parity": {
			"surface": surface_comparison,
			"surface_limit_meters": SURFACE_DISTANCE_LIMIT_METERS,
			"bounds_max_delta_meters": bounds_delta,
			"bounds_limit_meters": BOUNDS_LIMIT_METERS,
			"volume_delta_cubic_meters": volume_delta,
			"volume_limit_cubic_meters": volume_limit,
			"native": MeshAnalyzerScript.strip_transient_arrays(native_analysis),
			"current_csg_oracle": MeshAnalyzerScript.strip_transient_arrays(
				oracle_analysis
			),
			"gates": parity_gates,
		},
		"fallback": {
			"native_diagnostics": _diagnostic_summary(fallback_diagnostics),
			"csg_diagnostics": csg_diagnostics,
			"stale_native_collider_absent": stale_native_collider_absent,
			"targeting": fallback_targeting,
		},
		"gates": gates,
		"failures": _failures,
	}, true)
	_write_report()
	if passed:
		print("FORGE_V2_NATIVE_STATIC_PRESENTER_FAST_LANE: PASS")
		quit(0)
	else:
		push_error(
			"FORGE_V2_NATIVE_STATIC_PRESENTER_FAST_LANE: FAIL: %s"
			% "; ".join(_failures)
		)
		quit(1)


func _build_connected_explicit_bodies() -> Array[Resource]:
	var paths: Array[PackedVector3Array] = [
		PackedVector3Array([
			Vector3(-0.18, 0.000, 0.050),
			Vector3(0.02, 0.000, 0.050),
		]),
		PackedVector3Array([
			Vector3(-0.03, 0.003, 0.052),
			Vector3(0.15, 0.006, 0.055),
		]),
		PackedVector3Array([
			Vector3(0.10, 0.004, 0.054),
			Vector3(0.26, -0.002, 0.058),
		]),
	]
	var polygon := PackedVector2Array([
		Vector2(-0.012, -0.009),
		Vector2(0.010, -0.010),
		Vector2(0.014, -0.003),
		Vector2(0.011, 0.009),
		Vector2(-0.008, 0.012),
		Vector2(-0.014, 0.002),
	])
	var result: Array[Resource] = []
	for index in range(paths.size()):
		var body: Resource = MaterialBodyScript.new()
		body.set("body_id", StringName("native_presenter_stroke_%d" % index))
		body.set("body_kind", MaterialBodyScript.BODY_KIND_VOLUME_STROKE)
		body.set("shape_kind", MaterialBodyScript.SHAPE_KIND_PROFILE_PATH)
		body.set("material_variant_id", MATERIAL_VARIANT_ID)
		body.set("path_points", paths[index])
		body.set("path_surface_normals", PackedVector3Array([
			Vector3.UP,
			Vector3.UP,
		]))
		body.set("path_contact_directions", PackedVector3Array([
			Vector3.DOWN,
			Vector3.DOWN,
		]))
		body.set("profile_id", &"native_presenter_asymmetric_six")
		body.set("profile_display_name", "Native presenter asymmetric six")
		body.set("profile_polygon_2d_meters", polygon)
		body.set("profile_anchor_2d_meters", Vector2.ZERO)
		body.set(
			"profile_contact_point_relative_2d_meters",
			Vector2(0.0, -0.010)
		)
		body.set("profile_contact_direction_2d", Vector2.DOWN)
		body.set("profile_contact_distance_meters", 0.010)
		body.set("profile_runtime_schema_version", 1)
		body.set("profile_rotation_bias_degrees", 0.0)
		body.call("normalize")
		result.append(body)
	return result


func _body_prefix(bodies: Array[Resource], count: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for body_index in range(mini(count, bodies.size())):
		result.append(bodies[body_index])
	return result


func _await_native_publication_ready(
	expected_mode: String,
	expected_body_count: int
) -> Dictionary:
	for frame_index in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		var diagnostics := _native_diagnostics()
		var publication := _capture_native_publication()
		if (
			String(diagnostics.get("last_mode", "")) == expected_mode
			and String(diagnostics.get("lifecycle", "")) == "active"
			and bool(diagnostics.get("authoritative", false))
			and not bool(diagnostics.get("publication_pending", true))
			and int(diagnostics.get("prefix_body_count", -1))
			== expected_body_count
			and int(diagnostics.get("published_revision", -1))
			== expected_body_count
			and bool(publication.get("complete", false))
		):
			return {
				"ok": true,
				"waited_process_physics_pairs": frame_index + 1,
			}
	return {
		"ok": false,
		"diagnostics": _diagnostic_summary(_native_diagnostics()),
		"publication": _strip_runtime_objects(_capture_native_publication()),
	}


func _await_csg_fallback_ready() -> Dictionary:
	for frame_index in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		var diagnostics := _native_diagnostics()
		var csg_root := _presenter.get_node_or_null(
			"MaterialBodyCsgRoot/StaticMaterialBodyCsgRoot"
		) as Node3D
		var colliders := _collect_targetable_csg_colliders()
		if (
			String(diagnostics.get("last_mode", "")) == "fallback_csg"
			and not bool(diagnostics.get("authoritative", true))
			and csg_root != null
			and csg_root.visible
			and not colliders.is_empty()
		):
			return {
				"ok": true,
				"waited_process_physics_pairs": frame_index + 1,
			}
	return {"ok": false}


func _await_native_fallback_retirement() -> void:
	for _frame_index in range(READINESS_FRAME_LIMIT):
		await process_frame
		await physics_frame
		var native_root := _presenter.get_node_or_null(
			"MaterialBodyCsgRoot/NativeStaticMaterialBodyRoot"
		) as Node3D
		if (
			native_root != null
			and not native_root.visible
			and native_root.get_child_count() == 0
			and _count_targetable_native_colliders(_presenter) == 0
		):
			return


func _native_diagnostics() -> Dictionary:
	return _presenter.call("get_native_static_sync_diagnostics") as Dictionary


func _capture_native_publication() -> Dictionary:
	var native_root := _presenter.get_node_or_null(
		"MaterialBodyCsgRoot/NativeStaticMaterialBodyRoot"
	) as Node3D
	if native_root == null:
		return {"complete": false, "native_root_present": false}
	var revisions: Array[Node] = []
	for child: Node in native_root.get_children():
		if String(child.name).begins_with("NativeStaticMaterialBodyRevision_"):
			revisions.append(child)
	if revisions.size() != 1:
		return {
			"complete": false,
			"native_root_present": true,
			"revision_count": revisions.size(),
			"root": native_root,
		}
	var revision := revisions[0] as Node3D
	var mesh := revision.get_node_or_null(
		"NativeStaticMaterialBodyMesh"
	) as MeshInstance3D
	var body := revision.get_node_or_null(
		"NativeStaticMaterialBodyCollision"
	) as StaticBody3D
	var shape := revision.get_node_or_null(
		"NativeStaticMaterialBodyCollision/NativeStaticMaterialBodyShape"
	) as CollisionShape3D
	return {
		"complete": (
			native_root.visible
			and revision.visible
			and mesh != null
			and mesh.mesh is ArrayMesh
			and body != null
			and shape != null
			and shape.shape is ConcavePolygonShape3D
		),
		"native_root_present": true,
		"revision_count": revisions.size(),
		"root": native_root,
		"revision": revision,
		"mesh": mesh,
		"body": body,
		"shape": shape,
	}


func _validate_native_publication_contract(
	publication: Dictionary,
	identity: Dictionary,
	expected_revision: int
) -> Dictionary:
	var native_root := publication.get("root", null) as Node3D
	var revision := publication.get("revision", null) as Node3D
	var mesh_instance := publication.get("mesh", null) as MeshInstance3D
	var collision_body := publication.get("body", null) as StaticBody3D
	var collision_shape := publication.get("shape", null) as CollisionShape3D
	if (
		native_root == null
		or revision == null
		or mesh_instance == null
		or collision_body == null
		or collision_shape == null
	):
		return {"ok": false, "reason": "publication_nodes_missing"}
	var mesh := mesh_instance.mesh as ArrayMesh
	var normals_valid := _mesh_has_finite_nonzero_normals(mesh)
	var expected_material := _presenter.call(
		"_build_csg_body_material",
		MATERIAL_VARIANT_ID,
		false
	) as StandardMaterial3D
	var material_valid := _materials_match(
		mesh_instance.material_override as StandardMaterial3D,
		expected_material
	)
	var metadata_valid := true
	for metadata_node: Node in [revision, mesh_instance, collision_body]:
		metadata_valid = metadata_valid and (
			bool(metadata_node.get_meta("forge_v2_material_surface", false))
			and StringName(metadata_node.get_meta(
				"forge_v2_material_variant_id",
				StringName()
			)) == StringName(identity.get("material_variant_id", StringName()))
			and StringName(metadata_node.get_meta(
				"forge_v2_body_id",
				StringName()
			)) == StringName(identity.get("body_id", StringName()))
			and StringName(metadata_node.get_meta(
				"forge_v2_surface_target_id",
				StringName()
			)) == StringName(identity.get("surface_target_id", StringName()))
			and not bool(metadata_node.get_meta(
				"forge_v2_publication_pending",
				true
			))
			and int(metadata_node.get_meta("forge_v2_native_revision", -1))
			== expected_revision
		)
	var csg_off := _csg_static_publication_is_hidden_and_off()
	var transforms_identity := (
		native_root.transform.is_equal_approx(Transform3D.IDENTITY)
		and revision.transform.is_equal_approx(Transform3D.IDENTITY)
		and mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY)
		and collision_body.transform.is_equal_approx(Transform3D.IDENTITY)
		and collision_shape.transform.is_equal_approx(Transform3D.IDENTITY)
	)
	var ok := (
		bool(publication.get("complete", false))
		and int(publication.get("revision_count", -1)) == 1
		and collision_body.collision_layer
		== PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		and collision_body.collision_mask == 0
		and metadata_valid
		and normals_valid
		and material_valid
		and transforms_identity
		and csg_off
	)
	return {
		"ok": ok,
		"revision_count": int(publication.get("revision_count", -1)),
		"collision_layer": collision_body.collision_layer,
		"metadata_valid": metadata_valid,
		"finite_nonzero_render_normals": normals_valid,
		"render_material_matches_current_csg": material_valid,
		"identity_transforms": transforms_identity,
		"csg_static_publication_hidden_and_off": csg_off,
		"surface_target_id": String(identity.get("surface_target_id", "")),
		"body_id": String(identity.get("body_id", "")),
		"material_variant_id": String(identity.get("material_variant_id", "")),
	}


func _expected_surface_identity(bodies: Array[Resource]) -> Dictionary:
	var zones := _presenter.call("_build_csg_body_zones", bodies) as Array
	if zones.size() != 1 or not (zones[0] is Dictionary):
		return {}
	var zone := zones[0] as Dictionary
	var primary_body_ids := zone.get("primary_body_ids", []) as Array
	return {
		"material_variant_id": StringName(zone.get(
			"material_variant_id",
			StringName()
		)),
		"body_id": StringName(_presenter.call(
			"_resolve_zone_collision_body_id",
			primary_body_ids
		)),
		"surface_target_id": StringName(zone.get(
			"surface_target_id",
			StringName()
		)),
	}


func _mesh_has_finite_nonzero_normals(mesh: ArrayMesh) -> bool:
	if mesh == null or mesh.get_surface_count() != 1:
		return false
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() < Mesh.ARRAY_MAX:
		return false
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.is_empty() or normals.size() != vertices.size():
		return false
	for normal: Vector3 in normals:
		if not normal.is_finite() or normal.length_squared() <= 0.5:
			return false
	return true


func _materials_match(
	actual: StandardMaterial3D,
	expected: StandardMaterial3D
) -> bool:
	return (
		actual != null
		and expected != null
		and actual.albedo_color.is_equal_approx(expected.albedo_color)
		and is_equal_approx(actual.roughness, expected.roughness)
		and is_equal_approx(actual.metallic, expected.metallic)
		and actual.emission_enabled == expected.emission_enabled
		and actual.emission.is_equal_approx(expected.emission)
		and actual.transparency == expected.transparency
		and actual.cull_mode == expected.cull_mode
	)


func _csg_static_publication_is_hidden_and_off() -> bool:
	var csg_root := _presenter.get_node_or_null(
		"MaterialBodyCsgRoot/StaticMaterialBodyCsgRoot"
	) as Node3D
	if csg_root == null or csg_root.visible:
		return false
	return _all_csg_shapes_off(csg_root)


func _all_csg_shapes_off(node: Node) -> bool:
	if node is CSGShape3D:
		var shape := node as CSGShape3D
		if (
			shape.collision_layer
			& PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		) != 0:
			return false
		if bool(shape.get_meta("forge_v2_material_surface", false)):
			return false
	for child: Node in node.get_children():
		if not _all_csg_shapes_off(child):
			return false
	return true


func _capture_resolver_abc_probe(
	mesh: ArrayMesh,
	mesh_instance: MeshInstance3D,
	allowed_colliders: Array,
	identity: Dictionary,
	label: String
) -> Dictionary:
	if mesh == null or allowed_colliders.is_empty():
		return {"ok": false, "reason": "probe_mesh_or_colliders_missing"}
	var camera := _workspace.get("camera") as Camera3D
	if camera == null:
		return {"ok": false, "reason": "workspace_camera_missing"}
	var arrays := mesh.surface_get_arrays(0)
	if arrays.size() < Mesh.ARRAY_MAX:
		return {"ok": false, "reason": "probe_mesh_arrays_missing"}
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
	if index_data is PackedInt32Array:
		indices = index_data as PackedInt32Array
	if indices.is_empty():
		indices.resize(vertices.size())
		for vertex_index in range(vertices.size()):
			indices[vertex_index] = vertex_index
	var candidates: Array[Dictionary] = []
	for triangle_index in range(indices.size() / 3):
		var a := vertices[indices[triangle_index * 3]]
		var b := vertices[indices[triangle_index * 3 + 1]]
		var c := vertices[indices[triangle_index * 3 + 2]]
		var cross := (b - a).cross(c - a)
		if cross.length_squared() <= 0.000000000001:
			continue
		candidates.append({
			"triangle": triangle_index,
			"center": (a + b + c) / 3.0,
			"cross": cross.normalized(),
			"area_squared": cross.length_squared(),
		})
	candidates.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return (
			float(first.get("area_squared", 0.0))
			> float(second.get("area_squared", 0.0))
		)
	)
	for candidate_variant: Variant in candidates:
		var candidate := candidate_variant as Dictionary
		for normal_sign: float in [-1.0, 1.0]:
			var local_center := candidate.get("center", Vector3.ZERO) as Vector3
			var local_guess := (
				candidate.get("cross", Vector3.ZERO) as Vector3
			) * normal_sign
			var workspace_center := local_center
			var workspace_guess := local_guess
			if mesh_instance != null:
				workspace_center = _workspace.to_local(
					mesh_instance.to_global(local_center)
				)
				workspace_guess = (
					_workspace.global_transform.basis.inverse()
					* (mesh_instance.global_transform.basis * local_guess)
				).normalized()
			var direct := _direct_probe(
				workspace_center,
				workspace_guess,
				allowed_colliders
			)
			if not bool(direct.get("ok", false)):
				continue
			var expected_position := direct.get(
				"local_position",
				workspace_center
			) as Vector3
			var expected_normal := direct.get(
				"local_normal",
				workspace_guess
			) as Vector3
			var up := (
				Vector3.UP
				if absf(expected_normal.dot(Vector3.UP)) < 0.94
				else Vector3.RIGHT
			)
			camera.global_position = _workspace.to_global(
				expected_position
				+ expected_normal * CAMERA_DISTANCE_METERS
			)
			camera.look_at(_workspace.to_global(expected_position), up)
			camera.current = true
			camera.near = 0.005
			camera.far = 2.0
			await process_frame
			var projection := _workspace.call(
				"project_workspace_local_to_screen",
				expected_position
			) as Dictionary
			if not bool(projection.get("valid", false)):
				continue
			var hit := _workspace.call(
				"resolve_strict_surface_target",
				projection.get("screen_position", Vector2.ZERO),
				PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE,
				StringName(identity.get("surface_target_id", StringName()))
			) as Dictionary
			var validation := _validate_resolver_hit(
				hit,
				expected_position,
				expected_normal,
				allowed_colliders,
				identity
			)
			if not bool(validation.get("ok", false)):
				continue
			var collider := hit.get("collider", null) as Object
			return {
				"ok": true,
				"label": label,
				"triangle": int(candidate.get("triangle", -1)),
				"collider_class": collider.get_class() if collider != null else "",
				"surface_target_id": String(identity.get("surface_target_id", "")),
				"body_id": String(identity.get("body_id", "")),
				"material_variant_id": String(identity.get(
					"material_variant_id",
					StringName()
				)),
				"position_error_meters": validation.get(
					"position_error_meters",
					INF
				),
				"normal_dot": validation.get("normal_dot", 0.0),
				"abc_normal_dot_contact": validation.get("abc_dot", 1.0),
			}
	return {"ok": false, "reason": "no resolver-valid surface candidate"}


func _direct_probe(
	local_center: Vector3,
	local_normal: Vector3,
	allowed_colliders: Array
) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		_workspace.to_global(
			local_center + local_normal * DIRECT_RAY_OFFSET_METERS
		),
		_workspace.to_global(
			local_center - local_normal * DIRECT_RAY_OFFSET_METERS
		),
		PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := _workspace.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not allowed_colliders.has(hit.get("collider", null)):
		return {"ok": false}
	var local_position := _workspace.to_local(
		hit.get("position", Vector3.ZERO) as Vector3
	)
	var local_hit_normal := (
		_workspace.global_transform.basis.inverse()
		* (hit.get("normal", Vector3.ZERO) as Vector3)
	).normalized()
	return {
		"ok": (
			local_position.distance_to(local_center)
			<= HIT_POSITION_LIMIT_METERS
			and local_hit_normal.dot(local_normal) >= NORMAL_DOT_MIN
		),
		"local_position": local_position,
		"local_normal": local_hit_normal,
	}


func _validate_resolver_hit(
	hit: Dictionary,
	expected_position: Vector3,
	expected_normal: Vector3,
	allowed_colliders: Array,
	identity: Dictionary
) -> Dictionary:
	var actual_position := hit.get("local_position", Vector3.ZERO) as Vector3
	var actual_normal := (
		hit.get("local_normal", Vector3.ZERO) as Vector3
	).normalized()
	var contact := (
		hit.get("local_contact_direction", Vector3.ZERO) as Vector3
	).normalized()
	var position_error := actual_position.distance_to(expected_position)
	var normal_dot := actual_normal.dot(expected_normal)
	var abc_dot := actual_normal.dot(contact)
	var ok := (
		bool(hit.get("valid", false))
		and allowed_colliders.has(hit.get("collider", null))
		and StringName(hit.get("target_kind", StringName()))
		== PlacementTargetResolverScript.TARGET_KIND_MATERIAL_SURFACE
		and StringName(hit.get("surface_target_id", StringName()))
		== StringName(identity.get("surface_target_id", StringName()))
		and StringName(hit.get("source_body_id", StringName()))
		== StringName(identity.get("body_id", StringName()))
		and StringName(hit.get("source_record_id", StringName()))
		== StringName(identity.get("material_variant_id", StringName()))
		and not bool(hit.get("is_clamped", true))
		and position_error <= HIT_POSITION_LIMIT_METERS
		and normal_dot >= NORMAL_DOT_MIN
		and abc_dot <= ABC_DOT_MAX
	)
	return {
		"ok": ok,
		"position_error_meters": position_error,
		"normal_dot": normal_dot,
		"abc_dot": abc_dot,
	}


func _build_independent_current_csg_oracle(
	bodies: Array[Resource]
) -> ArrayMesh:
	var combiner := CSGCombiner3D.new()
	combiner.name = "IndependentCurrentCsgOracle"
	combiner.operation = CSGShape3D.OPERATION_UNION
	combiner.calculate_tangents = false
	combiner.visible = false
	_workspace.add_child(combiner)
	for body_index in range(bodies.size()):
		if not bool(_presenter.call(
			"_append_csg_body_shape",
			combiner,
			bodies[body_index],
			MATERIAL_VARIANT_ID,
			false,
			body_index
		)):
			combiner.queue_free()
			return null
	await process_frame
	await process_frame
	var baked := combiner.bake_static_mesh()
	combiner.queue_free()
	return baked


func _strict_topology_passes(analysis: Dictionary) -> bool:
	return (
		int(analysis.get("triangle_count", 0)) > 0
		and int(analysis.get("nonfinite_vertex_count", -1)) == 0
		and int(analysis.get("degenerate_triangle_count", -1)) == 0
		and bool(analysis.get("strict_watertight", false))
		and int(analysis.get("strict_component_count", -1)) == 1
		and int(analysis.get("strict_boundary_edge_count", -1)) == 0
		and int(analysis.get("strict_nonmanifold_edge_count", -1)) == 0
		and int(analysis.get("strict_directed_edge_mismatch_count", -1)) == 0
	)


func _bounds_delta(first: Dictionary, second: Dictionary) -> float:
	var maximum := 0.0
	for suffix: String in [
		"position_x",
		"position_y",
		"position_z",
		"size_x",
		"size_y",
		"size_z",
	]:
		maximum = maxf(maximum, absf(
			float(first.get("aabb_%s" % suffix, INF))
			- float(second.get("aabb_%s" % suffix, -INF))
		))
	return maximum


func _publication_resource_identity(publication: Dictionary) -> Dictionary:
	var revision := publication.get("revision", null) as Node3D
	var mesh_instance := publication.get("mesh", null) as MeshInstance3D
	var body := publication.get("body", null) as StaticBody3D
	var shape := publication.get("shape", null) as CollisionShape3D
	return {
		"revision_node": revision.get_instance_id() if revision != null else 0,
		"mesh_node": mesh_instance.get_instance_id() if mesh_instance != null else 0,
		"mesh_resource": (
			mesh_instance.mesh.get_instance_id()
			if mesh_instance != null and mesh_instance.mesh != null
			else 0
		),
		"collision_body": body.get_instance_id() if body != null else 0,
		"collision_shape_node": shape.get_instance_id() if shape != null else 0,
		"collision_shape_resource": (
			shape.shape.get_instance_id()
			if shape != null and shape.shape != null
			else 0
		),
	}


func _collect_targetable_csg_colliders() -> Array:
	var result: Array = []
	var csg_root := _presenter.get_node_or_null(
		"MaterialBodyCsgRoot/StaticMaterialBodyCsgRoot"
	) as Node3D
	_collect_targetable_csg_colliders_recursive(csg_root, result)
	return result


func _collect_targetable_csg_colliders_recursive(
	node: Node,
	result: Array
) -> void:
	if node == null:
		return
	if node is CSGShape3D:
		var csg := node as CSGShape3D
		if (
			csg.collision_layer
			& PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
		) != 0:
			result.append(csg)
	for child: Node in node.get_children():
		_collect_targetable_csg_colliders_recursive(child, result)


func _count_targetable_native_colliders(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	if node is StaticBody3D:
		var body := node as StaticBody3D
		if (
			String(body.name) == "NativeStaticMaterialBodyCollision"
			and (
				body.collision_layer
				& PlacementTargetResolverScript.MATERIAL_SURFACE_COLLISION_LAYER
			) != 0
		):
			count += 1
	for child: Node in node.get_children():
		count += _count_targetable_native_colliders(child)
	return count


func _diagnostic_summary(diagnostics: Dictionary) -> Dictionary:
	return {
		"lifecycle": String(diagnostics.get("lifecycle", "")),
		"last_mode": String(diagnostics.get("last_mode", "")),
		"authoritative": bool(diagnostics.get("authoritative", false)),
		"publication_pending": bool(diagnostics.get(
			"publication_pending",
			false
		)),
		"prefix_body_count": int(diagnostics.get("prefix_body_count", -1)),
		"material_variant_id": String(diagnostics.get(
			"material_variant_id",
			StringName()
		)),
		"expected_revision": int(diagnostics.get("expected_revision", -1)),
		"published_revision": int(diagnostics.get("published_revision", -1)),
		"staged_revision": int(diagnostics.get("staged_revision", -1)),
		"reset_count": int(diagnostics.get("reset_count", -1)),
		"append_count": int(diagnostics.get("append_count", -1)),
		"publication_count": int(diagnostics.get("publication_count", -1)),
		"fallback_count": int(diagnostics.get("fallback_count", -1)),
		"last_failure_reason": String(diagnostics.get(
			"last_failure_reason",
			""
		)),
		"last_native_total_ms": float(diagnostics.get(
			"last_native_total_ms",
			0.0
		)),
		"output_vertices": int(diagnostics.get("output_vertices", -1)),
		"output_triangles": int(diagnostics.get("output_triangles", -1)),
	}


func _strip_runtime_objects(value: Dictionary) -> Dictionary:
	var result := value.duplicate(false)
	for key: String in ["root", "revision", "mesh", "body", "shape"]:
		result.erase(key)
	return result


func _require(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _finish_failure(message: String) -> void:
	_require(false, message)
	_report.merge({
		"ok": false,
		"outcome": "fail",
		"failures": _failures,
	}, true)
	_write_report()
	push_error("FORGE_V2_NATIVE_STATIC_PRESENTER_FAST_LANE: %s" % message)
	quit(1)


func _write_report() -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_report, "\t"))
		file.close()
