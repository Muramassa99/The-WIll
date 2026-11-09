extends SceneTree

const MotionNode = preload("res://core/models/combat_animation_motion_node.gd")
const PreparedPose = preload("res://core/models/combat_prepared_pose.gd")
const CURL_FIELDS: Array[StringName] = [
	&"right_hand_finger_curl_degrees", &"left_hand_finger_curl_degrees",
]
# Independent copy of the pre-feature exclusions: compatibility must not be
# established by asking the newly modified signature function for its rules.
const LEGACY_NON_POSE_FIELDS: Array[StringName] = [
	&"node_id", &"node_index", &"draft_notes", &"retarget_node",
	&"prepared_pose", &"prepared_pose_signature", &"transition_duration_seconds",
	&"tip_curve_in_handle", &"tip_curve_out_handle",
	&"pommel_curve_in_handle", &"pommel_curve_out_handle", &"locked_for_authoring",
]
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var node := MotionNode.new()
	node.normalize()
	_check(node.right_hand_finger_curl_degrees.is_empty() and node.left_hand_finger_curl_degrees.is_empty(), "new_node_has_no_authored_fingers")
	var legacy_signature: String = _legacy_pose_signature(node)
	_check(PreparedPose.node_pose_signature(node) == legacy_signature, "empty_controls_preserve_pre_feature_signature")
	_check(PreparedPose.SCHEMA_VERSION == 4, "prepared_pose_schema_unchanged")
	var dirty: Dictionary = {"index": -4.0, &"middle": 72.5, "ring": 245, &"pinky": 0.0, &"thumb": 90.0, &"unknown": 18.0}
	var normalized: Dictionary = MotionNode.normalize_empty_hand_finger_curls(dirty)
	_check(normalized.size() == 4, "only_four_supported_fingers_are_retained")
	_check(normalized[&"index"] == 0.0 and normalized[&"ring"] == 180.0, "finite_controls_clamp_to_zero_and_180")
	_check(normalized[&"middle"] == 72.5 and normalized.has(&"pinky") and normalized[&"pinky"] == 0.0, "fractional_and_authored_zero_values_preserved")
	_check(dirty["index"] == -4.0 and dirty["ring"] == 245 and dirty.has(&"thumb"), "normalization_does_not_mutate_caller_dictionary")
	var canonical_keys := true
	for key: Variant in normalized:
		canonical_keys = canonical_keys and key is StringName
	_check(canonical_keys, "keys_are_canonical_string_names")
	var invalid: Dictionary = {&"index": NAN, &"middle": INF, &"ring": -INF, &"pinky": "90"}
	_check(MotionNode.normalize_empty_hand_finger_curls(invalid).is_empty(), "nonfinite_and_nonnumeric_values_are_removed")
	_check(MotionNode.normalize_empty_hand_finger_curls({&"index": true, &"middle": false, &"ring": Vector3.ONE, &"pinky": null}).is_empty(), "bool_vector_and_null_are_not_curl_values")
	node.right_hand_finger_curl_degrees = invalid
	_check(PreparedPose.node_pose_signature(node) == legacy_signature, "invalid_controls_do_not_invalidate_prepared_pose")
	node.normalize()
	_check(node.right_hand_finger_curl_degrees.is_empty(), "node_normalize_removes_invalid_controls")
	node.right_hand_finger_curl_degrees = {&"index": 0.0}
	var zero_signature: String = PreparedPose.node_pose_signature(node)
	_check(zero_signature != legacy_signature, "authored_zero_differs_from_unauthored")
	_check(not node.right_hand_finger_curl_degrees.has(&"middle"), "authoring_one_finger_does_not_author_the_hand")
	node.right_hand_finger_curl_degrees = {}
	node.left_hand_finger_curl_degrees = {&"index": 0.0}
	_check(PreparedPose.node_pose_signature(node) != zero_signature, "left_and_right_finger_changes_are_distinct")
	node.left_hand_finger_curl_degrees = {}
	node.right_hand_finger_curl_degrees = {&"pinky": 180.0, &"middle": 72.5, &"index": 0.0}
	var ordered_signature: String = PreparedPose.node_pose_signature(node)
	node.right_hand_finger_curl_degrees = {"index": 0, "middle": 72.5, "pinky": 180}
	_check(PreparedPose.node_pose_signature(node) == ordered_signature, "signature_ignores_insertion_order_key_type_and_numeric_type")
	node.right_hand_finger_curl_degrees["middle"] = 73.0
	_check(PreparedPose.node_pose_signature(node) != ordered_signature, "changed_curl_invalidates_prepared_signature")
	node.right_hand_finger_curl_degrees = {&"index": -5.0, &"pinky": 190.0}
	node.left_hand_finger_curl_degrees = {&"ring": 30.0}
	var before_normalize: String = PreparedPose.node_pose_signature(node)
	node.normalize()
	_check(PreparedPose.node_pose_signature(node) == before_normalize, "signature_uses_same_canonical_values_as_node_normalize")
	_check(node.right_hand_finger_curl_degrees == {&"index": 0.0, &"pinky": 180.0} and node.left_hand_finger_curl_degrees == {&"ring": 30.0}, "normalization_keeps_hands_independent_and_sparse")
	var duplicated := node.duplicate_node()
	_check(PreparedPose.node_pose_signature(duplicated) == PreparedPose.node_pose_signature(node), "duplicate_preserves_authored_finger_state")
	duplicated.right_hand_finger_curl_degrees[&"index"] = 45.0
	duplicated.left_hand_finger_curl_degrees[&"ring"] = 120.0
	_check(node.right_hand_finger_curl_degrees[&"index"] == 0.0 and node.left_hand_finger_curl_degrees[&"ring"] == 30.0, "duplicate_finger_dictionaries_are_independent")
	var authored_signature: String = PreparedPose.node_pose_signature(node)
	node.prepared_pose = {"stored_finger_rotations": [Quaternion.IDENTITY]}
	node.prepared_pose_signature = authored_signature
	node.draft_notes = "cosmetic note"
	node.transition_duration_seconds = 0.7
	_check(PreparedPose.node_pose_signature(node) == authored_signature, "prepared_packet_and_nonpose_edits_remain_outside_signature")
	_roundtrip(node)
	var failed := false
	for check: Dictionary in checks:
		failed = failed or not bool(check.passed)
	print(JSON.stringify({"passed": not failed, "checks": checks}))
	quit(1 if failed else 0)

