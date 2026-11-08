extends RefCounted
class_name CombatForearmClearanceSnapshot

## Immutable per-request proxy metadata. Candidate evaluation reads FK values,
## never scene bones, grip state, physics queries or a candidate-rebased origin.
## Globals are Skeleton3D transforms whose ancestry includes RL_BoneRoot;
## clearances/contact points/normals are in world metres/world axes.
const Origin = preload("res://core/models/combat_origin_record.gd")
const ExistingPolicy = preload("res://runtime/player/hand_target_constraint_solver.gd")
const EPSILON := 1.0e-10
const FOREARMS := ["left_forearm", "right_forearm"]
static var _native_enabled := true
static var _native_checked := false
static var _native_kernel: RefCounted
static var _native_calls := 0
static var _reference_calls := 0
static var _native_constraint_calls := 0
static var _reference_constraint_calls := 0

static func configure_native_kernel(enabled: bool) -> void:
	_native_enabled = enabled
	_native_checked = false
	_native_kernel = null
	_native_calls = 0
	_reference_calls = 0
	_native_constraint_calls = 0
	_reference_constraint_calls = 0

static func backend_stats() -> Dictionary:
	return {"native_enabled": _native_enabled, "native_available": _native_kernel != null,
		"native_calls": _native_calls, "reference_calls": _reference_calls,
		"native_constraint_calls": _native_constraint_calls, "reference_constraint_calls": _reference_constraint_calls}

static func capture(rig: Node3D, normalization_meters: float = 0.01, active_slots: Array = []) -> Dictionary:
	if rig == null or not is_finite(normalization_meters) or normalization_meters <= 0.0:
		return _failure("forearm_clearance_capture_context_invalid")
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D
	var body: Node3D = rig.get("body_restriction_root") as Node3D
	if skeleton == null or body == null:
		return _failure("forearm_clearance_body_proxies_missing")
	var root_index := skeleton.find_bone(String(Origin.ORIGIN_RL_BONE_ROOT))
	if root_index < 0:
		return _failure("forearm_clearance_root_bone_missing")
	var shapes: Array[Dictionary] = []
	var forearms: Array[int] = []
	for child: Node in body.get_children():
		var attachment := child as Node3D
		if attachment == null:
			continue
		var shape_node := attachment.get_node_or_null("RestrictionArea/RestrictionShape") as CollisionShape3D
		if shape_node == null or shape_node.shape == null:
			continue
		var bone_name := String(attachment.get_meta("bone_name", ""))
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0 or not _descends_from(skeleton, bone_index, root_index):
			return _failure("forearm_clearance_proxy_bone_origin_invalid:" + String(attachment.name))
		# Restriction attachments follow the named bone with identity local basis.
		# Child-local transforms remain correct even before a proxy world sync.
		var local_shape := attachment.global_transform.affine_inverse() * shape_node.global_transform
		var descriptor := {"attachment_name": String(attachment.name), "bone_index": bone_index,
			"bone_name": bone_name, "end_bone_name": String(attachment.get_meta("end_bone_name", "")),
			"region": String(attachment.get_meta("proxy_region", "")), "bone_local_shape": local_shape,
			"bone_local_origin_id": StringName(bone_name), "kind": ""}
		if shape_node.shape is CapsuleShape3D:
			var capsule := shape_node.shape as CapsuleShape3D
			descriptor.kind = "capsule"
			descriptor["radius"] = capsule.radius
			descriptor["half_mid"] = maxf(capsule.height * 0.5 - capsule.radius, 0.0)
		elif shape_node.shape is BoxShape3D:
			descriptor.kind = "box"
			descriptor["half_size"] = (shape_node.shape as BoxShape3D).size * 0.5
		else:
			return _failure("forearm_clearance_proxy_shape_unsupported:" + String(attachment.name))
		if String(descriptor.region) in FOREARMS:
			if descriptor.kind != "capsule":
				return _failure("forearm_clearance_forearm_not_capsule")
			forearms.append(shapes.size())
		shapes.append(descriptor)
	var present: Dictionary = {}
	for index: int in forearms:
		present[shapes[index].region] = true
	if not present.has("left_forearm") or not present.has("right_forearm"):
		return _failure("forearm_clearance_both_forearm_proxies_required")
	var pairs: Array[Dictionary] = []
	for first: int in forearms:
		var slot := &"hand_left" if shapes[first].region == "left_forearm" else &"hand_right"
		if not active_slots.is_empty() and not active_slots.has(slot):
			continue
		for second: int in shapes.size():
			if first == second or _exempt(shapes[first], shapes[second]):
				continue
			pairs.append({"forearm": first, "body": second,
				"reason": "FOREARM_CLEARANCE:" + String(shapes[first].attachment_name) + ":" + String(shapes[second].attachment_name)})
	return prepare({"valid": true, "origin_id": Origin.ORIGIN_RL_BONE_ROOT,
		"candidate_globals_space": "Skeleton3D", "contact_origin_id": &"world",
		"skeleton_world": skeleton.global_transform, "bone_count": skeleton.get_bone_count(),
		"normalization_meters": normalization_meters, "shapes": shapes, "pairs": pairs})

