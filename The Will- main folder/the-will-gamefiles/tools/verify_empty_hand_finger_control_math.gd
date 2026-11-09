extends SceneTree

## Geometry/input checks only; the imported-rig finger writer and station UI
## have separate verifiers. Camera rays are the actual engine camera API.
const ControlMath = preload("res://runtime/combat/combat_empty_hand_finger_control.gd")
const SessionState = preload("res://core/models/combat_animation_session_state.gd")
var output_dir := "C:/WORKSPACE/godot_runs/empty_hand_finger_control_math"
var checks: Array[Dictionary] = []
var viewport: SubViewport
var fixture: Node3D
var skeleton: Skeleton3D
var camera: Camera3D


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out-dir="):
			output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.own_world_3d = true
	root.add_child(viewport)
	fixture = Node3D.new()
	viewport.add_child(fixture)
	skeleton = Skeleton3D.new()
	fixture.add_child(skeleton)
	_add_bone("RL_BoneRoot", -1, Vector3.ZERO)
	for side: String in ["R", "L"]:
		var hand := _add_bone("CC_Base_%s_Hand" % side, 0, Vector3(-0.3, 0.0, 0.0))
		_add_bone("CC_Base_%s_Index1" % side, hand, Vector3(0.3, 0.0, 0.1))
		_add_bone("CC_Base_%s_Pinky1" % side, hand, Vector3(0.3, 0.0, -0.1))
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	camera.current = true
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 5.0))
	await process_frame
	_test_world_frames()
	_test_facing_arc_and_endpoints()
	_test_edge_on_tangent()
	_test_focus_chain()
	var passed: bool = true
	for check: Dictionary in checks:
		passed = passed and bool(check.passed)
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write empty-hand control math report")
		quit(1)
		return
	file.store_string(JSON.stringify({"passed": passed, "checks": checks,
		"scope": "Synthetic named-bone geometry, real Camera3D rays, control input and SessionState focus; no rendered UI or imported-rig skin certification."}, "\t"))
	file.close()
	print("EMPTY_HAND_FINGER_CONTROL_MATH passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)


func _add_bone(bone_name: String, parent: int, position: Vector3) -> int:
	var id: int = skeleton.get_bone_count()
	skeleton.add_bone(bone_name)
	skeleton.set_bone_parent(id, parent)
	skeleton.set_bone_rest(id, Transform3D(Basis.IDENTITY, position))
	skeleton.set_bone_pose_position(id, position)
	return id


func _test_world_frames() -> void:
	var base: Dictionary = ControlMath.frame(skeleton, &"hand_right", 90.0)
	_check(not base.is_empty(), "named_bone_frame_available")
	if base.is_empty(): return
	_check((base.origin as Vector3).length() < 0.00001, "midpoint_is_independent_of_scene_origin", {"origin": base.origin})
	_check((base.axis as Vector3).is_equal_approx(Vector3.BACK), "pinky_to_index_defines_positive_axis")
	_check((base.marker_position as Vector3).distance_to(Vector3(0.0, 0.3, 0.0)) < 0.00001,
		"quarter_arc_is_physically_positive_y_at_90_degrees", {"marker": base.marker_position})
	fixture.transform = Transform3D(Basis.from_euler(Vector3(0.3, -0.7, 0.2)).scaled(Vector3.ONE * 1.3), Vector3(4.0, -2.0, 3.0))
	skeleton.transform = Transform3D(Basis.from_euler(Vector3(-0.2, 0.5, 0.4)).scaled(Vector3.ONE * 0.7), Vector3(-0.4, 0.8, 0.2))
	var full: Transform3D = skeleton.global_transform
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var moved: Dictionary = ControlMath.frame(skeleton, slot, 90.0)
		_check((moved.origin as Vector3).distance_to(full * (base.origin as Vector3)) < 0.00001,
			"translated_rotated_scaled_midpoint_" + String(slot))
		_check((moved.marker_position as Vector3).distance_to(full * (base.marker_position as Vector3)) < 0.00002,
			"uniform_parent_transform_preserves_physical_arc_" + String(slot))
		_check(absf(float(moved.radius) - 0.3 * 1.3 * 0.7) < 0.00001, "radius_scales_with_actual_bone_span_" + String(slot))
	fixture.basis = Basis.from_euler(Vector3(0.3, -0.7, 0.2)).scaled(Vector3(1.4, 0.75, 1.8))
	skeleton.basis = Basis.from_euler(Vector3(-0.2, 0.5, 0.4)).scaled(Vector3(0.9, 1.6, 0.65))
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var prefix := "CC_Base_L_" if slot == &"hand_left" else "CC_Base_R_"
		var index: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Index1")).origin)
		var pinky: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(prefix + "Pinky1")).origin)
		var moved: Dictionary = ControlMath.frame(skeleton, slot, 90.0)
		var expected_axis: Vector3 = (index - pinky).normalized()
		_check((moved.origin as Vector3).distance_to((index + pinky) * 0.5) < 0.00001,
			"nonuniform_parent_uses_actual_world_midpoint_" + String(slot))
		_check((moved.axis as Vector3).distance_to(expected_axis) < 0.00001 and absf(expected_axis.dot(moved.radial)) < 0.00001,
			"nonuniform_parent_builds_orthogonal_world_arc_" + String(slot))
		var quarter: Vector3 = (index + pinky) * 0.5 + expected_axis.cross(moved.radial) * index.distance_to(pinky) * 1.5
		_check((moved.marker_position as Vector3).distance_to(quarter) < 0.00002,
			"nonuniform_parent_quarter_arc_uses_world_cross_product_" + String(slot))
	fixture.transform = Transform3D.IDENTITY
	skeleton.transform = Transform3D.IDENTITY
	_check(ControlMath.frame(skeleton, &"missing_hand", 0.0).is_empty(), "unknown_hand_has_no_control")


