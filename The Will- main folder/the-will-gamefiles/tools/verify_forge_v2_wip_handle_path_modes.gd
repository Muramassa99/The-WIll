extends SceneTree

const ForgeV2AuthoringStateScript = preload(
	"res://runtime/forge_v2/forge_v2_authoring_state.gd"
)
const ForgeV2MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const ForgeV2WipCompatibilityAdapterScript = preload(
	"res://runtime/forge_v2/forge_v2_wip_compatibility_adapter.gd"
)

const HANDLE_START := Vector3(-0.16, 0.0, 0.0)
const HANDLE_MIDDLE := Vector3(0.0, 0.04, 0.0)
const HANDLE_END := Vector3(0.16, 0.0, 0.0)
const GEOMETRY_EPSILON := 0.000001

var failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	_verify_supported_mode(
		"three-point spline",
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH,
		PackedVector3Array([HANDLE_START, HANDLE_MIDDLE, HANDLE_END])
	)
	_verify_supported_mode(
		"three-point linear",
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
		PackedVector3Array([HANDLE_START, HANDLE_MIDDLE, HANDLE_END])
	)
	_verify_supported_mode(
		"two-point linear",
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
		PackedVector3Array([HANDLE_START, HANDLE_END])
	)
	_verify_rejected_mode(
		"two-point spline",
		ForgeV2MaterialBodyScript.SHAPE_KIND_SPLINE_PROFILE_PATH,
		PackedVector3Array([HANDLE_START, HANDLE_END]),
		"forge_v2_primary_handle_spline_requires_exactly_three_points"
	)
	_verify_rejected_mode(
		"four-point linear",
		ForgeV2MaterialBodyScript.SHAPE_KIND_PROFILE_PATH,
		PackedVector3Array([
			HANDLE_START,
			Vector3(-0.05, 0.0, 0.0),
			Vector3(0.05, 0.0, 0.0),
			HANDLE_END,
		]),
		"forge_v2_primary_handle_linear_requires_two_or_three_points"
	)
	_verify_rejected_mode(
		"capsule path",
		ForgeV2MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH,
		PackedVector3Array([HANDLE_START, HANDLE_MIDDLE, HANDLE_END]),
		"forge_v2_primary_handle_path_shape_unsupported"
	)

	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		quit(1)
		return
	print("Forge V2 WIP Handle path mode verifier passed")
	quit(0)


func _verify_supported_mode(
	label: String,
	shape_kind: StringName,
	path_points: PackedVector3Array
) -> void:
	var fixture := _build_handle_fixture(shape_kind, path_points)
	var state := fixture.get("state") as Resource
	var body := fixture.get("body") as Resource
	var validation := (
		ForgeV2WipCompatibilityAdapterScript.resolve_valid_handle_body(state)
	)
	_expect(
		bool(validation.get("valid", false)),
		"%s was rejected: %s" % [
			label,
			String(validation.get("error", "unknown error")),
		]
	)
	if not bool(validation.get("valid", false)):
		return
	var resolved_points := validation.get(
		"path_points",
		PackedVector3Array()
	) as PackedVector3Array
	_expect(
		resolved_points == path_points,
		"%s did not retain its authored raw path" % label
	)
	var expected_axis := (path_points[path_points.size() - 1] - path_points[0]).normalized()
	var resolved_axis := validation.get("axis", Vector3.ZERO) as Vector3
	_expect(
		resolved_axis.distance_to(expected_axis) <= GEOMETRY_EPSILON,
		"%s did not derive its axis from the first and last authored points" % label
	)

	var grip_geometry := (
		ForgeV2WipCompatibilityAdapterScript._resolve_handle_grip_geometry(
			body,
			resolved_points,
			_build_profile_samples(),
			Vector3.ZERO,
			_build_handle_box_vertices(),
			_build_box_indices()
		)
	)
	var semantic_path := grip_geometry.get(
		"profile_path",
		PackedVector3Array()
	) as PackedVector3Array
	_expect(
		semantic_path.size() == 3,
		"%s did not normalize to the three-point semantic grip path" % label
	)
	if semantic_path.size() != 3:
		return
	_expect(
		semantic_path[0].distance_to(HANDLE_START) <= GEOMETRY_EPSILON,
		"%s semantic grip span start changed" % label
	)
	_expect(
		semantic_path[2].distance_to(HANDLE_END) <= GEOMETRY_EPSILON,
		"%s semantic grip span end changed" % label
	)
	_expect(
		absf(semantic_path[1].x) <= 0.002,
		"%s semantic grip contact did not resolve near the exact mesh midpoint" % label
	)


func _verify_rejected_mode(
	label: String,
	shape_kind: StringName,
	path_points: PackedVector3Array,
	expected_error: String
) -> void:
	var fixture := _build_handle_fixture(shape_kind, path_points)
	var validation := (
		ForgeV2WipCompatibilityAdapterScript.resolve_valid_handle_body(
			fixture.get("state") as Resource
		)
	)
	_expect(not bool(validation.get("valid", false)), "%s was accepted" % label)
	_expect(
		String(validation.get("error", "")) == expected_error,
		"%s returned an unexpected validation error: %s" % [
			label,
			String(validation.get("error", "")),
		]
	)


func _build_handle_fixture(
	shape_kind: StringName,
	path_points: PackedVector3Array
) -> Dictionary:
	var body: Resource = ForgeV2MaterialBodyScript.new()
	body.set("body_id", &"verify_wip_handle_path_mode")
	body.set("body_kind", ForgeV2MaterialBodyScript.BODY_KIND_HANDLE_PROFILE)
	body.set("shape_kind", shape_kind)
	body.set("path_points", path_points)
	var path_normals := PackedVector3Array()
	for _point: Vector3 in path_points:
		path_normals.append(Vector3.UP)
	body.set("path_surface_normals", path_normals)
	body.set("profile_polygon_2d_meters", _build_profile_samples())
	body.set("committed_layer_id", &"verify_committed_handle_layer")
	body.set("layer_active", true)

	var state: Resource = ForgeV2AuthoringStateScript.new()
	var bodies: Array[Resource] = [body]
	state.set("material_bodies", bodies)
	return {"state": state, "body": body}


func _build_profile_samples() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-0.02, -0.015),
		Vector2(0.02, -0.015),
		Vector2(0.02, 0.015),
		Vector2(-0.02, 0.015),
	])


func _build_handle_box_vertices() -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(HANDLE_START.x, -0.02, -0.015),
		Vector3(HANDLE_END.x, -0.02, -0.015),
		Vector3(HANDLE_END.x, 0.02, -0.015),
		Vector3(HANDLE_START.x, 0.02, -0.015),
		Vector3(HANDLE_START.x, -0.02, 0.015),
		Vector3(HANDLE_END.x, -0.02, 0.015),
		Vector3(HANDLE_END.x, 0.02, 0.015),
		Vector3(HANDLE_START.x, 0.02, 0.015),
	])


func _build_box_indices() -> PackedInt32Array:
	return PackedInt32Array([
		0, 2, 1, 0, 3, 2,
		4, 5, 6, 4, 6, 7,
		0, 4, 7, 0, 7, 3,
		1, 2, 6, 1, 6, 5,
		0, 1, 5, 0, 5, 4,
		3, 7, 6, 3, 6, 2,
	])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