## Runtime-only cache. Never serialize this snapshot into motion nodes/saves.
## Metadata is immutable after prepare; transformed diagnostic copies must be
## prepared anew. Each request gets a private native instance, never shared FK.
static func prepare(snapshot: Dictionary) -> Dictionary:
	if not snapshot.get("valid", false):
		return snapshot
	var prepared := snapshot.duplicate()
	prepared.erase("_prepared_native")
	var reasons := PackedStringArray()
	for pair: Dictionary in snapshot.get("pairs", []):
		reasons.append(pair.reason)
	prepared["constraint_reasons"] = reasons
	if _native_enabled and ClassDB.class_exists(&"CombatForearmClearanceKernel"):
		var kernel: RefCounted = ClassDB.instantiate(&"CombatForearmClearanceKernel") as RefCounted
		if kernel != null and kernel.has_method("prepare") and kernel.has_method("query_constraints"):
			var result: Dictionary = kernel.call("prepare", prepared)
			if not result.get("valid", false):
				return result
			prepared["_prepared_native"] = kernel
	return prepared

static func evaluate_constraints(snapshot: Dictionary, candidate_globals: Array) -> Dictionary:
	var kernel: RefCounted = snapshot.get("_prepared_native") as RefCounted
	if _native_enabled and kernel != null:
		var values: PackedFloat64Array = kernel.call("query_constraints", candidate_globals)
		var reasons: PackedStringArray = snapshot.constraint_reasons
		if values.size() != reasons.size():
			return _failure("forearm_clearance_fast_candidate_invalid")
		_native_constraint_calls += 1
		return {"valid": true, "constraints": values, "constraint_reasons": reasons}
	_reference_constraint_calls += 1
	var result := evaluate_reference(snapshot, candidate_globals)
	if not result.get("valid", false):
		return result
	return {"valid": true, "constraints": result.constraints, "constraint_reasons": result.constraint_reasons}

static func evaluate(snapshot: Dictionary, candidate_globals: Array) -> Dictionary:
	if _native_enabled:
		if not _native_checked:
			_native_checked = true
			if ClassDB.class_exists(&"CombatForearmClearanceKernel"):
				_native_kernel = ClassDB.instantiate(&"CombatForearmClearanceKernel") as RefCounted
		if _native_kernel != null:
			_native_calls += 1
			return _native_kernel.call("evaluate", snapshot, candidate_globals)
	_reference_calls += 1
	return evaluate_reference(snapshot, candidate_globals)

static func evaluate_reference(snapshot: Dictionary, candidate_globals: Array) -> Dictionary:
	if not snapshot.get("valid", false) or not snapshot.get("skeleton_world") is Transform3D:
		return _failure("forearm_clearance_snapshot_invalid")
	var world: Transform3D = snapshot.skeleton_world
	var normalization: float = snapshot.get("normalization_meters", 0.0)
	if not world.is_finite() or normalization <= 0.0:
		return _failure("forearm_clearance_snapshot_metric_invalid")
	var world_shapes: Array[Dictionary] = []
	for shape: Dictionary in snapshot.shapes:
		var index: int = shape.bone_index
		if index < 0 or index >= candidate_globals.size() or not candidate_globals[index] is Transform3D:
			return _failure("forearm_clearance_candidate_bone_missing")
		var transformed := _world_shape(shape, world * (candidate_globals[index] as Transform3D) * (shape.bone_local_shape as Transform3D))
		if not transformed.get("valid", false):
			return transformed
		world_shapes.append(transformed)
	var constraints := PackedFloat64Array()
	var reasons := PackedStringArray()
	var contacts: Array[Dictionary] = []
	var minimum := INF
	for pair: Dictionary in snapshot.pairs:
		var first: Dictionary = world_shapes[pair.forearm]
		var second: Dictionary = world_shapes[pair.body]
		var contact := capsule_pair(first, second) if second.kind == "capsule" else capsule_box(first, second)
		if not contact.get("valid", false):
			return contact
		var clearance: float = contact.clearance_meters
		if not is_finite(clearance):
			return _failure("forearm_clearance_nonfinite_distance")
		contact["reason"] = pair.reason
		contact["forearm_region"] = snapshot.shapes[pair.forearm].region
		contact["body_region"] = snapshot.shapes[pair.body].region
		contact["forearm_bone_index"] = snapshot.shapes[pair.forearm].bone_index
		contact["body_bone_index"] = snapshot.shapes[pair.body].bone_index
		contact["origin_id"] = &"world"
		constraints.append(-clearance / normalization)
		reasons.append(pair.reason)
		contacts.append(contact)
		minimum = minf(minimum, clearance)
	return {"valid": true, "constraints": constraints, "constraint_reasons": reasons,
		"contacts": contacts, "minimum_clearance_meters": minimum, "origin_id": Origin.ORIGIN_RL_BONE_ROOT}

