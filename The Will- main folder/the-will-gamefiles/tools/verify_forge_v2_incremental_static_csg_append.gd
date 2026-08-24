extends SceneTree

const PresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const StressFixtureScript = preload(
	"res://tools/forge_v2_workpiece_stress_fixture.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_incremental_static_csg_append.txt"
)

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = PresenterScript.new()
	presenter.name = "IncrementalStaticCsgAppendVerifier"
	root.add_child(presenter)
	await process_frame

	var bodies: Array = [
		StressFixtureScript.build_seed_body(),
		StressFixtureScript.build_operation_body(0),
		StressFixtureScript.build_operation_body(1),
	]
	_require(not bodies.has(null), "deterministic fixture body missing")

	presenter.call("_sync_static_csg_zones", [bodies[0]])
	var zone := _single_zone(presenter)
	_require(zone != null, "initial full rebuild did not create one zone")
	var zone_instance_id := zone.get_instance_id() if zone != null else 0
	var first_child_instance_id := _child_instance_id(zone, 0)
	_assert_mode(presenter, "full_rebuild", 0, 1)

	presenter.call("_sync_static_csg_zones", bodies.slice(0, 2))
	var append_one_zone := _single_zone(presenter)
	_require(
		append_one_zone != null
		and append_one_zone.get_instance_id() == zone_instance_id,
		"first append replaced the existing zone node"
	)
	_require(
		_child_instance_id(append_one_zone, 0) == first_child_instance_id,
		"first append replaced the old operand child"
	)
	_require(
		append_one_zone != null and append_one_zone.get_child_count() == 2,
		"first append did not add exactly one operand child"
	)
	var second_child_instance_id := _child_instance_id(append_one_zone, 1)
	_assert_mode(presenter, "incremental_append", 1, 1)
	await process_frame
	await physics_frame
	_require(
		append_one_zone != null
		and not bool(append_one_zone.get_meta(
			"forge_v2_publication_pending",
			true
		)),
		"first append target metadata did not publish after process+physics"
	)

	presenter.call("_sync_static_csg_zones", bodies.slice(0, 2))
	var no_op_zone := _single_zone(presenter)
	_require(
		no_op_zone != null
		and no_op_zone.get_instance_id() == zone_instance_id
		and _child_instance_id(no_op_zone, 0) == first_child_instance_id
		and _child_instance_id(no_op_zone, 1) == second_child_instance_id,
		"no-op sync changed the persistent zone tree"
	)
	_assert_mode(presenter, "no_op", 1, 1)

	presenter.call("_sync_static_csg_zones", bodies)
	var final_zone := _single_zone(presenter)
	_require(
		final_zone != null
		and final_zone.get_instance_id() == zone_instance_id,
		"second append replaced the existing zone node"
	)
	_require(
		final_zone != null
		and final_zone.get_child_count() == 3
		and _child_instance_id(final_zone, 0) == first_child_instance_id
		and _child_instance_id(final_zone, 1) == second_child_instance_id,
		"second append did not preserve both old children and add one child"
	)
	_assert_mode(presenter, "incremental_append", 2, 1)
	_assert_final_zone_matches_full_build(presenter, final_zone, bodies)

	var pre_mutation_zone_id := final_zone.get_instance_id() if final_zone != null else 0
	(bodies[0] as Resource).set(
		"updated_timestamp",
		float((bodies[0] as Resource).get("updated_timestamp")) + 1.0
	)
	presenter.call("_sync_static_csg_zones", bodies)
	var mutation_zone := _single_zone(presenter)
	var mutation_diagnostics := (
		presenter.call("get_csg_static_sync_diagnostics") as Dictionary
	)
	_require(
		String(mutation_diagnostics.get("last_mode", "")) == "full_rebuild",
		"prefix mutation did not take the full-rebuild fallback"
	)
	_require(
		mutation_zone != null
		and mutation_zone.get_instance_id() != pre_mutation_zone_id,
		"prefix mutation reused a stale zone node"
	)

	var mixed_body: Resource = StressFixtureScript.build_operation_body(2)
	mixed_body.set("material_variant_id", &"mat_verifier_second")
	var mixed_bodies := bodies.duplicate()
	mixed_bodies.append(mixed_body)
	presenter.call("_sync_static_csg_zones", mixed_bodies)
	var mixed_diagnostics := (
		presenter.call("get_csg_static_sync_diagnostics") as Dictionary
	)
	_require(
		String(mixed_diagnostics.get("last_mode", "")) == "full_rebuild"
		and String(mixed_diagnostics.get("last_fallback_reason", ""))
		== "complex_composition",
		"multi-material append did not take the strict complex fallback"
	)

	var lines := PackedStringArray([
		"ok=%s" % str(failures.is_empty()).to_lower(),
		"simple_append_reuses_zone=true",
		"old_operand_children_reused=true",
		"one_new_child_per_append=true",
		"no_op_reuses_tree=true",
		"final_zone_signature_and_body_ids_match_full_build=true",
		"organic_operand_tree_matches_full_build=true",
		"prefix_mutation_full_rebuild=true",
		"multimaterial_full_rebuild=true",
		"failures=%s" % JSON.stringify(failures),
	])
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	if failures.is_empty():
		print("FORGE_V2_INCREMENTAL_STATIC_CSG_APPEND PASS")
		quit(0)
	else:
		push_error("; ".join(failures))
		quit(1)


