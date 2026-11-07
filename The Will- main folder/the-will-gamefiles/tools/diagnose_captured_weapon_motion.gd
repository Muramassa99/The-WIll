extends SceneTree

## Fast diagnostic from a recorded real editor pose. Replays named local bone
## transforms through the same rig adapter; never reads/writes a player library.
## --request-row replays the recorded request and rigid contact instead of a
## declared camera-plane translation. Recorded JSON transforms have float loss.
## External scene collision validation is intentionally absent and reported.
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const Adapter = preload("res://runtime/player/combat_weapon_motion_rig_adapter.gd")
const Allocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
var capture_dir := "C:/WORKSPACE/godot_runs/shoulder_motion_20261107/before_pommel"
var output_dir := "C:/WORKSPACE/godot_runs/shoulder_motion_20261107/captured_pommel"
var row_index := 5
var request_row_index := -1
var distance_m := 0.05
var compare_hold := false

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--out-dir="): output_dir = argument.trim_prefix("--out-dir=")
		if argument.begins_with("--row="): row_index = int(argument.trim_prefix("--row="))
		if argument.begins_with("--request-row="): request_row_index = int(argument.trim_prefix("--request-row="))
		if argument.begins_with("--distance="): distance_m = float(argument.trim_prefix("--distance="))
		if argument == "--compare-hold=true": compare_hold = true
	call_deferred("_run")

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(capture_dir.path_join("manifest.json")))
	var lines := FileAccess.get_file_as_string(capture_dir.path_join("bone_trace.jsonl")).split("\n", false)
	if manifest.is_empty() or row_index < 0 or row_index >= lines.size():
		push_error("Capture manifest or row unavailable")
		quit(1)
		return
	var captured: Dictionary = JSON.parse_string(lines[row_index])
	var request_capture: Dictionary = {}
	var request_context: Dictionary = {}
	if request_row_index >= 0:
		if request_row_index >= lines.size():
			push_error("Captured request row unavailable")
			quit(1)
			return
		request_capture = JSON.parse_string(lines[request_row_index])
		request_context = request_capture.get("adapter_context", {})
		if not request_context.get("request") is Dictionary or request_context.get("arms", []).is_empty():
			push_error("Captured adapter request/context unavailable")
			quit(1)
			return
	var case: Dictionary = manifest.cases[0]
	var rig := RigScene.instantiate() as PlayerHumanoidRig
	root.add_child(rig)
	await process_frame
	await process_frame
	rig.set_authoring_preview_mode_enabled(true)
	rig.set_process(false)
	rig.set_physics_process(false)
	for tree: Node in rig.find_children("*", "AnimationTree", true, false):
		(tree as AnimationTree).active = false
	var skeleton: Skeleton3D = rig.skeleton
	if skeleton == null or captured.bones.size() != case.skeleton.size():
		push_error("Capture skeleton layout unavailable")
		quit(1)
		return
	for index: int in case.skeleton.size():
		var name := String(case.skeleton[index].name)
		var bone := skeleton.find_bone(name)
		if bone < 0:
			push_error("Capture bone missing: " + name)
			quit(1)
			return
		var pose: Dictionary = captured.bones[index].local
		skeleton.set_bone_pose_position(bone, _v3(pose.p))
		skeleton.set_bone_pose_rotation(bone, _quat(pose.q))
		skeleton.set_bone_pose_scale(bone, _v3(pose.scale))
	skeleton.global_transform = _frame(captured.skeleton_world)
	skeleton.force_update_all_bone_transforms()
	rig.set("_wrist_motion_states", captured.get("wrist_cache", {}).duplicate(true))
	rig.set("_shoulder_motion_states", captured.get("accepted_shoulder_cache", {}).duplicate(true))
	var prop := Node3D.new()
	root.add_child(prop)
	prop.global_transform = _frame(captured.weapon_world)
	var side := String(case.get("side", "R"))
	var slot := &"hand_left" if side == "L" else &"hand_right"
	var hand := skeleton.find_bone("CC_Base_" + side + "_Hand")
	var binding := prop.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(hand)
	var yaw := deg_to_rad(float(case.camera.orbit_yaw_degrees))
	var pitch := deg_to_rad(float(case.camera.orbit_pitch_degrees))
	# Matches the preview's declared yaw/pitch camera orbit; downward screen Y.
	var camera_down := Vector3(sin(yaw) * sin(pitch), -cos(pitch), cos(yaw) * sin(pitch))
	var target := prop.global_transform
	target.origin += camera_down * distance_m
	var contact := Vector3.ZERO
	# First populated manipulator row supplies the weapon-local contact anchor.
	for line: String in lines:
		var recorded: Dictionary = JSON.parse_string(line)
		var manipulator: Dictionary = recorded.get("manipulator", {})
		if manipulator.has("contact_local"):
			contact = _v3(manipulator.contact_local)
			break
	var request := {"weapon": prop, "mode": "pommel", "primary_slot": slot,
		"support_slot": StringName(), "previous_weapon": prop.global_transform,
		"target_weapon": target, "contact_local": contact,
		"hand_in_weapon_by_slot": {slot: binding}, "commit": false,
		"policy": {"trace_rejections": true}}
	if request_row_index >= 0:
		var original: Dictionary = request_context.request
		var bindings: Dictionary = {}
		for key: String in original.hand_in_weapon_by_slot:
			bindings[StringName(key)] = _frame(original.hand_in_weapon_by_slot[key])
		request = {"weapon": prop, "mode": String(original.mode),
			"primary_slot": StringName(original.primary_slot), "support_slot": StringName(original.support_slot),
			"previous_weapon": _frame(original.previous_weapon), "target_weapon": _frame(original.target_weapon),
			"contact_local": _v3(original.contact_local), "hand_in_weapon_by_slot": bindings,
			"commit": false, "policy": request_context.policy.duplicate(true)}
		request.policy["trace_rejections"] = true
		# These are the input shoulder states retained by the recorded adapter,
		# not the accepted output states of the request we are reproducing.
		var shoulder_cache: Dictionary = {}
		for arm: Dictionary in request_context.arms:
			shoulder_cache[StringName(arm.slot)] = arm.shoulder_state.duplicate(true)
		rig.set("_shoulder_motion_states", shoulder_cache)
	var adapter := Adapter.new()
	var initialized: Dictionary = adapter._initialize(rig, request)
	var baseline: Dictionary = {}
	var captured_contract: Dictionary = {}
	if initialized.get("valid", false):
		baseline = {"q": adapter.q, "lower": adapter.lower, "upper": adapter.upper,
			"shoulder_state": adapter.arms[0].shoulder_state,
			"start_allowance": adapter.start_allowance}
		if request_row_index >= 0:
			var same_profile := true
			var same_calibration := true
			for index: int in adapter.arms.size():
				same_profile = same_profile and _same_captured_value(adapter.arms[index].shoulder_profile, request_context.arms[index].shoulder_profile)
				same_calibration = same_calibration and _same_captured_value(adapter.arms[index].shoulder_calibration, request_context.arms[index].shoulder_calibration)
			captured_contract = {"profile_matches": same_profile, "named_calibration_matches": same_calibration,
				"q_matches": _same_captured_value(adapter.q, request_context.q),
				"lower_matches": _same_captured_value(adapter.lower, request_context.lower),
				"upper_matches": _same_captured_value(adapter.upper, request_context.upper),
				"prop_matches_previous_weapon": _same_captured_value(captured.weapon_world, request_context.request.previous_weapon),
				"recorded_q": request_context.q}
			if not same_profile or not same_calibration:
				push_error("Captured shoulder profile/calibration differs; refusing a silently changed replay")
				quit(1)
				return
	var result: Dictionary = Adapter.new().allocate(rig, request)
	for key: String in ["motion_adapter", "accepted_payload", "accepted_pose"]: result.erase(key)
	var comparison: Dictionary = {}
	if compare_hold and initialized.get("valid", false):
		# Deliberate diagnostic counterfactual, NEVER committed. Both runs skip
		# storage/context validation equally; only the named shoulder-hold rows
		# differ. All remaining FK, rigid binding and anatomical bounds remain.
		var input: Dictionary = adapter._allocator_input()
		input["validate_candidate"] = Callable()
		var strict: Dictionary = Allocator.solve(input, Callable(adapter, "_evaluate"), adapter.policy)
		var relaxed: Dictionary = Allocator.solve(input, Callable(self, "_evaluate_without_shoulder_hold").bind(adapter), adapter.policy)
		for compared: Dictionary in [strict, relaxed]: compared.erase("accepted_payload")
		comparison = {"scope": "Diagnostic only: strict versus removed shoulder-hold rows; neither run uses storage/collision validator or commits.",
			"strict_without_storage": strict, "relaxed_hold_without_storage": relaxed}
	var report := {"capture_dir": capture_dir, "capture_row": row_index, "captured_phase": captured.phase,
		"request_row": request_row_index, "request_phase": request_capture.get("phase", ""), "captured_contract": captured_contract,
		"scope": "Real captured named bone poses; %s; no external scene collision validator. JSON quaternion/scale reconstruction is subject to float loss; not a full UI reproduction." % ("recorded request and acquired rigid contact; captured profile and named calibration checked" if request_row_index >= 0 else "declared camera-plane target and derived single rigid contact"),
		"distance_m": distance_m, "target_direction_world": camera_down, "initialized": initialized,
		"baseline": baseline, "result": result, "isolated_comparison": comparison}
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output := FileAccess.open(output_dir.path_join("report.json"), FileAccess.WRITE)
	if output == null:
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("CAPTURED_WEAPON_MOTION status=%s reason=%s scale=%s output=%s" % [result.get("status", ""), result.get("reason", ""), result.get("task_scale", 0.0), output_dir])
	quit(0)