func _screen_point(frame: Dictionary, degrees: float) -> Vector2:
	# Physical XY circle of this fixture; independent of the helper's drag math.
	var angle := deg_to_rad(degrees)
	return camera.unproject_position((frame.origin as Vector3) + Vector3(cos(angle), sin(angle), 0.0) * float(frame.radius))


func _test_facing_arc_and_endpoints() -> void:
	var frame: Dictionary = ControlMath.frame(skeleton, &"hand_right", 0.0)
	var state: Dictionary = ControlMath.begin_drag(camera, frame, _screen_point(frame, 0.0), 0.0)
	var value: float = ControlMath.update_drag(state, camera, _screen_point(frame, 90.0))
	_check(absf(value - 90.0) < 0.001, "facing_camera_quarter_circle_means_90_degrees", {"degrees": value})
	value = ControlMath.update_drag(state, camera, _screen_point(frame, 45.0))
	_check(absf(value - 45.0) < 0.001, "facing_camera_reverses_without_delay", {"degrees": value})
	state = ControlMath.begin_drag(camera, frame, _screen_point(frame, 170.0), 170.0)
	for angle: float in [200.0, 230.0, 260.0]:
		value = ControlMath.update_drag(state, camera, _screen_point(frame, angle))
		_check(is_equal_approx(value, 180.0), "upper_end_consumes_overshoot_%.0f" % angle)
	value = ControlMath.update_drag(state, camera, _screen_point(frame, 250.0))
	_check(absf(value - 170.0) < 0.001, "upper_end_immediate_reversal_has_no_accumulated_deadzone", {"degrees": value})
	state = ControlMath.begin_drag(camera, frame, _screen_point(frame, 10.0), 10.0)
	for angle: float in [-20.0, -50.0, -80.0]:
		value = ControlMath.update_drag(state, camera, _screen_point(frame, angle))
		_check(is_zero_approx(value), "lower_end_consumes_overshoot_%.0f" % angle)
	value = ControlMath.update_drag(state, camera, _screen_point(frame, -70.0))
	_check(absf(value - 10.0) < 0.001, "lower_end_immediate_reversal_has_no_accumulated_deadzone", {"degrees": value})


