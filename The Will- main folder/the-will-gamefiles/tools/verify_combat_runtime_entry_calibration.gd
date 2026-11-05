extends SceneTree

## Real text-resource round trip of a captured pose, exercising the cold entry
## fallback without inventing a neutral from the current animation.
const Entry = preload("res://runtime/combat/combat_runtime_entry_transition.gd")
const Pose = preload("res://core/models/combat_prepared_pose.gd")
const Profile = preload("res://core/defs/characters/josie/wrist_motion_profile.tres")
var source_path := "C:/WORKSPACE/godot_runs/weapon_motion_allocator_20261029/station_final/isolated_R_library.tres"
var output_dir := "C:/WORKSPACE/godot_runs/weapon_motion_allocator_20261029/entry_calibration"
var checks: Array[Dictionary] = []
var details := {}
var visited := {}

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): source_path = argument.trim_prefix("--source=")
		if argument.begins_with("--out-dir="): output_dir = argument.trim_prefix("--out-dir=")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(output_dir)
	var library: Resource = ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var snapshot: Dictionary = _find_pose(library)
	_check("source_contains_valid_prepared_pose", not snapshot.is_empty())
	if snapshot.is_empty():
		_finish()
		return
	var fresh_profile: Dictionary = Profile.as_dictionary()
	var live := snapshot.duplicate(true)
	for packet: Dictionary in live.arm_constraints_by_slot.values():
		packet["wrist_profile"] = fresh_profile.duplicate(true)
	var wrapper := Resource.new()
	wrapper.set_meta("prepared_pose", live)
	var path := output_dir.path_join("calibration_roundtrip.tres")
	var error := ResourceSaver.save(wrapper, path)
	_check("text_resource_save", error == OK)
	var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) if error == OK else null
	_check("text_resource_reload", loaded != null)
	if loaded == null:
		_finish()
		return
	var saved: Dictionary = loaded.get_meta("prepared_pose", {})
	var saved_profile: Dictionary = saved.arm_constraints_by_slot.values()[0].wrist_profile
	var differences: Array[Dictionary] = []
	for key: String in fresh_profile:
		if fresh_profile[key] == saved_profile.get(key): continue
		var difference := {"key": key, "fresh": fresh_profile[key], "saved": saved_profile.get(key)}
		if fresh_profile[key] is float and saved_profile.get(key) is float:
			difference["delta"] = float(saved_profile[key]) - float(fresh_profile[key])
			difference["fresh_bits"] = var_to_bytes(fresh_profile[key]).hex_encode()
			difference["saved_bits"] = var_to_bytes(saved_profile[key]).hex_encode()
			difference["equal_approx"] = is_equal_approx(fresh_profile[key], saved_profile[key])
		differences.append(difference)
	details["profile_roundtrip_differences"] = differences
	details["exact_profile_equal"] = fresh_profile == saved_profile
	var cold: Dictionary = _cold_capture(live)
	var restored: Dictionary = Entry._supply_matching_saved_neutrals(cold, saved)
	details["cold_restore_result"] = restored
	_check("cold_entry_restores_text_saved_neutrals", bool(restored.get("valid", false)))
	_check("restored_capture_is_valid", bool(Pose.validate(cold).get("valid", false)))
	_check("restored_upperarm_neutrals", (cold.get("entry_restored_neutral_bones", []) as Array).size() == 4)
	var altered := _cold_capture(live)
	for packet: Dictionary in altered.arm_constraints_by_slot.values():
		packet.wrist_profile.forearm_roll_limit_radians += deg_to_rad(1.0)
	var rejected: Dictionary = Entry._supply_matching_saved_neutrals(altered, saved)
	details["changed_limit_result"] = rejected
	_check("genuine_limit_change_rejected", not bool(rejected.get("valid", false)) and rejected.get("reason") == "neutral_calibration_constraint_changed:wrist_profile")
	var altered_rest := _cold_capture(live)
	for packet: Dictionary in altered_rest.arm_constraints_by_slot.values():
		packet.wrist_calibration.anatomical_in_hand_bone = Basis(Vector3.RIGHT, 0.1) * packet.wrist_calibration.anatomical_in_hand_bone
	var rest_rejected: Dictionary = Entry._supply_matching_saved_neutrals(altered_rest, saved)
	_check("changed_wrist_calibration_rejected", not bool(rest_rejected.get("valid", false)) and rest_rejected.get("reason") == "neutral_calibration_wrist_model_changed")
	var malformed := saved_profile.duplicate(true)
	malformed["forearm_roll_limit_radians"] = NAN
	_check("nonfinite_profile_rejected", not Entry._matching_wrist_profile(fresh_profile, malformed))
	malformed = saved_profile.duplicate(true)
	malformed.erase("angle_epsilon_radians")
	_check("missing_profile_field_rejected", not Entry._matching_wrist_profile(fresh_profile, malformed))
	malformed = saved_profile.duplicate(true)
	malformed["revision"] = "different_wrist_model"
	_check("changed_profile_revision_rejected", not Entry._matching_wrist_profile(fresh_profile, malformed))
	_finish()

func _cold_capture(snapshot: Dictionary) -> Dictionary:
	var cold := snapshot.duplicate(true)
	for packet: Dictionary in cold.arm_constraints_by_slot.values():
		var missing: Array[StringName] = []
		for bone: Variant in packet.twist_neutral_rotations.keys():
			if String(bone).contains("UpperarmTwist"):
				packet.twist_neutral_rotations.erase(bone)
				missing.append(StringName(bone))
		packet["missing_twist_neutrals"] = missing
		packet["valid"] = false
		packet["reason"] = "arm_constraint_capture_incomplete"
	return cold

func _find_pose(value: Variant) -> Dictionary:
	if value is Dictionary:
		if value.has("arm_constraints_by_slot") and bool(Pose.validate(value).get("valid", false)): return value
		for child: Variant in value.values():
			var found := _find_pose(child)
			if not found.is_empty(): return found
	elif value is Array:
		for child: Variant in value:
			var found := _find_pose(child)
			if not found.is_empty(): return found
	elif value is Resource:
		if visited.has(value.get_instance_id()): return {}
		visited[value.get_instance_id()] = true
		for property: Dictionary in value.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or (int(property.usage) & PROPERTY_USAGE_STORAGE) == 0: continue
			var found := _find_pose(value.get(property.name))
			if not found.is_empty(): return found
	return {}

func _check(name: String, passed: bool) -> void:
	checks.append({"name": name, "passed": passed})

func _finish() -> void:
	var passed := true
	for check: Dictionary in checks: passed = passed and bool(check.passed)
	var file := FileAccess.open(output_dir.path_join("entry_calibration_report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"passed": passed, "checks": checks, "details": details}, "\t"))
		file.close()
	print("ENTRY_CALIBRATION passed=%s checks=%d output=%s" % [passed, checks.size(), output_dir])
	quit(0 if passed else 1)
