extends SceneTree

const ForgeV2ProfileShapeLibraryScript = preload(
	"res://runtime/forge_v2/forge_v2_profile_shape_library.gd"
)

const RESULT_PATH := (
	"C:/WORKSPACE/godot_runs/"
	+ "verify_forge_v2_explicit_surface_profile_frame_2026-08-12.txt"
)
const EPSILON := 0.00001


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(RESULT_PATH.get_base_dir())
	var authored_polygon := PackedVector2Array([
		Vector2(-0.032, -0.024),
		Vector2(0.012, -0.028),
		Vector2(0.037, -0.006),
		Vector2(0.026, 0.031),
		Vector2(-0.029, 0.022),
	])
	var authored_contact_point := Vector2(0.0, -0.028)
	var authored_contact_direction := Vector2.DOWN
	var camera_ray_a_to_b := Vector3.FORWARD
	var raw_surface_normal := Vector3.BACK
	var explicit_bc := Vector3.FORWARD
	var non_tangent_input := Vector3(1.0, 0.0, 0.35).normalized()
	var frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.
		resolve_explicit_surface_profile_path_frame(
			non_tangent_input,
			raw_surface_normal,
			authored_contact_direction,
			authored_contact_point,
			explicit_bc,
			0.0
		)
	)
	_require(bool(frame.get("valid", false)), "explicit surface frame was invalid")
	var tangent := frame.get("tangent", Vector3.ZERO) as Vector3
	var axis_x := frame.get("axis_x", Vector3.ZERO) as Vector3
	var axis_y := frame.get("axis_y", Vector3.ZERO) as Vector3
	var resolved_contact := frame.get(
		"resolved_contact",
		Vector3.ZERO
	) as Vector3
	_require(
		absf(tangent.dot(raw_surface_normal)) <= EPSILON
		and tangent.dot(Vector3.RIGHT) > 0.999,
		"surface tool tangent was not projected into the local surface plane"
	)
	_require(
		resolved_contact.dot(explicit_bc) > 0.999,
		"explicit B-C was not the resolved contact authority"
	)
	var b_to_a := -camera_ray_a_to_b
	_require(
		b_to_a.dot(resolved_contact) <= EPSILON,
		"resolved B-C violated the camera-side ABC 90-to-180-degree rule"
	)
	_require(
		axis_x.cross(axis_y).dot(tangent) < -0.999,
		"explicit frame changed the established authored CSG handedness oracle"
	)
	_require(
		_authored_polygon_roundtrips(
			authored_polygon,
			axis_x,
			axis_y
		),
		"asymmetric authored profile was reflected inside the explicit frame"
	)

	var opposite_raw_normal_frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.
		resolve_explicit_surface_profile_path_frame(
			Vector3.RIGHT,
			Vector3.FORWARD,
			authored_contact_direction,
			authored_contact_point,
			explicit_bc,
			0.0
		)
	)
	_require(
		(opposite_raw_normal_frame.get(
			"resolved_contact",
			Vector3.ZERO
		) as Vector3).dot(explicit_bc) > 0.999,
		"raw surface-normal sign overrode explicit B-C"
	)

	var noisy_tangents := PackedVector3Array([
		Vector3(1.0, 0.0, 0.02),
		Vector3(1.0, 0.0, -0.03),
		Vector3(1.0, 0.0, 0.04),
		Vector3(1.0, 0.0, -0.01),
	])
	var previous_contact := Vector3.ZERO
	for sample_index in range(noisy_tangents.size()):
		var sample_frame: Dictionary = (
			ForgeV2ProfileShapeLibraryScript.
			resolve_explicit_surface_profile_path_frame(
				noisy_tangents[sample_index],
				raw_surface_normal,
				authored_contact_direction,
				authored_contact_point,
				explicit_bc,
				0.0
			)
		)
		var sample_tangent := sample_frame.get(
			"tangent",
			Vector3.ZERO
		) as Vector3
		var sample_contact := sample_frame.get(
			"resolved_contact",
			Vector3.ZERO
		) as Vector3
		_require(
			absf(sample_tangent.dot(raw_surface_normal)) <= EPSILON,
			"sample %d retained a non-surface tangent" % sample_index
		)
		_require(
			sample_contact.dot(explicit_bc) > 0.999,
			"sample %d flipped away from explicit B-C" % sample_index
		)
		if previous_contact.length_squared() > 0.5:
			_require(
				previous_contact.dot(sample_contact) > 0.999,
				"flat-surface samples zig-zagged front/back"
			)
		previous_contact = sample_contact

	var reversed_frame: Dictionary = (
		ForgeV2ProfileShapeLibraryScript.
		resolve_explicit_surface_profile_path_frame(
			Vector3.LEFT,
			raw_surface_normal,
			authored_contact_direction,
			authored_contact_point,
			explicit_bc,
			0.0
		)
	)
	var reversed_tangent := reversed_frame.get(
		"tangent",
		Vector3.ZERO
	) as Vector3
	var reversed_axis_x := reversed_frame.get(
		"axis_x",
		Vector3.ZERO
	) as Vector3
	var reversed_axis_y := reversed_frame.get(
		"axis_y",
		Vector3.ZERO
	) as Vector3
	_require(
		reversed_axis_x.cross(reversed_axis_y).dot(reversed_tangent)
		< -0.999,
		"reversed path lost the authored handedness convention"
	)
	_require(
		axis_x.dot(reversed_axis_x) < -0.999
		and axis_y.dot(reversed_axis_y) > 0.999
		and (reversed_frame.get(
			"resolved_contact",
			Vector3.ZERO
		) as Vector3).dot(resolved_contact) > 0.999,
		"reverse path direction did not retain the intentional directional mirror"
	)

	_write_result([
		"ok=true",
		"explicit_bc_is_contact_authority=true",
		"surface_tangent_projection=true",
		"camera_side_abc=true",
		"authored_csg_handedness_oracle=-1",
		"asymmetric_profile_not_reflected=true",
		"flat_surface_no_front_back_zig_zag=true",
		"reverse_path_directional_mirror=true",
	])
	quit(0)


func _authored_polygon_roundtrips(
	polygon: PackedVector2Array,
	axis_x: Vector3,
	axis_y: Vector3
) -> bool:
	for authored_point: Vector2 in polygon:
		var world_point := (
			axis_x * authored_point.x
			+ axis_y * authored_point.y
		)
		var reconstructed := Vector2(
			world_point.dot(axis_x),
			world_point.dot(axis_y)
		)
		if reconstructed.distance_to(authored_point) > EPSILON:
			return false
	return true


func _require(condition: bool, message: String) -> void:
	if condition:
		return
	_write_result(["ok=false", "error=%s" % message])
	push_error(message)
	quit(1)


func _write_result(lines: Array[String]) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
