extends SceneTree

const MaterialBodyScript = preload(
	"res://runtime/forge_v2/forge_v2_material_body.gd"
)
const PresenterScript = preload(
	"res://runtime/forge_v2/forge_v2_volume_preview_presenter.gd"
)
const MeshAnalyzerScript = preload(
	"res://tools/forge_v2_workpiece_benchmark_mesh_analyzer.gd"
)

const MATERIAL_VARIANT_ID := &"mat_iron_gray"
const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_capsule_native_operand_parity_2026-08-22.json"
)
const RADIUS_METERS := 0.06
const ORACLE_SIDES := 24


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var presenter: Node3D = PresenterScript.new()
	root.add_child(presenter)
	var cases := {
		"straight": PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.36, 0.0, 0.0),
		]),
		"right_angle": PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.18, 0.0, 0.0),
			Vector3(0.18, 0.18, 0.0),
		]),
		"spatial_bend": PackedVector3Array([
			Vector3.ZERO,
			Vector3(0.14, 0.03, 0.02),
			Vector3(0.25, 0.12, -0.04),
			Vector3(0.34, 0.16, 0.05),
		]),
	}
	var results: Dictionary = {}
	for case_id: String in cases.keys():
		var body := _build_body(StringName(case_id), cases[case_id])
		var native_12 := presenter.call(
			"_build_active_material_body_sweep_mesh",
			body
		) as ArrayMesh
		var candidate_24 := _build_authored_ring_sweep(
			presenter,
			body,
			ORACLE_SIDES
		)
		var oracle_24 := await _build_current_csg_oracle(
			presenter,
			body,
			case_id
		)
		_require(native_12 != null, "%s native-12 mesh missing" % case_id)
		_require(candidate_24 != null, "%s candidate-24 mesh missing" % case_id)
		_require(oracle_24 != null, "%s CSG-24 oracle mesh missing" % case_id)
		var native_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(native_12)
		var candidate_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(candidate_24)
		var oracle_analysis: Dictionary = MeshAnalyzerScript.analyze_mesh(oracle_24)
		results[case_id] = {
			"path_length_meters": _path_length(body.path_points),
			"accounted_capsule_volume_cubic_meters": (
				body.rough_volume_cell_equivalents
				* pow(MaterialBodyScript.REFERENCE_CELL_WORLD_SIZE_METERS, 3.0)
			),
			"native_12": MeshAnalyzerScript.strip_transient_arrays(native_analysis),
			"authored_ring_24": MeshAnalyzerScript.strip_transient_arrays(
				candidate_analysis
			),
			"csg_oracle_24": MeshAnalyzerScript.strip_transient_arrays(oracle_analysis),
			"native_12_vs_csg_24": MeshAnalyzerScript.compare_surfaces(
				native_analysis,
				oracle_analysis
			),
			"authored_ring_24_vs_csg_24": MeshAnalyzerScript.compare_surfaces(
				candidate_analysis,
				oracle_analysis
			),
		}
	var report := {
		"ok": true,
		"radius_meters": RADIUS_METERS,
		"native_preview_sides": 12,
		"current_csg_oracle_sides": ORACLE_SIDES,
		"analytic_straight_area_ratio_12_over_24": cos(PI / 12.0),
		"analytic_straight_area_deficit_ratio": 1.0 - cos(PI / 12.0),
		"analytic_max_radial_inset_meters": (
			RADIUS_METERS * (1.0 - cos(PI / 12.0))
		),
		"cases": results,
	}
	var json := JSON.stringify(report, "  ", false)
	var output := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	_require(output != null, "could not open result path")
	output.store_string(json + "\n")
	output.close()
	print(json)
	quit(0)


func _build_body(case_id: StringName, points: PackedVector3Array) -> Resource:
	var body: Resource = MaterialBodyScript.new()
	body.body_id = StringName("capsule_parity_%s" % String(case_id))
	body.body_kind = MaterialBodyScript.BODY_KIND_VOLUME_STROKE
	body.shape_kind = MaterialBodyScript.SHAPE_KIND_CAPSULE_PATH
	body.material_variant_id = MATERIAL_VARIANT_ID
	body.path_points = points
	body.radius_meters = RADIUS_METERS
	var normals := PackedVector3Array()
	var contacts := PackedVector3Array()
	for _point: Vector3 in points:
		normals.append(Vector3.UP)
		contacts.append(Vector3.DOWN)
	body.path_surface_normals = normals
	body.path_contact_directions = contacts
	body.normalize()
	return body


func _build_authored_ring_sweep(
	presenter: Node,
	body: Resource,
	sides: int
) -> ArrayMesh:
	var polygon := presenter.call(
		"_build_circle_profile_polygon",
		RADIUS_METERS,
		sides
	) as PackedVector2Array
	polygon = presenter.call(
		"_ensure_counter_clockwise_profile_polygon",
		polygon
	) as PackedVector2Array
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added_vertices := int(presenter.call(
		"_append_linear_profile_sweep_preview",
		surface_tool,
		body,
		polygon,
		Color.WHITE
	))
	if added_vertices <= 0:
		return null
	surface_tool.index()
	surface_tool.generate_normals()
	return surface_tool.commit()


func _build_current_csg_oracle(
	presenter: Node,
	body: Resource,
	case_id: String
) -> ArrayMesh:
	var oracle_root := Node3D.new()
	oracle_root.name = "CapsuleCsgOracle_%s" % case_id
	root.add_child(oracle_root)
	if not bool(presenter.call(
		"_append_csg_body_shape",
		oracle_root,
		body,
		MATERIAL_VARIANT_ID,
		false,
		0
	)):
		oracle_root.queue_free()
		return null
	await process_frame
	await process_frame
	var polygon := _find_csg_polygon(oracle_root)
	var baked := polygon.bake_static_mesh() if polygon != null else null
	oracle_root.queue_free()
	return baked


func _find_csg_polygon(node: Node) -> CSGPolygon3D:
	if node is CSGPolygon3D:
		return node as CSGPolygon3D
	for child: Node in node.get_children():
		var found := _find_csg_polygon(child)
		if found != null:
			return found
	return null


func _path_length(points: PackedVector3Array) -> float:
	var result := 0.0
	for index in range(points.size() - 1):
		result += points[index].distance_to(points[index + 1])
	return result


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
