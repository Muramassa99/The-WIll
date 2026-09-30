extends "res://tools/grip_plane_proof/run_coordinated_grip_closure_proof.gd"

# Bounded counterfactuals for the recorded Middle-only search. This is not a
# solver and never proposes production angles, rules or an accepted grip.
const BASELINE_REPORT := "C:/WORKSPACE/test_artifacts/coordinated_grip_closure_2026-09-18T04-33-42.json"

func _run() -> void:
	var loaded: Dictionary = Store.new().load_matching(Runner.DEFINITION_PATH, Runner.SIGNATURE, "rest_middle_thumb_surface_measurements_v1")
	if not loaded.get("valid", false):
		push_error(str(loaded)); quit(1); return
	var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_REPORT))
	if not baseline is Dictionary or not baseline.get("ok", false):
		push_error("Missing valid explicit closure baseline report"); quit(1); return
	var report := {"schema": "shared_closure_seed_diagnostic_v1", "baseline_report": BASELINE_REPORT,
		"baseline_sha256": FileAccess.get_sha256(BASELINE_REPORT), "cases": [], "failures": [],
		"production_pose_written": false, "grip_accepted": false, "search_exhaustive": false}
	var right_pattern: Array = []
	for recorded: Dictionary in baseline.cases:
		if recorded.slot == "hand_right" and recorded.digit == "middle" and recorded.kind == "actual":
			for angle: float in recorded.selected.angles_rad:
				right_pattern.append(angle / deg_to_rad(DigitRules.RIGHT_FINGER_CLOSED_DEGREES))
	for recorded: Dictionary in baseline.cases:
		if recorded.digit != "middle" or recorded.kind != "actual":
			continue
		var path := String(recorded.source_trace)
		if not _workspace_trace_path(path) or FileAccess.get_sha256(path) != recorded.source_trace_sha256:
			report.failures.append("invalid_or_changed_explicit_workspace_trace"); continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			report.failures.append("unreadable_trace"); continue
		var trace: Variant = file.get_var(false)
		file.close()
		if not trace is Dictionary or not trace.get("valid", false) or not trace.get("validation", {}).get("valid", false) or not trace.get("capture_errors", []).is_empty() or trace.get("anatomy_signature") != loaded.resource.source_signature:
			report.failures.append("invalid_coherent_trace"); continue
		var chosen: Dictionary = {}
		for transaction: Dictionary in trace.transactions:
			if transaction.slot == trace.slot and transaction.get("result", {}).get("applied", false) and not transaction.get("finger_inputs", []).is_empty():
				chosen = transaction
		if chosen.is_empty():
			report.failures.append("missing_matching_finger_input"); continue
		var context := _prepare_trial(loaded.resource, chosen, chosen.finger_inputs[-1], &"middle")
		if not context.get("valid", false):
			report.failures.append(context); continue
		var target: Dictionary = _depth_query.prepare_target(context.actual_polygon, context.plane_origin_id, &"ClosureTrial_actual", true)
		if not target.get("valid", false):
			report.failures.append(target); continue
		_trial_cache.clear()
		var seeds: Array = [
			["zero", [0.0, 0.0, 0.0]],
			["first_coupled_step", [0.25, 0.25, 0.25]],
			["first_joint1_step", [0.25, 0.0, 0.0]],
			["first_joint2_step", [0.0, 0.25, 0.0]],
			["first_joint3_step", [0.0, 0.0, 0.25]],
			["coupled_half", [0.5, 0.5, 0.5]],
			["coupled_three_quarters", [0.75, 0.75, 0.75]],
			["coupled_full", [1.0, 1.0, 1.0]]]
		if right_pattern.size() == 3:
			seeds.append(["recorded_right_fraction_pattern_probe_not_general_rule", right_pattern])
		var placements: Array[float] = [0.0]
		if float(recorded.selected.parameters[3]) != 0.0:
			placements.append(float(recorded.selected.parameters[3]))
		var rows: Array = []
		for placement: float in placements:
			var zero: Dictionary = _trial(context, target, [0.0, 0.0, 0.0, placement])
			for seed: Array in seeds:
				var parameters: Array[float] = []
				for index: int in range(3):
					parameters.append(clampf(float(context.input.snapshot.preferred_angles_rad[index]) * float(seed[1][index]), float(context.input.snapshot.min_angles_rad[index]), float(context.input.snapshot.max_angles_rad[index])))
				parameters.append(placement)
				var result: Dictionary = _trial(context, target, parameters)
				if not result.get("valid", false):
					report.failures.append(result); continue
				var snapshot: Dictionary = context.input.snapshot.duplicate(true)
				var hand: Transform3D = snapshot.root_parent_world
				hand.origin += context.slide_direction_world * placement
				snapshot.root_parent_world = hand
				var angles: Array[float] = [parameters[0], parameters[1], parameters[2]]
				var fk: Dictionary = Spatial.new()._forward_kinematics(snapshot, angles)
				var plane_inverse: Transform3D = context.plane.affine_inverse()
				var points: Array = []
				for point: Vector3 in fk.joint_origins_world:
					points.append(plane_inverse * point)
				points.append(plane_inverse * (fk.tip_world as Vector3))
				rows.append({"seed": seed[0], "signed_preferred_fractions": seed[1], "placement_m": placement,
					"trial": _trial_brief(result), "fk_points_in_fixed_plane_m": points,
					"hinge_axis_dot_plane_normal": (fk.hinge_axes_world[0] as Vector3).dot(context.plane.basis.z),
					"beats_zero_same_placement_phase0": _trial_better(result, zero, context.guide_initial_radius_m * 0.8, 0),
					"beats_zero_same_placement_final": _trial_better(result, zero, 0.0, 4)})
		report.cases.append({"slot": context.slot, "preferred_angles_rad": context.input.snapshot.preferred_angles_rad,
			"min_angles_rad": context.input.snapshot.min_angles_rad, "max_angles_rad": context.input.snapshot.max_angles_rad,
			"slice_center_m": context.slice_center_m, "plane_origin_id": context.plane_origin_id,
			"rows": rows, "candidate_count": rows.size()})
	report["ok"] = report.failures.is_empty()
	var path := "C:/WORKSPACE/test_artifacts/shared_closure_seed_diagnostic_" + Time.get_datetime_string_from_system().replace(":", "-") + ".json"
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write bounded seed diagnostic"); quit(1); return
	output.store_string(JSON.stringify(_numbers(report), "\t")); output.close()
	print("SHARED_CLOSURE_SEED_DIAGNOSTIC=" + path)
	quit(0 if report.ok else 1)
