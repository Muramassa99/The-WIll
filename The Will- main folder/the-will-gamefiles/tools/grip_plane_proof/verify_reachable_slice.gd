extends SceneTree

const SlicerScript = preload("res://tools/grip_plane_proof/slice_reachable_surface.gd")
var slicer = SlicerScript.new()
var checks: int = 0
var failures: int = 0

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var far := _surface(PackedVector3Array([Vector3(5, -1, -1), Vector3(5, 1, -1), Vector3(5, 0, 1)]))
	var far_result: Dictionary = slicer.slice(far, Transform3D.IDENTITY, &"FixtureDigitPlane", 1.0, 0.0)
	_check(far_result["valid"] and far_result["segments"].is_empty(), "far infinite-plane intersection excluded")
	_check(far_result["counts"]["triangles_reach_pruned"] == 1 and far_result["counts"]["triangles_intersected"] == 0, "reach pruning precedes intersection")
	var crossing := _surface(PackedVector3Array([Vector3(-4, 0, -2), Vector3(4, 0, -2), Vector3(0, 0, 2)]))
	var before: PackedByteArray = var_to_bytes(crossing)
	var crossed: Dictionary = slicer.slice(crossing, Transform3D.IDENTITY, &"FixtureDigitPlane", 1.0, 0.25)
	_check(crossed["valid"] and crossed["segments"].size() == 1, "crossing retained with every triangle vertex outside search sphere")
	_check(crossed["counts"]["segments_clipped"] == 1, "crossing segment clipped")
	_check(crossed["contours"].is_empty() and crossed["classification_incomplete"], "cut crossing never closed along disk")
	var segment: Array = crossed["segments"][0]
	_check(is_equal_approx(absf((segment[0] as Vector2).x), 1.25) and (segment[0] as Vector2).is_equal_approx(-(segment[1] as Vector2)), "clipped endpoints include skin padding in meters")
	_check(var_to_bytes(crossing) == before, "complete input surface unchanged")
	_check(not crossed["counts"]["bvh_used"], "linear pruning reported honestly")
	_check_bounded(crossed)
	var cube := _surface(_box(Vector3(-0.25, -0.25, -0.25), Vector3(0.25, 0.25, 0.25)), true)
	var closed: Dictionary = slicer.slice(cube, Transform3D.IDENTITY, &"FixtureDigitPlane", 1.0, 0.0)
	_check(closed["valid"] and closed["contours"].size() == 1, "true closed section retained")
	var contour: PackedVector2Array = closed["contours"][0]
	_check(contour.size() >= 5 and contour[0] == contour[contour.size() - 1], "genuine contour explicitly repeats first point")
	_check(not closed["classification_incomplete"], "unpruned closed section complete")
	_check_bounded(closed)
	var clipped_cube: Dictionary = slicer.slice(cube, Transform3D.IDENTITY, &"FixtureDigitPlane", 0.3, 0.0)
	_check(not clipped_cube["segments"].is_empty() and clipped_cube["contours"].is_empty(), "cut square remains open arcs without disk boundary")
	_check(clipped_cube["classification_incomplete"], "partially clipped solid classification incomplete")
	_check_bounded(clipped_cube)
	var frame := Transform3D(Basis(Vector3(1, 2, 3).normalized(), 0.73), Vector3(2, -3, 4))
	var transformed: PackedVector3Array = (cube["triangles_world"] as PackedVector3Array).duplicate()
	for index: int in range(transformed.size()):
		transformed[index] = frame * transformed[index]
	var transformed_result: Dictionary = slicer.slice(_surface(transformed, true), frame, &"MovedDigitPlane", 1.0, 0.0)
	_check(transformed_result["valid"] and transformed_result["contours"].size() == 1, "translated rotated plane retains contour")
	_check(transformed_result["segments"].size() == closed["segments"].size(), "transformed source preserves segmentation")
	_check_bounded(transformed_result)
	_check(not slicer.slice(cube, frame, &"", 1.0, 0.0)["valid"], "missing plane origin rejected")
	_check(not slicer.slice(cube, Transform3D(Basis.from_scale(Vector3(2, 1, 1)), Vector3.ZERO), &"FixtureDigitPlane", 1.0, 0.0)["valid"], "non-metric plane rejected")
	_check(not slicer.slice(cube, Transform3D.IDENTITY, &"FixtureDigitPlane", INF, 0.0)["valid"], "nonfinite reach rejected")
	_check(not slicer.slice(cube, Transform3D.IDENTITY, &"FixtureDigitPlane", 1.0, -0.1)["valid"], "negative padding rejected")
	var invalid := _surface(PackedVector3Array([Vector3(INF, 0, 0), Vector3.ZERO, Vector3.ONE]))
	_check(not slicer.slice(invalid, Transform3D.IDENTITY, &"FixtureDigitPlane", 1.0, 0.0)["valid"], "nonfinite geometry rejected")
	print("REACHABLE_SLICE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _surface(triangles: PackedVector3Array, closed: bool = false) -> Dictionary:
	return {"valid": true, "triangles_world": triangles, "surface_source_origin_id": &"FixtureWeaponSurface",
		"resolved_world_origin_id": &"RL_BoneRoot", "capsule_surface_topology": {"valid": true, "closed": closed}}


func _box(low: Vector3, high: Vector3) -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(low.x, low.y, low.z), Vector3(high.x, low.y, low.z), Vector3(high.x, high.y, low.z), Vector3(low.x, high.y, low.z), Vector3(low.x, low.y, high.z), Vector3(high.x, low.y, high.z), Vector3(high.x, high.y, high.z), Vector3(low.x, high.y, high.z)])
	var triangles := PackedVector3Array()
	for face: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]:
		for index: int in [face[0], face[1], face[2], face[0], face[2], face[3]]:
			triangles.append(points[index])
	return triangles


func _check_bounded(result: Dictionary) -> void:
	for segment: Array in result["segments"]:
		for point: Vector2 in segment:
			_check(point.is_finite() and point.length() <= float(result["search_radius_m"]) + 0.0000001, "candidate endpoint stays inside padded reach")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