static func _world_shape(shape: Dictionary, transform: Transform3D) -> Dictionary:
	if not transform.is_finite() or transform.basis.determinant() <= EPSILON:
		return _failure("forearm_clearance_shape_transform_invalid")
	var scale := transform.basis.get_scale().abs()
	if shape.kind == "capsule":
		# Uniform scale is exact. For anisotropic scale, the largest singular
		# radius bound encloses transformed cap spheres; never underestimates.
		var radius_scale := maxf(scale.x, maxf(scale.y, scale.z))
		var axes := transform.basis.orthonormalized()
		var shear := maxf(absf(transform.basis.x.normalized().dot(transform.basis.y.normalized())),
			maxf(absf(transform.basis.x.normalized().dot(transform.basis.z.normalized())), absf(transform.basis.y.normalized().dot(transform.basis.z.normalized()))))
		if shear > 0.00001:
			# Frobenius norm bounds spectral norm for a sheared sphere transform.
			radius_scale = sqrt(transform.basis.x.length_squared() + transform.basis.y.length_squared() + transform.basis.z.length_squared())
		return {"valid": true, "kind": "capsule", "start": transform * Vector3(0.0, -float(shape.half_mid), 0.0),
			"end": transform * Vector3(0.0, float(shape.half_mid), 0.0), "radius": float(shape.radius) * radius_scale,
			"fallback_axis": axes.x, "fallback_up": axes.z}
	var rotation := transform.basis.orthonormalized()
	var to_box := rotation.transposed() * transform.basis
	var half: Vector3 = shape.half_size
	# Absolute projected extents also conservatively enclose a sheared box.
	var extent := to_box.x.abs() * half.x + to_box.y.abs() * half.y + to_box.z.abs() * half.z
	return {"valid": true, "kind": "box", "frame": Transform3D(rotation, transform.origin), "half_size": extent}

## Closest points cover complete segments, including interior/interior contact.
static func capsule_pair(first: Dictionary, second: Dictionary) -> Dictionary:
	var nearest := closest_segments(first.start, first.end, second.start, second.end)
	var difference: Vector3 = nearest.first - nearest.second
	var distance := difference.length()
	var normal := difference / distance if distance > EPSILON else _coincident_normal(first, second)
	return {"valid": true, "clearance_meters": distance - float(first.radius) - float(second.radius),
		"normal_world": normal, "forearm_axis_point_world": nearest.first, "body_axis_point_world": nearest.second,
		"forearm_surface_world": nearest.first - normal * float(first.radius),
		"body_surface_world": nearest.second + normal * float(second.radius)}

static func capsule_box(capsule: Dictionary, box: Dictionary) -> Dictionary:
	var frame: Transform3D = box.frame
	var inverse := frame.affine_inverse()
	var nearest := segment_box(inverse * (capsule.start as Vector3), inverse * (capsule.end as Vector3), box.half_size)
	var normal: Vector3 = frame.basis * (nearest.normal as Vector3)
	var axis_point: Vector3 = frame * (nearest.point as Vector3)
	return {"valid": true, "clearance_meters": float(nearest.signed_distance) - float(capsule.radius),
		"normal_world": normal, "forearm_axis_point_world": axis_point,
		"body_axis_point_world": frame * (nearest.surface as Vector3),
		"forearm_surface_world": axis_point - normal * float(capsule.radius),
		"body_surface_world": frame * (nearest.surface as Vector3)}

