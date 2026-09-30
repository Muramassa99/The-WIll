extends "res://tools/grip_plane_proof/run_full_hand_grip_proof.gd"

## Bounded extraction checks: same captured geometry through direct tool calls
## and a serial runtime worker; guide freeze; cancellation and host removal.
class CancellationJob extends "res://runtime/player/grip/handle_grip_acquisition.gd":
	func wait_for_cancellation() -> Dictionary:
		for tick: int in 2000:
			if _is_cancelled(): return _cancel_result()
			OS.delay_msec(1)
		return {"valid":false,"reason":"cancellation_test_timeout"}

var _checks: int = 0
var _failures: Array = []

func _report_stem() -> String:
	return "verify_handle_grip_acquisition"

func _check(condition: bool, label: String) -> void:
	_checks+=1
	if not condition: _failures.append(label)

func _without_timings(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if str(key).ends_with("_ms") or str(key).ends_with("_usec"): continue
			result[key]=_without_timings(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_without_timings(item))
		return result
	return value

func _search(context: Dictionary) -> Dictionary:
	var job := SharedGripAcquisition.new()
	var configured: Dictionary = job.configure_prepared(context,_config,root,_selected_digits())
	_check(configured.get("valid",false),"runtime configuration")
	if not configured.get("valid",false): return configured
	job._reset_acquisition()
	var parameters: Array = context.open_parameters.duplicate()
	var states: Array = []
	for phase: String in ["circle","hull_transition"]:
		var amount: float = 0.0 if phase=="circle" else 0.5
		var radius: float = 0.05 if phase=="circle" else 0.0
		_circle_cache.clear(); _slice_cache.clear(); _fixed_guides.clear(); _frozen_parameters.clear()
		_set_phase(phase,amount)
		var direct: Dictionary = _circle_sample(context,parameters,radius,true)
		job._set_phase(phase,amount)
		var threaded: Dictionary = await job._runtime_work("_circle_sample",[context,parameters,radius,true])
		_check(direct.get("valid",false) and threaded.get("valid",false),phase+" valid samples")
		_check(_without_timings(direct)==_without_timings(threaded),phase+" direct/worker complete geometry equality")
		states.append({"phase":phase,"direct_valid":direct.get("valid",false),"worker_valid":threaded.get("valid",false),
			"identical_excluding_timing":_without_timings(direct)==_without_timings(threaded)})
		if phase=="hull_transition" and threaded.get("valid",false):
			var frozen: Dictionary = await job._runtime_work("_freeze_guides",[context,threaded])
			_check(frozen.get("valid",false),"guide freeze succeeded without report dependency")
			for digit: Dictionary in threaded.digits:
				_check(_without_timings(job._fixed_guides[digit.digit])==_without_timings(digit.guide_geometry),"frozen exact guide "+str(digit.digit))
			var moved: Array = parameters.duplicate(); moved[-1]+=0.01; moved[-2]-=0.01
			var bounded: Array = job._clamped(context,moved)
			_check(bounded[-1]==parameters[-1] and bounded[-2]==parameters[-2],"reseat freezes both shared offsets")
	for scenario: String in ["cancel","host_removed","shutdown"]:
		var host := Node.new(); root.add_child(host)
		var cancelled := CancellationJob.new()
		var setup: Dictionary = cancelled.configure_prepared(context,_config,host,_selected_digits())
		_check(setup.get("valid",false),scenario+" configuration")
		if scenario=="cancel": process_frame.connect(cancelled.cancel,CONNECT_ONE_SHOT)
		elif scenario=="host_removed": process_frame.connect(host.free,CONNECT_ONE_SHOT)
		else: process_frame.connect(cancelled.shutdown,CONNECT_ONE_SHOT)
		var stopped: Dictionary = await cancelled._runtime_work("wait_for_cancellation",[])
		_check(stopped.get("cancelled",false) and not stopped.get("valid",false),scenario+" cancellation returned")
		_check(cancelled._worker==null,scenario+" worker joined")
		if is_instance_valid(host): host.free()
	_check(job._parameter_count()==17,"all fifteen hinges plus two shared offsets")
	var valid: bool = _failures.is_empty()
	print("ACQUISITION_EXTRACTION_CHECKS="+JSON.stringify({"slot":context.slot,"checks":_checks,"failures":_failures}))
	return {"valid":valid,"slot":context.slot,"checks":_checks,"failures":_failures.duplicate(),"states":states,
		"production_pose_written":false,"grip_accepted":false}
