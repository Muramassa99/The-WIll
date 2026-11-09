extends SceneTree

const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
# Independent pre-native contract. Do not derive expected bytes from the new
# dispatcher or kernel; existing saved signatures must remain byte-identical.
const REFERENCE_CURL_FIELDS: Array[StringName] = [
	&"right_hand_finger_curl_degrees", &"left_hand_finger_curl_degrees",
]
const REFERENCE_DIGITS: Array[StringName] = [&"index", &"middle", &"ring", &"pinky"]
const REFERENCE_EXCLUDED: Array[StringName] = [
	&"node_id", &"node_index", &"draft_notes", &"retarget_node",
	&"prepared_pose", &"prepared_pose_signature", &"transition_duration_seconds",
	&"tip_curve_in_handle", &"tip_curve_out_handle", &"pommel_curve_in_handle",
	&"pommel_curve_out_handle", &"locked_for_authoring",
	&"right_hand_finger_curl_degrees", &"left_hand_finger_curl_degrees",
]
var checks: Array[Dictionary] = []
var kernel: RefCounted
var timings: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ClassDB.class_exists(&"CombatPoseCaptureKernel"), "native_class_registered")
	if not checks[-1].passed:
		_finish()
		return
	kernel = ClassDB.instantiate(&"CombatPoseCaptureKernel") as RefCounted
	_check(kernel != null, "native_class_instantiated")
	if kernel == null:
		_finish()
		return
	_check(PreparedPose.SCHEMA_VERSION == 4, "prepared_schema_unchanged")
	_check(PreparedPose.node_pose_signature(null) == "", "null_dispatch")
	_check(_native_signature(null) == "", "null_native")
	var node := MotionNode.new()
	_parity(node, "untouched_default")
	node.normalize()
	_parity(node, "normalized_default")
	var base: String = _reference_signature(node)
	var curl_cases: Array[Dictionary] = [
		{}, {&"index": 0.0}, {&"pinky": 180.0, &"index": 3.125, &"middle": 45},
		{"index": 0, "middle": 90.25, "ring": 180, "pinky": 12.5},
		{&"index": -4.0, &"middle": 245.0, &"ring": -0.0, &"pinky": 179.999},
		{&"index": NAN, &"middle": INF, &"ring": -INF, &"pinky": "90"},
		{&"index": true, &"middle": false, &"ring": Vector3.ONE, &"pinky": null},
		{&"thumb": 90.0, &"unknown": 25.0},
	]
	for case_index: int in curl_cases.size():
		for side: int in 2:
			var sample := node.duplicate_node()
			sample.set(REFERENCE_CURL_FIELDS[side], curl_cases[case_index].duplicate(true))
			_parity(sample, "curl_%d_side_%d" % [case_index, side])
			if case_index >= 5:
				_check(PreparedPose.node_pose_signature(sample) == base, "invalid_or_unknown_curls_ignored_%d_%d" % [case_index, side])
	var sparse_a := node.duplicate_node()
	sparse_a.right_hand_finger_curl_degrees = {&"pinky": 180.0, &"index": 0.0, &"middle": 90.0}
	sparse_a.left_hand_finger_curl_degrees = {&"ring": 15.25}
	var sparse_b := node.duplicate_node()
	sparse_b.right_hand_finger_curl_degrees = {"middle": 90, "index": 0, "pinky": 180}
	sparse_b.left_hand_finger_curl_degrees = {"ring": 15.25}
	_parity(sparse_a, "both_hands_sparse")
	_parity(sparse_b, "both_hands_reordered")
	_check(PreparedPose.node_pose_signature(sparse_a) == PreparedPose.node_pose_signature(sparse_b), "curl_order_key_type_and_numeric_type_canonical")
	var zero := node.duplicate_node()
	zero.right_hand_finger_curl_degrees = {&"index": 0.0}
	_check(PreparedPose.node_pose_signature(zero) != base, "explicit_zero_is_authored")
	var left_zero := node.duplicate_node()
	left_zero.left_hand_finger_curl_degrees = {&"index": 0.0}
	_check(PreparedPose.node_pose_signature(left_zero) != PreparedPose.node_pose_signature(zero), "hands_remain_distinct")
	var excluded_changes: Dictionary = {
		&"node_id": &"renumbered", &"node_index": 9, &"draft_notes": "cosmetic",
		&"retarget_node": Resource.new(), &"prepared_pose": {"bones": [Quaternion.IDENTITY]},
		&"prepared_pose_signature": "stored", &"transition_duration_seconds": 1.45,
		&"tip_curve_in_handle": Vector3(1, 2, 3), &"tip_curve_out_handle": Vector3(3, 2, 1),
		&"pommel_curve_in_handle": Vector3(0, 5, 1), &"pommel_curve_out_handle": Vector3(-1, 4, 7),
		&"locked_for_authoring": true,
	}
	for field: StringName in excluded_changes:
		var sample := node.duplicate_node()
		sample.set(field, excluded_changes[field])
		_parity(sample, "excluded_%s" % field)
		_check(PreparedPose.node_pose_signature(sample) == base, "exclusion_preserved_%s" % field)
	# Mutate every other currently stored script field, rather than testing only
	# one endpoint. This covers origin IDs, arm state and future additive fields.
	for property: Dictionary in node.get_property_list():
		var name := StringName(property.name)
		if name in REFERENCE_EXCLUDED or (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var changed: Variant = _different_value(node.get(name))
		if changed == null:
			continue
		var sample := node.duplicate_node()
		sample.set(name, changed)
		_parity(sample, "authored_%s" % name)
		_check(PreparedPose.node_pose_signature(sample) != base, "authored_change_detected_%s" % name)
	var generic := Resource.new()
	generic.resource_name = "generic resource fallback"
	_check(PreparedPose.node_pose_signature(generic) == _reference_signature(generic), "non_motion_resource_script_fallback")
	_benchmark(sparse_a)
	_finish()

func _different_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL: return not bool(value)
		TYPE_INT: return int(value) + 1
		TYPE_FLOAT: return float(value) + 0.125
		TYPE_STRING_NAME: return StringName(String(value) + "_probe")
		TYPE_STRING: return String(value) + "_probe"
		TYPE_VECTOR3: return (value as Vector3) + Vector3(0.125, -0.25, 0.5)
	return null

func _parity(node: Resource, label: String) -> void:
	var before: PackedByteArray = var_to_bytes(_raw_script_fields(node))
	var expected: String = _reference_signature(node)
	_check(PreparedPose.node_pose_signature(node) == expected, label + "_dispatch_parity")
	_check(_native_signature(node) == expected, label + "_native_parity")
	_check(PreparedPose._node_pose_signature_script(node) == expected, label + "_fallback_parity")
	_check(var_to_bytes(_raw_script_fields(node)) == before, label + "_does_not_mutate")

func _native_signature(node: Resource) -> String:
	var curls: Dictionary = {}
	if node != null:
		for field: StringName in PreparedPose.EMPTY_HAND_CURL_FIELDS:
			curls[field] = MotionNode.normalize_empty_hand_finger_curls(node.get(field))
	return kernel.call("node_pose_signature", node, PreparedPose.NON_POSE_FIELDS,
		PreparedPose.EMPTY_HAND_CURL_FIELDS, MotionNode.EMPTY_HAND_FINGER_IDS, curls,
		PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE)

func _raw_script_fields(node: Resource) -> Array:
	var result: Array = []
	for property: Dictionary in node.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			var value: Variant = node.get(property.name)
			# Retarget is excluded from the signature but must retain identity.
			# Avoid serializing an arbitrary Resource merely to check nonmutation.
			if value is Resource:
				value = value.get_instance_id()
			result.append([property.name, value])
	return result

func _reference_signature(node: Resource) -> String:
	if node == null:
		return ""
	var values: Array = []
	var curl_fields: Dictionary = {}
	for property: Dictionary in node.get_property_list():
		var name := StringName(property.name)
		if name in REFERENCE_CURL_FIELDS:
			var authored: Variant = node.get(name)
			if authored is Dictionary:
				var normalized: Dictionary = {}
				for digit: StringName in REFERENCE_DIGITS:
					var value: Variant = authored.get(digit, authored.get(String(digit), null))
					if (value is int or value is float) and is_finite(float(value)):
						normalized[digit] = clampf(float(value), 0.0, 180.0)
				curl_fields[name] = normalized
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name in REFERENCE_EXCLUDED:
			continue
		values.append([name, node.get(name)])
	for field: StringName in REFERENCE_CURL_FIELDS:
		var curls: Dictionary = curl_fields.get(field, {})
		if curls.is_empty():
			continue
		var ordered: Array = []
		for digit: StringName in REFERENCE_DIGITS:
			if curls.has(digit):
				ordered.append([digit, curls[digit]])
		values.append([field, ordered])
	return var_to_bytes(values).hex_encode().sha256_text()

func _benchmark(node: Resource) -> void:
	const ITERATIONS := 300
	# Warm both paths; report the whole dispatcher, including sparse-map policy.
	for index: int in 20:
		PreparedPose.node_pose_signature(node)
		PreparedPose._node_pose_signature_script(node)
	var started: int = Time.get_ticks_usec()
	for index: int in ITERATIONS:
		PreparedPose._node_pose_signature_script(node)
	var script_usec: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	for index: int in ITERATIONS:
		PreparedPose.node_pose_signature(node)
	var native_usec: int = Time.get_ticks_usec() - started
	timings = {"iterations": ITERATIONS, "script_usec_total": script_usec,
		"native_dispatch_usec_total": native_usec,
		"script_usec_per_call": float(script_usec) / ITERATIONS,
		"native_dispatch_usec_per_call": float(native_usec) / ITERATIONS}

func _check(passed: bool, name: String) -> void:
	checks.append({"passed": passed, "name": name})

func _finish() -> void:
	var failed: int = 0
	for check: Dictionary in checks:
		if not check.passed:
			failed += 1
	print(JSON.stringify({"passed": failed == 0, "check_count": checks.size(),
		"failed_count": failed, "checks": checks, "signature_timings": timings}))
	quit(1 if failed > 0 else 0)
