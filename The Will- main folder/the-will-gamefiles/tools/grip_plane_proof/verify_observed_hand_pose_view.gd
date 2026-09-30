extends SceneTree

const Observed = preload("res://tools/grip_plane_proof/observed_hand_pose_view.gd")
const Contact = preload("res://tools/grip_plane_proof/prepared_grip_slice_contact.gd")
const Store = preload("res://tools/grip_plane_proof/character_hand_anatomy_store.gd")
const Extension = preload("res://tools/grip_plane_proof/extend_prepared_anatomy_capture.gd")
const Inputs = preload("res://tools/grip_plane_proof/run_prepared_skin_contact_proof.gd")
const DIGITS: Array[StringName] = [&"middle",&"thumb",&"index",&"ring",&"pinky"]
const LBS_ROUNDOFF_M: float = 0.000003
var _checks: int = 0
var _failures: Array[String] = []
var _cases: Array = []
var _faults: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var path: String = OS.get_environment("THE_WILL_ANATOMY_RESOURCE_PATH").strip_edges().simplify_path()
	if not path.begins_with("res://tools/grip_plane_proof/prepared_characters/josie/") or path.get_extension() != "tres":
		push_error("Explicit full-hand anatomy resource required"); quit(1); return
	var loaded: Dictionary = Store.new().load_matching(path,path.get_file().get_basename(),Store.FULL_HAND_PREPARATION_REVISION)
	var old: Dictionary = Store.new().load_matching(Inputs.DEFINITION_PATH,Inputs.SIGNATURE,"rest_middle_thumb_surface_measurements_v1")
	if not _check(loaded.get("valid",false) and old.get("valid",false),"prepared definitions load"):
		quit(1); return
	var anatomy_before: PackedByteArray = _definition_bytes(loaded.resource)
	var paths: PackedStringArray = OS.get_environment("THE_WILL_GRIP_PLACEMENT_PATHS").split(";",false)
	_check(not paths.is_empty(),"explicit captured trace paths supplied")
	var slots: Dictionary = {}
	for requested: String in paths:
		var source: String = requested.strip_edges().replace("\\","/").simplify_path()
		if not _check(source.to_lower().begins_with("c:/workspace/test_artifacts/") and source.get_extension() == "bin","trace confined to workspace test artifacts"): continue
		var source_hash: String = FileAccess.get_sha256(source)
		var file := FileAccess.open(source,FileAccess.READ)
		if not _check(file != null,"capture readable"): continue
		var raw: Variant = file.get_var(false); file.close()
		if not _check(raw is Dictionary and raw.get("valid",false) and raw.get("schema") == "grip_placement_trace_v1","valid original placement trace"): continue
		var before: PackedByteArray = var_to_bytes(raw)
		var trace: Dictionary = raw
		if trace.anatomy_signature == old.resource.source_signature:
			var extension: Dictionary = Extension.new().extend_trace(old.resource,loaded.resource,trace)
			if not _check(extension.get("valid",false),"explicit same-skin anatomy extension"): continue
			trace = extension.trace
		if not _check(trace.anatomy_signature == loaded.resource.source_signature,"capture uses selected measured anatomy"): continue
		var chosen: Dictionary = {}
		for transaction: Dictionary in trace.transactions:
			if transaction.get("result",{}).get("applied",false) and not transaction.get("finger_inputs",[]).is_empty(): chosen = transaction
		if not _check(not chosen.is_empty(),"actual capture has complete placement transaction"): continue
		var slot: StringName = trace.slot; slots[slot] = true
		var stages: Array = [chosen.before,chosen.finger_inputs[-1]]
		for stage: Dictionary in stages:
			if not _check(stage.get("valid",false) and stage.get("posed_character") is Dictionary,"captured observation stage present"): continue
			_test_observation(loaded.resource,stage.posed_character,slot,source+"/"+str(stage.stage))
		_test_faults(loaded.resource,chosen.finger_inputs[-1].posed_character,slot)
		_check(var_to_bytes(raw) == before and FileAccess.get_sha256(source) == source_hash,"original trace memory and file remain unchanged")
	_check(slots.has(&"hand_right") and slots.has(&"hand_left"),"both actual hand setups observed")
	_check(_definition_bytes(loaded.resource) == anatomy_before,"prepared anatomy remains byte-identical")
	var report := {"schema":"verify_observed_hand_pose_view_v1","ok":_failures.is_empty(),"checks":_checks,"failures":_failures,
		"cases":_cases,"faults":_faults,"anatomy_path":path,"anatomy_signature":loaded.resource.source_signature,
		"helper_sha256":FileAccess.get_sha256("res://tools/grip_plane_proof/observed_hand_pose_view.gd"),
		"geometry_oracle":"original_arrays_weights_bind_poses_and_independently_composed_CAPTURED_frames",
		"original_weight_sums_preserved":true,"skin_geometry_roundoff_guard_m":LBS_ROUNDOFF_M,
		"production_pose_written":false,"arm_realization_verified":false,"actual_3d_grip_verified":false,"grip_accepted":false}
	var output: String = "C:/WORKSPACE/test_artifacts/verify_observed_hand_pose_view_"+Time.get_datetime_string_from_system().replace(":","-")+".json"
	if FileAccess.file_exists(output): push_error("Refusing to replace observation verifier"); quit(1); return
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null: push_error("Cannot write observation verifier"); quit(1); return
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("OBSERVED_HAND_VERIFIER="+output)
	print("OBSERVED_HAND_SUMMARY="+JSON.stringify({"ok":report.ok,"checks":_checks,"failures":_failures,"faults":_faults.size()}))
	quit(0 if report.ok else 1)


