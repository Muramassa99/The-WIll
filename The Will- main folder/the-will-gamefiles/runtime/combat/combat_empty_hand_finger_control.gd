extends RefCounted
## Editor-only focus and gizmo math. Saved curls are scalars; all visual points
## are derived from named bones in Skeleton3D space, then transformed to world.

const DIGITS: Array[StringName] = [&"index", &"middle", &"ring", &"pinky"]

static func focus_ids(slot: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	if slot != &"hand_right" and slot != &"hand_left":
		return result
	var prefix := "left_finger_" if slot == &"hand_left" else "right_finger_"
	for digit: StringName in DIGITS:
		result.append(StringName(prefix + String(digit)))
	return result

static func decode_focus(focus: StringName) -> Dictionary:
	for slot: StringName in [&"hand_right", &"hand_left"]:
		var ids := focus_ids(slot)
		var index := ids.find(focus)
		if index >= 0:
			return {"slot": slot, "digit": DIGITS[index]}
	return {}

static func get_curls(motion: CombatAnimationMotionNode, slot: StringName) -> Dictionary:
	if motion == null:
		return {}
	return motion.left_hand_finger_curl_degrees if slot == &"hand_left" else motion.right_hand_finger_curl_degrees

static func frame(skeleton: Skeleton3D, slot: StringName, angle_degrees: float) -> Dictionary:
	if skeleton == null or (slot != &"hand_left" and slot != &"hand_right"):
		return {}
	var prefix := "CC_Base_L_" if slot == &"hand_left" else "CC_Base_R_"
	var hand_id := skeleton.find_bone(prefix + "Hand")
	var index_id := skeleton.find_bone(prefix + "Index1")
	var pinky_id := skeleton.find_bone(prefix + "Pinky1")
	if hand_id < 0 or index_id < 0 or pinky_id < 0:
		return {}
	var hand: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(hand_id).origin)
	var index: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index_id).origin)
	var pinky: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(pinky_id).origin)
	var origin := (index + pinky) * 0.5
	var span := index.distance_to(pinky)
	if span < 0.00001:
		return {}
	var axis := (index - pinky) / span
	var radial := origin - hand
	radial -= axis * radial.dot(axis)
	if radial.length_squared() < 0.00000001:
		return {}
	radial = radial.normalized()
	var radius := span * 1.5
	return {"available": true, "origin": origin, "axis": axis,
		"radial": radial, "radius": radius,
		"marker_position": origin + radial.rotated(axis, deg_to_rad(clampf(angle_degrees, 0.0, 180.0))) * radius}

static func begin_drag(camera: Camera3D, control_frame: Dictionary, pointer: Vector2, angle: float) -> Dictionary:
	if camera == null or control_frame.is_empty():
		return {}
	return {"frame": control_frame.duplicate(), "pointer": pointer,
		"angle_degrees": clampf(angle, 0.0, 180.0),
		"radial": _pointer_radial(camera, control_frame, pointer), "screen_tangent": Vector2.RIGHT}

static func update_drag(state: Dictionary, camera: Camera3D, pointer: Vector2) -> float:
	var control_frame: Dictionary = state.frame
	var previous: Vector3 = state.radial
	var current := _pointer_radial(camera, control_frame, pointer)
	var delta_radians := 0.0
	if not previous.is_zero_approx() and not current.is_zero_approx():
		delta_radians = previous.signed_angle_to(current, control_frame.axis)
	else:
		# An edge-on arc has no useful ray/plane intersection. Follow its screen
		# tangent instead; retain the last tangent at its projected turning point.
		var origin: Vector3 = control_frame.origin
		var radial: Vector3 = (control_frame.radial as Vector3).rotated(control_frame.axis, deg_to_rad(float(state.angle_degrees)))
		var radius: float = control_frame.radius
		var tangent: Vector3 = (control_frame.axis as Vector3).cross(radial)
		var marker := origin + radial * radius
		var projected := camera.unproject_position(marker + tangent * radius) - camera.unproject_position(marker)
		if projected.length() > 4.0:
			state.screen_tangent = projected.normalized()
		delta_radians = (pointer - (state.pointer as Vector2)).dot(state.screen_tangent) / maxf(projected.length(), 20.0)
	# Consume every pointer sample even at an endpoint: reversal is immediate,
	# with no hidden accumulated rotation request beyond the 180-degree arc.
	state.pointer = pointer
	state.radial = current
	state.angle_degrees = clampf(float(state.angle_degrees) + rad_to_deg(delta_radians), 0.0, 180.0)
	return float(state.angle_degrees)

static func _pointer_radial(camera: Camera3D, control_frame: Dictionary, pointer: Vector2) -> Vector3:
	var ray := camera.project_ray_normal(pointer)
	var axis: Vector3 = control_frame.axis
	if absf(axis.dot(ray)) < 0.08:
		return Vector3.ZERO
	var origin: Vector3 = control_frame.origin
	var hit: Variant = Plane(axis, origin).intersects_ray(camera.project_ray_origin(pointer), ray)
	if not hit is Vector3:
		return Vector3.ZERO
	var radial: Vector3 = hit - origin
	return radial.normalized() if radial.length_squared() > 0.00000001 else Vector3.ZERO
