extends RefCounted

## Live transaction boundary for V6 surface contact. Scene reads
## and application stay in preview_grip_acquisition; one owned worker prepares
## and solves detached input. Cancellation is observed between bounded steps.
const Solver = preload("res://runtime/player/grip/surface_driven_grip_solver.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const ROOT := &"RL_BoneRoot"
const DIGITS := [&"index", &"middle", &"ring", &"pinky", &"thumb"]
var _anatomy: Resource
var _capture: Dictionary={}
var _config: Dictionary={}
var _tree: SceneTree
var _host: WeakRef
var _worker: Thread
var _mutex := Mutex.new()
var _cancel_requested := false
var _running := false
var _configured := false
var _progress: Dictionary={}

func configure(anatomy: Resource,capture: Dictionary,config: Dictionary,host: Node) -> Dictionary:
	if _running: return {"valid":false,"reason":"acquisition_already_running"}
	_configured=false
	if anatomy==null or not capture.get("posed_character") is Dictionary or not capture.get("object") is Dictionary:
		return {"valid":false,"reason":"missing_acquisition_input"}
	if capture.get("slot") not in [&"hand_right",&"hand_left"] or not is_instance_valid(host) or not host.is_inside_tree():
		return {"valid":false,"reason":"invalid_acquisition_slot_or_host"}
	if not capture.get("saved_grip_source",{}).get("valid",false):
		return {"valid":false,"reason":capture.get("saved_grip_source",{}).get("reason","missing_saved_wrapper_source")}
	_anatomy=anatomy
	_capture=capture.duplicate(true)
	_config=config.duplicate(true)
	# One pose owner fits the four fingers, then Thumb at the established seat.
	_config.erase("selected_digits")
	_tree=host.get_tree()
	_host=weakref(host)
	_cancel_requested=false
	_progress={"stage":"configured","running":false,"method":"surface_contact_v6"}
	_configured=true
	return {"valid":true}

func cancel() -> void:
	_mutex.lock()
	_cancel_requested=true
	_mutex.unlock()

func _is_cancelled() -> bool:
	_mutex.lock()
	var result := _cancel_requested
	_mutex.unlock()
	return result

func _progress_update(values: Dictionary) -> void:
	_mutex.lock()
	_progress.merge(values,true)
	_mutex.unlock()

func progress() -> Dictionary:
	_mutex.lock()
	var result := _progress.duplicate(true)
	_mutex.unlock()
	return result

func shutdown() -> void:
	cancel()
	if _worker!=null and _worker.is_started(): _worker.wait_to_finish()
	_worker=null

func solve() -> Dictionary:
	if _running or not _configured: return {"valid":false,"reason":"acquisition_not_configured_or_running"}
	_running=true
	_progress_update({"stage":"preparing","running":true})
	var span := Chronology.begin("saved_acquisition.solve",{"slot":_capture.slot,"digits":DIGITS})
	_worker=Thread.new()
	var active := _worker
	var error := active.start(Callable(self,"_work"))
	if error!=OK:
		_worker=null; _running=false; _configured=false
		Chronology.finish(span,{"valid":false,"reason":"worker_start_failed"})
		return {"valid":false,"reason":"acquisition_worker_start_failed","error":error}
	while active.is_alive():
		var host: Variant=_host.get_ref()
		if host==null or not is_instance_valid(host) or not host.is_inside_tree(): cancel()
		await _tree.process_frame
	var value: Variant=active.wait_to_finish() if active.is_started() else null
	_worker=null; _running=false; _configured=false
	var result: Dictionary=value if value is Dictionary else {"valid":false,"reason":"invalid_worker_result"}
	if _is_cancelled(): result.merge({"valid":false,"cancelled":true,"reason":"acquisition_cancelled"},true)
	_progress_update({"stage":"cancelled" if _is_cancelled() else "complete","running":false,"valid":result.get("valid",false)})
	Chronology.finish(span,{"valid":result.get("valid",false),"reason":result.get("reason",""),"cancelled":result.get("cancelled",false),"total_ms":result.get("total_ms",0.0)})
	return result

func _work() -> Dictionary:
	var started := Time.get_ticks_usec()
	if _is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
	var solver := Solver.new()
	solver.configure_lifecycle(Callable(self,"_is_cancelled"),Callable(self,"_progress_update"))
	# Private prepared data only: no scene, exact slices or circle progression.
	var solver_started := Time.get_ticks_usec()
	var result: Dictionary=solver.run(_anatomy,_capture,_config)
	var solver_elapsed_ms := float(Time.get_ticks_usec()-solver_started)/1000.0
	result.merge(solver.diagnostic_snapshot(),true)
	if not result.has("total_ms"): result["total_ms"]=solver_elapsed_ms
	result["source_weapon_to_world"]=_capture.object.weapon_to_world
	result["source_weapon_to_world_origin_id"]=ROOT
	result["vectors_origin_id"]=ROOT
	result["contact_backend"]="native_nearest_surface_bvh"
	result["transaction_total_ms"]=float(Time.get_ticks_usec()-started)/1000.0
	return result