func _test_observation(definition: Resource, capture: Dictionary, slot: StringName, label: String) -> void:
	var before: PackedByteArray = var_to_bytes(capture)
	var observed: Dictionary = Observed.new().observe(definition,capture,slot,DIGITS)
	if not _check(observed.get("valid",false),label+" observed: "+str(observed.get("reason",""))): return
	var view: Dictionary = observed.view
	_check(var_to_bytes(capture) == before,label+" source capture unchanged")
	_check(not view.grip_accepted and not observed.grip_accepted and not view.arm_realization_verified and not view.actual_3d_grip_verified,label+" no acceptance or arm realization claim")
	_check(view.observed_not_reposed and not observed.geometry_reposed and not view.hypothetical_placement_only,label+" measured geometry provenance")
	_check(view.posed.vertices_world == observed.adapter.base_pose.vertices_world and view.posed.vertices_machine == observed.adapter.base_pose.vertices_machine,label+" original captured skin retained exactly")
	_check(view.pose_packet.machine_to_world == capture.machine_to_world and view.pose_packet.bone_origin_ids == capture.bone_origin_ids,label+" presentation and bone identities preserved")
	_check(view.pose_packet.pose_id == capture.pose_id and view.pose_packet.source_pose_id == capture.pose_id,label+" view retains exact captured pose epoch")
	for index: int in capture.origin_records.size():
		_check(var_to_bytes(view.pose_packet.origin_records[index]) == var_to_bytes(capture.origin_records[index]),label+" original affine origin record unchanged "+str(index))
	var frames: Dictionary = _captured_frames(capture)
	if not _check(frames.get("valid",false),label+" independent original origin composition"): return
	var errors: Dictionary = _oracle(definition.reference_skin,capture,frames,view.posed)
	_check(errors.machine_m <= LBS_ROUNDOFF_M and errors.world_m <= LBS_ROUNDOFF_M,label+" actual skin equals independent original-array LBS")
	var slices: Array = []
	for id: StringName in DIGITS:
		var state: Dictionary = view.digit_states[id]
		for joint: int in 3:
			var actual: Transform3D = capture.machine_to_world * (frames.bones[state.snapshot.bone_names[joint]] as Transform3D)
			_check(state.joint_transforms_world[joint] == actual,label+" actual "+str(id)+" joint frame retained "+str(joint))
		var ready: Dictionary = Contact.new().prepare(observed.adapter,id)
		if not _check(ready.get("valid",false),label+" prepare observation "+str(id)): continue
		var sliced: Dictionary = Contact.new().slice_candidate(ready,view,state.plane_to_world,state.plane_origin_id)
		_check(sliced.get("valid",false),label+" actual skin slice "+str(id)+": "+str(sliced.get("reason","")))
		if sliced.get("valid",false):
			_check(sliced.pose_id == capture.pose_id and not sliced.grip_accepted and not sliced.actual_3d_grip_verified,label+" slice retains observation scope")
			for edge: Dictionary in sliced.segments:
				_check(edge.origin_id == state.plane_origin_id and not str(edge.source_id).is_empty(),label+" edge has source and named plane")
			slices.append({"digit":id,"segments":sliced.segments.size(),"owned_counts":[sliced.owned[0].size(),sliced.owned[1].size(),sliced.owned[2].size()]})
	_check(slices.size() == 5,label+" all five actual planes remain queryable")
	_cases.append({"label":label,"slot":slot,"source_pose_id":capture.pose_id,"skin_error":errors,"slices":slices,
		"articulation_valid":observed.articulation_valid,"articulation":observed.articulation,"grip_accepted":false})


