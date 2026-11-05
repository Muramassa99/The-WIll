extends "res://tools/diagnose_skill3_tip_direction_stall.gd"

## Diagnostic only: retain one difficult real request, finish the gestures, then
## compare production, traced baseline, 60 iterations and released forearm tier.
## No counterfactual is committed/saved. Production candidate validation still
## temporarily installs and restores poses exactly as its original path does.
const ProbeAllocator = preload("res://tools/combat_weapon_motion_allocator_trace.gd")
const OriginalAllocator = preload("res://core/resolvers/combat_weapon_motion_allocator.gd")
var probe_adapter: RefCounted
var probe_input: Dictionary = {}
var probe_policy: Dictionary = {}
var probe_scene: Dictionary = {}
var probe_original_result: Dictionary = {}
var probe_previous_scene: Dictionary = {}
var probe_label := ""

func _sample(label: String, extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = super._sample(label, extra)
	if circle_actor == null or circle_weapon == null:
		return row
	var allocation: Dictionary = circle_root.get_meta("weapon_motion_allocation_result", {})
	var adapter: Variant = allocation.get("motion_adapter")
	if probe_adapter == null and label.begins_with("continuous") and String(allocation.get("status", "")) == "SCALED" and adapter is RefCounted and not probe_previous_scene.is_empty():
		probe_adapter = adapter
		probe_input = (adapter.call("_allocator_input") as Dictionary).duplicate(true)
		probe_policy = (adapter.get("policy") as Dictionary).duplicate(true)
		probe_scene = probe_previous_scene.duplicate(true)
		probe_original_result = _probe_result(allocation)
		probe_label = label
	probe_previous_scene = _probe_scene_checkpoint()
	return row

func _reopen_write(ui: CombatAnimationStationUI, side: String) -> void:
	await super._reopen_write(ui, side)
	if probe_adapter == null:
		allocation_report["convergence_probe"] = {"available": false, "reason": "No difficult real request captured."}
		return
	var current_scene: Dictionary = probe_adapter.call("_capture_commit_state")
	var saved_counters := {}
	for key: String in ["timings", "storage_validation_failures", "storage_validation_last_failure"]:
		saved_counters[key] = (probe_adapter.get(key) as Dictionary).duplicate(true)
	var baseline: Dictionary = _probe_run(probe_policy, false)
	var cases: Array[Dictionary] = []
	cases.append(_probe_run(probe_policy, true))
	cases[0]["name"] = "original_policy"
	var longer := probe_policy.duplicate(true)
	longer["max_iterations"] = 60
	cases.append(_probe_run(longer, true))
	cases[1]["name"] = "original_policy_60_iterations"
	var released := probe_policy.duplicate(true)
	var hold_order: Array = OriginalAllocator._hold_order(String(probe_input.mode), probe_policy)
	var released_order: Array = []
	for tier: PackedStringArray in hold_order:
		var retained := PackedStringArray()
		for group: String in tier:
			if group != "forearm": retained.append(group)
		if not retained.is_empty(): released_order.append(retained)
	var by_mode: Dictionary = released.get("hold_order_by_mode", {}).duplicate(true)
	by_mode[String(probe_input.mode)] = released_order
	released["hold_order_by_mode"] = by_mode
	cases.append(_probe_run(released, true))
	cases[2]["name"] = "forearm_hold_tier_removed_only"
	probe_adapter.call("_restore_commit_state", current_scene)
	for key: String in saved_counters: probe_adapter.set(key, saved_counters[key])
	var restored: Dictionary = probe_adapter.call("_capture_commit_state")
	var report := {"available": true, "captured_at": probe_label,
		"scope": "One retained real request. Trace adds overhead: these timings are not a speed benchmark. Limits, target, sampling and acceptance tolerances are unchanged.",
		"input": probe_input, "original_live_result": probe_original_result,
		"restored_checkpoint_matches_original_weapon": (probe_scene.weapon_world as Transform3D).is_equal_approx(probe_input.previous_weapon),
		"production_rerun": baseline, "cases": cases,
		"trace_copy_matches_production": _probe_equivalence(baseline.result, cases[0].result),
		"original_live_matches_production_rerun": _probe_equivalence(probe_original_result, baseline.result),
		"scene_restored_exactly": current_scene == restored}
	var path := output_dir.path_join("convergence_probe.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(_json(report), "\t"))
		file.close()
	allocation_report["convergence_probe"] = {"available": true, "path": path,
		"trace_copy_matches_production": report.trace_copy_matches_production,
		"original_live_matches_production_rerun": report.original_live_matches_production_rerun,
		"scene_restored_exactly": report.scene_restored_exactly}
	print("CONVERGENCE_PROBE ", JSON.stringify(_json(allocation_report.convergence_probe)))

func _probe_run(test_policy: Dictionary, traced: bool) -> Dictionary:
	probe_adapter.call("_restore_commit_state", probe_scene.duplicate(true))
	var zero_counters: Dictionary = (probe_adapter.get("timings") as Dictionary).duplicate()
	for key in zero_counters: zero_counters[key] = 0
	probe_adapter.set("timings", zero_counters)
	probe_adapter.set("storage_validation_failures", {})
	probe_adapter.set("storage_validation_last_failure", {})
	var result: Dictionary
	var started := Time.get_ticks_usec()
	if traced:
		ProbeAllocator.begin_probe(12000)
		result = ProbeAllocator.solve(probe_input, Callable(probe_adapter, "_evaluate"), test_policy)
	else:
		result = OriginalAllocator.solve(probe_input, Callable(probe_adapter, "_evaluate"), test_policy)
	var report := {"policy": test_policy, "result": _probe_result(result),
		"instrumented_elapsed_ms": float(Time.get_ticks_usec() - started) / 1000.0,
		"counters": (probe_adapter.get("timings") as Dictionary).duplicate(true),
		"storage_validation_failures": (probe_adapter.get("storage_validation_failures") as Dictionary).duplicate(true),
		"storage_validation_last_failure": (probe_adapter.get("storage_validation_last_failure") as Dictionary).duplicate(true)}
	if traced:
		report["trace"] = ProbeAllocator.probe_trace.duplicate(true)
		report["trace_dropped_events"] = ProbeAllocator.probe_dropped_events
		for event: Dictionary in report.trace:
			if String(event.get("event", "")) == "task_qp":
				event["distal_conditioning"] = _probe_distal_conditioning(event.jacobian)
	return report

func _probe_result(result: Dictionary) -> Dictionary:
	var compact := result.duplicate(false)
	for key: String in ["accepted_payload", "motion_adapter", "accepted_pose"]: compact.erase(key)
	return compact.duplicate(true)

func _probe_equivalence(a: Dictionary, b: Dictionary) -> Dictionary:
	var qa := PackedFloat64Array(a.get("accepted_q", []))
	var qb := PackedFloat64Array(b.get("accepted_q", []))
	var error := 0.0
	if qa.size() == qb.size():
		for index: int in qa.size(): error = maxf(error, absf(qa[index] - qb[index]))
	else: error = INF
	return {"status": a.get("status") == b.get("status"), "reason": a.get("reason") == b.get("reason"),
		"task_scale": a.get("task_scale") == b.get("task_scale"), "q_max_abs_error": error,
		"accepted_weapon_exact": a.get("accepted_weapon") == b.get("accepted_weapon")}

func _probe_scene_checkpoint() -> Dictionary:
	var rotations: Array[Quaternion] = []
	for index: int in circle_actor.skeleton.get_bone_count():
		rotations.append(circle_actor.skeleton.get_bone_pose_rotation(index))
	return {"rotations": rotations, "weapon_world": circle_weapon.global_transform,
		"wrist_states": (circle_actor.get("_wrist_motion_states") as Dictionary).duplicate(true),
		"wrist_failures": (circle_actor.get("_wrist_motion_failures") as Dictionary).duplicate(true)}

func _probe_distal_conditioning(jacobian: Array) -> Dictionary:
	if jacobian.size() != 3: return {}
	var columns: Array[Vector3] = []
	var indices: Array[int] = []
	var groups: Array = probe_input.joint_groups
	for index: int in groups.size():
		if String(groups[index]) in ["elbow", "wrist"]:
			indices.append(index)
			columns.append(Vector3(jacobian[0][index], jacobian[1][index], jacobian[2][index]))
	if columns.size() != 3: return {"indices": indices}
	var determinant := columns[0].dot(columns[1].cross(columns[2]))
	var norm_product := columns[0].length() * columns[1].length() * columns[2].length()
	return {"indices": indices, "determinant": determinant,
		"normalized_abs_determinant": absf(determinant) / maxf(norm_product, 1.0e-30),
		"column_norms": [columns[0].length(), columns[1].length(), columns[2].length()]}