func _roundtrip(node: Resource) -> void:
	# This verifier owns only this unique temporary resource, not a user skill.
	var path := "user://verify_empty_hand_finger_state_%d_%d.tres" % [OS.get_process_id(), Time.get_ticks_usec()]
	var save_error: Error = ResourceSaver.save(node, path)
	_check(save_error == OK, "finger_state_resource_save", {"error": save_error})
	if save_error != OK:
		return
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_check(loaded != null, "finger_state_resource_reload")
	if loaded != null:
		_check(loaded.get("right_hand_finger_curl_degrees") == node.get("right_hand_finger_curl_degrees") and loaded.get("left_hand_finger_curl_degrees") == node.get("left_hand_finger_curl_degrees"), "resource_roundtrip_preserves_sparse_per_hand_data")
		_check(PreparedPose.node_pose_signature(loaded) == PreparedPose.node_pose_signature(node), "resource_roundtrip_preserves_signature")
		_check(loaded.get("prepared_pose") == node.get("prepared_pose") and loaded.get("prepared_pose_signature") == node.get("prepared_pose_signature"), "existing_prepared_packet_survives_resource_roundtrip")
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(remove_error == OK, "owned_temporary_resource_removed", {"error": remove_error})

func _legacy_pose_signature(node: Resource) -> String:
	var values: Array = []
	for property: Dictionary in node.get_property_list():
		var name: StringName = StringName(property.name)
		if name in CURL_FIELDS:
			continue # These properties did not exist before this feature.
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0 or name in LEGACY_NON_POSE_FIELDS:
			continue
		values.append([name, node.get(name)])
	return var_to_bytes(values).hex_encode().sha256_text()

func _check(passed: bool, name: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "name": name, "details": details})
