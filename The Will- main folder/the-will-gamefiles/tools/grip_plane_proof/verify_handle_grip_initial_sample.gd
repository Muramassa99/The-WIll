extends "res://tools/grip_plane_proof/run_handle_grip_process_proof.gd"


func _report_stem() -> String:
	return "verify_handle_grip_initial_sample"


func _search(context: Dictionary) -> Dictionary:
	_circle_cache.clear(); _slice_cache.clear(); _invalid.clear()
	_circle_evaluations = 0
	_set_phase("circle", 0.0)
	var parameters: Array = context.open_parameters.duplicate()
	var sample: Dictionary = _circle_sample(context, parameters, 0.05, true)
	print("INITIAL_HANDLE_SAMPLE=" + JSON.stringify(_json({"slot": context.slot,
		"parameters": parameters, "valid": sample.get("valid", false), "reason": sample.get("reason"), "details": sample.get("details")})))
	var translation: Vector3 = context.translation_u_world * float(parameters[6]) + context.translation_v_world * float(parameters[7])
	var candidate: Dictionary = _rigid_candidate(context, parameters, translation)
	var details: Array = []
	if candidate.get("valid", false):
		for digit: StringName in DIGITS:
			var state: Dictionary = candidate.digit_states[digit]
			var prepared: Dictionary = context.observations[digit].duplicate()
			prepared.machine_to_world = candidate.pose_packet.machine_to_world
			var slice: Dictionary = _observer.slice_candidate(prepared, candidate, state.plane_to_world, state.plane_origin_id)
			if not slice.get("valid", false): details.append(slice); continue
			var annotated: Dictionary = _palm.annotate(context.palm_region, candidate, slice, state.plane_to_world)
			if not annotated.get("valid", false): details.append(annotated); continue
			var zero_edges: Array = []
			for edge: Dictionary in annotated.segments:
				if edge.a == edge.b: zero_edges.append(edge)
			details.append({"digit": digit, "original_count": slice.segments.size(),
				"annotated_count": annotated.segments.size(), "zero_edges": zero_edges})
	print("INITIAL_HANDLE_EDGE_DIAGNOSTICS=" + JSON.stringify(_json({"slot": context.slot, "details": details})))
	return {"valid": sample.get("valid", false), "reason": sample.get("reason", ""), "slot": context.slot,
		"selected": sample, "edge_diagnostics": details, "evaluation_count": _circle_evaluations,
		"production_pose_written": false, "grip_accepted": false}