func _same_captured_value(actual: Variant, recorded: Variant) -> bool:
	if actual is Vector3:
		return recorded is Array and actual.distance_to(_v3(recorded)) <= 1.0e-6
	if actual is Transform3D:
		return recorded is Dictionary and actual.origin.distance_to(_frame(recorded).origin) <= 1.0e-6 and actual.basis.is_equal_approx(_frame(recorded).basis)
	if actual is Basis:
		return recorded is Dictionary and actual.is_equal_approx(_frame(recorded).basis)
	if actual is Dictionary:
		if not recorded is Dictionary or actual.size() != recorded.size(): return false
		for key: Variant in actual:
			if not recorded.has(key) or not _same_captured_value(actual[key], recorded[key]): return false
		return true
	if actual is Array or actual is PackedFloat64Array or actual is PackedFloat32Array or actual is PackedStringArray:
		if not recorded is Array or actual.size() != recorded.size(): return false
		for index: int in actual.size():
			if not _same_captured_value(actual[index], recorded[index]): return false
		return true
	if actual is float or actual is int:
		return (recorded is float or recorded is int) and absf(float(actual) - float(recorded)) <= 1.0e-6
	return actual == recorded

func _evaluate_without_shoulder_hold(values: PackedFloat64Array, adapter: CombatWeaponMotionRigAdapter) -> Dictionary:
	var evaluated: Dictionary = adapter._evaluate(values)
	for pair: Array in [["constraints", "constraint_reasons"], ["search_constraints", "search_constraint_reasons"]]:
		var constraints := PackedFloat64Array(evaluated.get(pair[0], []))
		var reasons := PackedStringArray(evaluated.get(pair[1], []))
		for index: int in mini(constraints.size(), reasons.size()):
			if reasons[index].begins_with("SHOULDER_HOLD:"):
				constraints[index] = -1.0
		evaluated[pair[0]] = constraints
	return evaluated

func _v3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _quat(values: Array) -> Quaternion:
	return Quaternion(float(values[0]), float(values[1]), float(values[2]), float(values[3]))

func _frame(values: Dictionary) -> Transform3D:
	return Transform3D(Basis(_quat(values.q)).scaled(_v3(values.scale)), _v3(values.p))
