extends "res://runtime/player/grip/handle_grip_acquisition.gd"

## Observe the skin actually produced by the rig, without replacing it with a
## calibrated candidate pose. This reuses acquisition's exact material query;
## it does not run closure, reseating, native IK, or write a scene pose.
const ActualView = preload("res://runtime/player/grip/observed_hand_pose_view.gd")

var _actual_view: Dictionary = {}


func assess(anatomy: Resource, capture: Dictionary, config: Dictionary, host: Node) -> Dictionary:
	var configured: Dictionary = configure(anatomy, capture, config, host)
	if not configured.get("valid", false):
		return configured
	_running = true
	_progress_update({"stage": "assessing_actual_skin", "running": true})
	var result: Dictionary = await _runtime_work(&"_assess", [])
	_actual_view.clear()
	_running = false
	_progress_update({"stage": "actual_skin_assessment_complete", "running": false})
	return result


func _assess() -> Dictionary:
	var started := Time.get_ticks_usec()
	_actual_view.clear()
	_reset_acquisition()
	var observed: Dictionary = ActualView.new().observe(_definition,
		_capture_input.posed_character, _capture_input.slot, _selected_digits())
	if not observed.get("valid", false):
		return {"valid": false, "reason": "actual_pose_observation_failed", "details": observed}
	if _is_cancelled():
		return _cancel_result()
	# Preparation is bound to the new captured epoch. Never reuse a hypothetical
	# rigidly translated forearm, an earlier palm identity, or frozen guide cache.
	var context: Dictionary = _prepare(_definition, _capture_input)
	if not context.get("valid", false):
		return {"valid": false, "reason": "actual_material_context_failed", "details": context}
	_actual_view = observed.view
	var parameters: Array = _zero_parameters()
	var digits: Array[StringName] = _selected_digits()
	for digit_index: int in digits.size():
		for joint: int in 3:
			parameters[digit_index * 3 + joint] = observed.view.digit_states[digits[digit_index]].angles_rad[joint]
	_circle_cache.clear()
	_slice_cache.clear()
	_set_phase("circle", 0.0)
	# Radius zero is the established material-assessment seam, not a new guide
	# shrink or any claim that the realized hand preserves the prior frozen guide.
	var material: Dictionary = _circle_sample(context, parameters, 0.0, true)
	_actual_view.clear()
	material["planar_predicate_only_not_acceptance"] = material.get("diagnostic_grip_accepted", false)
	material["diagnostic_grip_accepted"] = false
	material["grip_accepted"] = false
	material["actual_3d_grip_verified"] = false
	var contacts: Array = material.get("material_contacts", [])
	var safe: bool = material.get("valid", false) and material.get("material_safe", false)
	return {"valid": material.get("valid", false), "reason": material.get("reason", ""),
		"slot": _capture_input.slot, "source_pose_id": observed.source_pose_id,
		"selected": material, "material_query_valid": material.get("valid", false),
		"actual_material_safe": safe, "actual_material_contacts": contacts,
		"actual_material_contact_count": contacts.size(), "minimum_distinct_sections": MIN_MATERIAL_SECTIONS,
		"planar_material_contact_condition": safe and contacts.size() >= MIN_MATERIAL_SECTIONS,
		"actual_articulation": observed.articulation, "articulation_valid": observed.articulation_valid,
		"observed_not_reposed": true, "source_capture_unchanged": observed.source_capture_unchanged,
		"source_capture_sha256": observed.source_capture_sha256,
		"assessment_scope": &"actual_skin_on_selected_digit_planes_not_whole_hand_3d_certificate",
		"frozen_wrapper_preservation_verified": false,
		"grip_accepted": false, "actual_3d_grip_verified": false, "production_pose_written": false,
		"assessment_ms": float(Time.get_ticks_usec() - started) / 1000.0}


func _rigid_candidate(context: Dictionary, parameters: Array, translation: Vector3) -> Dictionary:
	if not _actual_view.is_empty():
		return _actual_view
	return super._rigid_candidate(context, parameters, translation)
