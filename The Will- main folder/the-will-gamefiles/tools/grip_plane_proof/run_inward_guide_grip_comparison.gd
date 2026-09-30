extends "res://tools/grip_plane_proof/run_handle_grip_process_proof.gd"

## Step-1 comparison only. Reuse the exact already-adapted right-hand capture;
## acquire afresh with the live character configuration and canonical solver.
const CharacterData = preload("res://runtime/player/grip/character_grip_data.gd")
const RigScene = preload("res://scenes/player/player_humanoid_rig.tscn")
const BASELINE_PATH := "C:/WORKSPACE/test_artifacts/full_hand_grip_process_2026-09-27T09-05-46.json"
const BASELINE_SHA := "98f81ae6d7b2cd1e3c6fd971770b5041e555401ee9ba1e417c475f0d11b014d8"
var _comparison_baseline_path: String = BASELINE_PATH
var _comparison_baseline_sha: String = BASELINE_SHA


func _selected_digits() -> Array[StringName]:
	return [&"middle", &"thumb", &"index", &"ring", &"pinky"]


func _report_stem() -> String:
	return "inward_guide_grip_comparison"


func _run() -> void:
	var expected := OS.get_environment("THE_WILL_DIAGNOSTIC_USER_ROOT").replace("\\", "/").simplify_path().to_lower()
	if not expected.begins_with("c:/workspace/") or expected != OS.get_user_data_dir().replace("\\", "/").simplify_path().to_lower():
		push_error("Requires isolated workspace user data"); quit(1); return
	var requested_baseline := OS.get_environment("THE_WILL_GRIP_COMPARISON_BASELINE")
	if not requested_baseline.is_empty():
		_comparison_baseline_path=requested_baseline.replace("\\","/").simplify_path()
		_comparison_baseline_sha=OS.get_environment("THE_WILL_GRIP_COMPARISON_BASELINE_SHA256").to_lower()
		if not _comparison_baseline_path.begins_with("C:/WORKSPACE/test_artifacts/") or _comparison_baseline_path.get_extension()!="json" or _comparison_baseline_sha.length()!=64:
			push_error("Explicit workspace baseline and SHA256 required"); quit(1); return
	if FileAccess.get_sha256(_comparison_baseline_path) != _comparison_baseline_sha:
		push_error("Comparison baseline hash mismatch"); quit(1); return
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_comparison_baseline_path))
	if baseline.get("schema")!="handle_grip_process_proof_v1" or not baseline.get("ok",false):
		push_error("Completed acquisition baseline required"); quit(1); return
	var source: Dictionary = {}
	for case: Dictionary in baseline.cases:
		if case.slot == "hand_right": source = case
	if source.is_empty():
		push_error("Missing right-hand baseline"); quit(1); return
	var path: String = source.source_trace
	if not _workspace_trace_path(path) or FileAccess.get_sha256(path) != source.source_trace_sha256:
		push_error("Exact adapted source trace required"); quit(1); return
	var file := FileAccess.open(path, FileAccess.READ)
	var trace: Dictionary = file.get_var(false); file.close()
	var stage: Dictionary = {}
	for transaction: Dictionary in trace.transactions:
		if transaction.serial == source.source_transaction:
			stage = transaction.finger_inputs[-1]
	if stage.is_empty() or stage.transaction_serial != source.source_transaction:
		push_error("Matching captured input required"); quit(1); return
	var rig: Node3D = RigScene.instantiate()
	root.add_child(rig); rig.set_process(false)
	for node: Node in rig.find_children("*", "", true, false):
		if node is AnimationPlayer: node.stop()
		if node is AnimationTree: node.active = false
		if node is SkeletonModifier3D: node.active = false
	var data: Dictionary = CharacterData.load_for_actor(rig)
	if not data.get("valid", false) or trace.anatomy_signature != data.anatomy.source_signature:
		push_error("Current character does not match captured anatomy: " + str(data.get("reason", "")))
		rig.free(); quit(1); return
	_config = data.config.duplicate(true)
	if not is_equal_approx(float(_config.get("guide_inward_target_offset_m", 0.0)), 0.0015):
		push_error("Step-1 comparison requires an explicit live 1.5 mm target offset")
		rig.free(); quit(1); return
	var started := Time.get_ticks_usec()
	var context: Dictionary = _prepare(data.anatomy, stage)
	if not context.get("valid", false):
		push_error(str(context)); rig.free(); quit(1); return
	var result: Dictionary = await _search(context)
	result["source_trace"] = path
	result["source_trace_sha256"] = FileAccess.get_sha256(path)
	result["source_transaction"] = source.source_transaction
	var report: Dictionary = _report_extensions()
	report.merge({"ok": result.get("valid", false), "cases": [result],
		"selected_digits": _selected_digits(), "anatomy_signature": data.anatomy.source_signature,
		"production_pose_written": false, "actual_3d_grip_verified": false,
		"failures": [] if result.get("valid", false) else [result.get("reason", "search_failed")],
		"scope": "right_hand_five_digit_same_frozen_input_current_live_configuration",
		"baseline_report": _comparison_baseline_path, "baseline_report_sha256": _comparison_baseline_sha,
		"envelope_configuration_path": CharacterData.PROFILE_PATH,
		"envelope_configuration_sha256": FileAccess.get_sha256(CharacterData.PROFILE_PATH),
		"contact_configuration": _config.duplicate(true),
		"total_diagnostic_ms": float(Time.get_ticks_usec() - started) / 1000.0}, true)
	var output_path := "C:/WORKSPACE/test_artifacts/" + _report_stem() + "_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save comparison report"); rig.free(); quit(1); return
	file.store_string(JSON.stringify(_json(report), "\t")); file.close()
	print("INWARD_GUIDE_RESULT=" + output_path)
	print("INWARD_GUIDE_SUMMARY=" + JSON.stringify({"ok": report.ok, "failures": report.failures,
		"total_ms": report.total_diagnostic_ms, "selected": _brief(result.get("selected", {}))}))
	rig.free()
	quit(0 if report.ok else 1)