static func closest_segments(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> Dictionary:
	var first := b - a
	var second := d - c
	var offset := a - c
	var aa := first.dot(first)
	var ee := second.dot(second)
	var ff := second.dot(offset)
	var s := 0.0
	var t := 0.0
	if aa <= EPSILON and ee <= EPSILON:
		return {"first": a, "second": c}
	if aa <= EPSILON:
		t = clampf(ff / ee, 0.0, 1.0)
	else:
		var cc := first.dot(offset)
		if ee <= EPSILON:
			s = clampf(-cc / aa, 0.0, 1.0)
		else:
			var bb := first.dot(second)
			var determinant := aa * ee - bb * bb
			if determinant > EPSILON * aa * ee:
				s = clampf((bb * ff - cc * ee) / determinant, 0.0, 1.0)
			t = (bb * s + ff) / ee
			if t < 0.0:
				t = 0.0
				s = clampf(-cc / aa, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((bb - cc) / aa, 0.0, 1.0)
	return {"first": a + first * s, "second": c + second * t}

## Exact minimum signed AABB point-distance over the whole segment. Outside
## intervals have a quadratic squared distance; interior depth is the lower
## envelope of the six face distances. Testing their breakpoints is bounded.
static func segment_box(start: Vector3, end: Vector3, half: Vector3) -> Dictionary:
	var direction := end - start
	var parameters: Array[float] = [0.0, 1.0]
	var slopes: Array[float] = []
	var offsets: Array[float] = []
	for axis: int in 3:
		for sign_value: float in [-1.0, 1.0]:
			slopes.append(direction[axis] * sign_value)
			offsets.append(start[axis] * sign_value - half[axis])
			if absf(direction[axis]) > EPSILON:
				var crossing := (sign_value * half[axis] - start[axis]) / direction[axis]
				if crossing > 0.0 and crossing < 1.0:
					parameters.append(crossing)
	parameters.sort()
	var candidates: Array[float] = parameters.duplicate()
	for interval: int in parameters.size() - 1:
		var low: float = parameters[interval]
		var high: float = parameters[interval + 1]
		var middle := start + direction * ((low + high) * 0.5)
		var numerator := 0.0
		var denominator := 0.0
		for axis: int in 3:
			if absf(middle[axis]) > half[axis]:
				var face := half[axis] if middle[axis] > 0.0 else -half[axis]
				numerator += direction[axis] * (start[axis] - face)
				denominator += direction[axis] * direction[axis]
		if denominator > EPSILON:
			candidates.append(clampf(-numerator / denominator, low, high))
	# Max of six affine signed face distances describes the inside SDF.
	# Its minimum occurs at an endpoint or an intersection of two face lines.
	for first: int in 6:
		for second: int in range(first + 1, 6):
			var divisor := slopes[first] - slopes[second]
			if absf(divisor) <= EPSILON:
				continue
			var parameter := (offsets[second] - offsets[first]) / divisor
			if parameter > 0.0 and parameter < 1.0:
				candidates.append(parameter)
	var best := {"signed_distance": INF}
	for parameter: float in candidates:
		var point := start + direction * parameter
		var surface := point.clamp(-half, half)
		var outward := point - surface
		var distance := outward.length()
		var normal := Vector3.ZERO
		if distance > EPSILON:
			normal = outward / distance
		else:
			var depths := point.abs() - half
			var axis := 0
			if depths.y > depths.x:
				axis = 1
			if depths.z > depths[axis]:
				axis = 2
			distance = depths[axis]
			normal[axis] = 1.0 if point[axis] >= 0.0 else -1.0
			surface = point - normal * distance
		if distance < float(best.signed_distance):
			best = {"signed_distance": distance, "point": point, "surface": surface, "normal": normal, "parameter": parameter}
	return best

static func _coincident_normal(first: Dictionary, second: Dictionary) -> Vector3:
	var a: Vector3 = (first.end as Vector3) - (first.start as Vector3)
	var b: Vector3 = (second.end as Vector3) - (second.start as Vector3)
	var cross := a.cross(b)
	if cross.length_squared() > EPSILON:
		return cross.normalized()
	var fallback: Vector3 = second.get("fallback_axis", Vector3.RIGHT)
	if a.length_squared() > EPSILON:
		fallback -= a * fallback.dot(a) / a.length_squared()
	if fallback.length_squared() <= EPSILON:
		fallback = second.get("fallback_up", Vector3.FORWARD)
	return fallback.normalized()

static func _exempt(first: Dictionary, second: Dictionary) -> bool:
	if first.region == second.region or first.bone_name == second.bone_name:
		return true
	if not String(first.end_bone_name).is_empty() and first.end_bone_name == second.bone_name:
		return true
	if not String(second.end_bone_name).is_empty() and second.end_bone_name == first.bone_name:
		return true
	for pairs: Array in [ExistingPolicy.ANATOMICAL_NEIGHBOR_REGION_PAIRS, ExistingPolicy.BODY_SELF_COLLISION_EXEMPT_REGION_PAIRS]:
		for pair: Array in pairs:
			if (first.region == pair[0] and second.region == pair[1]) or (first.region == pair[1] and second.region == pair[0]):
				return true
	return false

static func _descends_from(skeleton: Skeleton3D, index: int, ancestor: int) -> bool:
	while index >= 0:
		if index == ancestor:
			return true
		index = skeleton.get_bone_parent(index)
	return false

static func _failure(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