func _test_edge_on_tangent() -> void:
	camera.position = Vector3(0.0, -5.0, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.BACK)
	var frame: Dictionary = ControlMath.frame(skeleton, &"hand_right", 0.0)
	var marker: Vector3 = frame.marker_position
	var start: Vector2 = camera.unproject_position(marker)
	var tangent_pixels: Vector2 = camera.unproject_position(marker + Vector3.UP * float(frame.radius)) - start
	# Here the arc lies in XY, so the positive tangent is +Y. It is edge-on
	# along the camera ray at angle zero; use the last noncollapsed direction.
	_check(absf(camera.project_ray_normal(start).dot(frame.axis)) < 0.00001, "edge_on_ray_is_parallel_to_arc_plane")
	var state: Dictionary = ControlMath.begin_drag(camera, frame, start, 0.0)
	_check((state.radial as Vector3).is_zero_approx(), "edge_on_drag_selects_tangent_fallback")
	var value: float = ControlMath.update_drag(state, camera, start + Vector2.RIGHT * 10.0)
	_check(absf(value - rad_to_deg(0.5)) < 0.001, "collapsed_tangent_retains_finite_screen_direction", {"degrees": value, "projection_length": tangent_pixels.length()})
	# At 90 degrees the actual tangent is -X, visible in this camera; use an
	# arc-length of r*pi/2 so the tangent controller requests a quarter turn.
	marker = (frame.origin as Vector3) + Vector3.UP * float(frame.radius)
	start = camera.unproject_position(marker)
	tangent_pixels = camera.unproject_position(marker + Vector3.LEFT * float(frame.radius)) - start
	state = ControlMath.begin_drag(camera, frame, start, 90.0)
	value = ControlMath.update_drag(state, camera, start + tangent_pixels * (PI / 2.0))
	_check(absf(value - 180.0) < 0.001, "visible_edge_on_tangent_requests_quarter_turn", {"degrees": value})
	_check((state.screen_tangent as Vector2).dot(tangent_pixels.normalized()) > 0.9999,
		"edge_on_fallback_uses_actual_camera_projected_tangent")
	# Move back immediately using the held tangent at this endpoint's collapse.
	var reverse_pointer: Vector2 = state.pointer - (state.screen_tangent as Vector2) * 2.0
	value = ControlMath.update_drag(state, camera, reverse_pointer)
	_check(value < 180.0 and value > 0.0, "edge_on_endpoint_allows_immediate_reversal", {"degrees": value})


func _test_focus_chain() -> void:
	var expected_right: Array[StringName] = [&"right_finger_index", &"right_finger_middle", &"right_finger_ring", &"right_finger_pinky"]
	var expected_left: Array[StringName] = [&"left_finger_index", &"left_finger_middle", &"left_finger_ring", &"left_finger_pinky"]
	_check(ControlMath.focus_ids(&"hand_right") == expected_right, "right_group_has_stable_anatomical_order")
	_check(ControlMath.focus_ids(&"hand_left") == expected_left, "left_group_has_stable_anatomical_order")
	var chain: Array = [&"tip", &"right_hand_proxy"]
	chain.append_array(ControlMath.focus_ids(&"hand_right"))
	chain.append(&"left_hand_proxy")
	chain.append_array(ControlMath.focus_ids(&"hand_left"))
	chain.append(&"pommel")
	var expected: Array = [&"tip", &"right_hand_proxy", &"right_finger_index", &"right_finger_middle", &"right_finger_ring", &"right_finger_pinky",
		&"left_hand_proxy", &"left_finger_index", &"left_finger_middle", &"left_finger_ring", &"left_finger_pinky", &"pommel"]
	var session := SessionState.new()
	for index: int in range(1, expected.size() + 1):
		session.cycle_focus(chain, 1)
		_check(session.current_focus == expected[index % expected.size()], "forward_focus_step_%02d" % index)
	for index: int in range(expected.size() - 1, -1, -1):
		session.cycle_focus(chain, -1)
		_check(session.current_focus == expected[index], "reverse_focus_step_%02d" % index)
	for focus: StringName in expected_right + expected_left:
		var decoded: Dictionary = ControlMath.decode_focus(focus)
		_check(not decoded.is_empty() and decoded.digit in [&"index", &"middle", &"ring", &"pinky"], "focus_roundtrip_" + String(focus))
	_check(ControlMath.decode_focus(&"weapon").is_empty(), "nonfinger_focus_not_decoded")


func _check(passed: bool, name: String, detail: Dictionary = {}) -> void:
	checks.append({"passed": passed, "name": name, "detail": detail})
	if not passed:
		push_error("EMPTY_HAND_FINGER_CONTROL_MATH failed: " + name)