func _assert_mode(
	presenter: Node,
	expected_mode: String,
	expected_append_count: int,
	expected_full_rebuild_count: int
) -> void:
	var diagnostics := (
		presenter.call("get_csg_static_sync_diagnostics") as Dictionary
	)
	_require(
		String(diagnostics.get("last_mode", "")) == expected_mode,
		"expected mode %s, got %s" % [
			expected_mode,
			String(diagnostics.get("last_mode", "")),
		]
	)
	_require(
		int(diagnostics.get("incremental_append_count", -1))
		== expected_append_count,
		"incremental append diagnostic count drifted"
	)
	_require(
		int(diagnostics.get("full_rebuild_count", -1))
		== expected_full_rebuild_count,
		"full rebuild diagnostic count drifted"
	)


func _assert_final_zone_matches_full_build(
	presenter: Node,
	actual_zone: Node,
	bodies: Array
) -> void:
	var expected_zones := presenter.call("_build_csg_body_zones", bodies) as Array
	_require(expected_zones.size() == 1, "full builder did not resolve one zone")
	if expected_zones.size() != 1 or actual_zone == null:
		return
	var expected_zone := expected_zones[0] as Dictionary
	var zone_key := String(expected_zone.get("zone_key", ""))
	var signatures: Dictionary = presenter.get("csg_static_zone_signatures")
	var ids_by_key: Dictionary = presenter.get("csg_static_zone_body_ids_by_key")
	_require(
		String(signatures.get(zone_key, ""))
		== String(expected_zone.get("signature", "")),
		"incremental final zone signature differs from full build"
	)
	_require(
		JSON.stringify(ids_by_key.get(zone_key, []))
		== JSON.stringify(expected_zone.get("primary_body_ids", [])),
		"incremental final primary body IDs differ from full build"
	)
	var oracle := presenter.call(
		"_build_csg_zone_node",
		expected_zone,
		false,
		"OracleZone"
	) as CSGCombiner3D
	_require(oracle != null, "full-build organic operand oracle was not created")
	if oracle == null:
		return
	_require(
		_child_operand_signatures(actual_zone)
		== _child_operand_signatures(oracle),
		"incremental organic operand geometry/order differs from full build"
	)
	oracle.free()


func _child_operand_signatures(zone: Node) -> PackedStringArray:
	var result := PackedStringArray()
	if zone == null:
		return result
	for child: Node in zone.get_children():
		result.append(_operand_signature(child))
	return result


func _operand_signature(node: Node) -> String:
	if node == null:
		return "null"
	var parts := PackedStringArray([
		node.get_class(),
		String(node.name),
	])
	if node is CSGShape3D:
		parts.append("operation=%d" % int((node as CSGShape3D).operation))
	if node is CSGMesh3D:
		parts.append("mesh=%s" % _mesh_signature((node as CSGMesh3D).mesh))
	for child: Node in node.get_children():
		parts.append(_operand_signature(child))
	return "|".join(parts)


func _mesh_signature(mesh: Mesh) -> String:
	if mesh == null:
		return "null"
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return "hash_error"
	context.update(var_to_bytes(mesh.get_surface_count()))
	for surface_index in range(mesh.get_surface_count()):
		context.update(var_to_bytes(mesh.surface_get_arrays(surface_index)))
	return context.finish().hex_encode()


func _single_zone(presenter: Node) -> CSGCombiner3D:
	var zones: Dictionary = presenter.get("csg_static_zone_nodes")
	if zones.size() != 1:
		return null
	return zones.values()[0] as CSGCombiner3D


func _child_instance_id(node: Node, child_index: int) -> int:
	if node == null or child_index < 0 or child_index >= node.get_child_count():
		return 0
	return node.get_child(child_index).get_instance_id()


func _require(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