func _test_faults(definition: Resource, capture: Dictionary, slot: StringName) -> void:
	var tool := Observed.new()
	var base: Dictionary = tool.observe(definition,capture,slot,DIGITS)
	if not _check(base.get("valid",false),str(slot)+" fault source observation available"): return
	var broken: Dictionary = capture.duplicate(true); broken.anatomy_signature = "wrong_signature"
	_reject(tool.observe(definition,broken,slot,DIGITS),str(slot)+" wrong source signature")
	broken = capture.duplicate(true)
	broken.bone_origin_ids.erase(base.adapter.digit_inputs[&"middle"].snapshot.bone_names[0])
	_reject(tool.observe(definition,broken,slot,DIGITS),str(slot)+" missing bone contributor")
	broken = capture.duplicate(true); broken.candidate_not_captured_pose = true
	_reject(tool.observe(definition,broken,slot,DIGITS),str(slot)+" synthetic candidate cannot masquerade as actual capture")
	broken = capture.duplicate(true); broken.machine_to_world = Transform3D(Basis.IDENTITY,Vector3(NAN,0,0))
	_reject(tool.observe(definition,broken,slot,DIGITS),str(slot)+" nonfinite presentation")
	var state: Dictionary = base.view.digit_states[&"middle"]
	var ready: Dictionary = Contact.new().prepare(base.adapter,&"middle")
	var wrong_plane: Transform3D = state.plane_to_world; wrong_plane.origin += wrong_plane.basis.x*0.003
	_reject(Contact.new().slice_candidate(ready,base.view,wrong_plane,state.plane_origin_id),str(slot)+" mismatched observed plane")
	var collision: Dictionary = capture.duplicate(true)
	collision.origin_records.append(base.adapter.digit_inputs[&"middle"].origin_records[0].duplicate(true))
	_reject(tool.observe(definition,collision,slot,DIGITS),str(slot)+" existing source cannot own observation origin")
	var high: float = state.snapshot.max_angles_rad[2]
	var low: float = state.snapshot.min_angles_rad[2]
	var limit_fault: Dictionary = _changed_terminal(capture,base.adapter,high+0.1,false)
	var measured: Dictionary = tool.observe(definition,limit_fault,slot,DIGITS)
	if _check(measured.get("valid",false),str(slot)+" out-of-range actual geometry remains observable"):
		var report: Dictionary = measured.view.digit_states[&"middle"].articulation_measurements[2]
		_check(not report.within_range_numeric_guard and not measured.articulation_valid,str(slot)+" measured authored-limit violation reported")
		_check(absf(report.measured_twist_angle_rad-(high+0.1)) <= 0.00002 and not report.angle_was_clamped,str(slot)+" out-of-range twist not clamped")
		_check(not measured.grip_accepted and not measured.view.grip_accepted and not measured.view.articulation_valid,str(slot)+" invalid articulation cannot become accepted grip")
		var frames: Dictionary = _captured_frames(limit_fault)
		var errors: Dictionary = _oracle(definition.reference_skin,limit_fault,frames,measured.view.posed)
		_check(errors.world_m <= LBS_ROUNDOFF_M,str(slot)+" limit violation keeps actual skin without reposing")
		_faults.append({"label":str(slot)+" measured limit fault","reported":true,"joint":report,"skin_error":errors})
	var axis_fault: Dictionary = _changed_terminal(capture,base.adapter,(low+high)*0.5,true)
	measured = tool.observe(definition,axis_fault,slot,DIGITS)
	if _check(measured.get("valid",false),str(slot)+" off-axis actual geometry remains observable"):
		var report: Dictionary = measured.view.digit_states[&"middle"].articulation_measurements[2]
		_check(report.off_axis_error_rad > Observed.OFF_AXIS_TOLERANCE_RAD and not measured.articulation_valid,str(slot)+" off-axis motion reported separately")
		_check(not report.pose_was_reprojected and not measured.grip_accepted,str(slot)+" off-axis articulation never reprojected or accepted")
		_faults.append({"label":str(slot)+" measured off-axis fault","reported":true,"joint":report})


