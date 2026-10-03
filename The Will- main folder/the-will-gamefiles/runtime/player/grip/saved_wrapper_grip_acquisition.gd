extends RefCounted

## Live transaction boundary for the accepted saved-wrapper method. Scene reads
## and application stay in preview_grip_acquisition; one owned worker prepares
## and solves detached input. Cancellation is observed between bounded steps.
const Context = preload("res://runtime/player/grip/saved_wrapper_grip_context.gd")
const Solver = preload("res://runtime/player/grip/contact_driven_grip_preparation.gd")
const Chronology = preload("res://runtime/player/grip/grip_chronology.gd")
const ROOT := &"RL_BoneRoot"
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
	for native_class: StringName in [&"GripSavedContactKernel",&"GripSliceKernel",&"GripTopologyKernel"]:
		if not ClassDB.class_exists(native_class): return {"valid":false,"reason":"required_grip_extension_missing","class":native_class}
	_anatomy=anatomy
	_capture=capture.duplicate(true)
	_config=config.duplicate(true)
	# The production transaction always prepares every digit; tool selection
	# options never silently reduce a live hand to a subset.
	_config.erase("selected_digits")
	_tree=host.get_tree()
	_host=weakref(host)
	_cancel_requested=false
	_progress={"stage":"configured","running":false,"method":"saved_wrapper_contact_cpp"}
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
	var span := Chronology.begin("saved_acquisition.solve",{"slot":_capture.slot,"digits":Context.DIGITS})
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
	if _is_cancelled(): result={"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
	_progress_update({"stage":"cancelled" if _is_cancelled() else "complete","running":false,"valid":result.get("valid",false)})
	Chronology.finish(span,{"valid":result.get("valid",false),"reason":result.get("reason",""),"cancelled":result.get("cancelled",false),"total_ms":result.get("total_ms",0.0)})
	return result

func _work() -> Dictionary:
	var started := Time.get_ticks_usec()
	var span := Chronology.begin("saved_acquisition.prepare",{"slot":_capture.slot})
	var prepared := Context.new().prepare(_anatomy,_capture,_config)
	Chronology.finish(span,{"valid":prepared.get("valid",false),"reason":prepared.get("reason","")})
	if _is_cancelled(): return {"valid":false,"cancelled":true,"reason":"acquisition_cancelled"}
	if not prepared.get("valid",false): return prepared
	var solver := Solver.new()
	solver.configure_lifecycle(Callable(self,"_is_cancelled"),Callable(self,"_progress_update"))
	# No host: run's numerical path does not await or read a scene on this worker.
	var result: Dictionary=solver.run(prepared.context,prepared.saved,null)
	result["source_weapon_to_world"]=_capture.object.weapon_to_world
	result["source_weapon_to_world_origin_id"]=ROOT
	result["vectors_origin_id"]=ROOT
	result["contact_backend"]="cpp_saved_contact_batch"
	result["transaction_total_ms"]=float(Time.get_ticks_usec()-started)/1000.0
	return result