func _changed_terminal(capture: Dictionary, adapter: Dictionary, angle: float, off_axis: bool) -> Dictionary:
	# Synthetic fault only: alter one captured terminal frame in its declared
	# machine space. Observation must measure this supplied pose, not repair it.
	var result: Dictionary = capture.duplicate(true)
	var snapshot: Dictionary = adapter.digit_inputs[&"middle"].snapshot
	var parent: Transform3D = adapter.base_frames[snapshot.bone_names[1]]
	var relative: Transform3D = snapshot.relative_transforms[2]
	var axis: Vector3 = (snapshot.hinge_axes_local[2] as Vector3).normalized()
	relative.basis = relative.basis * Basis(snapshot.neutral_local_rotations[2]) * Basis(axis,angle)
	if off_axis:
		var other: Vector3 = axis.cross(Vector3.RIGHT)
		if other.length_squared() < 0.1: other = axis.cross(Vector3.UP)
		relative.basis = relative.basis * Basis(other.normalized(),0.2)
	var wanted: StringName = result.bone_origin_ids[snapshot.bone_names[2]]
	for record: Dictionary in result.origin_records:
		if record.origin_id == wanted:
			_check(record.parent_origin_id == &"RL_BoneRoot","fault target frame has captured machine parent")
			record.transform_to_parent = parent * relative
	return result


func _captured_frames(packet: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for record: Dictionary in packet.origin_records: records[record.origin_id] = record
	var bones: Dictionary = {}
	for name: Variant in packet.bone_origin_ids:
		var frame: Dictionary = _direct_frame(records,packet.bone_origin_ids[name])
		if not frame.valid: return frame
		bones[name] = frame.frame
	var mesh: Dictionary = _direct_frame(records,packet.mesh_origin_id)
	return {"valid":mesh.valid,"bones":bones,"mesh":mesh.get("frame")}


func _direct_frame(records: Dictionary, id: StringName) -> Dictionary:
	var frame := Transform3D.IDENTITY
	var seen: Dictionary = {}
	var current: StringName = id
	while current != &"RL_BoneRoot":
		if seen.has(current) or not records.has(current): return {"valid":false}
		seen[current] = true
		frame = (records[current].transform_to_parent as Transform3D)*frame
		current = StringName(records[current].parent_origin_id)
	return {"valid":true,"frame":frame}


func _oracle(reference: Dictionary, packet: Dictionary, frames: Dictionary, posed: Dictionary) -> Dictionary:
	# Independent original-array LBS; no Candidate evaluator, prepared weighted
	# coefficients or observation-returned bone transforms are used here.
	var vertex_index: int = 0
	var machine_error: float = 0.0
	var world_error: float = 0.0
	for surface: Dictionary in reference.surfaces:
		var vertices: PackedVector3Array = surface.vertices
		var weights: PackedFloat32Array = surface.weights
		var width: int = weights.size()/vertices.size()
		for index: int in vertices.size():
			var point := Vector3.ZERO # accumulator explicitly in RL_BoneRoot
			var total: float = 0.0
			for influence: int in width:
				var offset: int = index*width+influence
				var weight: float = weights[offset]
				if weight == 0.0: continue
				var bind: int = surface.bones[offset]
				var name: StringName = reference.bind_bone_names[bind]
				point += weight*((frames.bones[name] as Transform3D)*((reference.bind_poses[bind] as Transform3D)*vertices[index]))
				total += weight
			point += (1.0-total)*(frames.mesh as Transform3D).origin
			var world: Vector3 = packet.machine_to_world*point
			machine_error = maxf(machine_error,point.distance_to(posed.vertices_machine[vertex_index]))
			world_error = maxf(world_error,world.distance_to(posed.vertices_world[vertex_index]))
			vertex_index += 1
	return {"machine_m":machine_error,"world_m":world_error,"vertices":vertex_index}


func _definition_bytes(definition: Resource) -> PackedByteArray:
	var data: Dictionary = {}
	for field: String in Store.FIELDS: data[field] = definition.get(field)
	return var_to_bytes(data)


func _reject(result: Dictionary, label: String) -> void:
	_check(not result.get("valid",false),label+" rejected")
	_faults.append({"label":label,"rejected":not result.get("valid",false),"reason":result.get("reason","")})


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition: _failures.append(label)
	return condition
